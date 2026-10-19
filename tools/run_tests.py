#!/usr/bin/env python3
"""make test: the test files run in several headless Godot processes at once (P2).

Every process runs tests/test_runner.tscn with --claim=<a folder of this run's>: it goes down the same list of files,
longest first, and takes the next one no other process has claimed, so no process sits idle while another still has
a queue. Times come from .godot/test_times.json (this checkout's last runs, written after each run) or else
tests/support/test_times.json (a copy kept in the repo for fresh checkouts); a file with no time yet goes first.

A file longer than half a process's share goes out a test at a time instead (the runner's --split), so the
playthrough tests and the spell sweep run side by side rather than setting the finish.

Output comes a file at a time as each finishes, with that file's lines together. The summary adds up every process,
and the run fails if a test failed, a process stopped before finishing its file, a file never ran, or no tests ran.

How many processes: JOBS=n, or by default as many as there are idle cores (ps) and free memory (vm_stat, about 1.5 GB
each at their peak) for right now, between 2 and 8, since other threads' tests, renders and the owner's own game share
the Mac. Past 8 the two longest files (the spell sweep and the Phase 5 exit) set the time anyway. JOBS=1 runs the
single process make test used to.

Across all lanes at most TEST_SLOTS (8) of these processes run at once, and so at most IMPORT_SLOTS (3) import editors
(tools/godot_slot.sh has why and how): a process takes a slot before it starts and waits for one if they are all in
use, and a process still waiting when another has run out of files gives up, since there is nothing left for it.
GODOT_SLOTS=off turns the cap off. The top BUILD_TEST_SLOTS (5) of the 8 are kept for the build lane (BUILD_LANE=1, or
.godot/build-lane in the checkout, see tools/godot_slot.sh): a development lane only claims the other three, the build
lane tries the reserved ones first and then the rest.

make test [ONLY=substr] [FILES=a.gd,b.gd] [JOBS=n]   Stdlib only.
"""
from __future__ import annotations

import argparse
import json
import os
import random
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEST_DIRS = ("tests/unit", "tests/integration")
LOCAL_TIMES = os.path.join(ROOT, ".godot", "test_times.json")
REPO_TIMES = os.path.join(ROOT, "tests", "support", "test_times.json")
MAX_JOBS = 8
WORKER_GB = 1.5
SLOT_ROOT = os.environ.get("STRAHD_SLOT_ROOT", "/tmp/strahd-godot-slots-%d" % os.getuid())
# Each pool's size (the default of its limit) and how many of its top slots the build lane keeps (tools/godot_slot.sh).
POOL_SIZE = {"test": 8, "import": 3}
BUILD_RESERVE = {"test": ("BUILD_TEST_SLOTS", 5), "import": ("BUILD_IMPORT_SLOTS", 1)}
SUMMARY = re.compile(r"^\d+ tests, \d+ passed, \d+ failed$")
# What tools/logcheck.sh fails a run on, besides FAIL lines.
ERROR = re.compile(r"SCRIPT ERROR|ERROR:|Parse Error|Failed loading|WARNING: .*GDScript")


def test_files() -> list[str]:
    """Every test file, in the order the single runner takes them (tests/unit, then tests/integration)."""
    out = []
    for d in TEST_DIRS:
        full = os.path.join(ROOT, d)
        if os.path.isdir(full):
            out += sorted(f for f in os.listdir(full) if f.startswith("test_") and f.endswith(".gd"))
    return out


def load_times() -> dict[str, int]:
    times: dict[str, int] = {}
    for path in (REPO_TIMES, LOCAL_TIMES):  # this checkout's own times win
        try:
            with open(path, encoding="utf-8") as f:
                times.update({k: int(v) for k, v in json.load(f).items()})
        except (OSError, ValueError):
            pass
    return times


def save_times(new: dict[str, int]) -> None:
    times = {}
    try:
        with open(LOCAL_TIMES, encoding="utf-8") as f:
            times = json.load(f)
    except (OSError, ValueError):
        pass
    times.update(new)
    try:
        with open(LOCAL_TIMES, "w", encoding="utf-8") as f:
            json.dump(dict(sorted(times.items())), f, indent=1)
            f.write("\n")
    except OSError:
        pass


def default_jobs() -> int:
    """As many processes as there are idle cores (the load average overstates it on macOS) and free memory for, between
    2 and MAX_JOBS. Each process peaks at about WORKER_GB."""
    cores = os.cpu_count() or 4
    try:
        cpu = subprocess.run(["ps", "-A", "-o", "%cpu="], capture_output=True, text=True, timeout=5).stdout.split()
        idle = cores - sum(float(x) for x in cpu) / 100.0
    except (OSError, ValueError, subprocess.SubprocessError):
        idle = cores - os.getloadavg()[0]
    jobs = int(idle + 0.5)
    try:
        vm = subprocess.run(["vm_stat"], capture_output=True, text=True, timeout=5).stdout
        page = int(re.search(r"page size of (\d+) bytes", vm).group(1))
        pages = sum(int(re.search(r"Pages %s:\s+(\d+)" % k, vm).group(1)) for k in ("free", "inactive", "speculative"))
        jobs = min(jobs, int(pages * page / (WORKER_GB * 2**30)))
    except (OSError, AttributeError, ValueError, subprocess.SubprocessError):
        pass
    return max(2, min(MAX_JOBS, jobs))


