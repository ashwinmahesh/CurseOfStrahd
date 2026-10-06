"""Keyframe strips for the animation pipeline (docs/art/animation.md). Runs inside Blender's Python.

A keyframe strip is one Gemini image per view (tools/art/anim_keyframes.py): three figures in a row, drawn from the
same angle. Frame 1 copies the view from the turnaround sheet, so its height tells us the strip's scale relative to
the sheet; frames 2 and 3 are the new poses (wind-up and strike, or two strides).
"""
import json
from pathlib import Path

import numpy as np

import cutout

ROOT = cutout.ROOT
REGISTRY = ROOT / "art" / "anim" / "animations.json"


def registry():
    return json.loads(REGISTRY.read_text())


def spec(asset_id):
    reg = registry()
    if asset_id not in reg:
        raise SystemExit(f"{asset_id} is not in {REGISTRY.relative_to(ROOT)}")
    return reg[asset_id]


def strip_path(asset_id, kind, view):
    return ROOT / "art" / "generated" / "anim" / asset_id / f"{kind}_{view}.png"


def clean_source(arr):
    """Background off, hard alpha, and the pipeline's smoothing when this tree has it (so keyframes get the same
    treatment as the turnaround the walk sheet is cut from)."""
    arr = cutout.binarize_alpha(cutout.remove_background(arr))
    if hasattr(cutout, "smooth_colours"):
        arr = cutout.smooth_colours(arr)
    return arr


def drop_ground_lines(arr, min_frac=0.6, max_thick=8):
    """Gemini sometimes rules a ground line under the figures, which glues them into one shape. Clears thin
    horizontal bands holding one unbroken run across most of the picture (figures always leave gaps)."""
    out = arr.copy()
    h, w = arr.shape[:2]
    alpha = arr[..., 3] > 0.5
    longest = np.zeros(h, dtype=int)
    for y in range(h):
        runs = cutout.column_runs(alpha[y])
        longest[y] = max((b - a for a, b in runs), default=0)
    wide = longest > min_frac * w
    y = 0
    while y < h:
        if not wide[y]:
            y += 1
            continue
        y1 = y
        while y1 < h and wide[y1]:
            y1 += 1
        if y1 - y <= max_thick:
            out[max(0, y - 1):min(h, y1 + 1)] = 0.0
        y = y1
    return out


class Keyframe:
    """One figure from a strip, with the numbers needed to place it like the turnaround's view."""

    def __init__(self, crop):
        self.crop = crop
        self.h, self.w = crop.shape[:2]
        self.anchor = stance_x(crop)
        xs = np.nonzero(crop[..., 3] > 0.5)[1]
        # The middle of the body's mass: where a stride is centred (its feet are spread or off the ground).
        self.mass = float(np.median(xs)) if len(xs) else self.w / 2.0


def stance_x(crop, band=0.2):
    """Where the figure stands, in crop pixels from the left: the median column of its lowest `band` of rows
    (between the feet). Keeps feet planted when a pose reaches out with a weapon or a lunge."""
    h = crop.shape[0]
    rows = crop[int(h * (1.0 - band)):, :, 3] > 0.5
    xs = np.nonzero(rows)[1]
    return float(np.median(xs)) if len(xs) else crop.shape[1] / 2.0


def split_strip(arr, count=3):
    """The `count` figures of a strip, left to right, as tight crops. Each figure is one large connected shape
    plus every smaller piece nearest to it (a detached staff, a spark, a tail tip). Returns (crops, problems)."""
    comps = cutout.label_components(arr[..., 3] > 0.5)
    info = []
    for c in comps:
        area = sum(x1 - x0 for _, x0, x1 in c)
        if area < 40:
            continue
        x0 = min(r[1] for r in c)
        x1 = max(r[2] for r in c)
        info.append((area, x0, x1, c))
    info.sort(key=lambda t: t[0], reverse=True)
    problems = []
    if len(info) < count:
        return None, [f"found {len(info)} shapes, wanted {count} figures"]
    mains = info[:count]
    if mains[-1][0] < 0.25 * mains[0][0]:
        problems.append("figures are merged or one is missing (shapes of very different size)")
    centres = sorted(0.5 * (m[1] + m[2]) for m in mains)
    gaps = np.diff(centres)
    if len(gaps) and gaps.min() < 0.45 * gaps.max():
        problems.append("figures are unevenly spaced (two touching, or a loose piece taken for a figure)")
    groups = [[m[3]] for m in mains]
    boxes = [(m[1], m[2]) for m in mains]
    for area, x0, x1, c in info[count:]:
        cx = 0.5 * (x0 + x1)
        dist = [max(b[0] - cx, cx - b[1], 0.0) for b in boxes]
        groups[int(np.argmin(dist))].append(c)
    crops = []
    for parts in groups:
        mask = np.zeros(arr.shape[:2], dtype=bool)
        for c in parts:
            for y, x0, x1 in c:
                mask[y, x0:x1] = True
        ys, xs = np.nonzero(mask)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        crop = arr[y0:y1, x0:x1].copy()
        crop[~mask[y0:y1, x0:x1]] = 0.0
        crops.append((x0, crop))
    return [c for _, c in sorted(crops, key=lambda t: t[0])], problems


