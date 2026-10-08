#!/usr/bin/env bash
# Godot's import, for make import and every target that imports. A headless editor imports textures one at a time;
# with a window it imports several at once: reimporting 20 big sprite sheets took 8.5 to 9.5 min headless and 4 min
# windowed, with the same bytes out (2026-10-07). So it runs through tools/godot with NOFOCUS_HIDE=1, which never puts
# the editor's window on screen, and puts project.godot back afterwards (the editor rewrites it when it quits).
# Headless instead with IMPORT_HEADLESS=1, outside a logged-in desktop session (launchctl's manager isn't Aqua), or
# when the windowed import fails. Prints the import's output, for tools/logcheck.sh. Same GODOT variable as the Makefile.
# The first import after a big drop of new files can log errors that a second pass doesn't (scripts read before the
# art they name is imported: seen on a fresh worktree and after the W4 textures arrived), so an import that logs errors
# runs once more, and only the second pass's output counts. An error that's real is in both.
# One import per folder at a time: a second one waits for the first (.godot/import.lock), since two at once race on
# .godot (the owner's make run and the build's make ci in the main folder, 2026-10-08). Ctrl-C stops the import at
# once: the windowed editor otherwise finishes importing before it notices. A Godot stopped from outside (kill, or
# Ctrl-C in another terminal) isn't imported again, headless or as a second pass: the import ends there.
# A folder with no import cache yet (a plain git worktree add) starts from an APFS clone of the main checkout's cache
# and .import files, when the two are on the same volume, so only what differs is imported. A full import (no cache
# to start from) writes about 8 GB, and one that fills the disk part-way leaves a broken cache: it's refused, exit 75,
# with under IMPORT_MIN_FREE_GB (20) free. This script's own notes go to stderr, which make shows; a refused or
# stopped import also prints an ERROR: line on stdout, so tools/logcheck.sh fails it and make import doesn't mark it
# done.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
godot="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$root"
ERRORS='SCRIPT ERROR|ERROR:|Parse Error|Failed loading'   # what tools/logcheck.sh fails on
lock=".godot/import.lock"
child=""
owned=""

log="$(mktemp "${TMPDIR:-/tmp}/strahd_import.XXXXXX")"   # portable: the release workflow runs on Linux
keep=""
finish() {
  # Only an import that took the lock put project.godot aside, so only it puts it back.
  if [ -n "$keep" ]; then
    cmp -s "$keep" project.godot || cp -p "$keep" project.godot
    rm -f "$keep"
  fi
  rm -f "$log"
  if [ -n "$owned" ]; then
    rm -f "$lock/pid"
    rmdir "$lock" 2> /dev/null || true
  fi
}
trap finish EXIT

## Ctrl-C or a kill: stop Godot now (a polite TERM, then KILL after three seconds) and leave.
stop() {
  if [ -n "$child" ] && kill -0 "$child" 2> /dev/null; then
    kill -TERM "$child" 2> /dev/null || true
    for _ in 1 2 3; do
      kill -0 "$child" 2> /dev/null || break
      sleep 1
    done
    kill -KILL "$child" 2> /dev/null || true
  fi
  echo "make import: stopped" >&2
  exit 130
}
trap stop INT TERM

## Waits its turn: the lock is a folder (made atomically), holding the PID of the import that has it. One left by an
## import that was killed is cleared, and so is one whose PID isn't importing this folder (a lock cloned along with
## .godot from another folder, or a PID reused since).
here="$(pwd -P)"
holds() {
  kill -0 "$1" 2> /dev/null && [ "$(lsof -a -p "$1" -d cwd -Fn 2> /dev/null | sed -n 's/^n//p')" = "$here" ]
}
mkdir -p .godot
said=""
until mkdir "$lock" 2> /dev/null; do
  holder="$(cat "$lock/pid" 2> /dev/null || true)"
  if [ -n "$holder" ] && ! holds "$holder"; then
    rm -f "$lock/pid"
    rmdir "$lock" 2> /dev/null || true
    continue
  fi
  [ -n "$said" ] || echo "make import: another import is running in this folder (PID ${holder:-?}); waiting for it" >&2
  said=1
  sleep 2
