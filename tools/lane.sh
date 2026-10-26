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
# with its own import. The seed is only brought up to main when it has drifted: `new` compares the seed's commit with
# the lane's branch (or base) and refreshes the seed, with its import, only past LANE_SEED_DRIFT files (default 1500) or
# LANE_SEED_ART_DRIFT textures and models (40); otherwise the lane is cloned from the seed as it is, the few files that
# differ come from its branch and its first make import does the rest. LANE_REFRESH_SEED=1 forces a refresh;
# `tools/lane.sh seed` (make lane-seed SSD=1) refreshes the seed on its own, once, e.g. after a landing. The seed's lock
# is a readers/writer lock (see take_gate): any number of lanes clone from the seed at once, a refresh waits for the
# clones running and holds off new ones, and a clone waits for an import running in the seed (make import there).
# Each lane there is locked too, so `git worktree prune` keeps it while the drive is unplugged; `done` unlocks it before
# removing it. Unplugging the drive stops any Godot or git run in those lanes mid-write: plug it back in and re-run
# `make lane` or `hdiutil attach` to get them back. reclone and done need SSD=1 for those lanes as well.
#
# The main checkout is only ever read: nothing is written into it, and no git command that writes runs there.
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

## The seed's lock is a readers/writer lock made of folders (mkdir is atomic):
##   <root>/.seed.lock          the gate, holding the PID of whoever has it: taken for a moment to join as a reader, and
##                              kept for a whole refresh, so no new clone starts while the seed is changing.
##   <root>/.seed.readers/<pid>  one file for each make lane that is cloning from the seed right now.
## A refresh takes the gate, waits for the readers to finish, and refreshes; a clone takes the gate, checks that no
## import is running in the seed, signs in as a reader and lets go of the gate. Any number of clones run at once.
## A gate or a reader whose PID is gone is cleared.
seed_gate=""     # the gate's folder, while this shell has it
seed_reader=""   # this shell's reader file, while it is cloning
take_gate() {
  local lock="$root/.seed.lock" pid told=""
  until mkdir "$lock" 2> /dev/null; do
    pid="$(cat "$lock/pid" 2> /dev/null || true)"
    if [ -n "$pid" ] && ! kill -0 "$pid" 2> /dev/null; then
      rm -rf "$lock"
      continue
    fi
    # A folder with no PID in it for a minute: its maker stopped between mkdir and writing the PID.
    if [ -z "$pid" ] && [ -n "$(find "$lock" -maxdepth 0 -mmin +1 2> /dev/null)" ]; then
      rm -rf "$lock"
      continue
    fi
    [ -n "$told" ] || say "another make lane is at the seed (PID ${pid:-?}); waiting for it"
    told=1
    sleep 0.2
  done
  echo $$ > "$lock/pid"
  seed_gate="$lock"
}
drop_gate() { [ -z "$seed_gate" ] || rm -rf "$seed_gate"; seed_gate=""; }
## How many clones are running; the files of readers that are gone are removed.
live_readers() {
  local f n=0
  for f in "$root"/.seed.readers/*; do
    [ -e "$f" ] || continue
    if kill -0 "${f##*/}" 2> /dev/null; then n=$((n + 1)); else rm -f "$f"; fi
  done
  echo "$n"
}
drain_readers() {
  local told=""
  while [ "$(live_readers)" != 0 ]; do
    [ -n "$told" ] || say "$(live_readers) lane(s) are being cloned from the seed; the refresh waits for them"
    told=1
    sleep 2
  done
}
join_readers() {
  mkdir -p "$root/.seed.readers"
  : > "$root/.seed.readers/$$"
  seed_reader="$root/.seed.readers/$$"
}
## Lets go of everything this shell holds on the seed; the EXIT trap, so a failed clone never leaves a lock behind.
leave_seed() {
  [ -z "$seed_reader" ] || rm -f "$seed_reader"
  seed_reader=""
  release_seed_import
  drop_gate
}
trap 'leave_seed' EXIT

