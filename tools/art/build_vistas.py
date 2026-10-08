"""Cuts the painted backdrops seen past a map's edge (Improvement Ideas W13, Vista, docs/art/atmosphere.md "Vistas")
out of their plain white ground: art/generated/vistas/<source>.png -> art/vistas/<name>.png with a soft alpha, so the
mist at a crag's foot thins out rather than stopping at a hard edge.

  python3 tools/art/build_vistas.py

The paintings come from tools/art/generate.sh with art/prompts/vista_preamble.txt; BACKDROPS picks the take used.
"""
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
# name -> (generated source, height in pixels of the cut-out)
BACKDROPS = {
    "castle_ravenloft": ("castle_ravenloft_far_1", 768),
}


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


def main():
    out_dir = ROOT / "art" / "vistas"
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, (source, height) in BACKDROPS.items():
        img = cut(ROOT / "art" / "generated" / "vistas" / (source + ".png"), height)
        img.save(out_dir / (name + ".png"))
        print("backdrop", name, img.size)


if __name__ == "__main__":
    main()
