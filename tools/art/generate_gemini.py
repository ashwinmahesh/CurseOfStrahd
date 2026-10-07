#!/usr/bin/env python3
"""Gemini image generation, the counterpart of tools/art/generate.sh for Gemini Flash image models.

Usage: tools/art/generate_gemini.py <name> <subfolder> "<prompt>" [--model M] [--aspect 3:2] [--ref img.png] [--size 2K]
Adds the project style preamble, saves art/generated/<subfolder>/<name>.png and logs the call to
art/generation_log.jsonl. Stdlib only. The key comes from GEMINI_API_KEY (read from ~/.zshrc if
the shell doesn't have it) and is sent as a header, never in the URL.

Every call, failed ones too, is counted in the art spend ledger (tools/art/gemini_budget.py, make art-spend), and
nothing is sent once the key is at its stop point or today's requests are spent (GEMINI_OVERRUN=1 sends anyway).

Gemini returns opaque images, so prompts ask for a plain flat background and the sprite pipeline
removes it (blender/lib/cutout.py remove_background).

--ref sends an existing image along with the prompt (e.g. the neutral portrait when generating another
expression of the same character); it is recorded in the log.

--size asks for a larger image (2K or 4K) where a picture is shown big, such as the travel map; the default is 1K.

Gemini usually returns JPEG data. The file is always written as a real PNG (converted with macOS `sips`), because
Godot imports everything under res:// and refuses JPEG bytes behind a .png name ("Not a PNG file").
"""
import argparse
import base64
import datetime as dt
import json
import os
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gemini_budget  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
DEFAULT_MODEL = "gemini-3.1-flash-image"


def api_key():
    return gemini_budget.api_key()


def write_png(raw, out):
    """Writes the returned image as a real PNG. Non-PNG bytes are decoded in a temp folder outside the project
    (so Godot never sees them) and converted with sips."""
    if raw[:8] == b"\x89PNG\r\n\x1a\n":
        out.write_bytes(raw)
        return
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / "image.jpg"
        src.write_bytes(raw)
        dst = Path(tmp) / "image.png"
        r = subprocess.run(["sips", "-s", "format", "png", str(src), "--out", str(dst)], capture_output=True, text=True)
        if r.returncode != 0 or not dst.exists():
            sys.exit(f"Could not convert the returned image to PNG: {r.stderr.strip()[:300]}")
        out.write_bytes(dst.read_bytes())


def main():
    p = argparse.ArgumentParser()
    p.add_argument("name")
    p.add_argument("folder")
    p.add_argument("prompt")
    p.add_argument("--model", default=os.environ.get("GEMINI_MODEL", DEFAULT_MODEL))
    p.add_argument("--aspect", default="1:1", help="e.g. 1:1, 3:2, 16:9")
    p.add_argument("--ref", action="append", default=[], help="reference image (PNG), may repeat")
    p.add_argument("--size", default="", help="1K (default), 2K or 4K")
    a = p.parse_args()

    preamble = (ROOT / "art" / "prompts" / "style_preamble.txt").read_text().strip()
    parts = [{"inlineData": {"mimeType": "image/png", "data": base64.b64encode(Path(r).read_bytes()).decode()}}
             for r in a.ref]
    parts.append({"text": f"{preamble} {a.prompt}"})
    body = {
        "contents": [{"role": "user", "parts": parts}],
        "generationConfig": {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": a.aspect}},
    }
    if a.size:
        body["generationConfig"]["imageConfig"]["imageSize"] = a.size
    key = api_key()
    gemini_budget.guard(a.model, a.size, key)

    def count(status, code=None):
        gemini_budget.record(a.model, a.size, a.name, a.folder, status, code, key)

    req = urllib.request.Request(ENDPOINT.format(model=a.model), data=json.dumps(body).encode(),
                                 headers={"x-goog-api-key": key, "Content-Type": "application/json"})
    try:
        data = json.load(urllib.request.urlopen(req, timeout=300))
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        try:
            detail = json.loads(detail)["error"]["message"]
        except (ValueError, KeyError, TypeError):
            pass
        count("error", e.code)
        if e.code == 402 or "credits are depleted" in str(detail).lower():
            gemini_budget.depleted(key)
        sys.exit(f"Gemini request failed ({e.code}): {str(detail)[:400]}")
    except (urllib.error.URLError, OSError) as e:
        count("error", "network")
        sys.exit(f"Gemini request failed (network): {e}")

    parts = data.get("candidates", [{}])[0].get("content", {}).get("parts", [])
    images = [part["inlineData"]["data"] for part in parts if "inlineData" in part]
    if not images:
        count("refused")
        sys.exit(f"No image returned: {json.dumps(data)[:400]}")
    out = ROOT / "art" / "generated" / a.folder / f"{a.name}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    write_png(base64.b64decode(images[0]), out)
    usage = data.get("usageMetadata", {})
    # One time for the log and the ledger, so the ledger can tell this call from the same line in another worktree.
    now = dt.datetime.now().astimezone()
    gemini_budget.record(a.model, a.size, a.name, a.folder, "ok", key=key, when=now)
    with open(ROOT / "art" / "generation_log.jsonl", "a") as f:
        f.write(json.dumps({"time": now.strftime("%Y-%m-%dT%H:%M:%S"), "name": a.name, "folder": a.folder,
                            "model": a.model, "aspect": a.aspect, **({"size": a.size} if a.size else {}), "prompt": a.prompt,
                            **({"ref": [os.path.relpath(Path(r).resolve(), ROOT) for r in a.ref]} if a.ref else {}),
                            "output_tokens": usage.get("candidatesTokenCount")}) + "\n")
    print(f"Saved image: {out}")


if __name__ == "__main__":
    main()
