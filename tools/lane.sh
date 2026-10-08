#!/usr/bin/env bash
# Lane folders that cost almost no disk (owner, 2026-10-08): a git worktree whose files and Godot import cache are APFS
# clones of the main checkout's, so a lane pays only for the files it changes. A plain worktree held its own copy of
# all the art (mostly plain git, not LFS) plus a 6 to 8 GB .godot, and about 30 of them filled the disk.
#
#   tools/lane.sh new <name> <branch> [<base>]   make lane NAME=<name> BRANCH=<branch> [BASE=main]
#     ~/Documents/CurseOfStrahdGame-<name> on <branch> (made from <base>, main by default, if it doesn't exist yet):
#     a worktree added without a checkout, the main checkout's files and .godot cloned in (cp -c), the index synced
#     without rewriting files that already match, then only the files that differ from <branch> checked out. A branch
#     cut from today's main costs almost nothing; one behind main pays for the files main has changed since.
#   tools/lane.sh reclone <name>                  make lane-reclone NAME=<name>
#     for a lane that already exists: every tracked file whose content is the same as main's (same blob, unchanged in
#     both folders) becomes a clone of main's file again, freeing its copy. Changed and untracked files are left
#     alone, and so are the branch and what's staged; only the index's file timestamps are refreshed, as make
#     lfs-quiet does. Run it with no Godot running in the lane.
#   tools/lane.sh done <name>                     make lane-done NAME=<name>
#     removes the lane's folder once its branch is merged into main and it has nothing uncommitted.
#
# Lanes on the external SSD (owner, 2026-10-08): LANE_ROOT=/Volumes/StrahdLanes (make lane ... SSD=1) puts the lane in
# an APFS disk image on the SSD, /Volumes/ASH-SSD/Worktrees/StrahdLanes.sparsebundle, attached here when it isn't.
# The SSD itself is exFAT with 1 MB clusters (a lane straight on it would take about 95 GB), and clones can't cross
# volumes, so lanes there clone from a seed inside the image: <LANE_ROOT>/seed, a locked detached worktree at main
# with its own import, which `new` brings up to main first (one make lane at a time: the others wait for it). Each
# lane there is locked too, so `git worktree prune` keeps it while the drive is unplugged; `done` unlocks it before
# removing it. Unplugging the drive stops any Godot or git run in those lanes mid-write: plug it back in and re-run
# `make lane` or `hdiutil attach` to get them back. reclone and done need SSD=1 for those lanes as well.
#
# The main checkout is only ever read: nothing is written into it, and no git command that writes runs there. The
# play copy (CurseOfStrahdGame-play, make play's) is refused as a lane.
set -euo pipefail
main="$(cd "$(git rev-parse --path-format=absolute --git-common-dir)/.." && pwd)"
say() { printf 'lane: %s\n' "$*"; }
root="${LANE_ROOT:-$(dirname "$main")}"
ssd_image="/Volumes/ASH-SSD/Worktrees/StrahdLanes.sparsebundle"
case "$root" in /Volumes/StrahdLanes|/Volumes/StrahdLanes/*)
  if [ ! -d /Volumes/StrahdLanes ]; then
    [ -d "$ssd_image" ] || { say "the SSD ($ssd_image) is not plugged in" >&2; exit 1; }
    hdiutil attach -quiet -nobrowse "$ssd_image"
  fi ;;
esac
[ -d "$root" ] || { say "LANE_ROOT $root isn't a folder" >&2; exit 2; }
root="$(cd "$root" && pwd)"   # absolute: git -C "$main" would read a relative path as one inside the main checkout
# What lanes clone from: the main checkout, or the seed when the lanes live on another volume.
source_dir="$main"
[ "$(stat -f %d "$root")" = "$(stat -f %d "$main")" ] || source_dir="$root/seed"

free_gb() { df -k "$root" | awk 'NR == 2 { printf "%.1f", $4 / 1048576 }'; }
# Git's output only when it fails: a checkout lists thousands of old images as "should have been pointers" (the Git
# LFS noise make lfs-quiet explains).
quiet() { local out; if ! out="$("$@" 2>&1)"; then printf '%s\n' "$out" >&2; return 1; fi; }

## Holds <root>/.seed.lock from the seed's refresh until the new lane is cloned from it, so no lane clones a seed that
## another make lane is still checking out or importing. A lock whose PID is gone is cleared.
seed_lock=""
lock_seed() {
  local lock="$root/.seed.lock" pid told=""
  until mkdir "$lock" 2> /dev/null; do
    pid="$(cat "$lock/pid" 2> /dev/null || true)"
    if [ -n "$pid" ] && ! kill -0 "$pid" 2> /dev/null; then
      rm -rf "$lock"
      continue
    fi
    [ -n "$told" ] || say "another make lane is bringing the seed up to main (PID ${pid:-?}); waiting for it"
    told=1
    sleep 5
  done
  echo $$ > "$lock/pid"
  seed_lock="$lock"
  trap 'unlock_seed' EXIT
}
unlock_seed() { [ -z "$seed_lock" ] || rm -rf "$seed_lock"; seed_lock=""; }

## The seed on the other volume, made or brought up to main, then imported there once for all its lanes.
## LANE_NO_IMPORT=1 skips the import (each lane then imports what changed on its own first make import).
refresh_seed() {
  [ "$source_dir" != "$main" ] || return 0
  lock_seed
  if [ ! -d "$source_dir" ]; then
    quiet git -C "$main" worktree add -q --detach "$source_dir" main
    git -C "$main" worktree lock --reason "seed for lanes on the removable SSD" "$source_dir"
    # main's import cache, and the untracked .import files beside the assets (without them Godot imports every asset
    # again). Plain copies: clones can't cross volumes.
    mkdir -p "$source_dir/.godot" && cp -Rp "$main/.godot/imported" "$source_dir/.godot/"
    rsync -a --ignore-existing --exclude=/.git --exclude=/.godot --exclude=/captures --exclude=/builds \
      --include='*/' --include='*.import' --exclude='*' --prune-empty-dirs "$main/" "$source_dir/"
    say "made the seed at $source_dir"
  else
    # -f: the seed holds nothing of anyone's, and an import stopped part-way can leave project.godot rewritten.
    quiet git -C "$source_dir" checkout -q -f --detach main
  fi
  if [ -z "${LANE_NO_IMPORT:-}" ] && ! make -C "$source_dir" import; then
    say "the seed's import logged errors (make -C $source_dir import); the lane gets them too"
  fi
}

