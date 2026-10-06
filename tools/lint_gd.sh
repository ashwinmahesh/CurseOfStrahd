#!/usr/bin/env bash
# Compiles every rules/ and combat/ script on its own (godot --check-only, no autoloads), so a rules script no test
# loads still can't hide a parse error, and rules/ and combat/ provably stay free of autoloads. Exit 1 on failure.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
status=0
count=0
while IFS= read -r f; do
  count=$((count + 1))
  out=$("$GODOT" --path . --headless --check-only --script "res://$f" 2>&1 | grep -E "SCRIPT ERROR|ERROR:|WARNING:" | sort -u)
  if [ -n "$out" ]; then
    echo "  FAIL  $f"
    echo "$out" | sed 's/^/        /'
    status=1
  fi
done < <(find rules combat story -name "*.gd" | sort)
echo "$count scripts checked"
exit $status
