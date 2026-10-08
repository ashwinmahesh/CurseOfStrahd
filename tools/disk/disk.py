#!/usr/bin/env python3
"""Where this repo's disk goes, and getting a worktree's copies back to shared clones (owner, 2026-10-08).

The Mac's disk filled on 2026-10-07 with about 30 worktrees, each holding its own copy of the checked-out art (about
4.8 GB, mostly plain git, not LFS) and of the Godot import cache (8.3 GB). APFS clones (cp -c) share their blocks
until one side changes, so a worktree made or seeded from the main checkout by cloning costs almost nothing; a
`git worktree add` checkout, a fresh `make import`, rsync or a plain copy each write a full private copy. macOS files
all of it under "System Data", and du counts clones in full, so neither shows what deleting a folder would free.

  python3 tools/disk/disk.py report [--fast]          (make disk [FAST=1])
      Free space on each volume that holds a worktree (for a disk image, such as the SSD lanes' StrahdLanes, also on
      the drive it grows into); then each worktree: branch, merged into origin/main or not, uncommitted files, and the bytes its
      files and its .godot hold on their own (APFS private size: what removing it frees; --fast skips this walk);
      then the git store: packs, LFS objects, and tmp_pack_* left by a repack or fetch that died (disk full).
      Read-only: git runs with --no-optional-locks, so not even an index is rewritten.

  python3 tools/disk/disk.py reshare [<worktree>] [--godot] [--dry-run] [--min-kb N]
      For each tracked file of <worktree> (default: this checkout) that is byte-for-byte the main checkout's file at
      the same path, replaces it with an APFS clone of the main checkout's, keeping its own mode and timestamps; with
      --godot, the files in .godot/imported too. The worktree's files read exactly as before, so git and Godot see no
      change; then its index is refreshed (the LFS filter, and again without it as make lfs-quiet does). The main
      checkout is only read. --godot refuses while a Godot process runs in the worktree, since an import there could
      be rewriting the cache. A file that changes while it runs is left alone. It refuses the play copy
      (CurseOfStrahdGame-play, which only tools/play/play.sh changes), any locked worktree, and a worktree on another
      volume (an external drive), where clones can't reach.

Stdlib only; macOS (getattrlist, clonefile).
"""
from __future__ import annotations

import argparse
import concurrent.futures
import ctypes
import ctypes.util
import os
import plistlib
import shutil
import struct
import subprocess
import sys
import time
from pathlib import Path

GB = 1024 ** 3
_libc = ctypes.CDLL(ctypes.util.find_library("c"), use_errno=True)


class _AttrList(ctypes.Structure):
    _fields_ = [("bitmapcount", ctypes.c_ushort), ("reserved", ctypes.c_uint16),
                ("commonattr", ctypes.c_uint32), ("volattr", ctypes.c_uint32),
                ("dirattr", ctypes.c_uint32), ("fileattr", ctypes.c_uint32),
                ("forkattr", ctypes.c_uint32)]


_ATTR_CMN_RETURNED_ATTRS = 0x80000000
_ATTR_CMNEXT_PRIVATESIZE = 0x00000008   # in forkattr with FSOPT_ATTR_CMN_EXTENDED (sys/attr.h)
_FSOPT_NOFOLLOW = 0x1
_FSOPT_ATTR_CMN_EXTENDED = 0x20
_CLONE_NOFOLLOW = 0x1
_CLONE_NOOWNERCOPY = 0x2
_ATTRS = _AttrList(5, 0, _ATTR_CMN_RETURNED_ATTRS, 0, 0, 0, _ATTR_CMNEXT_PRIVATESIZE)


def private_size(path: str) -> int | None:
    """Bytes of the file that no clone shares (what deleting it frees), or None where APFS doesn't say."""
    buf = ctypes.create_string_buffer(64)
    if _libc.getattrlist(os.fsencode(path), ctypes.byref(_ATTRS), buf, 64,
                         _FSOPT_NOFOLLOW | _FSOPT_ATTR_CMN_EXTENDED) != 0:
        return None
    # u32 length, attribute_set_t (five u32: common, vol, dir, file, fork), then the off_t
    if not struct.unpack_from("<I", buf.raw, 4 + 16)[0] & _ATTR_CMNEXT_PRIVATESIZE:
        return None
    return struct.unpack_from("<q", buf.raw, 24)[0]


