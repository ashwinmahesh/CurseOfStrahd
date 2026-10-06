"""Checks a generated turnaround sheet before it's rigged: tools/art/new_creatures.py redraws sheets that fail.

blender -b --python blender/check_turnaround.py -- --in <png> [--views 5]

Prints CHECK {"problems": [...], "heights": [...], "widths": [...]}: the sheet must split into the expected number of
figures, of similar height (a view drawn at another scale pops when the walk turns), none cut off by the picture's edge.
"""
import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import cutout  # noqa: E402


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--in", dest="src", required=True)
    p.add_argument("--views", type=int, default=5)
    a = p.parse_args(sys.argv[sys.argv.index("--") + 1:])
    sheet = cutout.binarize_alpha(cutout.remove_background(cutout.load_rgba(a.src)))
    problems = []
    alpha = sheet[..., 3] > 0.5
    if alpha[:, :2].any() or alpha[:, -2:].any() or alpha[:2, :].any() or alpha[-2:, :].any():
        problems.append("a figure touches the edge of the picture")
    try:
        figures = cutout.find_figures(sheet, a.views)
    except Exception as e:  # noqa: BLE001 - any failure to split is a redraw
        figures = []
        problems.append(f"could not split the sheet: {e}")
    heights = [int(f.shape[0]) for f in figures]
    widths = [int(f.shape[1]) for f in figures]
    if len(figures) != a.views:
        problems.append(f"found {len(figures)} figures, wanted {a.views}")
    elif min(heights) < 0.7 * max(heights):
        problems.append(f"views of very different height {heights}")
    if figures and max(heights) < 0.45 * sheet.shape[0]:
        problems.append("figures are drawn small")
    print("CHECK " + json.dumps({"problems": problems, "heights": heights, "widths": widths}))


main()