done
owned=1
echo $$ > "$lock/pid"

## No import cache here yet: a clone of the main checkout's when it's on this volume (seconds, almost no disk), with
## main's untracked .import files beside the assets; else a full import, refused when the disk is nearly full.
cache_empty() { [ -z "$(ls -A .godot/imported 2> /dev/null | head -1)" ]; }
if cache_empty; then
  main="$(cd "$(git rev-parse --path-format=absolute --git-common-dir)/.." && pwd -P)"
  if [ "$main" != "$here" ] && [ -d "$main/.godot/imported" ] && [ "$(stat -f %d "$main")" = "$(stat -f %d .)" ]; then
    echo "make import: no import cache here yet; starting from a clone of $main's (almost no disk)" >&2
    rm -rf .godot/imported
    cp -Rc "$main/.godot/imported" .godot/
    git -C "$main" ls-files -z --others --ignored --exclude-standard -- '*.import' ':!captures/' ':!builds/' \
      | rsync --ignore-existing --from0 --files-from=- "$main/" ./ \
      || echo "make import: some of main's .import files weren't copied; Godot imports those assets afresh" >&2
  fi
fi
if cache_empty; then
  free="$(df -Pk . | awk 'NR == 2 { print int($4 / 1048576) }')"
  if [ "$free" -lt "${IMPORT_MIN_FREE_GB:-20}" ]; then
    echo "make import: no import cache here, and a full import writes about 8 GB; only $free GB free on this disk" \
      "(${IMPORT_MIN_FREE_GB:-20} needed; IMPORT_MIN_FREE_GB sets it). make disk shows where the space went; a lane" \
      "made with make lane starts from a clone instead." >&2
    echo "ERROR: make import refused: $free GB free"
    exit 75
  fi
fi
# Put aside only once it's this import's turn: taken while another import's editor had rewritten it, the rewrite is
# what would be put back (seen 2026-10-08, the owner's make run waiting on the build's make ci).
keep="$(mktemp "${TMPDIR:-/tmp}/strahd_project.XXXXXX")"
cp -p project.godot "$keep"

## Runs a command in the background into $log and waits, so Ctrl-C reaches stop() at once. Its exit status.
run() {
  "$@" > "$log" 2>&1 &
  child=$!
  wait "$child"
  local status=$?
  child=""
  return $status
}

## Whether an exit status is Godot stopped from outside: HUP, INT, KILL or TERM (a crash is another signal).
stopped() { case "$1" in 129|130|137|143) return 0 ;; *) return 1 ;; esac; }

## One import into $log: windowed (off screen) where it can, else headless. Exit status as Godot's.
import_once() {
  if [ -z "${IMPORT_HEADLESS:-}" ] && [ "$(launchctl managername 2>/dev/null)" = "Aqua" ]; then
    run env NOFOCUS_HIDE=1 GODOT="$godot" tools/godot --path . --import --audio-driver Dummy
    local status=$?
    if [ $status -eq 0 ] || stopped $status; then
      return $status
    fi
    echo "make import: the import with a hidden window failed (exit $status); importing headless instead"
  fi
  run "$godot" --path . --headless --import
}

import_once
status=$?
if stopped $status; then
  cat "$log"
  echo "make import: Godot was stopped (signal $((status - 128))) before the import finished; run make import again" >&2
  echo "ERROR: make import stopped"
  exit $status
fi
if [ $status -ne 0 ] || grep -qE "$ERRORS" "$log"; then
  echo "make import: the first pass logged errors; importing again, and the second pass is what counts"
  import_once
  status=$?
fi
cat "$log"
exit $status