def clonefile(src: str, dst: str) -> None:
    if _libc.clonefile(os.fsencode(src), os.fsencode(dst), _CLONE_NOFOLLOW | _CLONE_NOOWNERCOPY) != 0:
        err = ctypes.get_errno()
        raise OSError(err, os.strerror(err), dst)


def git(cwd: Path, *args: str, check: bool = True) -> str:
    out = subprocess.run(["git", "--no-optional-locks", *args], cwd=cwd, capture_output=True, text=True)
    if check and out.returncode != 0:
        raise SystemExit(f"disk: git {' '.join(args)} failed in {cwd}: {out.stderr.strip()}")
    return out.stdout


def main_checkout(cwd: Path) -> Path:
    return Path(git(cwd, "rev-parse", "--path-format=absolute", "--git-common-dir").strip()).parent


def free_gb(path: Path) -> float:
    return shutil.disk_usage(path).free / GB


def own_bytes(root: Path, skip_godot: bool) -> tuple[int, int]:
    """(allocated bytes, private bytes) of the regular files under root."""
    alloc = own = 0
    for dirpath, dirnames, filenames in os.walk(root):
        if skip_godot and dirpath == str(root):
            dirnames[:] = [d for d in dirnames if d not in (".godot", ".git")]
        for name in filenames:
            p = os.path.join(dirpath, name)
            try:
                st = os.lstat(p)
            except OSError:
                continue
            if (st.st_mode & 0o170000) != 0o100000:
                continue
            size = st.st_blocks * 512
            ps = private_size(p)
            alloc += size
            own += size if ps is None else min(ps, size)
    return alloc, own


# ---------------------------------------------------------------------------------------------------------- report

def worktrees(main: Path) -> list[tuple[Path, str]]:
    out: list[tuple[Path, str]] = []
    path: Path | None = None
    for line in git(main, "worktree", "list", "--porcelain").splitlines():
        if line.startswith("worktree "):
            path = Path(line[len("worktree "):])
        elif line.startswith("branch ") and path:
            out.append((path, line[len("branch refs/heads/"):]))
        elif line == "detached" and path:
            out.append((path, "(detached)"))
    return out


def volume_of(path: Path) -> Path:
    """The mount point of the volume that holds path."""
    p = path.resolve()
    dev = os.stat(p).st_dev
    while p != p.parent and os.stat(p.parent).st_dev == dev:
        p = p.parent
    return p


def image_files() -> dict[str, str]:
    """Mount point -> the disk image file mounted there, for every attached image (hdiutil info)."""
    out = subprocess.run(["hdiutil", "info", "-plist"], capture_output=True)
    if out.returncode != 0:
        return {}
    images: dict[str, str] = {}
    for image in plistlib.loads(out.stdout).get("images", []):
        for entity in image.get("system-entities", []):
            if entity.get("mount-point"):
                images[entity["mount-point"]] = image.get("image-path", "")
    return images