## Holds the seed's make import lock (.godot/import.lock, taken as tools/import.sh takes it: a folder holding the PID
## of a process working in the seed, so this shell moves there), waiting for an import that's running in the seed.
seed_import_lock=""
hold_seed_import() {
  local lock="$source_dir/.godot/import.lock" pid told=""
  cd "$source_dir"
  mkdir -p .godot
  until mkdir "$lock" 2> /dev/null; do
    pid="$(cat "$lock/pid" 2> /dev/null || true)"
    if [ -n "$pid" ] && ! kill -0 "$pid" 2> /dev/null; then
      rm -rf "$lock"
      continue
    fi
    [ -n "$told" ] || say "an import is running in the seed (PID ${pid:-?}); waiting for it"
    told=1
    sleep 5
  done
  echo $$ > "$lock/pid"
  seed_import_lock="$lock"
}
release_seed_import() { [ -z "$seed_import_lock" ] || rm -rf "$seed_import_lock"; seed_import_lock=""; }
## Waits for an import that's running in the seed (a make import run there), without taking its lock: clones read it.
wait_seed_import() {
  local lock="$source_dir/.godot/import.lock" pid told=""
  while [ -d "$lock" ]; do
    pid="$(cat "$lock/pid" 2> /dev/null || true)"
    if [ -n "$pid" ] && ! kill -0 "$pid" 2> /dev/null; then
      rm -rf "$lock"
      continue
    fi
    [ -n "$told" ] || say "an import is running in the seed (PID ${pid:-?}); waiting for it"
    told=1
    sleep 5
  done
}

## Does the seed need bringing up to main for a lane on <target> (a commit)? Yes when it isn't there yet or has no
## import cache, when LANE_REFRESH_SEED=1, or when its commit has drifted from <target>: over LANE_SEED_ART_DRIFT (40)
## textures or models, which every lane cloned from it would import again, or over LANE_SEED_DRIFT (1500) files of any
## kind. A lane cloned from a seed that is a little behind gets the files that differ from its branch, and imports
## the few that changed on its first make import: far less than a refresh and an import of the whole seed.
seed_needs_refresh() {
  local target="$1" head files art
  local max="${LANE_SEED_DRIFT:-1500}" max_art="${LANE_SEED_ART_DRIFT:-40}"
  [ -d "$source_dir/.godot/imported" ] || return 0
  [ "${LANE_REFRESH_SEED:-}" != 1 ] || return 0
  head="$(git -C "$source_dir" rev-parse -q --verify HEAD 2> /dev/null)" || return 0
  files="$(git -C "$main" diff --name-only "$head" "$target" 2> /dev/null)" || return 0
  art="$(printf '%s\n' "$files" | grep -Eic '\.(png|jpe?g|webp|svg|glb|gltf|obj|fbx|exr|hdr)$' || true)"
  files="$(printf '%s\n' "$files" | grep -c . || true)"
  if [ "$files" -gt "$max" ] || [ "$art" -gt "$max_art" ]; then
    say "the seed differs from $target in $files file(s), $art of them textures or models (limits $max, $max_art): refreshing it first"
    return 0
  fi
  say "the seed differs from $target in $files file(s), $art of them textures or models (limits $max, $max_art): cloning from it as it is"
  return 1
}

