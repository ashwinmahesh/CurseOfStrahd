"""Gives an HD turnaround redraw the colours of the original turnaround (docs/art/animation.md, HD sheets).

blender -b --python blender/hd_colour.py -- --id <asset_id> [--src <raw redraw>]

Exits with status 2 (and writes nothing) when the redraw isn't the same sheet: a different number of views, a figure of
another height or width, or a picture that differs from the original beyond the colours (MAX_DIFF), so the caller can
ask Gemini again (tools/art/hd_turnarounds.py).

Gemini redraws a turnaround at twice the size line for line, but often a little paler or with a garment's colour
shifted (Kip's mustard shirt came back cream, his brown trousers beige). The animation strips were drawn from the
original, so the standing frames (from the redraw) would change colour against the walk. The redraw is aligned on the
original (a search over small offsets) and gets the original's colours where they differ over an area: the
difference of the two pictures blurred over a few pixels is added to the redraw, so fills take the original's colour
and the redraw keeps its own sharp lines. Writes <turnaround>_hd.png from --src (default: the same file).
"""
import argparse
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "lib"))
sys.path.insert(0, str(HERE))
import anim  # noqa: E402
import cutout  # noqa: E402
import render_walk as rw  # noqa: E402

RADIUS = 5      # box blur radius at the redraw's size (three passes: about a 9 px Gaussian)
SEARCH = 3      # alignment search, in the original's pixels
MAX_DIFF = 0.07  # mean blurred colour difference (0..1) above which the redraw is another picture, not a recolour
SIZE_TOL = (0.06, 0.15)   # a figure's height and width may differ by this share from the original's, doubled


def layout_problems(lo_rgba, hd_rgba, views):
    """Differences in the figures' count and size between the original sheet and its redraw at twice the size."""
    figs = []
    for sheet in (lo_rgba, hd_rgba):
        s = cutout.binarize_alpha(cutout.remove_background(sheet))
        figs.append(cutout.find_figures(s, views or rw.view_count(s)))
    lo, hd = figs
    if len(lo) != len(hd):
        return [f"{len(hd)} figures, the original has {len(lo)}"]
    out = []
    for i, (a, b) in enumerate(zip(lo, hd)):
        dh = abs(b.shape[0] / (2.0 * a.shape[0]) - 1.0)
        dw = abs(b.shape[1] / (2.0 * a.shape[1]) - 1.0)
        if dh > SIZE_TOL[0] or dw > SIZE_TOL[1]:
            out.append(f"figure {i + 1} is {b.shape[1]}x{b.shape[0]}, expected about {2 * a.shape[1]}x{2 * a.shape[0]}")
    return out


def blur(a, r=RADIUS, passes=3):
    for _ in range(passes):
        for axis in (0, 1):
            c = np.cumsum(np.pad(a, [(r + 1, r) if i == axis else (0, 0) for i in range(a.ndim)], mode="edge"),
                          axis=axis)
            n = a.shape[axis]
            hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis)
            lo = np.take(c, np.arange(0, n), axis=axis)
            a = (hi - lo) / (2 * r + 1)
    return a


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--id", required=True)
    p.add_argument("--src")
    a = p.parse_args(sys.argv[sys.argv.index("--") + 1:])
    flags = anim.walk_flags(a.id)
    orig_path = cutout.ROOT / flags["turnaround"]
    out_path = orig_path.with_name(orig_path.stem + "_hd.png")
    hd_rgba = cutout.load_rgba(a.src or out_path)
    lo_rgba = cutout.load_rgba(orig_path)
    hd, lo = hd_rgba[..., :3], lo_rgba[..., :3]
    k = hd.shape[0] / lo.shape[0]
    if abs(k - 2.0) > 0.01 or abs(hd.shape[1] / lo.shape[1] - 2.0) > 0.01:
        print(f"HD REJECT {a.id}: the redraw is not twice the original ({hd.shape[:2]} vs {lo.shape[:2]})")
        sys.exit(2)
    problems = layout_problems(lo_rgba, hd_rgba, flags["views"])
    # Align: the redraw halved against the original, over small shifts.
    small = hd[:2 * lo.shape[0]:2, :2 * lo.shape[1]:2].mean(axis=2)
    ref = lo.mean(axis=2)
    best, shift = None, (0, 0)
    s = SEARCH
    for dy in range(-s, s + 1):
        for dx in range(-s, s + 1):
            d = np.abs(np.roll(ref, (dy, dx), axis=(0, 1))[s:-s, s:-s] - small[s:-s, s:-s]).mean()
            if best is None or d < best:
                best, shift = d, (dy, dx)
    up = np.repeat(np.repeat(np.roll(lo, shift, axis=(0, 1)), 2, axis=0), 2, axis=1)[:hd.shape[0], :hd.shape[1]]
    before = np.abs(blur(up) - blur(hd)).mean()
    if before > MAX_DIFF:
        problems.append(f"differs from the original beyond its colours ({before:.3f})")
    if problems:
        print(f"HD REJECT {a.id}: " + "; ".join(problems))
        sys.exit(2)
    fixed = np.clip(hd + blur(up) - blur(hd), 0.0, 1.0)
    out = np.concatenate([fixed, np.ones(fixed.shape[:2] + (1,), np.float32)], axis=2)
    cutout.save_rgba(out, out_path)
    print(f"HD colours {a.id}: shift {shift}, mean colour difference {before:.3f} -> {out_path.name}")


if __name__ == "__main__":
    main()
