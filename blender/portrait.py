"""Generated portrait -> square, palette-snapped portrait for the initiative strip and party frames.

blender -b --python blender/portrait.py -- --in <png> --id <asset_id> [--size 512]

Centre-crops to a square, downsizes by box averaging (whole factors) or Blender's scaler, snaps every
pixel to the Strahd palette (cutout.quantize, same as the sprites) and writes art/portraits/<id>.png.
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


def main():
    a = args()
    arr = resize(square(cutout.load_rgba(a.src)), a.size)
    arr[..., 3] = 1.0
    out = cutout.ROOT / "art" / "portraits" / f"{a.id}.png"
    cutout.save_rgba(cutout.quantize(arr), out)
    print(f"portrait: {out} ({a.size}x{a.size})")


main()