## The lane folder for <name>, refused if it is (or is inside) the main checkout.
lane_dir() {
  local dest
  dest="$root/CurseOfStrahdGame-$1"
  case "$1" in ""|*/*|.*) say "a lane name is one word, like 'stealth'" >&2; exit 2 ;; esac
  case "$1" in play) say "CurseOfStrahdGame-play is make play's copy; only tools/play/play.sh changes it" >&2; exit 2 ;; esac
  case "$dest/" in "$main"/*) say "$dest is the main checkout; lanes never touch it" >&2; exit 2 ;; esac
  printf '%s' "$dest"
}

## No lane folder at <dest>: says so, and where git has a lane of that name instead (a lane on the SSD needs SSD=1).
missing() {
  local other
  other="$(git -C "$main" worktree list --porcelain | sed -n "s|^worktree \(.*/CurseOfStrahdGame-$1\)\$|\1|p" | head -1)"
  if [ -n "$other" ] && [ "$other" != "$2" ]; then
    say "no lane folder at $2; git has one at $other (SSD=1 for lanes on the SSD)"
  else
    say "no lane folder at $2"
  fi
  exit 1
}

## Refreshes the lane's index timestamps without the LFS filter too, as make lfs-quiet does, so files whose bytes
## match read as unchanged (old images under the LFS paths are still plain blobs in the history).
refresh() {
  git update-index -q --refresh > /dev/null 2>&1 || true
  git -c filter.lfs.process= -c filter.lfs.clean=cat -c filter.lfs.required=false update-index -q --refresh \
    > /dev/null 2>&1 || true
}