## The seed on the other volume, made or brought up to main, then imported there once for all its lanes. Called with
## the gate and no readers. LANE_NO_IMPORT=1 skips the import (each lane then imports what changed on its own first
## make import).
refresh_seed() {
  if [ ! -d "$source_dir" ]; then
    quiet git -C "$main" worktree add -q --detach "$source_dir" main
    git -C "$main" worktree lock --reason "seed for lanes on the removable SSD" "$source_dir"
    hold_seed_import
    # main's import cache: a plain copy, since clones can't cross volumes.
    cp -Rp "$main/.godot/imported" "$source_dir/.godot/"
    say "made the seed at $source_dir"
  else
    hold_seed_import
    # -f: the seed holds nothing of anyone's, and an import stopped part-way can leave project.godot rewritten.
    quiet git -C "$source_dir" checkout -q -f --detach main
  fi
  # Every refresh: main's untracked .import files that the seed doesn't have yet (the tracked ones came with the
  # checkout). They hold the import settings of the art beside them: without them Godot imports that art again in the
  # seed, with default settings for art merged into main since. One the seed already has is kept, since Godot rewrites
  # it there after importing (its own uid, for one) and copying main's over it would import that art again each time.
  git -C "$main" ls-files -z --others --ignored --exclude-standard -- '*.import' ':!captures/' ':!builds/' \
    | rsync --ignore-existing --from0 --files-from=- "$main/" "$source_dir/" \
    || say "some of main's .import files weren't copied (one changed or went away meanwhile); the seed imports those"
  release_seed_import   # the seed's own import takes it
  if [ -z "${LANE_NO_IMPORT:-}" ] && ! make -C "$source_dir" import; then
    say "the seed's import logged errors (make -C $source_dir import); the lane gets them too"
  fi
}

## Gets the seed ready for a lane on <target> and signs in as a reader of it until leave_seed: refreshed first only
## when seed_needs_refresh says so (the gate is kept for that, so no other lane starts cloning), then cloned from
## alongside any other lanes.
enter_seed() {
  [ "$source_dir" != "$main" ] || return 0
  take_gate
  if [ ! -d "$source_dir" ] || seed_needs_refresh "$1"; then
    drain_readers
    refresh_seed
  fi
  wait_seed_import
  join_readers
  drop_gate
}

## tools/lane.sh seed: the refresh on its own, whatever the drift (a landing, or before a batch of new lanes).
seed_cmd() {
  if [ "$source_dir" = "$main" ]; then
    say "the lanes here clone from the main checkout; there is no seed to refresh (SSD=1 for the SSD's)"
    return 0
  fi
  take_gate
  drain_readers
  refresh_seed
  drop_gate
  say "the seed is at $(git -C "$source_dir" rev-parse --short HEAD)"
}

