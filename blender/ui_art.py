"""Menu ornaments and icons (owner feedback after Phase 3: gothic curves and icons on the overlays).

Gemini draws each piece as a black silhouette on white (art/generated/ui/). This turns darkness into alpha and
writes white shapes to art/ui/, so the game tints them with palette colours (gilt) and they stay crisp on any
background. Run: make ui_art
"""
import sys
from pathlib import Path

import bpy
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib import cutout  # noqa: E402

SRC = cutout.ROOT / "art" / "generated" / "ui"
OUT = cutout.ROOT / "art" / "ui"

# The icon sheet's 4 x 4 grid, row by row (the prompt in art/generation_log.jsonl).
ICONS = [
    "character", "inventory", "journal", "party",
    "map", "rest", "search", "sneak",
    "split", "menu", "spells", "talk",
    "trade", "key", "attack", "door",
]


def mask(arr):
    """White shapes whose alpha is how dark the source was (anti-aliased edges kept)."""
    lum = arr[..., 0] * 0.299 + arr[..., 1] * 0.587 + arr[..., 2] * 0.114
    a = np.clip((0.92 - lum) / 0.75, 0.0, 1.0)
    out = np.ones(arr.shape, dtype=np.float32)
    out[..., 3] = a
    return out


def crop(arr, pad=4):
    ys, xs = np.nonzero(arr[..., 3] > 0.05)
    y0, y1 = max(0, ys.min() - pad), min(arr.shape[0], ys.max() + pad + 1)
    x0, x1 = max(0, xs.min() - pad), min(arr.shape[1], xs.max() + pad + 1)
    return arr[y0:y1, x0:x1]


def square(arr):
    h, w = arr.shape[:2]
    n = max(h, w)
    out = np.zeros((n, n, 4), dtype=np.float32)
    out[..., :3] = 1.0
    out[(n - h) // 2:(n - h) // 2 + h, (n - w) // 2:(n - w) // 2 + w] = arr
    return out


def resized(arr, width, height):
    img = cutout.to_bpy_image(arr, "ui_resize")
    img.scale(width, height)
    data = np.empty(width * height * 4, dtype=np.float32)
    img.pixels.foreach_get(data)
    bpy.data.images.remove(img)
    out = np.flipud(data.reshape(height, width, 4)).copy()
    out[..., :3] = 1.0
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    corner = crop(mask(cutout.load_rgba(SRC / "ui_corner.png")))
    side = 192
    cutout.save_rgba(resized(corner, side, round(side * corner.shape[0] / corner.shape[1])), OUT / "corner.png")
    divider = crop(mask(cutout.load_rgba(SRC / "ui_divider.png")))
    cutout.save_rgba(resized(divider, 640, round(640 * divider.shape[0] / divider.shape[1])), OUT / "divider.png")
    sheet = mask(cutout.load_rgba(SRC / "ui_icons.png"))
    h, w = sheet.shape[:2]
    for i, name in enumerate(ICONS):
        r, c = divmod(i, 4)
        cell = sheet[r * h // 4:(r + 1) * h // 4, c * w // 4:(c + 1) * w // 4]
        cutout.save_rgba(resized(square(crop(cell, 6)), 96, 96), OUT / "icons" / f"{name}.png")
    print(f"ui art: corner, divider and {len(ICONS)} icons written to {OUT.relative_to(cutout.ROOT)}")


main()
