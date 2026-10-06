#!/usr/bin/env bash
# OpenAI fallback (not the pinned provider). Wraps `openai images generate` so every call uses the style preamble, the pinned model, the
# project output folder, and is logged to art/generation_log.jsonl (plan §7 step 2).
# Usage: tools/art/generate.sh <name> <subfolder> "<prompt>" [--background transparent] [extra flags]
# MODEL=<id> overrides the pinned model (used for the style test).
# The key comes from OPENAI_API_KEY (set in ~/.zshrc); it never goes in the repo.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NAME="$1"; SUB="$2"; PROMPT="$3"; shift 3
MODEL="${MODEL:-$(python3 -c "import json;print(json.load(open('$ROOT/art/manifest.json'))['image_model'])")}"
OUT="$ROOT/art/generated/$SUB"
mkdir -p "$OUT"
[ -n "${OPENAI_API_KEY:-}" ] || { [ -f "$HOME/.zshrc" ] && eval "$(grep -E '^export OPENAI_API_KEY=' "$HOME/.zshrc")"; }
[ -n "${OPENAI_API_KEY:-}" ] || { echo "OPENAI_API_KEY is not set" >&2; exit 1; }
FULL="$(cat "$ROOT/art/prompts/style_preamble.txt") $PROMPT"
openai images generate --model "$MODEL" --quality high --output-format png --inline off \
  --prompt "$FULL" --name "$NAME" --output-dir "$OUT" "$@"
python3 - "$ROOT" "$NAME" "$SUB" "$MODEL" "$PROMPT" "$*" <<'PY'
import json, sys, time
root, name, sub, model, prompt, extra = sys.argv[1:]
with open(f"{root}/art/generation_log.jsonl", "a") as f:
    f.write(json.dumps({"time": time.strftime("%Y-%m-%dT%H:%M:%S"), "name": name, "folder": sub,
                        "model": model, "quality": "high", "prompt": prompt, "extra_flags": extra}) + "\n")
PY