## The lane folder for <name>, refused if it is (or is inside) the main checkout.
lane_dir() {
  local dest
  dest="$root/CurseOfStrahdGame-$1"
  case "$1" in ""|*/*|.*) say "a lane name is one word, like 'stealth'" >&2; exit 2 ;; esac
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
  local name="$1" branch="$2" base="${3:-main}" dest before target
  dest="$(lane_dir "$name")"
  [ -e "$dest" ] && { say "$dest already exists"; exit 1; }
  # The commit the lane starts at: its branch's, or the base's.
  target="$(git -C "$main" rev-parse -q --verify "refs/heads/$branch^{commit}" 2> /dev/null \
    || git -C "$main" rev-parse -q --verify "$base^{commit}" 2> /dev/null || echo main)"
  enter_seed "$target"   # reads the seed until the lane is cloned
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
  # A file that goes away mid-copy (main's checkout or import moving on: lanes never lock main) is only reported: git
  # puts back the tracked ones below, and the lane's first make import the rest. Any other failure stops here.
  local item copy_errors
  copy_errors="$(mktemp -t strahd_lane)"
  for item in "$source_dir"/* "$source_dir"/.[!.]*; do
    case "$(basename "$item")" in .git|.DS_Store) continue ;; esac
    [ -e "$item" ] || continue
    cp -Rpc "$item" "$dest/" 2>> "$copy_errors" || true
  done
  leave_seed
  if grep -v 'No such file or directory' "$copy_errors" | grep -q .; then
    cat "$copy_errors" >&2
    rm -f "$copy_errors"
    say "copying $source_dir into $dest failed; to start again: git -C $main worktree unlock $dest;" \
      "git -C $main worktree remove --force $dest" >&2
    exit 1
  fi
  [ ! -s "$copy_errors" ] || say "files went away in $source_dir while it was copied ($(grep -c . "$copy_errors") cp message(s))"
  rm -f "$copy_errors"
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
  # The engine core is a git submodule (addons/dnd_core, docs/plans/engine_split.md). The copy of main's files brought a gitfile that
  # points into main's .git, so the folder is cleared and checked out for this lane, borrowing the objects main's copy already has
  # (no download when the lane's commit of the core is one main has). Core edits go on a branch inside it (git switch -c <name>).
  if [ -f "$dest/.gitmodules" ] && grep -q 'addons/dnd_core' "$dest/.gitmodules"; then
    rm -rf "$dest/addons/dnd_core"
    local ref=()
    [ -e "$main/addons/dnd_core/.git" ] && ref=(--reference "$main/addons/dnd_core")
    if ! git -C "$dest" submodule update --init --quiet ${ref[@]+"${ref[@]}"} > /dev/null 2>&1; then
      say "the engine core (addons/dnd_core) could not be checked out: run git -C $dest submodule update --init"
    fi
  fi
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
  # Merged means in main, or replayed onto it: the build thread lands a lane's commits as new commits (cherry-picks), which
  # git cherry recognises by their patches. Compared with origin/main too, the branch main follows.
  git -C "$dest" fetch -q origin main > /dev/null 2>&1 || true
  if ! git -C "$dest" merge-base --is-ancestor "$branch" main \
      && ! git -C "$dest" merge-base --is-ancestor "$branch" origin/main \
      && [ "$(git -C "$dest" cherry origin/main "$branch" 2> /dev/null | grep -c '^+')" != 0 ]; then
    say "$branch isn't merged into main yet (git cherry origin/main $branch lists what is not); leaving $dest"
    exit 1
  fi
  if [ -n "$(git -C "$dest" status --porcelain --untracked-files=normal)" ]; then
    say "$dest has uncommitted changes (git -C $dest status); leaving it"
    exit 1
  fi
  # A lane with the engine core checked out: its own edits must be committed and on the core's main, or the lane keeps them.
  local core="$dest/addons/dnd_core"
  if [ -e "$core/.git" ]; then
    if [ -n "$(git -C "$core" status --porcelain --untracked-files=normal)" ]; then
      say "the engine core in $dest has uncommitted changes (git -C $core status); leaving it"
      exit 1
    fi
    git -C "$core" fetch -q origin main > /dev/null 2>&1 || true
    if [ "$(git -C "$core" cherry origin/main HEAD 2> /dev/null | grep -c '^+')" != 0 ]; then
      say "the engine core in $dest has commits that are not on the core's main (git -C $core cherry origin/main); leaving it"
      exit 1
    fi
  fi
  before="$(free_gb)"
  [ "$source_dir" = "$main" ] || git -C "$main" worktree unlock "$dest" 2>/dev/null || true
  # git refuses to remove a worktree that holds a submodule without --force; everything it could lose was checked above.
  git -C "$main" worktree remove --force "$dest"   # writes only main's .git/worktrees, never its files
  say "removed $dest ($branch is merged into main; the branch is kept)"
  say "disk free: $before GB before, $(free_gb) GB after"
}

case "${1:-}" in
  seed) seed_cmd ;;
  new) [ $# -ge 3 ] || { echo "usage: tools/lane.sh new <name> <branch> [<base>]"; exit 2; }; new_lane "$2" "$3" "${4:-main}" ;;
  reclone) [ $# -ge 2 ] || { echo "usage: tools/lane.sh reclone <name>"; exit 2; }; reclone_lane "$2" ;;
  done) [ $# -ge 2 ] || { echo "usage: tools/lane.sh done <name>"; exit 2; }; done_lane "$2" ;;
  *) echo "usage: tools/lane.sh new <name> <branch> [<base>] | reclone <name> | done <name> | seed"; exit 2 ;;
esac