new_lane() {
  local name="$1" branch="$2" base="${3:-main}" dest before
  dest="$(lane_dir "$name")"
  [ -e "$dest" ] && { say "$dest already exists"; exit 1; }
  refresh_seed
  before="$(free_gb)"
  if git -C "$main" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$main" worktree add --no-checkout "$dest" "$branch" > /dev/null
  else
    git -C "$main" worktree add --no-checkout -b "$branch" "$dest" "$base" > /dev/null
    say "made branch $branch from $base"
  fi
  [ "$source_dir" = "$main" ] || git -C "$main" worktree lock --reason "on the removable SSD" "$dest"
  # Everything in the main checkout (or the seed) but its .git: tracked files, LFS art as checked out there, .godot
  # (the import cache), and ignored folders such as captures/. cp -c makes copy-on-write clones, so nothing is copied.
  local item
  for item in "$source_dir"/* "$source_dir"/.[!.]*; do
    case "$(basename "$item")" in .git|.DS_Store) continue ;; esac
    [ -e "$item" ] || continue
    cp -Rpc "$item" "$dest/"
  done
  unlock_seed
  rm -rf "$dest/.godot/import.lock"   # make import's, if the folder cloned from was importing: never this lane's
  cd "$dest"
  git reset -q
  refresh
  # Files that differ from <branch> (main has moved on since it, or main's checkout is mid-change): from the branch.
  local differ extra
  differ="$(git diff --name-only | wc -l | tr -d ' ')"
  [ "$differ" = "0" ] || git diff --name-only -z | xargs -0 git checkout -q --
  # Files in the main checkout that aren't in <branch> and aren't ignored: copies of main's own, removed here only.
  extra="$(git ls-files --others --exclude-standard | wc -l | tr -d ' ')"
  [ "$extra" = "0" ] || git ls-files --others --exclude-standard -z | xargs -0 rm -f
  refresh
  say "$dest on $branch: $differ file(s) checked out from the branch, $extra extra file(s) removed"
  say "disk free: $before GB before, $(free_gb) GB after (other lanes write meanwhile)"
  [ -z "$(git status --porcelain)" ] || say "git status isn't clean yet: check it before working here"
}

reclone_lane() {
  local dest before
  dest="$(lane_dir "$1")"
  [ -d "$dest" ] || missing "$1" "$dest"
  before="$(free_gb)"
  cd "$dest"
  refresh
  python3 - "$source_dir" "$dest" <<'EOF'
import ctypes, os, subprocess, sys

main, lane = sys.argv[1], sys.argv[2]


def git(cwd, *args):
    return subprocess.run(["git", "-C", cwd, *args], capture_output=True, check=True).stdout


def entries(raw, tree):
    out = {}
    for rec in raw.split(b"\0"):
        if not rec:
            continue
        meta, path = rec.split(b"\t", 1)
        parts = meta.split()
        if tree:
            mode, kind, blob = parts
            if kind == b"blob":
                out[path] = (mode, blob)
        elif parts[2] == b"0":
            out[path] = (parts[0], parts[1])
    return out


mine = entries(git(lane, "ls-files", "-s", "-z"), False)
theirs = entries(git(main, "ls-tree", "-r", "-z", "HEAD"), True)
# Files whose timestamps differ from the index (changed, or not known to be unchanged) in either folder are left alone.
dirty = set(git(lane, "diff-files", "--name-only", "-z").split(b"\0")) | set(git(main, "diff-files", "--name-only", "-z").split(b"\0"))
libc = ctypes.CDLL("libc.dylib", use_errno=True)
cloned = bytes_ = skipped = 0
for path, entry in mine.items():
    if theirs.get(path) != entry or path in dirty or entry[0] == b"120000":
        continue
    src, dst = os.path.join(main.encode(), path), os.path.join(lane.encode(), path)
    if not (os.path.isfile(src) and os.path.isfile(dst)) or os.path.islink(dst):
        continue
    tmp = dst + b".lane-reclone"
    if os.path.lexists(tmp):
        os.remove(tmp)
    if libc.clonefile(src, tmp, 1) != 0:   # CLONE_NOFOLLOW
        skipped += 1
        continue
    os.replace(tmp, dst)
    cloned += 1
    bytes_ += os.path.getsize(dst)
print("lane: %d file(s) now clones of main's (%.1f GB of copies released), %d left alone after a failed clone"
      % (cloned, bytes_ / 2**30, skipped))
EOF
  refresh
  say "disk free: $before GB before, $(free_gb) GB after (other lanes write meanwhile)"
  [ -z "$(git status --porcelain --untracked-files=no)" ] || say "git status shows changes; they were there before or are yours"
}

done_lane() {
  local dest branch before
  dest="$(lane_dir "$1")"
  [ -d "$dest" ] || missing "$1" "$dest"
  branch="$(git -C "$dest" rev-parse --abbrev-ref HEAD)"
  if ! git -C "$dest" merge-base --is-ancestor "$branch" main; then
    say "$branch isn't merged into main yet; leaving $dest"
    exit 1
  fi
  if [ -n "$(git -C "$dest" status --porcelain --untracked-files=normal)" ]; then
    say "$dest has uncommitted changes (git -C $dest status); leaving it"
    exit 1
  fi
  before="$(free_gb)"
  [ "$source_dir" = "$main" ] || git -C "$main" worktree unlock "$dest" 2>/dev/null || true
  git -C "$main" worktree remove "$dest"   # writes only main's .git/worktrees, never its files
  say "removed $dest ($branch is merged into main; the branch is kept)"
  say "disk free: $before GB before, $(free_gb) GB after"
}

case "${1:-}" in
  new) [ $# -ge 3 ] || { echo "usage: tools/lane.sh new <name> <branch> [<base>]"; exit 2; }; new_lane "$2" "$3" "${4:-main}" ;;
  reclone) [ $# -ge 2 ] || { echo "usage: tools/lane.sh reclone <name>"; exit 2; }; reclone_lane "$2" ;;
  done) [ $# -ge 2 ] || { echo "usage: tools/lane.sh done <name>"; exit 2; }; done_lane "$2" ;;
  *) echo "usage: tools/lane.sh new <name> <branch> [<base>] | reclone <name> | done <name>"; exit 2 ;;
esac
