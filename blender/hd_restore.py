"""Undoes the first colour match of an HD turnaround redraw (blender/hd_colour.py before 2026-10-07 evening).

blender -b --python blender/hd_restore.py -- --id <asset_id> [--id ...]

That match added the blurred difference between the original and the redraw to the redraw, which left soft halos
round the figures wherever the two outlines differed by a pixel or two, and an embossed look along shifted lines. The
redraws themselves were overwritten, but they can be recovered: the matched image is the redraw's detail (redraw minus
its blur, kept exactly) plus the original's blur. Solving for the redraw in the frequency domain restores every
structure smaller than about 100 px; the broadest colour areas keep the original's colours, which is all the match
should have done. Writes the turnaround in place and prints how far the result is from the redraw's matched form.
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
import hd_colour  # noqa: E402

PAD = 64
THRESHOLD = 0.05   # where 1 - blur's response is below this, the matched image's own (original's) colours are kept


def box3_response(n, r=hd_colour.RADIUS, passes=3):
    """Frequency response of hd_colour.blur along one axis of length n (a box of 2r+1, `passes` times)."""
    w = 2 * np.pi * np.fft.fftfreq(n)
    k = 2 * r + 1
    with np.errstate(invalid="ignore", divide="ignore"):
        d = np.where(np.abs(w) < 1e-12, 1.0, np.sin(k * w / 2) / (k * np.sin(w / 2)))
    return d ** passes


def restore(fixed, lo, shift=None):
    """The redraw recovered from `fixed` (RGB, the matched image) and `lo` (the original, RGB at half size): the
    alignment the match used is found again (the shift near the best fit whose recovery re-matches most exactly)."""
    if shift is not None:
        return restore_at(fixed, lo, tuple(shift))
    small = fixed[:2 * lo.shape[0]:2, :2 * lo.shape[1]:2].mean(axis=2)
    ref = lo.mean(axis=2)
    s = hd_colour.SEARCH
    best, shift = None, (0, 0)
    for dy in range(-s, s + 1):
        for dx in range(-s, s + 1):
            d = np.abs(np.roll(ref, (dy, dx), axis=(0, 1))[s:-s, s:-s] - small[s:-s, s:-s]).mean()
            if best is None or d < best:
                best, shift = d, (dy, dx)
    tries = [restore_at(fixed, lo, (shift[0] + dy, shift[1] + dx)) for dy in (-1, 0, 1) for dx in (-1, 0, 1)
             if abs(shift[0] + dy) <= s and abs(shift[1] + dx) <= s]
    return min(tries, key=lambda r: r[2])


ITERATIONS = 80


def restore_at(fixed, lo, shift):
    """Landweber iteration on the match itself (clip included): each step adds what re-matching the estimate misses.
    The error shrinks by one more blur each step, so halos and shifted-line ghosts fade out (to a few per cent, spread
    wide), clipped pixels stay consistent, and the broadest colour areas keep the matched (original's) colours."""
    up = np.repeat(np.repeat(np.roll(lo, shift, axis=(0, 1)), 2, axis=0), 2, axis=1)[:fixed.shape[0], :fixed.shape[1]]
    b_up = hd_colour.blur(up)
    hd = fixed.copy()
    for _ in range(ITERATIONS):
        hd = np.clip(hd + fixed - np.clip(hd + b_up - hd_colour.blur(hd), 0.0, 1.0), 0.0, 1.0)
    check = np.clip(hd + b_up - hd_colour.blur(hd), 0.0, 1.0)
    return hd, shift, float(np.abs(check - fixed).mean())


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--id", action="append", required=True)
    p.add_argument("--shifts", help="JSON {id: [dy, dx]}: the alignment each match printed (else searched for)")
    a = p.parse_args(sys.argv[sys.argv.index("--") + 1:])
    shifts = json.loads(Path(a.shifts).read_text()) if a.shifts else {}
    for asset_id in a.id:
        flags = anim.walk_flags(asset_id)
        if not flags["turnaround_hd"]:
            print(f"RESTORE SKIP {asset_id}: no HD turnaround")
            continue
        path = cutout.ROOT / flags["turnaround_hd"]
        fixed = cutout.load_rgba(path)[..., :3]
        lo = cutout.load_rgba(cutout.ROOT / flags["turnaround"])[..., :3]
        hd, shift, err = restore(fixed, lo, shifts.get(asset_id))
        out = np.concatenate([hd, np.ones(hd.shape[:2] + (1,), np.float32)], axis=2)
        cutout.save_rgba(out, path)
        print(f"RESTORED {asset_id}: shift {shift}, re-matched differs by {err:.4f}")


if __name__ == "__main__":
    main()
