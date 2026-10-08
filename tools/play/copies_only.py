#!/usr/bin/env python3
"""tools/play/copies_only.py <play copy> <commit>: whether every change in the play copy is a copy of main's.

make play is the only thing that changes the play copy, so a change in it is never the owner's. But once something
wrote main's newer files into it without moving it (2026-10-08, while the disk was full: 287 files, 16 of them left
empty), and the forward checkout then refused. For every changed or untracked file, this checks that it is byte for
byte <commit>'s or HEAD's version (with or without the Git LFS filter), or empty (a write that failed), or deleted.
Ignored caches (.godot/, builds/) aren't looked at.

Exit 0 and print the untracked files, NUL-separated, when all are copies: play.sh then checks out <commit> over them
and has git clean remove those untracked ones. Exit 1 and list the files that aren't copies otherwise. Stdlib only.
"""
import subprocess
import sys


def main() -> int:
    play, target = sys.argv[1], sys.argv[2]

    def git(*args: str) -> bytes:
        return subprocess.run(["git", "-C", play, *args], capture_output=True).stdout

    def blob(rev: str, path: str) -> bytes:
        return git("rev-parse", "-q", "--verify", "%s:%s" % (rev, path)).strip()

    untracked, foreign = [], []
    for entry in git("status", "--porcelain", "-z", "--untracked-files=all").decode().split("\0"):
        if not entry:
            continue
        code, path = entry[:2], entry[3:]
        try:
            with open("%s/%s" % (play, path), "rb") as f:
                empty = f.read(1) == b""
        except OSError:
            empty = True   # deleted: the checkout brings it back
        wanted = {blob(target, path), blob("HEAD", path)} - {b""}
        have = {git("hash-object", "--path", path, path).strip(), git("hash-object", "--no-filters", path).strip()}
        if not (empty or wanted & have):
            foreign.append(path)
        elif code == "??":
            untracked.append(path)
    if foreign:
        sys.stderr.write("make play: these files in the play copy aren't copies of main's, so nothing was changed:\n")
        sys.stderr.write("".join("  %s\n" % p for p in foreign))
        return 1
    sys.stdout.write("\0".join(untracked))
    return 0


if __name__ == "__main__":
    sys.exit(main())