def _slot_stale(slot: str) -> bool:
    """A slot is stale when its holder is gone, or it never got to write its PID (for a minute)."""
    try:
        with open(os.path.join(slot, "pid")) as f:
            pid = int(f.read().strip())
    except (OSError, ValueError):
        try:
            return time.time() - os.stat(slot).st_mtime > 60
        except OSError:
            return False
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return True
    except OSError:
        pass
    return False


_told = threading.Event()  # the "waiting" note comes once a run, not once a process


def is_build_lane() -> bool:
    """Whether this run is the build lane's: BUILD_LANE set (anything but empty or 0), or this checkout's
    .godot/build-lane holding its own absolute path (a copy of .godot in another folder names the wrong one)."""
    if os.environ.get("BUILD_LANE", "") not in ("", "0"):
        return True
    try:
        with open(os.path.join(ROOT, ".godot", "build-lane")) as f:
            return f.read().strip() == os.path.realpath(ROOT)
    except OSError:
        return False


def reserved_slots(pool: str) -> list[int]:
    """The slot numbers kept for the build lane: the top ones of the pool, always leaving a slot for the lanes."""
    size = POOL_SIZE.get(pool, 0)
    env, default = BUILD_RESERVE.get(pool, ("", 0))
    try:
        reserve = int(os.environ.get(env, default)) if env else 0
    except ValueError:
        reserve = default
    reserve = max(0, min(reserve, size - 1))
    return list(range(size - reserve + 1, size + 1))


def slot_candidates(pool: str, limit: int, build: bool) -> list[int]:
    """The slot numbers a run may claim, in the order of preference groups: a development lane gets 1..limit without
    the reserved ones; the build lane gets the reserved ones first, then the others, and no more than `limit`."""
    kept = reserved_slots(pool)
    dev = [i for i in range(1, max(1, limit) + 1) if i not in kept]
    return (kept + dev)[:max(1, limit)] if build else dev


def take_slot(pool: str, limit: int, giveup: threading.Event) -> str | None:
    """Waits for a free slot of the pool (the folders tools/godot_slot.sh makes) and returns its folder; "" when slots
    are off or can't be made (no cap); None when `giveup` was set while it waited."""
    if os.environ.get("GODOT_SLOTS") == "off":
        return ""
    root = os.path.join(SLOT_ROOT, pool)
    try:
        os.makedirs(root, mode=0o700, exist_ok=True)
    except OSError:
        return ""
    build = is_build_lane()
    kept = reserved_slots(pool)
    while True:
        order = slot_candidates(pool, limit, build)
        # Shuffled within each group, so the build lane's reserved slots still come first.
        groups = [[i for i in order if i in kept], [i for i in order if i not in kept]]
        for g in groups:
            random.shuffle(g)
        for i in groups[0] + groups[1]:
            slot = os.path.join(root, str(i))
            if os.path.isdir(slot) and _slot_stale(slot):
                shutil.rmtree(slot, ignore_errors=True)
            try:
                os.mkdir(slot)
            except FileExistsError:
                continue
            except OSError:
                return ""
            with open(os.path.join(slot, "pid"), "w") as f:
                f.write(str(os.getpid()))
            with open(os.path.join(slot, "where"), "w") as f:
                f.write(ROOT)
            if build:
                with open(os.path.join(slot, "build"), "w") as f:
                    f.write("build\n")
            return slot
        if giveup.is_set():
            return None
        if not _told.is_set():
            _told.set()
            if build:
                print("make test: waiting for a Godot slot (the build lane: up to %d at once, the reserved ones first; "
                      "TEST_SLOTS=n changes it)" % len(order), flush=True)
            else:
                print("make test: waiting for a Godot slot (%d at once for the development lanes across all lanes, "
                      "the rest kept for the build lane; TEST_SLOTS=n changes it)" % len(order), flush=True)
        giveup.wait(random.uniform(2, 4))


def free_slot(slot: str | None) -> None:
    if slot:
        shutil.rmtree(slot, ignore_errors=True)


def user_dir() -> str:
    """The game's user:// folder on this Mac (named by project.godot's config/name)."""
    with open(os.path.join(ROOT, "project.godot"), encoding="utf-8") as f:
        m = re.search(r'^config/name="([^"]+)"', f.read(), re.M)
    return os.path.expanduser("~/Library/Application Support/Godot/app_userdata/" + (m.group(1) if m else "Curse of Strahd"))


