"""Single-view prop on a flat white background -> cut-out, palette-snapped billboard sprite (P4-09).

blender -b --python blender/prop_sprite.py -- --in <png> --id <prop_id> --height <world units> [--max 512] [--saturate K]

Removes the background (cutout.remove_background, including enclosed gaps such as between wagon spokes), keeps
the main shape plus any piece at least 2 % of its size (drops specks), crops tight, scales so the longer side is
--max px, binarizes alpha, snaps to the palette, despeckles and writes art/sprites/props/<id>.png. The bottom row
of opaque pixels is where the prop meets the ground (anchor bottom centre). Records size, world height and the
Sprite3D pixel_size that gives that height in art/sprites/props/manifest.json.
"""
import argparse
import json
import sys
from pathlib import Path

import bpy
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import cutout  # noqa: E402

MANIFEST = cutout.ROOT / "art" / "sprites" / "props" / "manifest.json"


def args():
    p = argparse.ArgumentParser()
    p.add_argument("--in", dest="src", required=True)
    p.add_argument("--id", required=True)
    p.add_argument("--height", type=float, required=True, help="height in world units (one unit = 5 ft)")
    p.add_argument("--max", type=int, default=512)
    p.add_argument("--saturate", type=float, default=1.0)
    return p.parse_args(sys.argv[sys.argv.index("--") + 1:])


def keep_main(arr, min_frac=0.02):
    comps = cutout.label_components(arr[..., 3] > 0.5)
    sizes = [sum(r[2] - r[1] for r in c) for c in comps]
    big = max(sizes)
    out = arr.copy()
    for c, s in zip(comps, sizes):
        if s < min_frac * big:
            for y, x0, x1 in c:
                out[y, x0:x1] = 0.0
    return out


def resize(arr, w, h):
    img = cutout.to_bpy_image(arr, "prop_src")
    img.scale(w, h)
    out = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(out)
    bpy.data.images.remove(img)
    return np.flipud(out.reshape(h, w, 4)).copy()


def main():
    a = args()
    arr = cutout.binarize_alpha(cutout.remove_background(cutout.load_rgba(a.src)))
    arr = keep_main(arr)
    ys, xs = np.nonzero(arr[..., 3] > 0.5)
    arr = arr[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = arr.shape[:2]
    k = a.max / float(max(h, w))
    nw, nh = max(1, round(w * k)), max(1, round(h * k))
    small = cutout.binarize_alpha(resize(arr, nw, nh))
    small = cutout.despeckle(cutout.quantize(cutout.saturate(small, a.saturate)))
    # A 2 px margin, then round up to multiples of 4 (VRAM block compression); centred, feet 2 px above the bottom.
    ph, pw = -(-(nh + 4) // 4) * 4, -(-(nw + 4) // 4) * 4
    pad = np.zeros((ph, pw, 4), dtype=np.float32)
    x0 = (pw - nw) // 2
    pad[ph - 2 - nh:ph - 2, x0:x0 + nw] = small
    rel = Path("art") / "sprites" / "props" / f"{a.id}.png"
    cutout.save_rgba(pad, cutout.ROOT / rel)
    rows = np.nonzero(pad[..., 3].max(axis=1) > 0)[0]
    content_h = int(rows[-1] - rows[0] + 1)
    data = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}
    data.setdefault("props", {})[a.id] = {
        "file": str(rel),
        "width_px": int(pad.shape[1]),
        "height_px": int(pad.shape[0]),
        "world_height": a.height,
        "pixel_size": round(a.height / content_h, 5),
        "anchor": "bottom_center",
        "source": str(Path(a.src).resolve().relative_to(cutout.ROOT)),
    }
    if a.saturate != 1.0:
        data["props"][a.id]["saturate"] = a.saturate
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(data, indent=2) + "\n")
    print(f"prop: {rel} ({pad.shape[1]}x{pad.shape[0]} px, {a.height} units tall)")


main()
