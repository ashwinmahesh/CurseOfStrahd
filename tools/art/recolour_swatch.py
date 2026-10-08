#!/usr/bin/env python3
"""Recolours a texture swatch by its light and dark into a palette ramp, for a surface that is another's in a new
colour (the Castle Ravenloft guest bedroom's yellow damask from the green: no image generation).

Usage: tools/art/recolour_swatch.py <theme/from> <theme/to> <dark> <mid> <light>      (palette colour names)
then: make textures ONLY=<theme/to> and python3 tools/art/build_surfaces.py --only <theme/to>
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageEnhance, ImageOps

ROOT = Path(__file__).resolve().parents[2]


def main():
    src, dst, dark, mid, light = sys.argv[1:6]
    palette = json.loads((ROOT / "art" / "palette" / "palette.json").read_text())
    rgb = lambda name: tuple(int(palette[name].lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))
    for folder, ext, fmt in (("textures", "png", "PNG"), ("surfaces", "webp", "WEBP")):
        a = ROOT / "art" / "generated" / folder / ("%s.%s" % (src.replace("/", "_"), ext))
        b = ROOT / "art" / "generated" / folder / ("%s.%s" % (dst.replace("/", "_"), ext))
        if not a.exists():
            continue
        g = ImageEnhance.Contrast(Image.open(a).convert("L")).enhance(1.15)
        out = ImageOps.colorize(g, black=rgb(dark), mid=rgb(mid), white=rgb(light), midpoint=110)
        out.save(b, fmt, **({"quality": 92} if fmt == "WEBP" else {}))
        print("wrote", b.relative_to(ROOT))


if __name__ == "__main__":
    main()
