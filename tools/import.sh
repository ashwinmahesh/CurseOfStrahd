#!/usr/bin/env bash
# Godot's import, for make import and every target that imports. A headless editor imports textures one at a time;
# with a window it imports several at once: reimporting 20 big sprite sheets took 8.5 to 9.5 min headless and 4 min
# windowed, with the same bytes out (2026-10-07). So it runs through tools/godot with NOFOCUS_HIDE=1, which never puts
# the editor's window on screen, and puts project.godot back afterwards (the editor rewrites it when it quits).
# Headless instead with IMPORT_HEADLESS=1, outside a logged-in desktop session (launchctl's manager isn't Aqua), or
# when the windowed import fails. Prints the import's output, for tools/logcheck.sh. Same GODOT variable as the Makefile.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
godot="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$root"

headless() {
  "$godot" --path . --headless --import
}

if [ -n "${IMPORT_HEADLESS:-}" ] || [ "$(launchctl managername 2>/dev/null)" != "Aqua" ]; then
  headless
  exit $?
fi

keep="$(mktemp -t strahd_project)"
log="$(mktemp -t strahd_import)"
cp -p project.godot "$keep"
restore() {
  cmp -s "$keep" project.godot || cp -p "$keep" project.godot
  rm -f "$keep" "$log"
}
trap restore EXIT

NOFOCUS_HIDE=1 GODOT="$godot" tools/godot --path . --import --audio-driver Dummy > "$log" 2>&1
status=$?
if [ $status -eq 0 ]; then
  cat "$log"
  exit 0
fi
echo "make import: the import with a hidden window failed (exit $status); importing headless instead"
headless
