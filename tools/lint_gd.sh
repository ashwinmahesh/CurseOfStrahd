#!/usr/bin/env bash
# Compiles every rules/ and combat/ script on its own (godot --check-only, no autoloads), so a rules script no test
# loads still can't hide a parse error, and rules/ and combat/ provably stay free of autoloads. Exit 1 on failure.
# Several scripts compile at once (LINT_JOBS, 6 by default); each failure prints as one block.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
export GODOT
check() {
  local out
  out=$("$GODOT" --path . --headless --check-only --script "res://$1" 2>&1 | grep -E "SCRIPT ERROR|ERROR:|WARNING:" | sort -u)
  if [ -n "$out" ]; then
    printf '  FAIL  %s\n%s\n' "$1" "$(echo "$out" | sed 's/^/        /')"
    return 1
  fi
}
export -f check
files=$(find rules combat story -name "*.gd" | sort)
echo "$files" | xargs -P "${LINT_JOBS:-6}" -I{} bash -c 'check "$1"' _ {}
status=$?   # 123 when any check failed
echo "$(echo "$files" | grep -c .) scripts checked"
[ $status -eq 0 ]
