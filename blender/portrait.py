"""Generated portrait -> square, palette-snapped portrait for the initiative strip and party frames.

blender -b --python blender/portrait.py -- --in <png> --id <asset_id> [--size 512] [--keep-background] [--bg NAME] [--saturate K]

Centre-crops to a square, downsizes by box averaging (whole factors) or Blender's scaler, snaps every
pixel to the Strahd palette (cutout.quantize, same as the sprites), clears the single-pixel speckle the
JPEG source leaves (cutout.despeckle), flattens the background to one palette colour, ash_violet unless --bg names
another (Gemini often paints a grainy or mottled purple, worst on expression variants made from a reference) and writes
art/portraits/<id>.png.
"""
import argparse
import sys
from pathlib import Path

import bpy
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import cutout  # noqa: E402


def args():
    p = argparse.ArgumentParser()
    p.add_argument("--in", dest="src", required=True)
    p.add_argument("--id", required=True)
    p.add_argument("--size", type=int, default=512)
    p.add_argument("--keep-background", action="store_true", help="skip the flat-background pass")
    # Every portrait stands on the same ground, so they match side by side in the turn order and the party frames: the
    # border's own colour gave 26 of them a darker or greyer square (UI QA ART-04). "border" keeps the old behaviour.
    p.add_argument("--bg", default="ash_violet",
                   help="palette name for the flat background (default ash_violet; 'border': the border's own colour)")
    p.add_argument("--saturate", type=float, default=1.0, help="chroma boost before quantizing (cutout.saturate)")
    return p.parse_args(sys.argv[sys.argv.index("--") + 1:])


def square(arr):
    h, w = arr.shape[:2]
    s = min(h, w)
    y0, x0 = (h - s) // 2, (w - s) // 2
    return arr[y0:y0 + s, x0:x0 + s]


def resize(arr, size):
    s = arr.shape[0]
    if s % size == 0:
        k = s // size
        return arr.reshape(size, k, size, k, 4).mean(axis=(1, 3))
    img = cutout.to_bpy_image(arr, "portrait_src")
    img.scale(size, size)
    out = np.empty(size * size * 4, dtype=np.float32)
    img.pixels.foreach_get(out)
    bpy.data.images.remove(img)
    return np.flipud(out.reshape(size, size, 4)).copy()


def flatten_background(arr, min_share=0.04, colour=None, max_island=150):
    """The background is whatever is reachable from the top edge and the upper two thirds of the side edges
    through the colours that make up that border (each at least `min_share` of it). The figure's ink outline
    stops the fill; small islands inside the background are absorbed. Every such pixel takes the border's most common colour. Runs on the quantized image."""
    h, w = arr.shape[:2]
    rgb8 = np.round(arr[..., :3] * 255).astype(np.int64)
    key = (rgb8[..., 0] << 16) | (rgb8[..., 1] << 8) | rgb8[..., 2]
    side = int(h * 0.66)
    ring = np.concatenate([key[0], key[:side, 0], key[:side, -1]])
    vals, counts = np.unique(ring, return_counts=True)
    bg = vals[counts >= min_share * len(ring)]
    allowed = np.isin(key, bg)
    seed = np.zeros_like(allowed)
    seed[0] = True
    seed[:side, 0] = True
    seed[:side, -1] = True
    mask = cutout._grow(seed, allowed)
    # Specks of other colours left in the background (islands under max_island px, clear of the bottom edge,
    # where the bust is) join it.
    for comp in cutout.label_components(~mask):
        if sum(x1 - x0 for _, x0, x1 in comp) < max_island and max(y for y, _, _ in comp) < h - 1:
            for y, x0, x1 in comp:
                mask[y, x0:x1] = True
    top = vals[np.argmax(counts)]
    if colour is not None:
        r, g, b = (int(round(c * 255)) for c in colour)
        top = (r << 16) | (g << 8) | b
    out = arr.copy()
    out[mask, 0] = ((top >> 16) & 255) / 255.0
    out[mask, 1] = ((top >> 8) & 255) / 255.0
    out[mask, 2] = (top & 255) / 255.0
    return out


def main():
    a = args()
    arr = resize(square(cutout.load_rgba(a.src)), a.size)
    arr[..., 3] = 1.0
    out = cutout.ROOT / "art" / "portraits" / f"{a.id}.png"
    arr = cutout.despeckle(cutout.quantize(cutout.saturate(arr, a.saturate)))
    if not a.keep_background:
        arr = flatten_background(arr, colour=cutout.palette_colour(a.bg) if a.bg not in ("", "border") else None)
    cutout.save_rgba(arr, out)
    print(f"portrait: {out} ({a.size}x{a.size})")


main()
