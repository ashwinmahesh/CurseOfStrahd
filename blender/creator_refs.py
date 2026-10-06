"""Cuts a creator body turnaround into one reference image per view, for its attack keyframe strips
(tools/art/creator_art.py, docs/art/creator.md). Like blender/anim_refs.py, but for art/generated/creator bodies, which
have no art/manifest.json entry: five views, every profile facing right.

blender -b --python blender/creator_refs.py -- <body turnaround png> <out dir>
"""
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "lib"))
sys.path.insert(0, str(HERE))
import anim  # noqa: E402
import cutout  # noqa: E402
import render_walk as rw  # noqa: E402


def main():
    src, out = sys.argv[sys.argv.index("--") + 1:][:2]
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    sheet = anim.clean_source(cutout.load_rgba(src))
    figures = cutout.find_figures(sheet, 5)
    if len(figures) != 5:
        raise SystemExit(f"{src}: expected five views, found {len(figures)}")
    for name, fig in zip(rw.VIEWS5, figures):
        h, w = fig.shape[:2]
        m = int(h * 0.08)
        canvas = np.ones((h + 2 * m, max(w + 2 * m, int(h * 0.75)), 4), dtype=np.float32)
        x0 = (canvas.shape[1] - w) // 2
        region = canvas[m:m + h, x0:x0 + w]
        alpha = fig[..., 3:4]
        region[..., :3] = fig[..., :3] * alpha + region[..., :3] * (1.0 - alpha)
        cutout.save_rgba(canvas, out / f"{name}.png")
    print(f"views: {', '.join(rw.VIEWS5)} -> {out}")


main()
