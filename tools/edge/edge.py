#!/usr/bin/env python3
"""make run: the edge build (owner, 2026-10-17): main plus every lane branch that has been handed off but not merged
yet, so the owner can try lane work as soon as it is handed off instead of after the build thread's full test runs.
make run-main is the old make run (this checkout's own code).

An edge build is assembled from the branches listed in a plain file kept out of git, one branch per line
(~/.curse-of-strahd/edge/branches.txt; EDGE_HOME moves it). The build thread keeps it current as hand-offs arrive:
  make edge-add BRANCH=<branch> [BRANCH="a b"]     make edge-remove BRANCH=<branch>
  make edge-list (what each listed branch is, and what the last build held) · make edge-prune (drops the merged ones)
The assembly is a throwaway worktree, CurseOfStrahdGame-edge on the SSD's lane image (/Volumes/StrahdLanes; EDGE_ROOT
puts it on another folder, such as ~/Documents when the SSD is unplugged), made the first time by tools/lane.sh and then
kept: a detached HEAD at the base (main by default; EDGE_BASE=origin/main for the last ci-green one), then each listed
branch merged in order. A branch that is already in main, or already in the build through a branch above it, is
skipped; one that is missing, conflicts with what is already in or won't merge is left out and named on the console,
and the run goes on. Nothing is merged into a branch of the repository: the worktree's HEAD is the only thing that moves.
When the base and every branch are where the last build left them, the worktree is not touched at all.

Saves and settings (owner: the real ones are never touched). The build runs on its own user data folder, `Curse of Strahd Edge`
next to the downloaded game's `Curse of Strahd Fan Game` in ~/Library/Application Support: an override.cfg in the
worktree switches on the project's custom user dir (Godot reads it beside project.godot; the project's own
`.template` setting only reaches exported builds) and puts "(edge)" in the window title. The edge's saves/ are its own
and are kept between runs: they are seeded with a copy of the owner's (dev builds keep them in Godot/app_userdata/Curse of
Strahd) only when that folder is missing or empty, or on request (EDGE_FRESH=1 make run replaces them with a fresh copy).
Newer real saves are never merged into them. settings.cfg is copied from the owner's on every launch (EDGE_KEEP_DATA=1
keeps the edge's own settings too). So a branch that migrates or swaps data on load (item-audit's SaveSystem.WITHDRAWN)
only ever changes the copy; caches the build makes itself (shaders, looks) are kept as well. The owner's folder is only
read, and this script refuses a destination that is it, the downloaded game's or inside either. The console says which folder is in use, and warns when a merged branch raises
GameState.SAVE_VERSION.

Environment: EDGE_HOME, EDGE_ROOT, EDGE_BASE, EDGE_DATA (the user folder's name), EDGE_FRESH=1, EDGE_KEEP_DATA=1, EDGE_NO_RUN=1 (assemble
and import, don't start: same as `build`), GODOT (as the Makefile). The first run makes the worktree and imports it,
which takes minutes on a busy Mac; later runs import only what changed (the Makefile's FRESH rule).

Usage: tools/edge/edge.py run | build | list | add <branch>... | remove <branch>... | prune | reset
Stdlib only; macOS.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import List, Mapping, Optional, Sequence, Tuple

ROOT = Path(__file__).resolve().parents[2]   # the checkout this script is in (main's, or a lane's while it is tested)
LANE_NAME = "edge"                           # tools/lane.sh makes CurseOfStrahdGame-edge
LANE_BRANCH = "edge-build"                   # the branch lane.sh needs to make it; dropped once the HEAD is detached
MARKER = "strahd-edge"                       # a file in the worktree's git dir: this worktree is the throwaway one
RECORD = "builds/edge_build.json"            # what the last build held (builds/ is ignored by git)
SAVE_FILE = "core/game_state.gd"
SAVE_RE = re.compile(r"^const SAVE_VERSION\s*:=\s*(\d+)", re.M)
DEFAULT_GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
SSD_IMAGE = Path("/Volumes/ASH-SSD/Worktrees/StrahdLanes.sparsebundle")
SSD_MOUNT = "/Volumes/StrahdLanes"
# The Makefile's FRESH rule, in find's words: a file of these kinds newer than the last import stamp means import first.
IMPORT_KINDS = ("*.gd", "*.tscn", "*.tres", "*.png", "*.ogg", "*.wav", "*.mp3", "*.glb")
IMPORT_ERRORS = re.compile(r"SCRIPT ERROR|ERROR:|Parse Error|Failed loading")
IMPORT_STOPPED = (75, 129, 130, 137, 143)    # a refused or stopped import: no stamp, no game (as the Makefile)
USER_FILES = ("settings.cfg",)   # copied from the owner's folder beside saves/
HEADER = (
    "# Branches the edge build (make run) merges onto main, one per line, in this order. Handed-off lane work stays\n"
    "# here until it is merged: make edge-add BRANCH=<branch> / make edge-remove BRANCH=<branch>.\n"
    "# A branch already merged into main is skipped on its own; make edge-prune clears those.\n"
)


class EdgeError(Exception):
    """Something the run can't go on without; the message is for the console."""


