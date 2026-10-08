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
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
godot="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$root"
ERRORS='SCRIPT ERROR|ERROR:|Parse Error|Failed loading'   # what tools/logcheck.sh fails on

log="$(mktemp -t strahd_import)"
keep="$(mktemp -t strahd_project)"
cp -p project.godot "$keep"
restore() {
  cmp -s "$keep" project.godot || cp -p "$keep" project.godot
  rm -f "$keep" "$log"
}
trap restore EXIT

## One import into $log: windowed (off screen) where it can, else headless. Exit status as Godot's.
import_once() {
  if [ -z "${IMPORT_HEADLESS:-}" ] && [ "$(launchctl managername 2>/dev/null)" = "Aqua" ]; then
    NOFOCUS_HIDE=1 GODOT="$godot" tools/godot --path . --import --audio-driver Dummy > "$log" 2>&1
    local status=$?
    if [ $status -eq 0 ]; then
      return 0
    fi
    echo "make import: the import with a hidden window failed (exit $status); importing headless instead"
  fi
  "$godot" --path . --headless --import > "$log" 2>&1
}

import_once
status=$?
if [ $status -ne 0 ] || grep -qE "$ERRORS" "$log"; then
  echo "make import: the first pass logged errors; importing again, and the second pass is what counts"
  import_once
  status=$?
fi
cat "$log"
exit $status