def load_strip(path, expect=3):
    """Returns (keyframes or None, problems) for one strip image."""
    raw = cutout.load_rgba(path)
    arr = drop_ground_lines(clean_source(raw))
    problems = []
    alpha = arr[..., 3] > 0.5
    if alpha[:, :2].any() or alpha[:, -2:].any() or alpha[:2, :].any() or alpha[-2:, :].any():
        problems.append("a figure touches the edge of the picture (clipped)")
    crops, more = split_strip(arr, expect)
    problems += more
    return ([Keyframe(c) for c in crops] if crops else None), problems


def match_colours(frames, first, ref):
    """Gemini drifts a little in brightness and tint between images. Frame 1 redraws the turnaround view, so the
    per-channel tone curve that maps frame 1's colours onto the view's (quantile matching over opaque pixels) is
    applied to every frame of the strip."""
    a = first[first[..., 3] > 0.5][:, :3]
    b = ref[ref[..., 3] > 0.5][:, :3]
    if len(a) < 100 or len(b) < 100:
        return frames
    q = np.linspace(0.0, 1.0, 65)
    src = [np.quantile(a[:, ch], q) for ch in range(3)]
    dst = [np.quantile(b[:, ch], q) for ch in range(3)]
    out = []
    for f in frames:
        g = f.copy()
        m = g[..., 3] > 0.5
        for ch in range(3):
            xs = np.maximum.accumulate(src[ch] + np.arange(65) * 1e-6)
            g[..., ch][m] = np.interp(g[..., ch][m], xs, dst[ch])
        out.append(g)
    return out


def strip_scale(ref_h, ref_w, first):
    """Factor from strip pixels to turnaround pixels, from frame 1 (a redraw of the reference view). Also returns
    problems when frame 1 doesn't look like the view (Gemini put a new pose first)."""
    k = ref_h / float(first.h)
    problems = []
    ratio_ref, ratio_first = ref_w / float(ref_h), first.w / float(first.h)
    if abs(ratio_first - ratio_ref) > 0.3 * ratio_ref:
        problems.append(f"frame 1 is shaped unlike the turnaround view (w/h {ratio_first:.2f} vs {ratio_ref:.2f})")
    return k, problems


def write_frames_tres(tres_path, texture_res_path, cell, directions, durations, prefix, fps, loop, meta=None):
    """A Godot 4 SpriteFrames resource with one animation per direction (`prefix`_<dir>): row = direction,
    column = frame, each frame with its own relative duration."""
    w, h = cell
    lines_sub, anims = [], []
    for row, d in enumerate(directions):
        entries = []
        for f, dur in enumerate(durations):
            sid = f"{d}_{f}"
            lines_sub.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("1")\n'
                             f"region = Rect2({f * w}, {row * h}, {w}, {h})\n")
            entries.append(f'{{"duration": {float(dur)}, "texture": SubResource("{sid}")}}')
        anims.append(f'{{\n"frames": [{", ".join(entries)}],\n"loop": {"true" if loop else "false"},\n'
                     f'"name": &"{prefix}_{d}",\n"speed": {float(fps)}\n}}')
    meta_lines = "".join(f"metadata/{k} = {json.dumps(v)}\n" for k, v in (meta or {}).items())
    text = ('[gd_resource type="SpriteFrames" format=3]\n\n'
            f'[ext_resource type="Texture2D" path="{texture_res_path}" id="1"]\n\n'
            + "\n".join(lines_sub)
            + "\n[resource]\nanimations = [" + ", ".join(anims) + "]\n" + meta_lines)
    Path(tres_path).write_text(text)


def finish_sheet(sheet, saturate=1.0):
    """The same palette snap and cleanup the walk sheets get."""
    sheet = cutout.despeckle(cutout.quantize(cutout.saturate(cutout.binarize_alpha(sheet), saturate)))
    if hasattr(cutout, "merge_islands"):
        sheet = cutout.merge_islands(sheet)
    return sheet


def edge_touch(frame, margin=1):
    """Which edges of a rendered frame the figure reaches ('' when none): it is cut off there."""
    a = frame[..., 3] > 0.5
    return "".join(e for e, hit in (("left ", a[:, :margin].any()), ("right ", a[:, -margin:].any()),
                                     ("top ", a[:margin, :].any())) if hit).strip()
