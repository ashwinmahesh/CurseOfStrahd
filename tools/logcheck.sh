#!/usr/bin/env bash
# Passes Godot output through and fails on errors hiding behind a green run.
set -o pipefail
status=0
while IFS= read -r line; do
  printf '%s\n' "$line"
  case "$line" in
    *"SCRIPT ERROR"*|*"ERROR:"*|*"Parse Error"*|*"Failed loading"*|*"WARNING: "*"GDScript"*) status=1 ;;
    "  FAIL "*) status=1 ;;
  esac
done
exit $status
