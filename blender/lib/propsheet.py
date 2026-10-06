"""Billboard props and wall or floor pieces from Gemini images (docs/art/set_dressing.md). Runs inside Blender's Python.

A source is either one object on flat white or a sheet of four in a 2 x 2 grid (one Gemini call for four props).
`split` removes the background once and returns each slot's object; `finish` crops, smooths, scales, snaps to the
palette, cleans and writes art/sprites/props/<id>.png, returning its manifest entry. The cleanup is the walk sheets'
(docs/art/p4_cast_art_pass.md): edge-preserving smoothing before the snap, then despeckle and small-clump merging,
so props read as clean pixel art with no salt-and-pepper.
"""
from pathlib import Path

import bpy
import numpy as np

import cutout

PROPS_DIR = cutout.ROOT / "art" / "sprites" / "props"
## Texels per world unit the finished sprite aims for (about the closest zoom at 1080p), capped by --max and by
## the source's own resolution (never upscaled).
TEXELS_PER_UNIT = 256


def resize(arr, w, h):
    img = cutout.to_bpy_image(arr, "prop_src")
    img.scale(w, h)
    out = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(out)
    bpy.data.images.remove(img)
    return np.flipud(out.reshape(h, w, 4)).copy()


def area_downscale(arr, w, h):
    """Exact area averaging to (h, w), alpha-weighted so the white background doesn't bleed into edge colours.
    Averaging many source pixels per texel also flattens Gemini's JPEG noise before the palette snap."""
    sh, sw = arr.shape[:2]
    if w >= sw or h >= sh:
        return resize(arr, w, h)

    def weights(n_src, n_dst):
        m = np.zeros((n_dst, n_src), dtype=np.float32)
        scale = n_src / n_dst
        for i in range(n_dst):
            a, b = i * scale, (i + 1) * scale
            for j in range(int(a), min(n_src, int(np.ceil(b)))):
                m[i, j] = min(b, j + 1) - max(a, j)
        return m / m.sum(axis=1, keepdims=True)

    wy, wx = weights(sh, h), weights(sw, w)
    alpha = arr[..., 3]
    prem = arr[..., :3] * alpha[..., None]
    a2 = wy @ alpha @ wx.T
    rgb = np.stack([wy @ prem[..., c] @ wx.T for c in range(3)], axis=-1)
    out = np.zeros((h, w, 4), dtype=np.float32)
    nz = a2 > 1e-4
    out[..., :3][nz] = rgb[nz] / a2[nz][:, None]
    out[..., 3] = a2
    return out


def keep_main(arr, min_frac=0.02):
    """Drops specks: keeps the largest shape and any piece at least `min_frac` of its size."""
    comps = cutout.label_components(arr[..., 3] > 0.5)
    if not comps:
        return arr
    sizes = [sum(r[2] - r[1] for r in c) for c in comps]
    big = max(sizes)
    out = arr.copy()
    for c, s in zip(comps, sizes):
        if s < min_frac * big:
            for y, x0, x1 in c:
                out[y, x0:x1] = 0.0
    return out


def clear_grid_lines(arr, cols, rows, band=0.12, cover=0.6):
    """Gemini sometimes rules the sheet into quarters despite the prompt. A column (row) near a dividing line that is
    opaque over most of the image's height (width) is such a rule: it's cleared, so it neither joins the objects it
    touches nor becomes a shape of its own."""
    out = arr.copy()
    h, w = arr.shape[:2]
    opaque = arr[..., 3] > 0.5
    for k in range(1, cols):
        x0, x1 = int((k / cols - band) * w), int((k / cols + band) * w)
        frac = opaque[:, x0:x1].mean(axis=0)
        for x in np.nonzero(frac > cover)[0]:
            out[:, x0 + x] = 0.0
    for k in range(1, rows):
        y0, y1 = int((k / rows - band) * h), int((k / rows + band) * h)
        frac = opaque[y0:y1, :].mean(axis=1)
        for y in np.nonzero(frac > cover)[0]:
            out[y0 + y, :] = 0.0
    return out