def say(text: str = "") -> None:
    print("edge: " + text if text else "", flush=True)


def tilde(path: object) -> str:
    text, home = str(path), str(Path.home())
    return "~" + text[len(home):] if text.startswith(home + os.sep) else text


# --- git ---------------------------------------------------------------------------------------------------------

def git_try(repo: Path, *args: str) -> "subprocess.CompletedProcess[str]":
    env = dict(os.environ, LC_ALL="C", GIT_TERMINAL_PROMPT="0")
    return subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True, env=env)


def git(repo: Path, *args: str) -> str:
    done = git_try(repo, *args)
    if done.returncode != 0:
        raise EdgeError("git %s failed in %s: %s" % (" ".join(args), tilde(repo), (done.stderr or done.stdout).strip()))
    return done.stdout.strip()


def main_checkout() -> Path:
    """The folder the repository's .git is in (lane.sh's `main`), whichever worktree this script is run from."""
    common = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--path-format=absolute", "--git-common-dir"],
                            capture_output=True, text=True)
    if common.returncode != 0:
        raise EdgeError("%s isn't in a git repository" % tilde(ROOT))
    return Path(common.stdout.strip()).parent


def commit_of(repo: Path, name: str) -> str:
    done = git_try(repo, "rev-parse", "--verify", "--quiet", name + "^{commit}")
    return done.stdout.strip() if done.returncode == 0 else ""


def is_ancestor(repo: Path, old: str, new: str) -> bool:
    return git_try(repo, "merge-base", "--is-ancestor", old, new).returncode == 0


def short(sha: str) -> str:
    return sha[:9]


def is_worktree(repo: Path, path: Path) -> bool:
    here = path.resolve()
    return any(Path(line[len("worktree "):]).resolve() == here
               for line in git(repo, "worktree", "list", "--porcelain").splitlines() if line.startswith("worktree "))


# --- configuration -----------------------------------------------------------------------------------------------