def _alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def clean_leftovers(own: list[int]) -> None:
    """Each run cleans up after itself (owner, 2026-10-07): the save folders of this run's processes
    (user://test_saves/<pid>, which a stopped process never removes), and any test's per-process folder
    (user://test_saves/<pid>, user://test_<what>_<pid>) whose process has ended."""
    base = user_dir()
    saves = os.path.join(base, "test_saves")
    gone = []
    for name in (os.listdir(saves) if os.path.isdir(saves) else []):
        if name.isdigit() and (int(name) in own or not _alive(int(name))):
            gone.append(os.path.join(saves, name))
    for name in (os.listdir(base) if os.path.isdir(base) else []):
        m = re.match(r"test_\w+?_(\d+)$", name)
        if m and not _alive(int(m.group(1))):
            gone.append(os.path.join(base, name))
    for path in gone:
        shutil.rmtree(path, ignore_errors=True)


class Output:
    """Prints whole blocks under one lock, so two processes' lines never interleave, and keeps what failed."""

    def __init__(self) -> None:
        self.lock = threading.Lock()
        self.banner_seen = False
        self.fails: list[str] = []
        self.errors: list[str] = []

    def is_banner(self, line: str) -> bool:
        """Godot's first line, printed by every process: shown once."""
        if not line.startswith("Godot Engine v"):
            return False
        with self.lock:
            seen, self.banner_seen = self.banner_seen, True
        if not seen:
            self.block([line], "")
        return True

    def block(self, lines: list[str], file: str) -> None:
        if not lines:
            return
        with self.lock:
            for line in lines:
                if line.startswith("  FAIL "):
                    self.fails.append(line)
                elif ERROR.search(line):
                    self.errors.append("  %s%s" % (line.strip(), " (in %s)" % file if file else ""))
            sys.stdout.write("\n".join(lines) + "\n")
            sys.stdout.flush()