def split(arr, layout):
    """The objects of a source image, one per slot (row-major), background removed. layout "1x1" or "2x2".
    In a sheet each shape goes to the quarter its box centre is in, so an object that pokes a little past the
    middle stays whole. A slot with nothing in it comes back as None."""
    arr = cutout.binarize_alpha(cutout.remove_background(arr))
    if layout == "1x1":
        return [arr]
    cols, rows = (int(n) for n in layout.split("x"))
    h, w = arr.shape[:2]
    arr = clear_grid_lines(arr, cols, rows)
    masks = [np.zeros((h, w), dtype=bool) for _ in range(cols * rows)]
    for comp in cutout.label_components(arr[..., 3] > 0.5):
        ys = [r[0] for r in comp]
        cy = 0.5 * (min(ys) + max(ys))
        cx = 0.5 * (min(r[1] for r in comp) + max(r[2] for r in comp))
        slot = min(rows - 1, int(cy / h * rows)) * cols + min(cols - 1, int(cx / w * cols))
        for y, x0, x1 in comp:
            masks[slot][y, x0:x1] = True
    out = []
    for m in masks:
        if not m.any():
            out.append(None)
            continue
        part = arr.copy()
        part[~m] = 0.0
        out.append(part)
    return out


def finish(arr, prop_id, source, height=None, width=None, max_px=512, saturate=1.0, mount="stand"):
    """Crops, scales, snaps and writes art/sprites/props/<id>.png. The world size is its `height` (standing props,
    wall pieces) or its `width` (floor pieces, wide wall pieces); pixel_size gives that size in Godot."""
    arr = keep_main(arr)
    ys, xs = np.nonzero(arr[..., 3] > 0.5)
    arr = arr[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = arr.shape[:2]
    world = height if height else width
    target = min(max_px, max(h, w), int(round(TEXELS_PER_UNIT * world * max(h, w) / (h if height else w))))
    k = target / float(max(h, w))
    nw, nh = max(1, round(w * k)), max(1, round(h * k))
    small = cutout.binarize_alpha(area_downscale(cutout.smooth_colours(arr), nw, nh))
    small = cutout.quantize(cutout.saturate(small, saturate), neutral_area=0.5)
    small = cutout.merge_islands(cutout.despeckle(small, near=0.3, ring=True))
    # A 2 px margin, then round up to multiples of 4 (VRAM block compression); centred, the foot 2 px above the
    # bottom (a standing prop's ground contact; wall and floor pieces are centred on their anchor in game).
    ph, pw = -(-(nh + 4) // 4) * 4, -(-(nw + 4) // 4) * 4
    pad = np.zeros((ph, pw, 4), dtype=np.float32)
    x0 = (pw - nw) // 2
    pad[ph - 2 - nh:ph - 2, x0:x0 + nw] = small
    rel = Path("art") / "sprites" / "props" / f"{prop_id}.png"
    cutout.save_rgba(pad, cutout.ROOT / rel)
    rows = np.nonzero(pad[..., 3].max(axis=1) > 0)[0]
    cols = np.nonzero(pad[..., 3].max(axis=0) > 0)[0]
    content_h = int(rows[-1] - rows[0] + 1)
    content_w = int(cols[-1] - cols[0] + 1)
    pixel_size = (height / content_h) if height else (width / content_w)
    entry = {
        "file": str(rel),
        "width_px": int(pad.shape[1]),
        "height_px": int(pad.shape[0]),
        "world_height": round(content_h * pixel_size, 3),
        "world_width": round(content_w * pixel_size, 3),
        "pixel_size": round(pixel_size, 6),
        "anchor": "bottom_center",
        "mount": mount,
        "source": source,
    }
    if saturate != 1.0:
        entry["saturate"] = saturate
    print(f"prop: {rel} ({pad.shape[1]}x{pad.shape[0]} px, {entry['world_width']} x {entry['world_height']} units, {mount})")
    return entry