@dataclass
class Config:
    repo: Path          # the main checkout: read, never written
    home: Path          # the manifest and the lock
    root: Path          # the folder the worktree is made in
    base: str           # what the build starts from
    godot: str
    data_name: str      # the edge's user data folder, in `support`
    support: Path       # ~/Library/Application Support
    keep_data: bool
    no_run: bool
    fresh: bool = False  # EDGE_FRESH=1: replace the edge's saves with a fresh copy of the owner's

    @property
    def manifest(self) -> Path:
        return self.home / "branches.txt"

    @property
    def worktree(self) -> Path:
        return self.root / ("CurseOfStrahdGame-" + LANE_NAME)

    @property
    def edge_data(self) -> Path:
        return self.support / self.data_name

    @property
    def project_name(self) -> str:
        found = re.search(r'^config/name="([^"]*)"', (self.repo / "project.godot").read_text(encoding="utf-8"), re.M)
        return found.group(1) if found else "Curse of Strahd"

    @property
    def real_data(self) -> Path:
        """Where a dev build (make run, make run-main) keeps its saves and settings."""
        return self.support / "Godot" / "app_userdata" / self.project_name

    @property
    def fan_game_data(self) -> Path:
        """The downloaded game's folder (project.godot's custom_user_dir_name.template)."""
        return self.support / (self.project_name + " Fan Game")

    @classmethod
    def from_env(cls, env: Optional[Mapping[str, str]] = None) -> "Config":
        env = os.environ if env is None else env
        home = Path(env.get("HOME") or str(Path.home()))
        return cls(
            repo=main_checkout(),
            home=Path(env.get("EDGE_HOME") or home / ".curse-of-strahd" / "edge"),
            root=Path(env.get("EDGE_ROOT") or SSD_MOUNT),
            base=env.get("EDGE_BASE") or "main",
            godot=env.get("GODOT") or DEFAULT_GODOT,
            data_name=env.get("EDGE_DATA") or "Curse of Strahd Edge",
            support=home / "Library" / "Application Support",
            keep_data=bool(env.get("EDGE_KEEP_DATA")),
            no_run=bool(env.get("EDGE_NO_RUN")),
            fresh=bool(env.get("EDGE_FRESH")),
        )


# --- the manifest ------------------------------------------------------------------------------------------------

