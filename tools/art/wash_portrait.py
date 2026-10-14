#!/usr/bin/env python3
"""Washes a portrait to light for a figure made of it (the Lantern Girl's, from Rose's): every colour but the ground and
the outline is mapped by its brightness onto a ramp of palette colours (no image generation, no Blender). The sprite
side of the same look is a walk.tres `metadata/wash` (DirectionalSprite.wash).

Usage: tools/art/wash_portrait.py <portrait id> <new id>          e.g. rose lantern_girl
"""
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
# Brightness (0-1) at or above which each palette colour is used: ivory and wick for the lit parts, parchment and tan
# through the middle, umber for the deepest shade. The ground (ash violet), void and ink (outline) are kept.
RAMP = [(0.9, "ivory"), (0.75, "wick"), (0.62, "vellum"), (0.5, "parchment"), (0.38, "tan"), (0.25, "bone"),
        (0.12, "bone_dark"), (0.0, "umber")]


def main():
    src, dst = sys.argv[1:3]
    palette = json.loads((ROOT / "art" / "palette" / "palette.json").read_text())
    rgb = {k: tuple(int(v.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)) for k, v in palette.items()}
    kept = {rgb["ash_violet"], rgb["void"], rgb["ink"]}

    def wash(c):
        if c in kept:
            return c
        light = (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255
        return next(rgb[k] for t, k in RAMP if light >= t)

    img = Image.open(ROOT / "art" / "portraits" / f"{src}.png").convert("RGBA")
    seen, pixels = {}, []
    for r, g, b, a in img.getdata():
        if (r, g, b) not in seen:
            seen[(r, g, b)] = wash((r, g, b))
        pixels.append(seen[(r, g, b)] + (a,))
    out = Image.new("RGBA", img.size)
    out.putdata(pixels)
    out.save(ROOT / "art" / "portraits" / f"{dst}.png")
    print(f"wrote art/portraits/{dst}.png ({len(set(seen.values()))} colours)")


if __name__ == "__main__":
    main()
