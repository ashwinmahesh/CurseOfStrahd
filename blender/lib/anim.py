"""Keyframe strips for the animation pipeline (docs/art/animation.md). Runs inside Blender's Python.

A keyframe strip is one Gemini image per view (tools/art/anim_keyframes.py): three figures in a row, drawn from the
same angle. Frame 1 copies the view from the turnaround sheet, so its height tells us the strip's scale relative to
the sheet; frames 2 and 3 are the new poses (wind-up and strike, or two strides).
"""
import json
import math
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


def walk_flags(asset_id):
    """How the character's walk sheet is made, from its art/manifest.json "sprite_flags" (the same flags
    tools/art/rerender_sprites.py passes to `make sprite`): turnaround, body, saturate, side_faces, views, static.
    turnaround_hd: the same sheet redrawn at twice the resolution (<turnaround>_hd.png) when there is one."""
    manifest = json.loads((ROOT / "art" / "manifest.json").read_text())
    for a in manifest["assets"]:
        sp = a.get("sprites")
        if isinstance(sp, str) and sp.endswith("/walk.tres") and Path(sp).parent.name == asset_id:
            flags = dict(f.split("=", 1) for f in a.get("sprite_flags", []) if "=" in f)
            source = a.get("source", f"art/generated/characters/{asset_id}_turnaround.png")
            hd = Path(source).with_name(Path(source).stem + "_hd.png")
            return {"turnaround": source, "turnaround_hd": str(hd) if (ROOT / hd).exists() else None,
                    "body": flags.get("BODY", "humanoid"), "saturate": float(flags.get("SAT", 1.0)),
                    "side_faces": flags.get("SIDE", "right"), "views": int(flags["VIEWS"]) if "VIEWS" in flags else None,
                    "static": flags.get("STATIC") == "1"}
    raise SystemExit(f"{asset_id}: no walk sheet in art/manifest.json")


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
        y0 = min(r[0] for r in c)
        y1 = max(r[0] for r in c) + 1
        # A panel border Gemini sometimes rules around a frame: a big, nearly empty outline. Not a figure.
        if (y1 - y0) > 0.3 * arr.shape[0] and area < 0.05 * (y1 - y0) * (x1 - x0):
            continue
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
    boxes = [(m[1], m[2], min(r[0] for r in m[3]), max(r[0] for r in m[3])) for m in mains]
    h_img, w_img = arr.shape[:2]
    for area, x0, x1, c in info[count:]:
        y0, y1 = min(r[0] for r in c), max(r[0] for r in c)
        cx = 0.5 * (x0 + x1)
        dist = [max(b[0] - cx, cx - b[1], 0.0) for b in boxes]
        j = int(np.argmin(dist))
        b = boxes[j]
        # A piece by the figure (a spark, a strand of hair, a staff the hand doesn't touch) joins it; specks out in
        # the open (a dotted horizon, dust) are dropped unless they're sizeable (a thrown stone, a burst of flame).
        gap_x = max(b[0] - x1, x0 - b[1], 0)
        gap_y = max(b[2] - y1, y0 - b[3], 0)
        near = gap_x <= 0.02 * w_img and gap_y <= 0.02 * h_img
        sizeable = area >= 0.01 * mains[j][0] and gap_x <= 0.08 * w_img and gap_y <= 0.08 * h_img
        if near or sizeable:
            groups[j].append(c)
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


