#!/usr/bin/env bash
# make play (P1): the owner's stable copy of the game. A worktree of this repo (PLAY_DIR, default
# ~/Documents/CurseOfStrahdGame-play) that only moves forward, to the newest commit on main that the build thread marked
# after a clean make ci (refs/play/green; `git reflog refs/play/green` lists every mark). It keeps its own import
# cache, so a half-finished merge on main, or another thread's import, can't grey-screen a session.
# Each run moves the copy forward when a newer commit is marked (never while it's running), imports what changed,
# writes the What's new list (builds/play_build.json, tools/play/whats_new.py) and starts the game as make run does.
# PLAY_NO_RUN=1 updates it without starting the game. PLAY_REF picks another marker (for testing).
set -euo pipefail
src="$(cd "$(dirname "$0")/../.." && pwd)"
play="${PLAY_DIR:-$HOME/Documents/CurseOfStrahdGame-play}"
ref="${PLAY_REF:-refs/play/green}"
godot="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
say() { printf 'make play: %s\n' "$*"; }
# Git's output only when it fails: a fresh checkout lists thousands of old images as "should have been pointers" (the
# Git LFS noise make lfs-quiet explains), which says nothing about the play copy.
quiet() { local out; if ! out="$("$@" 2>&1)"; then printf '%s\n' "$out" >&2; return 1; fi; }
short() { git -C "$src" rev-parse --short=8 "$1"; }
# The play copy's own game, running (it is always started with --path "$play").
running() { pgrep -f -- "--path $play\$" > /dev/null 2>&1; }

green="$(git -C "$src" rev-parse -q --verify "$ref^{commit}" || true)"
if [ -z "$green" ]; then
  say "no commit is marked yet ($ref). The build thread marks main after each clean make ci."
  exit 1
fi
if ! git -C "$src" merge-base --is-ancestor "$green" main; then
  say "$ref ($(short "$green")) isn't on main, so the play copy stays where it is."
  exit 1
fi
if running; then
  say "the play copy is already running."
  exit 0
fi

fresh=""
if [ ! -e "$play/.git" ]; then
  if [ -e "$play" ]; then
    say "$play exists but isn't a worktree of this repo; move it or set PLAY_DIR."
    exit 1
  fi
  say "making the play copy at $play (once)."
  quiet git -C "$src" worktree add -q --detach "$play" "$green"
  git -C "$src" worktree lock --reason "make play: the owner's stable copy (tools/play/play.sh)" "$play"
  # Its import cache starts as an APFS clone of this checkout's (seconds, and almost no disk); Godot then imports only
  # what differs. The untracked .import files beside the assets come along, so nothing is imported from scratch.
  if [ -d "$src/.godot/imported" ]; then
    mkdir -p "$play/.godot"
    cp -Rc "$src/.godot/imported" "$play/.godot/" 2> /dev/null || cp -R "$src/.godot/imported" "$play/.godot/"
    rsync -a --ignore-existing --exclude=/.godot --exclude=/captures --exclude=/builds \
      --include='*/' --include='*.import' --exclude='*' --prune-empty-dirs "$src/" "$play/"
  fi
  fresh=1
fi

# A play copy with changes in it: if they're all copies of main's (tools/play/copies_only.py), check <commit> out over
# them and let git clean remove the untracked ones (never ignored files); otherwise stop and say which aren't.
tidy() {
  local target="$1" leftovers
  [ -z "$(git -C "$play" status --porcelain --untracked-files=all)" ] && return 0
  leftovers="$(mktemp -t strahd_play)"
  if ! python3 "$src/tools/play/copies_only.py" "$play" "$target" > "$leftovers"; then
    rm -f "$leftovers"
    exit 1
  fi
  say "putting back $(git -C "$play" status --porcelain --untracked-files=all | wc -l | tr -d ' ') file(s) that were copies of main's (or empty)."
  quiet git -C "$play" checkout -q -f --detach "$target"
  if [ -s "$leftovers" ]; then
    xargs -0 git -C "$play" clean -fq -- < "$leftovers"
  fi
  rm -f "$leftovers"
}

here="$(git -C "$play" rev-parse HEAD)"
if [ "$here" != "$green" ]; then
  if git -C "$src" merge-base --is-ancestor "$here" "$green"; then
    n="$(git -C "$src" rev-list --first-parent --count "$here..$green")"
    say "moving forward $(short "$here") -> $(short "$green") ($n change$([ "$n" = 1 ] || echo s) on main)."
    tidy "$green"
    quiet git -C "$play" checkout -q --detach "$green"
    fresh=1
  else
    say "the play copy is at $(short "$here"), which $ref doesn't follow from; leaving it there."
  fi
elif [ -n "$(git -C "$play" status --porcelain --untracked-files=all)" ]; then
  tidy "$green"
  fresh=1
fi

if [ -n "$fresh" ] || [ ! -f "$play/.godot/.last_import" ] || [ ! -f "$play/builds/play_build.json" ]; then
  mkdir -p "$play/builds"
  say "importing what changed (headless; log in builds/import.log)."
  "$godot" --path "$play" --headless --import > "$play/builds/import.log" 2>&1 || true
  if grep -qE 'SCRIPT ERROR|ERROR:|Parse Error|Failed loading' "$play/builds/import.log"; then
    say "the import logged errors (builds/import.log); starting anyway, since this commit passed make ci."
  fi
  touch "$play/.godot/.last_import"
  python3 "$src/tools/play/whats_new.py" "$play"
fi

[ -n "${PLAY_NO_RUN:-}" ] && exit 0
say "starting the game at $(short "$(git -C "$play" rev-parse HEAD)")."
cd "$play"
# As make run: a Godot started by a tool skips its extra activation when the bundle id matches, and from the owner's
# terminal the game still comes to the front.
exec env __CFBundleIdentifier=org.godotengine.godot "$godot" --path "$play" < /dev/null