def read_manifest(path: Path) -> List[str]:
    """The listed branches, in order, once each; blank lines and # comments are ignored."""
    if not path.is_file():
        return []
    names: List[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        name = line.split("#", 1)[0].strip()
        if name and name not in names:
            names.append(name)
    return names


def _write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(text, encoding="utf-8")
    os.replace(tmp, path)


def add_branches(path: Path, names: Sequence[str]) -> List[str]:
    """Appends the branches that aren't listed yet; returns those it added."""
    listed = read_manifest(path)
    new = [n for n in dict.fromkeys(names) if n not in listed]
    if new:
        text = path.read_text(encoding="utf-8") if path.is_file() else HEADER
        if text and not text.endswith("\n"):
            text += "\n"
        _write(path, text + "".join(n + "\n" for n in new))
    return new


def remove_branches(path: Path, names: Sequence[str]) -> List[str]:
    """Drops the lines that name these branches (comments and the other lines stay); returns those it dropped."""
    if not path.is_file():
        return []
    gone: List[str] = []
    kept: List[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        name = line.split("#", 1)[0].strip()
        if name and name in names:
            gone.append(name)
        else:
            kept.append(line)
    if gone:
        _write(path, "".join(line + "\n" for line in kept))
    return list(dict.fromkeys(gone))


# --- assembling the build ----------------------------------------------------------------------------------------

@dataclass
class Entry:
    name: str
    sha: str = ""
    status: str = ""    # merged | in-main | in-edge | conflict | failed | missing
    detail: str = ""
    save_version: Optional[int] = None


@dataclass
class Build:
    base: str
    base_sha: str
    head: str
    entries: List[Entry]
    save_version: Optional[int]
    reused: bool = False


def save_version(repo: Path, rev: str) -> Optional[int]:
    done = git_try(repo, "show", "%s:%s" % (rev, SAVE_FILE))
    found = SAVE_RE.search(done.stdout) if done.returncode == 0 else None
    return int(found.group(1)) if found else None


def plan_key(base_sha: str, entries: Sequence[Entry]) -> str:
    return hashlib.sha1(json.dumps([base_sha, [[e.name, e.sha] for e in entries]]).encode()).hexdigest()


def resolve(repo: Path, names: Sequence[str]) -> List[Entry]:
    entries = []
    for name in names:
        sha = commit_of(repo, name)
        entries.append(Entry(name, sha) if sha else Entry(name, "", "missing", "no such branch"))
    return entries


def _why(wt: Path, done: "subprocess.CompletedProcess[str]") -> Tuple[str, str]:
    """(status, detail) for a merge that didn't go through."""
    clash = git_try(wt, "diff", "--name-only", "--diff-filter=U").stdout.split()
    if clash:
        more = " (and %d more)" % (len(clash) - 4) if len(clash) > 4 else ""
        return "conflict", "conflicts with what is already in, in " + ", ".join(clash[:4]) + more
    lines = [x.strip() for x in (done.stderr + "\n" + done.stdout).splitlines() if x.strip()]
    return "failed", (lines[0] if lines else "git merge failed")[:160]


def assemble(wt: Path, base: str, base_sha: str, entries: List[Entry], force: bool = False) -> Build:
    """Puts the worktree at the base with each entry merged in order, and fills in the entries' outcome. Never raises
    for one branch: it is left out and named. Untouched when the last build had exactly this base and these tips."""
    key = plan_key(base_sha, entries)
    record = wt / RECORD
    if not force and record.is_file():
        try:
            last = json.loads(record.read_text(encoding="utf-8"))
        except ValueError:
            last = {}
        here = git_try(wt, "rev-parse", "HEAD").stdout.strip()
        if last.get("plan_key") == key and last.get("head") == here:
            return Build(base, base_sha, here, [Entry(**e) for e in last["entries"]], last.get("save_version"), True)
    git_try(wt, "merge", "--abort")
    git(wt, "checkout", "-q", "-f", "--detach", base_sha)
    head = base_sha
    base_version = save_version(wt, base_sha)
    for e in entries:
        if not e.sha:
            continue
        e.save_version = save_version(wt, e.sha)
        if is_ancestor(wt, e.sha, base_sha):
            e.status, e.detail = "in-main", "already merged into " + base
        elif is_ancestor(wt, e.sha, head):
            e.status, e.detail = "in-edge", "already in through a branch above it"
        else:
            done = git_try(wt, "merge", "--no-ff", "--no-edit", "--no-verify", "-m",
                           "edge: merge %s (%s)" % (e.name, short(e.sha)), e.sha)
            if done.returncode == 0:
                e.status = "merged"
                head = git(wt, "rev-parse", "HEAD")
            else:
                e.status, e.detail = _why(wt, done)
                git_try(wt, "merge", "--abort")
                if git(wt, "rev-parse", "HEAD") != head:
                    git(wt, "reset", "-q", "--hard", head)
    build = Build(base, base_sha, head, entries, base_version)
    record.parent.mkdir(parents=True, exist_ok=True)
    record.write_text(json.dumps({
        "built_at": dt.datetime.now().isoformat(timespec="seconds"), "base": base, "base_sha": base_sha, "head": head,
        "plan_key": key, "save_version": base_version, "entries": [e.__dict__ for e in entries]}, indent=1) + "\n",
        encoding="utf-8")
    return build


def report(build: Build, cfg: Config) -> None:
    say("make run plays the edge build: %s plus the branches handed off but not merged yet." % build.base)
    say("make run-main plays this checkout alone; make edge-add / edge-remove change the list (%s)." % tilde(cfg.manifest))
    say("  base  %-22s %s" % (build.base, short(build.base_sha)))
    marks = {"merged": "+", "in-main": "=", "in-edge": "=", "conflict": "-", "failed": "-", "missing": "?"}
    for e in build.entries:
        verb = {"merged": "merged in", "in-main": "already in main (skipped)", "in-edge": "already in (skipped)"}.get(
            e.status, "LEFT OUT: " + e.detail)
        say("  %s %-26s %-9s %s" % (marks.get(e.status, "?"), e.name, short(e.sha) if e.sha else "", verb))
    if not build.entries:
        say("  no branches are listed in %s, so this is %s alone." % (tilde(cfg.manifest), build.base))
    bumps = [e for e in build.entries if e.status == "merged" and e.save_version not in (None, build.save_version)]
    for e in bumps:
        say("!! %s changes GameState.SAVE_VERSION from %s to %s: a save made in the edge build won't load in main"
            % (e.name, build.save_version, e.save_version))
    if not bumps:
        say("save format: SAVE_VERSION %s, the same as %s." % (build.save_version, build.base))
    if build.reused:
        say("the folder already held exactly this (nothing to merge).")


# --- saves and settings ------------------------------------------------------------------------------------------

def _inside(path: Path, other: Path) -> bool:
    path, other = path.resolve(), other.resolve()
    return path == other or other in path.parents


def check_data_dirs(edge: Path, protected: Sequence[Path]) -> None:
    """The copy goes to the edge folder only: refuses one that is, holds or lies inside a folder the owner plays on."""
    for p in protected:
        if _inside(edge, p) or _inside(p, edge):
            raise EdgeError("%s is real game data (%s): the edge build must use a folder of its own (EDGE_DATA)"
                            % (tilde(edge), tilde(p)))


def refresh_data(real: Path, edge: Path, protected: Sequence[Path]) -> str:
    """Replaces the edge folder's saves/ and settings.cfg with copies of the owner's; theirs are only read.
    Caches the build made (shader_cache, look_cache, logs) stay. Returns a line for the console."""
    check_data_dirs(edge, [real, *protected])
    edge.mkdir(parents=True, exist_ok=True)
    saves = edge / "saves"
    if saves.is_symlink():
        saves.unlink()
    elif saves.exists():
        shutil.rmtree(saves)
    count = 0
    if (real / "saves").is_dir():
        shutil.copytree(real / "saves", saves, copy_function=shutil.copy2)
        count = sum(1 for p in saves.iterdir())
    for name in USER_FILES:
        mine, theirs = real / name, edge / name
        if mine.is_file():
            shutil.copy2(mine, theirs)
        elif theirs.exists():
            theirs.unlink()
    return "a fresh copy of your saves/ (%d entr%s) and settings" % (count, "y" if count == 1 else "ies")


def _entries(saves: Path) -> int:
    return sum(1 for _ in saves.iterdir()) if saves.is_dir() else 0


def _plural(n: int) -> str:
    return "%d entr%s" % (n, "y" if n == 1 else "ies")


def prepare_data(real: Path, edge: Path, protected: Sequence[Path], fresh: bool = False, keep_settings: bool = False) -> str:
    """What the edge folder holds at launch. Its saves/ are kept; they are seeded from the owner's (refresh_data) only
    when missing or empty (a symlink is replaced too: it could lead into the real ones) or when `fresh` asks.
    settings.cfg is copied on every launch unless keep_settings. Returns a line for the console."""
    check_data_dirs(edge, [real, *protected])
    saves = edge / "saves"
    kept = not saves.is_symlink() and _entries(saves) > 0
    if kept and not fresh:
        for name in ([] if keep_settings else USER_FILES):
            mine, theirs = real / name, edge / name
            if mine.is_file():
                shutil.copy2(mine, theirs)
            elif theirs.exists():
                theirs.unlink()
        return "kept your edge saves (%s)%s" % (_plural(_entries(saves)),
                                               ", and the edge's own settings" if keep_settings else "; settings copied from yours")
    refresh_data(real, edge, protected)
    n = _plural(_entries(saves))
    if kept:
        return "EDGE_FRESH=1: replaced the edge saves with a fresh copy of your real saves (%s) and settings" % n
    return "seeded from your real saves (%s) and settings" % n


def override_text(title: str, data_name: str) -> str:
    return (
        "; Written by tools/edge/edge.py on every launch; not part of the game. Godot reads this beside project.godot.\n"
        "; The edge build keeps its saves and settings in its own folder, and says so in its window title.\n"
        "[application]\n\n"
        'config/name="%s (edge)"\n'
        "config/use_custom_user_dir=true\n"
        'config/custom_user_dir_name="%s"\n' % (title, data_name))


# --- the worktree ------------------------------------------------------------------------------------------------

def ensure_volume(root: Path) -> None:
    text = str(root)
    if text == SSD_MOUNT or text.startswith(SSD_MOUNT + "/"):
        if not Path(SSD_MOUNT).is_dir():
            if not SSD_IMAGE.is_dir():
                raise EdgeError("the SSD (%s) is not plugged in; EDGE_ROOT=<folder> builds the edge on this disk instead, "
                                "and make run-main plays this checkout alone" % SSD_IMAGE)
            subprocess.run(["hdiutil", "attach", "-quiet", "-nobrowse", str(SSD_IMAGE)], check=True)
    if not root.is_dir():
        raise EdgeError("EDGE_ROOT %s isn't a folder" % root)


def marker(wt: Path) -> Path:
    return Path(git(wt, "rev-parse", "--absolute-git-dir")) / MARKER


def ensure_worktree(cfg: Config, base_sha: str) -> Tuple[Path, bool]:
    """(the edge worktree, whether it was just made). Only a worktree this script made is ever touched."""
    ensure_volume(cfg.root)
    wt = cfg.worktree
    if wt.resolve() == cfg.repo.resolve():
        raise EdgeError("%s is the main checkout; EDGE_ROOT must be another folder" % tilde(wt))
    known = is_worktree(cfg.repo, wt)
    if wt.exists():
        if not known:
            raise EdgeError("%s exists but isn't a worktree of this repository; move it or set EDGE_ROOT" % tilde(wt))
        if not marker(wt).exists():
            raise EdgeError("%s is a worktree this script didn't make; move it or set EDGE_ROOT" % tilde(wt))
        return wt, False
    if known:   # registered, folder gone: the drive was swapped or the folder removed by hand
        git_try(cfg.repo, "worktree", "unlock", str(wt))
        git(cfg.repo, "worktree", "prune")
    say("first run: making the edge folder %s (a clone of the lanes' seed, so it costs almost no disk)." % tilde(wt))
    say("it needs an import before the game starts: minutes, more on a busy Mac. Later runs import only what changed.")
    had_branch = bool(commit_of(cfg.repo, LANE_BRANCH))
    made = subprocess.run(["bash", str(ROOT / "tools" / "lane.sh"), "new", LANE_NAME, LANE_BRANCH, base_sha],
                          cwd=str(cfg.repo), env=dict(os.environ, LANE_ROOT=str(cfg.root)))
    if made.returncode != 0 or not wt.exists():
        raise EdgeError("tools/lane.sh could not make %s (exit %d); see its messages above. To start again: "
                        "git -C %s worktree unlock %s; git -C %s worktree remove --force %s"
                        % (tilde(wt), made.returncode, cfg.repo, wt, cfg.repo, wt))
    git(wt, "checkout", "-q", "--detach", base_sha)
    if not had_branch:
        git_try(cfg.repo, "branch", "-D", LANE_BRANCH)
    marker(wt).write_text("the throwaway worktree of tools/edge/edge.py\n", encoding="utf-8")
    return wt, True


def game_running(wt: Path) -> bool:
    pattern = "--path %s$" % re.sub(r"([.+*?()\[\]{}|^$\\])", r"\\\1", str(wt))
    return subprocess.run(["pgrep", "-f", "--", pattern], capture_output=True).returncode == 0


class Lock:
    """One assembly at a time: a folder holding the PID that has it (a stale one is cleared)."""

    def __init__(self, path: Path) -> None:
        self.path = path

    def __enter__(self) -> "Lock":
        self.path.parent.mkdir(parents=True, exist_ok=True)
        while True:
            try:
                self.path.mkdir()
                break
            except FileExistsError:
                try:
                    pid = int((self.path / "pid").read_text().strip())
                    os.kill(pid, 0)
                except (ValueError, OSError):
                    shutil.rmtree(self.path, ignore_errors=True)
                    continue
                raise EdgeError("another make run is assembling the edge build (PID %d); try again when it is done" % pid)
        (self.path / "pid").write_text(str(os.getpid()))
        return self

    def __exit__(self, *exc: object) -> None:
        shutil.rmtree(self.path, ignore_errors=True)


def needs_import(wt: Path) -> bool:
    stamp = wt / ".godot" / ".last_import"
    if not stamp.is_file():
        return True
    kinds: List[str] = []
    for pattern in IMPORT_KINDS:
        kinds += ["-o", "-name", pattern] if kinds else ["-name", pattern]
    found = subprocess.run(
        ["find", ".", "(", "-path", "./.godot", "-o", "-path", "./captures", "-o", "-path", "./builds", ")", "-prune",
         "-o", "(", *kinds, ")", "-newer", str(stamp), "-print", "-quit"],
        cwd=str(wt), capture_output=True, text=True)
    return bool(found.stdout.strip())


def import_project(cfg: Config, wt: Path) -> int:
    """tools/import.sh as the Makefile's FRESH runs it: its notes show, its output goes to builds/edge_import.log.
    It never takes or waits for a Godot slot (GODOT_SLOTS=off): the owner is waiting to play."""
    say("files changed since the last import: importing first (a few minutes if art changed; the game starts after).")
    log = wt / "builds" / "edge_import.log"
    log.parent.mkdir(parents=True, exist_ok=True)
    stamp = wt / ".godot" / ".last_import"
    with log.open("w") as out:
        status = subprocess.run([str(wt / "tools" / "import.sh")], cwd=str(wt), stdout=out,
                                env=dict(os.environ, GODOT=cfg.godot, GODOT_SLOTS="off")).returncode
    if status in IMPORT_STOPPED:
        return status
    stamp.parent.mkdir(parents=True, exist_ok=True)
    stamp.touch()
    if IMPORT_ERRORS.search(log.read_text(encoding="utf-8", errors="replace")):
        say("the import logged errors (%s); starting anyway." % tilde(log))
    return 0


def launch_command(cfg: Config, wt: Path) -> Tuple[List[str], dict]:
    """The game as make run starts it: the bundle id set, so Godot skips its own activation unless the owner's
    terminal started it, and stdin from /dev/null."""
    return [cfg.godot, "--path", str(wt)], dict(os.environ, __CFBundleIdentifier="org.godotengine.godot")


# --- commands ----------------------------------------------------------------------------------------------------

def cmd_run(cfg: Config, args: argparse.Namespace) -> int:
    launch = args.cmd == "run" and not cfg.no_run
    base_sha = commit_of(cfg.repo, cfg.base)
    if not base_sha:
        raise EdgeError("EDGE_BASE %s isn't a branch or commit of this repository" % cfg.base)
    check_data_dirs(cfg.edge_data, [cfg.real_data, cfg.fan_game_data])
    with Lock(cfg.home / "assemble.lock"):
        wt, first = ensure_worktree(cfg, base_sha)
        if game_running(wt):
            say("the edge build is already running; close it first (it is %s)." % tilde(wt))
            return 0
        build = assemble(wt, cfg.base, base_sha, resolve(cfg.repo, read_manifest(cfg.manifest)))
        report(build, cfg)
        (wt / "override.cfg").write_text(override_text(cfg.project_name, cfg.data_name), encoding="utf-8")
        what = prepare_data(cfg.real_data, cfg.edge_data, [cfg.fan_game_data], cfg.fresh, cfg.keep_data)
        say("saves and settings: %s, in %s." % (what, tilde(cfg.edge_data)))
        say("your own (%s) are only read, never written; EDGE_FRESH=1 make run starts the edge's saves over from them."
            % tilde(cfg.real_data))
        say("folder: %s" % tilde(wt))
        if first or needs_import(wt):
            status = import_project(cfg, wt)
            if status:
                return status
    if not launch:
        say("assembled and imported; not starting the game.")
        return 0
    argv, env = launch_command(cfg, wt)
    say("starting the game.")
    os.chdir(wt)
    os.dup2(os.open(os.devnull, os.O_RDONLY), 0)
    os.execvpe(argv[0], argv, env)
    return 0


def cmd_list(cfg: Config, args: argparse.Namespace) -> int:
    base_sha = commit_of(cfg.repo, cfg.base)
    names = read_manifest(cfg.manifest)
    say("%s lists %d branch%s; base %s %s" % (tilde(cfg.manifest), len(names), "" if len(names) == 1 else "es",
                                             cfg.base, short(base_sha)))
    for e in resolve(cfg.repo, names):
        if not e.sha:
            say("  %-26s no such branch" % e.name)
        elif is_ancestor(cfg.repo, e.sha, base_sha):
            say("  %-26s %-9s merged into %s (make edge-prune drops it)" % (e.name, short(e.sha), cfg.base))
        else:
            ahead = git(cfg.repo, "rev-list", "--count", "%s..%s" % (base_sha, e.sha))
            behind = git(cfg.repo, "rev-list", "--count", "%s..%s" % (e.sha, base_sha))
            say("  %-26s %-9s %s commit(s) ahead of %s, %s behind" % (e.name, short(e.sha), ahead, cfg.base, behind))
    record = cfg.worktree / RECORD
    if record.is_file():
        last = json.loads(record.read_text(encoding="utf-8"))
        left = [e["name"] for e in last["entries"] if e["status"] in ("conflict", "failed", "missing")]
        say("last build %s: head %s%s" % (last["built_at"], short(last["head"]),
                                          "; left out: " + ", ".join(left) if left else ""))
    return 0


def cmd_add(cfg: Config, args: argparse.Namespace) -> int:
    if not args.branches:
        raise EdgeError("name the branch: make edge-add BRANCH=<branch>")
    for name in args.branches:
        if not commit_of(cfg.repo, name):
            raise EdgeError("no branch or commit called %s; nothing added" % name)
    added = add_branches(cfg.manifest, args.branches)
    say("added %s" % ", ".join(added) if added else "already listed: %s" % ", ".join(args.branches))
    say("%d branch%s now in %s" % (len(read_manifest(cfg.manifest)), "" if len(read_manifest(cfg.manifest)) == 1 else "es",
                                   tilde(cfg.manifest)))
    return 0


def cmd_remove(cfg: Config, args: argparse.Namespace) -> int:
    if not args.branches:
        raise EdgeError("name the branch: make edge-remove BRANCH=<branch>")
    gone = remove_branches(cfg.manifest, args.branches)
    say("removed %s" % ", ".join(gone) if gone else "none of those were listed (%s)" % ", ".join(args.branches))
    return 0


def cmd_prune(cfg: Config, args: argparse.Namespace) -> int:
    base_sha = commit_of(cfg.repo, cfg.base)
    dead = []
    for e in resolve(cfg.repo, read_manifest(cfg.manifest)):
        if not e.sha:
            dead.append(e.name)
            say("  %s: no such branch any more" % e.name)
        elif is_ancestor(cfg.repo, e.sha, base_sha):
            dead.append(e.name)
            say("  %s: merged into %s" % (e.name, cfg.base))
    remove_branches(cfg.manifest, dead)
    say("dropped %d branch%s" % (len(dead), "" if len(dead) == 1 else "es"))
    return 0


def cmd_reset(cfg: Config, args: argparse.Namespace) -> int:
    """Removes the throwaway worktree so the next run makes it again (the edge's saves folder stays)."""
    wt = cfg.worktree
    if not wt.exists() or not is_worktree(cfg.repo, wt):
        say("there is no edge folder to remove (%s)." % tilde(wt))
        return 0
    if not marker(wt).exists():
        raise EdgeError("%s is a worktree this script didn't make; not removing it" % tilde(wt))
    if game_running(wt):
        raise EdgeError("the edge build is running; close it first")
    git_try(cfg.repo, "worktree", "unlock", str(wt))
    git(cfg.repo, "worktree", "remove", "--force", str(wt))
    say("removed %s; the next make run makes it again." % tilde(wt))
    return 0


COMMANDS = {"run": cmd_run, "build": cmd_run, "list": cmd_list, "add": cmd_add, "remove": cmd_remove,
            "prune": cmd_prune, "reset": cmd_reset}


def main(argv: Sequence[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("run", "build", "list", "prune", "reset"):
        sub.add_parser(name)
    for name in ("add", "remove"):
        sub.add_parser(name).add_argument("branches", nargs="*")
    args = ap.parse_args(argv)
    try:
        return COMMANDS[args.cmd](Config.from_env(), args)
    except EdgeError as err:
        print("edge: %s" % err, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
