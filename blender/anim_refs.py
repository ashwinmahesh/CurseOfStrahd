"""Cuts a turnaround sheet into one reference image per view, for generating attack and walk keyframes
(tools/art/anim_keyframes.py). Each view is centred on a plain white canvas with the figure's own height plus a
margin, so Gemini sees a single figure.

blender -b --python blender/anim_refs.py -- --id <asset_id> --out <dir>

Reads the turnaround, view count and facing from the character's art/manifest.json walk flags (as render_attack.py
does).

Writes <dir>/<view>.png and <dir>/views.json ({view: {"height": px, "width": px}}, the figure's size on the sheet).
"""
import argparse
import json
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
    p = argparse.ArgumentParser()
    p.add_argument("--id", required=True)
    p.add_argument("--out", required=True)
    a = p.parse_args(sys.argv[sys.argv.index("--") + 1:])
    flags = anim.walk_flags(a.id)
    sheet = cutout.binarize_alpha(cutout.remove_background(cutout.load_rgba(cutout.ROOT / flags["turnaround"])))
    figures = cutout.find_figures(sheet, flags["views"] or rw.view_count(sheet))
    names = rw.VIEWS5 if len(figures) == 5 else rw.VIEWS3
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    meta = {}
    for name, fig in zip(names, figures):
        if flags["side_faces"] == "left" and name not in ("front", "back"):
            fig = fig[:, ::-1].copy()
        h, w = fig.shape[:2]
        m = int(h * 0.08)
        canvas = np.ones((h + 2 * m, max(w + 2 * m, int(h * 0.75)), 4), dtype=np.float32)
        x0 = (canvas.shape[1] - w) // 2
        region = canvas[m:m + h, x0:x0 + w]
        alpha = fig[..., 3:4]
        region[..., :3] = fig[..., :3] * alpha + region[..., :3] * (1.0 - alpha)
        cutout.save_rgba(canvas, out / f"{name}.png")
        meta[name] = {"height": h, "width": w}
    (out / "views.json").write_text(json.dumps(meta, indent=1))
    print(f"views: {', '.join(meta)} -> {out}")


main()