class Worker:
    """One Godot process: reads its output, prints each file's lines together, and notes what it ran."""

    def __init__(self, n: int, cmd: list[str], out: Output, limit: int, giveup: threading.Event) -> None:
        self.n = n
        self.out = out
        self.giveup = giveup  # set when a process has run out of files: a worker still waiting for a slot isn't needed
        self.limit = limit
        self.skipped = False  # it gave up waiting for a slot, so it never started
        self.proc: subprocess.Popen[str] | None = None
        self.slot: str | None = None
        self.files: list[str] = []  # in the order it ran them
        self.times: dict[str, int] = {}
        self.current = ""  # the file it is in the middle of
        self.passed = 0
        self.failed: set[str] = set()  # file:test, or the file when it didn't load
        self.troubled = False  # a test failed or something printed an error
        self.finished = False  # it printed its summary
        self.thread = threading.Thread(target=self._run, args=(cmd,), daemon=True)
        self.thread.start()

    def _run(self, cmd: list[str]) -> None:
        self.slot = take_slot("test", self.limit, self.giveup)
        if self.slot is None:
            self.skipped = True
            return
        try:
            self.proc = subprocess.Popen(cmd, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                                         errors="replace", bufsize=1)
            self._read()
        finally:
            free_slot(self.slot)
            if self.finished:
                self.giveup.set()

    def _read(self) -> None:
        block: list[str] = []
        assert self.proc is not None and self.proc.stdout is not None
        for raw in self.proc.stdout:
            line = raw.rstrip("\n")
            if line.startswith("@@ start "):
                self.out.block(block, self.current)  # anything printed between files (start-up, mostly)
                block = []
                self.current = line[len("@@ start "):]
                if self.current not in self.files:
                    self.files.append(self.current)
                continue
            if line.startswith("@@ done "):
                name, ms = line[len("@@ done "):].rsplit(" ", 1)
                self.times[name] = self.times.get(name, 0) + int(ms)  # a split file comes a test at a time
                self.out.block(block, self.current)
                block = []
                self.current = ""
                continue
            if SUMMARY.match(line):
                self.finished = True
                continue
            if self.out.is_banner(line) or (not line and not self.current):
                continue
            if line.startswith("  ok    "):
                self.passed += 1
            elif line.startswith("  FAIL  "):
                self.failed.add(line[len("  FAIL  "):].split(": ", 1)[0])
                self.troubled = True
            elif ERROR.search(line):
                self.troubled = True
            block.append(line)
        self.out.block(block, self.current)
        self.proc.wait()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--godot", default=os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot"))
    ap.add_argument("--jobs", type=int, default=0)
    ap.add_argument("--only", default="")
    ap.add_argument("--files", default="")
    a = ap.parse_args()

    files = test_files()
    if a.files:
        # Names or paths (tests/unit/test_x.gd), with or without .gd. One that matches nothing stops the run: an empty
        # list used to mean every file, and a mistyped name ran the whole suite (lane 23, 2026-10-07).
        wanted = [os.path.basename(f.strip()) for f in a.files.split(",") if f.strip()]
        wanted = [f if f.endswith(".gd") else f + ".gd" for f in wanted]
        missing = [f for f in wanted if f not in files]
        if missing or not wanted:
            # A FAIL line, since tools/logcheck.sh is what fails make: macOS's make 3.81 ignores .SHELLFLAGS' pipefail.
            print("  FAIL  no test file named %s, so nothing ran. FILES takes names like test_dice.gd or paths like "
                  "tests/unit/test_dice.gd." % ", ".join(missing or [a.files]))
            return 1
        files = [f for f in wanted if f in files]
    wanted = a.jobs or default_jobs()
    jobs = max(1, min(wanted, len(files) or 1))
    split = []
    if jobs > 1:
        # Longest first; a file with no time yet goes before the rest, since it might be long. One process keeps the
        # order it was given, so JOBS=1 FILES=... replays a process's run exactly.
        times = load_times()
        files.sort(key=lambda f: (f in times, -times.get(f, 0), f))
        # A file longer than half a process's share is handed out a test at a time, so it doesn't set the finish.
        share = sum(times.get(f, 0) for f in files) / jobs
        split = [f for f in files if times.get(f, 0) > share / 2]
        if split:
            jobs = max(1, wanted)   # a split file's tests can keep more processes busy than there are files

    base = [a.godot, "--path", ROOT, "--headless", "--quit-after", "100000", "res://tests/test_runner.tscn", "--"]
    if a.only:
        base.append("--only=" + a.only)
    claim = tempfile.mkdtemp(prefix="strahd_tests_")
    print("make test: %d file%s in %d process%s%s%s" % (len(files), "" if len(files) == 1 else "s", jobs,
          "" if jobs == 1 else "es", "" if a.jobs else " (JOBS=n to change)",
          "; a test at a time from " + ", ".join(split) if split else ""), flush=True)
    started = time.monotonic()
    out = Output()
    workers: list[Worker] = []
    giveup = threading.Event()
    limit = max(1, int(os.environ.get("TEST_SLOTS", "8")))

    def stop(*_: object) -> None:
        giveup.set()
        for w in workers:
            if w.proc is not None and w.proc.poll() is None:
                w.proc.terminate()
            free_slot(w.slot)
        sys.exit(1)

    signal.signal(signal.SIGTERM, stop)
    try:
        for n in range(jobs):
            workers.append(Worker(n + 1, base + ["--claim=" + claim, "--files=" + ",".join(files)]
                                  + (["--split=" + ",".join(split)] if split else []), out, limit, giveup))
        for w in workers:
            w.thread.join()
    except KeyboardInterrupt:
        stop()
    finally:
        shutil.rmtree(claim, ignore_errors=True)
    elapsed = time.monotonic() - started
    workers = [w for w in workers if not w.skipped]   # the ones that never started have nothing to report
    jobs = len(workers)
    clean_leftovers([w.proc.pid for w in workers if w.proc is not None])

    ran: dict[str, int] = {}
    for w in workers:
        for name, ms in w.times.items():
            ran[name] = ran.get(name, 0) + ms
    save_times(ran)
    passed = sum(w.passed for w in workers)
    failed = sum(len(w.failed) for w in workers)
    problems = []
    for w in workers:
        if not w.finished or w.proc.returncode not in (0, 1):
            w.troubled = True
            where = "during %s" % w.current if w.current else "after %s" % (w.files[-1] if w.files else "starting")
            problems.append("  FAIL  process %d stopped %s (exit code %s)" % (w.n, where, w.proc.returncode))
    never = [f for f in files if f not in ran and not any(f == w.current for w in workers)]
    if never:
        problems.append("  FAIL  never ran: %s" % ", ".join(never))
    if passed + failed == 0 and not problems:
        problems.append("  FAIL  no tests ran")

    print("")
    if out.fails or out.errors or problems:
        print("Failed:")
        for line in out.fails + list(dict.fromkeys(out.errors)) + problems:
            print(line)
        # A failure that only shows after other files ran in the same process is easiest to find in their order.
        for w in workers:
            if w.troubled and w.files and jobs > 1:
                print("  process %d ran, in order: make test JOBS=1 FILES=%s" % (w.n, ",".join(w.files)))
        print("")
    print("make test: %d process%s, %d s" % (jobs, "" if jobs == 1 else "es", elapsed + 0.5))
    print("%d tests, %d passed, %d failed" % (passed + failed, passed, failed))
    return 1 if failed or out.errors or problems else 0


if __name__ == "__main__":
    sys.exit(main())