def key_out_magenta(arr):
    """Clears a flat magenta silhouette drawn as a stand-in (the horse under a rider, tools/art/anim_keyframes.py ride):
    the strip's most common strongly magenta colour, everything close to it, and the blended fringe around it."""
    rgb = arr[..., :3]
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    magenta = (sat > 0.45) & (r > g + 0.2) & (b > g + 0.15) & (arr[..., 3] > 0.5)
    if magenta.sum() < 500:
        return arr
    q = np.round(rgb[magenta] * 15).astype(int)
    keys, counts = np.unique(q[:, 0] * 256 + q[:, 1] * 16 + q[:, 2], return_counts=True)
    top = keys[np.argmax(counts)]
    centre = np.array([(top // 256) / 15.0, ((top // 16) % 16) / 15.0, (top % 16) / 15.0])
    dist = np.linalg.norm(rgb - centre, axis=2)
    gone = magenta & (dist < 0.3)
    # The blended fringe: pixels next to the cleared area that still lean magenta.
    for _ in range(2):
        near = np.zeros_like(gone)
        near[1:] |= gone[:-1]
        near[:-1] |= gone[1:]
        near[:, 1:] |= gone[:, :-1]
        near[:, :-1] |= gone[:, 1:]
        gone |= near & (r > g + 0.08) & (b > g + 0.05) & (dist < 0.55)
    gone |= horse_outline(arr, gone)
    out = arr.copy()
    out[gone] = 0.0
    return out


def horse_outline(arr, gone, thick=12):
    """The ink line Gemini sometimes draws round the magenta horse anyway: dark pixels by the cleared horse that aren't
    part of the rider (the rider's own lines lie in or beside the rider's colours; the horse's border magenta on one
    side and background on the other). Grown along the dark line from the horse's edge, `thick` pixels at most."""
    opaque = arr[..., 3] > 0.5
    rgb = arr[..., :3]
    ink = opaque & ~gone & (rgb.max(axis=2) < 0.35)
    # Rider colour: plenty of non-ink, non-horse pixels round about (a thin grey fringe on an outline doesn't count).
    body = (opaque & ~gone & ~ink).astype(bool)
    window = (2 * thick + 1) ** 2
    near_rider = cutout._box_sum(body, thick) > 0.2 * window
    line = ink & ~near_rider
    found = line & (cutout._box_sum(gone, 3) > 0)
    for _ in range(thick):
        grow = line & (cutout._box_sum(found, 1) > 0) & ~found
        if not grow.any():
            break
        found |= grow
    # The fringe of the removed line (anti-aliased greys between it and the background).
    fringe = opaque & ~gone & ~found & ~near_rider & (cutout._box_sum(found, 2) > 0) & (rgb.max(axis=2) < 0.8)
    return found | fringe


def load_strip(path, expect=3, key_magenta=False):
    """Returns (keyframes or None, problems) for one strip image."""
    raw = cutout.load_rgba(path)
    if key_magenta:
        raw = key_out_magenta(cutout.remove_background(raw))
    arr = drop_ground_lines(clean_source(raw))
    problems = []
    alpha = arr[..., 3] > 0.5
    if alpha[:, :2].any() or alpha[:, -2:].any() or alpha[:2, :].any() or alpha[-2:, :].any():
        problems.append("a figure touches the edge of the picture (clipped)")
    crops, more = split_strip(arr, expect)
    if any(m.startswith(("figures are merged", "figures are unevenly", "found ")) for m in more):
        # A beam or a smear bridging two poses: cut at the emptiest columns near even spacing instead.
        even = split_even(arr, expect)
        if even is not None:
            crops, more = even, []
    problems += more
    return ([Keyframe(c) for c in crops] if crops else None), problems


def split_even(arr, count):
    """The `count` figures of a strip whose figures touch (an effect reaching into the next pose), cut apart at the
    emptiest column near each even-spacing boundary; each slot keeps its largest shape and the pieces by it (an effect
    is cut at the boundary). None when the slots don't hold figures of about one height."""
    cols = (arr[..., 3] > 0.5).sum(axis=0).astype(float)
    xs = np.nonzero(cols)[0]
    if not len(xs):
        return None
    x_lo, x_hi = int(xs.min()), int(xs.max()) + 1
    slot = (x_hi - x_lo) / float(count)
    cuts = [x_lo]
    for i in range(1, count):
        guess = int(x_lo + i * slot)
        lo, hi = int(guess - 0.2 * slot), int(guess + 0.2 * slot)
        cuts.append(lo + int(np.argmin(cols[lo:hi])))
    cuts.append(x_hi)
    crops = []
    for a, b in zip(cuts[:-1], cuts[1:]):
        sub = arr.copy()
        sub[:, :a] = 0.0
        sub[:, b:] = 0.0
        got, _ = split_strip(sub, 1)
        if not got:
            return None
        crops.append(got[0])
    heights = [c.shape[0] for c in crops]
    if min(heights) < 0.75 * max(heights):
        return None
    return crops


def colour_profile(crop, palette=None):
    """The share of a figure's pixels in each palette colour (crop sampled every third pixel)."""
    pal = cutout.load_palette() if palette is None else palette
    q = cutout.quantize(crop[::3, ::3], pal)
    rgb = q[q[..., 3] > 0.5][:, :3]
    if len(rgb) == 0:
        return np.zeros(len(pal))
    idx = np.argmin(((rgb[:, None, :] - pal[None]) ** 2).sum(-1), axis=1)
    h = np.bincount(idx, minlength=len(pal)).astype(float)
    return h / h.sum()


# Owner 2026-10-07 ("colour glitching in the walk"): a pose Gemini recoloured (a green tabard, dark armour) pops when
# the poses play in turn. Shares of palette colours that overlap less than this with the reference pose's mean a
# recolour; ordinary pose changes (a raised arm, a motion smear) stay above about 0.78.
COLOUR_MATCH = 0.72


def colour_drift(keyframes, skip=()):
    """Problems for poses whose colours differ from frame 1's (the reference pose redrawn). `skip`: frame numbers that
    rightly show other colours (lying on the back shows the front of a figure seen from behind)."""
    pal = cutout.load_palette()
    ref = colour_profile(keyframes[0].crop, pal)
    out = []
    for i, kf in enumerate(keyframes[1:], start=2):
        if i in skip:
            continue
        overlap = float(np.minimum(ref, colour_profile(kf.crop, pal)).sum())
        if overlap < COLOUR_MATCH:
            out.append(f"frame {i} is recoloured (colours {overlap:.2f} like the reference)")
    return out


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
    if abs(ratio_first - ratio_ref) > 0.4 * ratio_ref:
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
    """The same palette snap and cleanup the walk sheets get (render_walk.py): grey lines on skin snap to the warm
    shades round them, outlines drawn in two dark shades survive the despeckle (eyes, brows and lips at HD sizes),
    small clumps merge into their surroundings."""
    sheet = cutout.quantize(cutout.saturate(cutout.binarize_alpha(sheet), saturate), neutral_area=0.5)
    return cutout.merge_islands(cutout.despeckle(sheet, near=0.3, ring=True))


def crop_even(frames, cell, min_wide, margin):
    """Crops every frame by the same amount on opposite sides (so the centre stays put) to the smallest even size
    that holds all their opaque pixels plus `margin`, no smaller than the walk cell's height and `min_wide` x its
    width. Returns (frames, (width, height))."""
    h, w = frames[0].shape[:2]
    cy, cx = h / 2.0, w / 2.0
    half_w, half_h = cell * min_wide / 2.0, cell / 2.0
    for f in frames:
        ys, xs = np.nonzero(f[..., 3] > 0.5)
        if len(xs):
            half_w = max(half_w, cx - xs.min() + margin, xs.max() + 1 - cx + margin)
            half_h = max(half_h, cy - ys.min() + margin, ys.max() + 1 - cy + margin)
    nw = min(w, 2 * int(math.ceil(half_w)))
    nh = min(h, 2 * int(math.ceil(half_h)))
    x0, y0 = (w - nw) // 2, (h - nh) // 2
    return [f[y0:y0 + nh, x0:x0 + nw].copy() for f in frames], (nw, nh)


def edge_touch(frame, margin=1):
    """Which edges of a rendered frame the figure reaches ('' when none): it is cut off there."""
    a = frame[..., 3] > 0.5
    return "".join(e for e, hit in (("left ", a[:, :margin].any()), ("right ", a[:, -margin:].any()),
                                     ("top ", a[:margin, :].any())) if hit).strip()


# ---------- HD sheets: trimmed frames in a packed atlas (docs/art/animation.md) ----------

def trim(frame, pad):
    """A rendered frame cut down to its opaque pixels plus `pad`: symmetrically about the frame's centre column (so
    a frame shown mirrored still lines up) and tightly above and below. Returns (crop, (x0, y0)), the crop's corner in
    the frame; an empty frame keeps a pad-sized transparent square at its foot."""
    h, w = frame.shape[:2]
    ys, xs = np.nonzero(frame[..., 3] > 0.5)
    if not len(xs):
        x0, y0 = w // 2 - pad, h - 2 * pad
        return frame[y0:y0 + 2 * pad, x0:x0 + 2 * pad].copy(), (x0, y0)
    cx = w / 2.0
    half = max(cx - xs.min(), xs.max() + 1 - cx) + pad
    x0, x1 = max(0, int(math.floor(cx - half))), min(w, int(math.ceil(cx + half)))
    y0, y1 = max(0, ys.min() - pad), min(h, ys.max() + 1 + pad)
    return frame[y0:y1, x0:x1].copy(), (x0, y0)


def even_cell(trimmed, size, cell, min_wide, margin):
    """crop_even for trimmed frames: the logical cell (the frame size the game sees) that holds every frame's opaque
    pixels plus `margin`, centred on the render like crop_even's. `trimmed`: [(crop, (x0, y0))] from trim() of frames
    `size` (w, h). Returns ((nw, nh), [(crop, (left, top))]) with each crop clipped to the cell and placed in it."""
    w, h = size
    cy, cx = h / 2.0, w / 2.0
    half_w, half_h = cell * min_wide / 2.0, cell / 2.0
    for crop, (x0, y0) in trimmed:
        ys, xs = np.nonzero(crop[..., 3] > 0.5)
        if len(xs):
            half_w = max(half_w, cx - (x0 + xs.min()) + margin, x0 + xs.max() + 1 - cx + margin)
            half_h = max(half_h, cy - (y0 + ys.min()) + margin, y0 + ys.max() + 1 - cy + margin)
    nw = min(w, 2 * int(math.ceil(half_w)))
    nh = min(h, 2 * int(math.ceil(half_h)))
    X0, Y0 = (w - nw) // 2, (h - nh) // 2
    placed = []
    for crop, (x0, y0) in trimmed:
        l, t = max(0, X0 - x0), max(0, Y0 - y0)
        r = max(0, (x0 + crop.shape[1]) - (X0 + nw))
        b = max(0, (y0 + crop.shape[0]) - (Y0 + nh))
        crop = crop[t:crop.shape[0] - b, l:crop.shape[1] - r]
        placed.append((crop, (x0 + l - X0, y0 + t - Y0)))
    return (nw, nh), placed


def pack_atlas(crops):
    """Shelf-packs crops (identical ones once) into one atlas with sides in multiples of 4 (VRAM compression works in
    4x4 blocks), roughly square. Returns (atlas, [(x, y, w, h)] per crop)."""
    keys, unique, index = {}, [], []
    for c in crops:
        k = (c.shape, hash(c.tobytes()))
        if k not in keys:
            keys[k] = len(unique)
            unique.append(c)
        index.append(keys[k])
    area = sum(c.shape[0] * c.shape[1] for c in unique)
    width = max(max(c.shape[1] for c in unique), int(math.sqrt(area) * 1.08))
    width = (width + 3) // 4 * 4
    order = sorted(range(len(unique)), key=lambda i: -unique[i].shape[0])
    spots, x, y, shelf = {}, 0, 0, 0
    for i in order:
        ch, cw = unique[i].shape[:2]
        if x + cw > width:
            x, y, shelf = 0, y + shelf, 0
        spots[i] = (x, y)
        x += cw
        shelf = max(shelf, ch)
    height = (y + shelf + 3) // 4 * 4
    atlas = np.zeros((height, width, 4), np.float32)
    for i, (x, y) in spots.items():
        c = unique[i]
        atlas[y:y + c.shape[0], x:x + c.shape[1]] = c
    return atlas, [(*spots[i], unique[i].shape[1], unique[i].shape[0]) for i in index]


def mirror_twins(dir_view):
    """{direction: the direction it mirrors}: each mirrored direction's twin shows the same view, unmirrored, turned the
    other way, so its frames are the twin's flipped left to right."""
    return {d: e for d, (v, m, turn) in dir_view.items() if m
            for e, (v2, m2, turn2) in dir_view.items() if v2 == v and not m2 and turn2 == -turn}


def write_sheet_tres(path, texture, cell, directions, cols, anims, meta, rects=None):
    """SpriteFrames with several animations per direction: row = direction, column = rendered frame. `rects`
    (packed sheets): per frame, row by row, (x, y, w, h) on the atlas and (left, top), where it sits in its cell."""
    w, h = cell
    subs, out = [], []
    for row, d in enumerate(directions):
        for c in range(cols):
            if rects is None:
                region = f"region = Rect2({c * w}, {row * h}, {w}, {h})\n"
            else:
                (x, y, rw_, rh), (left, top) = rects[row * cols + c]
                region = (f"region = Rect2({x}, {y}, {rw_}, {rh})\n"
                          f"margin = Rect2({left}, {top}, {w - rw_}, {h - rh})\n")
            subs.append(f'[sub_resource type="AtlasTexture" id="{d}_{c}"]\natlas = ExtResource("1")\n' + region)
        for name, idx, durs, fps, loop in anims:
            entries = ", ".join(f'{{"duration": {float(du)}, "texture": SubResource("{d}_{i}")}}' for i, du in zip(idx, durs))
            out.append(f'{{\n"frames": [{entries}],\n"loop": {"true" if loop else "false"},\n'
                       f'"name": &"{name}_{d}",\n"speed": {float(fps)}\n}}')
    meta_lines = "".join(f"metadata/{k} = {json.dumps(v)}\n" for k, v in meta.items())
    Path(path).write_text('[gd_resource type="SpriteFrames" format=3]\n\n'
                          f'[ext_resource type="Texture2D" path="{texture}" id="1"]\n\n' + "\n".join(subs)
                          + "\n[resource]\nanimations = [" + ", ".join(out) + "]\n" + meta_lines)


def pack_sheet(trimmed, size, cell, min_wide, margin, saturate=1.0):
    """Trimmed frames (trim()) of renders `size` (w, h) -> (atlas, (cell w, cell h), rects for write_sheet_tres): the
    logical cell that holds them all (even_cell), each frame palette-cleaned (finish_sheet) and packed (pack_atlas)."""
    (cw, ch), placed = even_cell(trimmed, size, cell, min_wide, margin)
    sheet, spots = pack_atlas([finish_sheet(crop, saturate) for crop, _ in placed])
    return sheet, (cw, ch), [(spot, at) for spot, (_crop, at) in zip(spots, placed)]


def hd_cell(turnaround_hd, cell=None, ss=None):
    """The cell and supersampling for a sheet: 768 px rendered at twice the size when the character has an HD
    turnaround (<turnaround>_hd.png), else the earlier 384 px; either can be given."""
    return cell or (768 if turnaround_hd else 384), ss or (2 if turnaround_hd else 1)
