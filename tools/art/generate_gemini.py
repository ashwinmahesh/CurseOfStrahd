#!/usr/bin/env python3
"""Gemini image generation, the counterpart of tools/art/generate.sh for Gemini Flash image models.

Usage: tools/art/generate_gemini.py <name> <subfolder> "<prompt>" [--model M] [--aspect 3:2]
Adds the project style preamble, saves art/generated/<subfolder>/<name>.png and logs the call to
art/generation_log.jsonl. Stdlib only. The key comes from GEMINI_API_KEY (read from ~/.zshrc if
the shell doesn't have it) and is sent as a header, never in the URL.

Gemini returns opaque images, so prompts ask for a plain flat background and the sprite pipeline
removes it (blender/lib/cutout.py remove_background).
"""
import argparse
import base64
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
DEFAULT_MODEL = "gemini-2.5-flash-image"


def api_key():
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        rc = Path.home() / ".zshrc"
        if rc.exists():
            m = re.search(r"^export GEMINI_API_KEY=['\"]?([^'\"\n]+)", rc.read_text(), re.M)
            key = m.group(1) if m else None
    if not key:
        sys.exit("GEMINI_API_KEY is not set")
    return key


def main():
    p = argparse.ArgumentParser()
    p.add_argument("name")
    p.add_argument("folder")
    p.add_argument("prompt")
    p.add_argument("--model", default=os.environ.get("GEMINI_MODEL", DEFAULT_MODEL))
    p.add_argument("--aspect", default="1:1", help="e.g. 1:1, 3:2, 16:9")
    a = p.parse_args()

    preamble = (ROOT / "art" / "prompts" / "style_preamble.txt").read_text().strip()
    body = {
        "contents": [{"role": "user", "parts": [{"text": f"{preamble} {a.prompt}"}]}],
        "generationConfig": {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": a.aspect}},
    }
    req = urllib.request.Request(ENDPOINT.format(model=a.model), data=json.dumps(body).encode(),
                                 headers={"x-goog-api-key": api_key(), "Content-Type": "application/json"})
    try:
        data = json.load(urllib.request.urlopen(req, timeout=300))
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        try:
            detail = json.loads(detail)["error"]["message"]
        except (ValueError, KeyError):
            pass
        sys.exit(f"Gemini request failed ({e.code}): {detail[:400]}")

    parts = data.get("candidates", [{}])[0].get("content", {}).get("parts", [])
    images = [part["inlineData"]["data"] for part in parts if "inlineData" in part]
    if not images:
        sys.exit(f"No image returned: {json.dumps(data)[:400]}")
    out = ROOT / "art" / "generated" / a.folder / f"{a.name}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(base64.b64decode(images[0]))
    usage = data.get("usageMetadata", {})
    with open(ROOT / "art" / "generation_log.jsonl", "a") as f:
        f.write(json.dumps({"time": time.strftime("%Y-%m-%dT%H:%M:%S"), "name": a.name, "folder": a.folder,
                            "model": a.model, "aspect": a.aspect, "prompt": a.prompt,
                            "output_tokens": usage.get("candidatesTokenCount")}) + "\n")
    print(f"Saved image: {out}")


if __name__ == "__main__":
    main()
