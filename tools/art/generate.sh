#!/usr/bin/env bash
# The one entry point for image generation (plan §7 step 2). Uses the provider and model pinned in
# art/manifest.json, adds the style preamble and logs every call to art/generation_log.jsonl.
# Usage: tools/art/generate.sh <name> <subfolder> "<prompt>" [--aspect 3:2]
# Gemini (pinned) returns opaque images: ask for a plain flat white background for sprites.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROVIDER="$(python3 -c "import json;print(json.load(open('$ROOT/art/manifest.json')).get('image_provider','gemini'))")"
MODEL="$(python3 -c "import json;print(json.load(open('$ROOT/art/manifest.json'))['image_model'])")"
if [ "$PROVIDER" = "gemini" ]; then
  exec python3 "$ROOT/tools/art/generate_gemini.py" "$@" --model "$MODEL"
else
  MODEL="$MODEL" exec "$ROOT/tools/art/generate_openai.sh" "$@"
fi
