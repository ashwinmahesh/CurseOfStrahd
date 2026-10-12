"""Cuts the painted backdrops seen past a map's edge (Improvement Ideas W13, Vista, docs/art/atmosphere.md "Vistas")
out of their plain white ground: art/generated/vistas/<source>.png -> art/vistas/<name>.png with a soft alpha, so the
mist at a crag's foot thins out rather than stopping at a hard edge.

  python3 tools/art/build_vistas.py [--generate] [--only id ...]

The paintings come from tools/art/generate.sh with art/prompts/vista_preamble.txt, one prompt per landmark in
tools/art/vista_recipes.json (Castle Ravenloft, and each region's own: the vault's Region Variety Plan); a recipe's
`take` picks the painting used. --generate paints two takes of each landmark that has none yet (the art spend ledger
checks the batch first).
"""
import argparse
import json
import math
import subprocess
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gemini_budget  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
RECIPES = ROOT / "tools" / "art" / "vista_recipes.json"
PAINTINGS = ROOT / "art" / "generated" / "vistas"
TAKES = 2


def cut(src: Path, height: int) -> Image.Image:
    im = Image.open(src).convert("RGB")
    im = im.resize((round(im.width * height / im.height), height), Image.LANCZOS)
    w, h = im.size
    px = im.load()
    out = Image.new("RGBA", (w, h))
    po = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            # How far from the white ground: near-white is clear, a little off it is mist, the rest is solid.
            d = math.sqrt(((255 - r) ** 2 + (255 - g) ** 2 + (255 - b) ** 2) / 3.0) / 255.0
            t = min(1.0, max(0.0, (d - 0.035) / 0.2))
            a = t * t * (3 - 2 * t)
            # Take the white out of the colour that's left, so thin mist doesn't go pale at its edges.
            if 0.0 < a < 1.0:
                r = max(0, min(255, int(255 - (255 - r) / a)))
                g = max(0, min(255, int(255 - (255 - g) / a)))
                b = max(0, min(255, int(255 - (255 - b) / a)))
            po[x, y] = (r, g, b, int(a * 255))
    return out


def generate(landmarks):
    """Two takes of each landmark that has no painting yet."""
    todo = [(k, t) for k in landmarks for t in range(1, TAKES + 1) if not (PAINTINGS / f"{k}_far_{t}.png").exists()]
    if not todo:
        return
    gemini_budget.preflight(len(todo), "1K", "vista landmarks")
    for k, t in todo:
        r = landmarks[k]
        subprocess.run([str(ROOT / "tools" / "art" / "generate.sh"), f"{k}_far_{t}", "vistas", r["prompt"],
                        "--aspect", r["aspect"], "--preamble", "art/prompts/vista_preamble.txt"], check=True)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--generate", action="store_true")
    p.add_argument("--only", nargs="*", default=[])
    a = p.parse_args()
    landmarks = {k: v for k, v in json.loads(RECIPES.read_text())["landmarks"].items() if not a.only or k in a.only}
    if a.generate:
        generate(landmarks)
    out_dir = ROOT / "art" / "vistas"
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, r in landmarks.items():
        img = cut(PAINTINGS / f"{name}_far_{r['take']}.png", int(r["height"]))
        img.save(out_dir / (name + ".png"))
        print("backdrop", name, img.size)


if __name__ == "__main__":
    main()
