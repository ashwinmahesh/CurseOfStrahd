"""Gives an HD turnaround redraw the colours of the original turnaround (docs/art/animation.md, HD sheets).

blender -b --python blender/hd_colour.py -- --id <asset_id> [--src <raw redraw>]

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
import anim  # noqa: E402
import cutout  # noqa: E402

RADIUS = 5      # box blur radius at the redraw's size (three passes: about a 9 px Gaussian)
SEARCH = 3      # alignment search, in the original's pixels


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
    hd = cutout.load_rgba(a.src or out_path)[..., :3]
    lo = cutout.load_rgba(orig_path)[..., :3]
    k = hd.shape[0] / lo.shape[0]
    if abs(k - 2.0) > 0.01 or abs(hd.shape[1] / lo.shape[1] - 2.0) > 0.01:
        raise SystemExit(f"{a.id}: the redraw is not twice the original ({hd.shape[:2]} vs {lo.shape[:2]})")
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
    fixed = np.clip(hd + blur(up) - blur(hd), 0.0, 1.0)
    before = np.abs(blur(up) - blur(hd)).mean()
    out = np.concatenate([fixed, np.ones(fixed.shape[:2] + (1,), np.float32)], axis=2)
    cutout.save_rgba(out, out_path)
    print(f"HD colours {a.id}: shift {shift}, mean colour difference {before:.3f} -> {out_path.name}")


if __name__ == "__main__":
    main()