def report(main: Path, fast: bool) -> None:
    trees = [(p, b) for p, b in worktrees(main) if p.is_dir()]
    here = volume_of(main)
    images = image_files()
    for vol in [here] + sorted({volume_of(p) for p, _ in trees} - {here}):
        line = f"free: {free_gb(vol):.1f} GB" + ("" if vol == here else f" in {vol}")
        image = images.get(str(vol))
        if image and Path(image).exists():
            # A sparse image grows into the drive it's on, so that drive's free space is the real limit.
            line += f" (a disk image on {volume_of(Path(image))}: {free_gb(Path(image)):.1f} GB free there)"
        print(line)
    rows = []

    def one(item: tuple[Path, str]) -> tuple:
        path, branch = item
        if path == main:
            merged = "source"
        elif branch == "(detached)":
            merged = "detached"
        else:
            r = subprocess.run(["git", "merge-base", "--is-ancestor", branch, "origin/main"], cwd=main)
            merged = "merged" if r.returncode == 0 else "unmerged"
        dirty = len(git(path, "status", "--porcelain", "--untracked-files=no", check=False).splitlines())
        files = godot = (0, 0)
        if not fast:
            files = own_bytes(path, skip_godot=True)
            godot = own_bytes(path / ".godot", skip_godot=False) if (path / ".godot").is_dir() else (0, 0)
        return path, branch, merged, dirty, files, godot

    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        rows = list(pool.map(one, trees))
    rows.sort(key=lambda r: -(r[4][1] + r[5][1]))
    print(f"\n{'worktree':44} {'branch':26} {'main?':9} {'changed':>7} {'files own':>10} {'.godot own':>11}")
    total = 0
    for path, branch, merged, dirty, files, godot in rows:
        total += files[1] + godot[1]
        own = "" if fast else f"{files[1] / GB:7.1f} GB {godot[1] / GB:8.1f} GB"
        name = path.name if volume_of(path) == here else f"{path.name} (on {volume_of(path).name})"
        print(f"{name[:44]:44} {branch[:26]:26} {merged:9} {dirty:7} {own}")
    if not fast:
        print(f"{'':90}{total / GB:.1f} GB own in all (plus what they share, once)")

    common = Path(git(main, "rev-parse", "--path-format=absolute", "--git-common-dir").strip())
    packs = list((common / "objects" / "pack").glob("*.pack"))
    tmp = list((common / "objects" / "pack").glob("tmp_*")) + list((common / "objects").glob("*/tmp_obj_*"))
    lfs = own_bytes(common / "lfs", skip_godot=False)[0] if (common / "lfs").is_dir() else 0
    print(f"\ngit: {sum(p.stat().st_size for p in packs) / GB:.1f} GB in {len(packs)} pack(s), "
          f"{lfs / GB:.1f} GB of LFS objects")
    if tmp:
        now = time.time()
        size = sum(p.stat().st_size for p in tmp)
        oldest = max((now - p.stat().st_mtime) / 3600 for p in tmp)
        print(f"git: {size / GB:.1f} GB in {len(tmp)} tmp file(s) a repack or fetch left (oldest {oldest:.1f} h); "
              "git prune only clears these after two weeks")


# --------------------------------------------------------------------------------------------------------- reshare

def godot_running_in(path: Path) -> list[str]:
    """PIDs of Godot processes whose --path or working directory is inside path."""
    ps = subprocess.run(["ps", "-Ao", "pid=,command="], capture_output=True, text=True).stdout
    pids = []
    for line in ps.splitlines():
        pid, _, cmd = line.strip().partition(" ")
        if "Godot" not in cmd:
            continue
        if f"--path {path}" in cmd or f"--path {path}/" in cmd:
            pids.append(pid)
            continue
        cwd = subprocess.run(["lsof", "-a", "-p", pid, "-d", "cwd", "-Fn"], capture_output=True, text=True).stdout
        for field in cwd.splitlines():
            if field.startswith("n") and (field[1:] == str(path) or field[1:].startswith(f"{path}/")):
                pids.append(pid)
    return pids


def same_bytes(a: str, b: str) -> bool:
    with open(a, "rb") as fa, open(b, "rb") as fb:
        while True:
            ca = fa.read(1 << 20)
            if ca != fb.read(1 << 20):
                return False
            if not ca:
                return True


def reshare_file(src: str, dst: str, min_bytes: int, dry_run: bool) -> tuple[str, int]:
    """('shared'|'already'|'differs'|'skipped'|'raced', private bytes freed) for one path."""
    try:
        s, d = os.lstat(src), os.lstat(dst)
    except OSError:
        return "skipped", 0
    if (s.st_mode & 0o170000) != 0o100000 or (d.st_mode & 0o170000) != 0o100000:
        return "skipped", 0
    if s.st_size != d.st_size or d.st_size < min_bytes:
        return "skipped" if s.st_size == d.st_size else "differs", 0
    own = private_size(dst)
    if own is not None and own == 0:
        return "already", 0
    if not same_bytes(src, dst):
        return "differs", 0
    freed = own if own is not None else d.st_blocks * 512
    if dry_run:
        return "shared", freed
    tmp = f"{dst}.reshare-{os.getpid()}"
    try:
        clonefile(src, tmp)
        c = os.lstat(tmp)
        s2, d2 = os.lstat(src), os.lstat(dst)
        # The clone carries src's timestamps: if either side moved since the comparison, leave this file alone.
        if (c.st_size, c.st_mtime_ns) != (s.st_size, s.st_mtime_ns) or (s2.st_mtime_ns, s2.st_size) != (
                s.st_mtime_ns, s.st_size) or (d2.st_mtime_ns, d2.st_size, d2.st_ino) != (
                d.st_mtime_ns, d.st_size, d.st_ino):
            os.unlink(tmp)
            return "raced", 0
        os.chmod(tmp, d.st_mode & 0o7777)
        os.utime(tmp, ns=(d.st_atime_ns, d.st_mtime_ns))
        os.rename(tmp, dst)
    except OSError as e:
        if os.path.lexists(tmp):
            os.unlink(tmp)
        print(f"disk: left {dst}: {e}", file=sys.stderr)
        return "skipped", 0
    return "shared", freed


def reshare(main: Path, target: Path, with_godot: bool, dry_run: bool, min_kb: int) -> None:
    if target == main:
        raise SystemExit("disk: that's the main checkout, the source of the clones; run this in a worktree")
    # The play copy is the owner's, changed only by tools/play/play.sh; a locked worktree is one someone set aside.
    gitdir = Path(git(target, "rev-parse", "--path-format=absolute", "--git-dir").strip())
    if target.name == "CurseOfStrahdGame-play" or (gitdir / "locked").exists():
        raise SystemExit(f"disk: {target} is the play copy or a locked worktree; reshare leaves it alone")
    if os.stat(target).st_dev != os.stat(main).st_dev:
        raise SystemExit(f"disk: {target} is on another volume than the main checkout, and clones can't cross volumes")
    if with_godot:
        busy = godot_running_in(target)
        if busy:
            raise SystemExit(f"disk: Godot is running in {target} (PID {', '.join(busy)}); --godot waits for it")
    before = free_gb(target)
    paths = [p for p in git(target, "ls-files", "-z").split("\0") if p]
    jobs = [(str(main / p), str(target / p)) for p in paths]
    if with_godot:
        imported = target / ".godot" / "imported"
        if imported.is_dir():
            jobs += [(str(main / ".godot" / "imported" / n), str(imported / n)) for n in os.listdir(imported)]
    counts: dict[str, int] = {}
    freed = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        for status, n in pool.map(lambda j: reshare_file(j[0], j[1], min_kb * 1024, dry_run), jobs, chunksize=64):
            counts[status] = counts.get(status, 0) + 1
            freed += n
    verb = "would share" if dry_run else "shared"
    print(f"disk: {target.name}: {verb} {counts.get('shared', 0)} file(s) with the main checkout "
          f"({freed / GB:.1f} GB {'to free' if dry_run else 'freed'}); {counts.get('already', 0)} already shared, "
          f"{counts.get('differs', 0)} differ, {counts.get('raced', 0)} changed while running, "
          f"{counts.get('skipped', 0)} skipped (missing, small or not a file)")
    if dry_run or not counts.get("shared"):
        return
    # New inodes: refresh the stat data so git doesn't rehash them later; the second pass is make lfs-quiet's.
    subprocess.run(["git", "update-index", "-q", "--refresh"], cwd=target, capture_output=True)
    subprocess.run(["git", "-c", "filter.lfs.process=", "-c", "filter.lfs.clean=cat", "-c",
                    "filter.lfs.required=false", "update-index", "-q", "--refresh"], cwd=target, capture_output=True)
    print(f"disk: free {before:.1f} GB before, {free_gb(target):.1f} GB after")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("report", help="free space, each worktree's own bytes, git leftovers (read-only)")
    r.add_argument("--fast", action="store_true", help="skip measuring each worktree's own bytes")
    s = sub.add_parser("reshare", help="replace a worktree's copies of main's files with clones")
    s.add_argument("worktree", nargs="?", default=".")
    s.add_argument("--godot", action="store_true", help="also .godot/imported (not while Godot runs there)")
    s.add_argument("--dry-run", action="store_true")
    s.add_argument("--min-kb", type=int, default=32, help="leave smaller files (code) alone; default 32")
    args = ap.parse_args()
    here = Path.cwd()
    main_root = main_checkout(here)
    if args.cmd == "report":
        report(main_root, args.fast)
    else:
        target = Path(git(Path(args.worktree).resolve(), "rev-parse", "--show-toplevel").strip())
        reshare(main_root, target, args.godot, args.dry_run, args.min_kb)


if __name__ == "__main__":
    main()
