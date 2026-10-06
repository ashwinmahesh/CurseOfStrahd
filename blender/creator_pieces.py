"""Paper-doll pieces for the character creator (docs/art/creator.md): from the keyed Gemini art in
art/generated/creator/ to what the game puts together at run time (world/look/hero_look.gd).

blender -b --python blender/creator_pieces.py -- body <id> [--casts] | head <id> | hair <id> | beard <id>

body <gender>_<build>_<outfit>: art/generated/creator/body_<id>.png (a bald, lime-skinned figure in the outfit, five
  views) walks on the humanoid rig (render_walk.py) and attacks from art/generated/creator/anim/<id>/attack_<view>.png
  (render_attack.py's six frames). Writes art/creator/pieces/bodies/<id>/walk.png, attack.png and piece.json: the
  cells, frames and timing, and for every frame where its bald head is (the skull's centre, top and width, so a head
  can be fitted over it) and the box holding its skin.
head <gender>_<head>: art/generated/creator/head_<id>.png (a base figure with another face, still bald) ->
  pieces/heads/<id>.png (each view's head above the neck, side by side) and <id>.json (each view's rect and skull).
hair <style> / beard <style>: art/generated/creator/<kind>_<id>.png (the male base with magenta hair or a beard) ->
  pieces/<kind>/<id>.png + .json: the keyed hair and its ink outline, placed against the base's skull.

Pieces keep skin and hair as shade indices (red 0-3) under alpha 254 (skin) and 253 (hair), which the game tints
with the chosen skin tone and hair colour; everything else is palette-snapped and cleaned like the walk sheets.
Heads, hair and beards are scaled to the walk sheets' pixel size (render_walk.py frames a figure at 1.12x its
height in the cell), so the game rarely has to resize them.
"""
import argparse
import json
import math
import shutil
import sys
import tempfile
from pathlib import Path

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "lib"))
sys.path.insert(0, str(HERE))
import anim  # noqa: E402
import creator  # noqa: E402
import cutout  # noqa: E402
import render_attack as ra  # noqa: E402
import render_walk as rw  # noqa: E402

SRC = cutout.ROOT / "art" / "generated" / "creator"
OUT = cutout.ROOT / "art" / "creator" / "pieces"
CELL = 384
WALK_FRAMES = 8
WALK_FPS = 10.0
# Hair and beards are drawn on this base; heads on the base of their gender.
HAIR_BASE = "base_male_average"
# Palette colour that stands in for skin while the sheet is cleaned (outfits have no green, so nothing else is it).
SKIN_STANDIN = "bile"


def args():
    p = argparse.ArgumentParser()
    p.add_argument("kind", choices=["body", "head", "hair", "beard"])
    p.add_argument("id")
    p.add_argument("--casts", action="store_true", help="the attack is a spell gesture")
    p.add_argument("--walk-only", action="store_true", help="skip the attack (while its strips are missing)")
    return p.parse_args(sys.argv[sys.argv.index("--") + 1:])


def figures(path):
    """The five views of a turnaround (front, front34, side, back34, back), cleaned as render_walk.py does."""
    sheet = anim.clean_source(cutout.load_rgba(path))
    figs = cutout.find_figures(sheet, 5)
    if len(figs) != 5:
        raise SystemExit(f"{path.name}: expected five views, found {len(figs)}")
    return figs


def keyed(fig, fig_h, expect=None):
    """Skin shades (-1 off the skin) and the head of one figure or pose. Cool shading Gemini put on the head's
    skin counts as skin shadow, and the head is found again with it, so a shadowed scalp keeps its width."""
    skin = creator.skin_mask(fig)
    hd = creator.head(fig, skin, fig_h=fig_h, expect=expect)
    if hd is not None:
        region = np.zeros(skin.shape, dtype=bool)
        region[: hd["cut"] + max(2, int(0.02 * fig_h))] = True
        skin |= creator.skin_shadow(fig, skin, region)
        hd = creator.head(fig, skin, fig_h=fig_h, expect=expect) or hd
    shade = creator.shades(fig, skin)
    return shade, hd


def finish(sheet, shade, hair=False):
    """Palette snap and cleanup of everything but the keyed pixels (`shade` >= 0), which are then stored as shade
    indices (alpha 254 for skin, 253 for hair). A pixel the cleanup turned into the keyed stand-in colour next to
    the keyed ones joins them at the base shade."""
    keyed_px = shade >= 0
    standin = np.array(cutout.palette_colour(SKIN_STANDIN), dtype=np.float32)
    tmp = sheet.copy()
    tmp[keyed_px, :3] = standin
    tmp[keyed_px, 3] = 1.0
    tmp = cutout.quantize(cutout.binarize_alpha(tmp), neutral_area=0.5)
    tmp = cutout.merge_islands(cutout.despeckle(tmp, near=0.3, ring=True))
    like = (tmp[..., 3] > 0.5) & (np.abs(tmp[..., :3] - standin).max(axis=2) < 1.5 / 255.0) & ~keyed_px
    joined = like & creator.dilate(keyed_px, 1)
    shade = shade.copy()
    shade[joined] = 2
    tmp[like & ~joined, :3] = np.array(cutout.palette_colour("moss"), dtype=np.float32)
    if not (shade >= 0).any():
        return tmp
    return creator.encode_keys(tmp, hair_shade=shade) if hair else creator.encode_keys(tmp, skin_shade=shade)


def skin_boxes(sheet, cell, cols, rows):
    """Per cell (row-major), the box (x0, y0, x1, y1, cell-local) holding its keyed pixels (alpha 253 or 254 in
    the finished sheet), or None."""
    cw, ch = cell
    a8 = np.round(sheet[..., 3] * 255.0).astype(np.int32)
    keyed_px = (a8 == creator.ALPHA_SKIN) | (a8 == creator.ALPHA_HAIR)
    out = []
    for r in range(rows):
        for c in range(cols):
            m = keyed_px[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw]
            if not m.any():
                out.append(None)
                continue
            ys, xs = np.nonzero(m)
            out.append([int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1])
    return out


def project(scene, cam, obj, points, res):
    """Pixel positions (x right, y down) of plane-local points on the rendered frame."""
    bpy.context.view_layer.update()
    out = []
    for p in points:
        co = world_to_camera_view(scene, cam, obj.matrix_world @ Vector(p))
        out.append((co.x * res[0], (1.0 - co.y) * res[1]))
    return out


def skull_points(hd, pivot, ppu):
    """The skull's left and right ends at its top, in the local coordinates of a plane made by rw.make_plane from
    a crop whose pivot is `pivot` (x, y in crop pixels): x right, z up."""
    px, py = pivot
    half = hd["skull_w"] / 2.0
    return [((hd["cx"] - half - px) / ppu, 0.0, (py - hd["top"]) / ppu),
            ((hd["cx"] + half - px) / ppu, 0.0, (py - hd["top"]) / ppu)]


def anchor_from(pts, offset=(0.0, 0.0)):
    (xa, ya), (xb, yb) = pts
    return [round(0.5 * (xa + xb) - offset[0], 2), round(0.5 * (ya + yb) - offset[1], 2), round(abs(xb - xa), 2)]


# ---------- bodies ----------

def body(a):
    src = SRC / f"body_{a.id}.png"
    figs = figures(src)
    height_px = max(f.shape[0] for f in figs)
    ppu = height_px / rw.FIGURE_HEIGHT
    views, shades_by_view, heads = {}, {}, {}
    for name, fig in zip(rw.VIEWS5, figs):
        shade, hd = keyed(fig, fig.shape[0])
        if hd is None:
            raise SystemExit(f"{a.id}: no head found in the {name} view")
        heads[name] = hd
        shades_by_view[name] = shade
    scene = cutout.reset_scene(CELL, CELL)
    cam = cutout.ortho_camera(scene, (0, -10, rw.FIGURE_HEIGHT * 0.52), (math.radians(90), 0, 0),
                              rw.FIGURE_HEIGHT * 1.12)
    cam.data.sensor_fit = "VERTICAL"
    for name, fig in zip(rw.VIEWS5, figs):
        views[name] = rw.build_view(name, creator.to_key_colours(fig, shades_by_view[name] >= 0,
                                                                  shades_by_view[name]), ppu)
    tmp = Path(tempfile.mkdtemp(prefix=f"creator_{a.id}_"))
    frames, anchors = [], []
    for d in rw.DIRECTIONS:
        view, mirrored, turn = rw.DIR_VIEW5[d]
        for name, parts in views.items():
            for obj in parts["root"].children_recursive:
                obj.hide_render = name != view
        root = views[view]["root"]
        root.scale = (-1.0 if mirrored else 1.0, 1.0, 1.0)
        root.rotation_euler = (0, 0, math.radians(turn))
        fig = figs[rw.VIEWS5.index(view)]
        h0, h1 = rw.rows(fig, rw.HEAD)
        for f in range(WALK_FRAMES):
            rw.pose(views[view], view, f, WALK_FRAMES, rw.FIGURE_HEIGHT)
            pts = skull_points(heads[view], (fig.shape[1] / 2.0, h1), ppu)
            anchors.append(anchor_from(project(scene, cam, views[view]["head"], pts, (CELL, CELL))))
            path = tmp / f"{d}_{f}.png"
            scene.render.filepath = str(path)
            bpy.ops.render.render(write_still=True)
            frames.append(cutout.load_rgba(path))
    walk = cutout.binarize_alpha(cutout.pack_grid(frames, WALK_FRAMES))
    walk_shade, _ = creator.from_key_colours(walk)
    out_dir = OUT / "bodies" / a.id
    out_dir.mkdir(parents=True, exist_ok=True)
    walk_out = finish(walk, walk_shade)
    cutout.save_rgba(walk_out, out_dir / "walk.png")
    piece = {"id": a.id, "source": str(src.relative_to(cutout.ROOT)),
             "dirs": {d: {"view": rw.DIR_VIEW5[d][0], "mirror": rw.DIR_VIEW5[d][1]} for d in rw.DIRECTIONS},
             "walk": {"cell": [CELL, CELL], "frames": WALK_FRAMES, "fps": WALK_FPS, "heads": anchors,
                      "skin": skin_boxes(walk_out, (CELL, CELL), WALK_FRAMES, len(rw.DIRECTIONS))}}
    shutil.rmtree(tmp, ignore_errors=True)
    if not a.walk_only:
        piece["attack"] = attack(a, figs, ppu, heads, shades_by_view, out_dir)
    (out_dir / "piece.json").write_text(json.dumps(piece, indent=1))
    print(f"body {a.id}: walk {walk_out.shape[1]}x{walk_out.shape[0]}"
          + (f", attack cells {piece['attack']['cell']}" if "attack" in piece else ", no attack yet"))


def attack(a, figs, ppu, heads, shades_by_view, out_dir):
    """render_attack.py's six frames per direction from the outfit's strips, skin keyed and heads found in every
    pose. Returns the attack's part of piece.json."""
    strips = {}
    problems = []
    for name, fig in zip(rw.VIEWS5, figs):
        path = SRC / "anim" / a.id / f"attack_{name}.png"
        if not path.exists():
            raise SystemExit(f"{a.id}: no attack strip {path.relative_to(cutout.ROOT)}")
        kfs, found = anim.load_strip(path)
        if kfs is None:
            raise SystemExit(f"{a.id}: attack strip {name} unusable: {'; '.join(found)}")
        k, more = anim.strip_scale(fig.shape[0], fig.shape[1], kfs[0])
        problems += [f"{name}: {p}" for p in found + more]
        crops = anim.match_colours([kf.crop for kf in kfs], kfs[0].crop, fig)
        for kf, crop in zip(kfs, crops):
            kf.crop = crop
        strips[name] = (kfs, k)
    ch, cw = 2 * int(round(CELL * ra.MAX_TALL / 2)), 2 * int(round(CELL * ra.MAX_WIDE / 2))
    scene = cutout.reset_scene(cw, ch)
    cam = cutout.ortho_camera(scene, (0, -10, rw.FIGURE_HEIGHT * 0.52), (math.radians(90), 0, 0),
                              rw.FIGURE_HEIGHT * 1.12 * ch / CELL)
    cam.data.sensor_fit = "VERTICAL"
    views = {}
    for name, fig in zip(rw.VIEWS5, figs):
        idle = anim.Keyframe(creator.to_key_colours(fig, shades_by_view[name] >= 0, shades_by_view[name]))
        kfs, k = strips[name]
        stand_x = (idle.anchor - idle.w / 2.0) / ppu
        root = bpy.data.objects.new(name, None)
        scene.collection.objects.link(root)
        planes, pose_heads = {}, {}
        planes["idle"] = ra.figure_plane(f"{name}_idle", idle, ppu, stand_x)
        pose_heads["idle"] = (heads[name], (idle.anchor, idle.h), ppu)
        for pose, kf in (("windup", kfs[1]), ("strike", kfs[2])):
            expect = heads[name]["area"] / (k * k)
            shade, hd = keyed(kf.crop, fig.shape[0] / k, expect=expect)
            if hd is None:
                problems.append(f"{name} {pose}: no head found; the standing head's place is used")
                hd = None
            kf.crop = creator.to_key_colours(kf.crop, shade >= 0, shade)
            planes[pose] = ra.figure_plane(f"{name}_{pose}", kf, ppu / k, stand_x)
            pose_heads[pose] = (hd, (kf.anchor, kf.h), ppu / k)
        for p in planes.values():
            p.parent = root
        views[name] = (root, planes, pose_heads)
    tmp = Path(tempfile.mkdtemp(prefix=f"creator_attack_{a.id}_"))
    frames, anchors = [], []
    for d in rw.DIRECTIONS:
        view, mirrored, turn = rw.DIR_VIEW5[d]
        for name, (root, planes, _) in views.items():
            for p in planes.values():
                p.hide_render = True
        root, planes, pose_heads = views[view]
        root.scale = (-1.0 if mirrored else 1.0, 1.0, 1.0)
        root.rotation_euler = (0, 0, math.radians(turn))
        for i, (pose, sx, sy, lean, _dur) in enumerate(ra.FRAMES):
            for key, p in planes.items():
                p.hide_render = key != pose
            p = planes[pose]
            depth = 1.0 + (ra.DEPTH.get(view, 0.0) if pose == "strike" else 0.0)
            p.scale = (sx * depth, 1.0, sy * depth)
            p.rotation_euler = (0, math.radians(lean * ra.LEAN.get(view, 0.5)), 0)
            hd, pivot, k_ppu = pose_heads[pose]
            if hd is None:
                hd, pivot, k_ppu = pose_heads["idle"]
                pts = project(scene, cam, planes["idle"], skull_points(hd, pivot, k_ppu), (cw, ch))
            else:
                pts = project(scene, cam, p, skull_points(hd, pivot, k_ppu), (cw, ch))
            anchors.append(pts)
            path = tmp / f"{d}_{i}.png"
            scene.render.filepath = str(path)
            bpy.ops.render.render(write_still=True)
            frames.append(cutout.load_rgba(path))
    # Crop every frame evenly round the centre to the smallest cell that holds them (anim.crop_even), keeping the
    # offset for the head anchors.
    h, w = frames[0].shape[:2]
    cy, cx = h / 2.0, w / 2.0
    half_w, half_h = CELL * ra.MIN_WIDE / 2.0, CELL / 2.0
    for f in frames:
        ys, xs = np.nonzero(f[..., 3] > 0.5)
        if len(xs):
            half_w = max(half_w, cx - xs.min() + ra.MARGIN, xs.max() + 1 - cx + ra.MARGIN)
            half_h = max(half_h, cy - ys.min() + ra.MARGIN, ys.max() + 1 - cy + ra.MARGIN)
    nw, nh = min(w, 2 * int(math.ceil(half_w))), min(h, 2 * int(math.ceil(half_h)))
    x0, y0 = (w - nw) // 2, (h - nh) // 2
    frames = [f[y0:y0 + nh, x0:x0 + nw].copy() for f in frames]
    sheet = cutout.binarize_alpha(cutout.pack_grid(frames, len(ra.FRAMES)))
    shade, _ = creator.from_key_colours(sheet)
    sheet_out = finish(sheet, shade)
    cutout.save_rgba(sheet_out, out_dir / "attack.png")
    shutil.rmtree(tmp, ignore_errors=True)
    for p in problems:
        print(f"WARNING {a.id}: {p}")
    return {"cell": [nw, nh], "frames": len(ra.FRAMES), "durations": [f[4] for f in ra.FRAMES], "fps": ra.FPS,
            "hit_frame": ra.HIT_FRAME, "casts": bool(a.casts),
            "heads": [anchor_from(pts, (x0, y0)) for pts in anchors],
            "skin": skin_boxes(sheet_out, (nw, nh), len(ra.FRAMES), len(rw.DIRECTIONS))}


# ---------- heads, hair and beards ----------

def nearest(arr, s):
    """Nearest-pixel resize by `s` (the walk renders sample with Closest, so pieces match them)."""
    h, w = arr.shape[:2]
    nh, nw = max(1, int(round(h * s))), max(1, int(round(w * s)))
    ys = np.minimum(((np.arange(nh) + 0.5) / s).astype(int), h - 1)
    xs = np.minimum(((np.arange(nw) + 0.5) / s).astype(int), w - 1)
    return arr[ys][:, xs]


def lower_body(fig, frac=0.5):
    """(bottom row, centre column) of a figure's lower half: where an edit that only changed the head stands."""
    h = fig.shape[0]
    a = fig[int(h * (1.0 - frac)):, :, 3] > 0.5
    xs = np.nonzero(a)[1]
    return h, float(np.median(xs)) if len(xs) else fig.shape[1] / 2.0


def pack(crops, meta, out_png, out_json, extra=None):
    """Lays the views' crops side by side (2 px apart) and writes the strip and its json."""
    gap = 2
    width = sum(c.shape[1] for c in crops) + gap * (len(crops) + 1)
    height = max(c.shape[0] for c in crops) + 2 * gap
    strip = np.zeros((height, width, 4), dtype=np.float32)
    x = gap
    views = {}
    for name, crop, m in zip(rw.VIEWS5, crops, meta):
        ch, cw = crop.shape[:2]
        strip[gap:gap + ch, x:x + cw] = crop
        views[name] = {"rect": [x, gap, cw, ch], **m}
        x += cw + gap
    out_png.parent.mkdir(parents=True, exist_ok=True)
    cutout.save_rgba(strip, out_png)
    out_json.write_text(json.dumps({"views": views, **(extra or {})}, indent=1))


def head_piece(a):
    src = SRC / f"head_{a.id}.png"
    figs = figures(src)
    s = CELL / (1.12 * max(f.shape[0] for f in figs))
    crops, meta = [], []
    for name, fig in zip(rw.VIEWS5, figs):
        shade, hd = keyed(fig, fig.shape[0])
        if hd is None:
            raise SystemExit(f"{a.id}: no head found in the {name} view")
        # Everything above the neck is head (shoulders start below it): skull, face, ears and horns.
        top = 0
        crop = fig[top:hd["cut"]].copy()
        sh = shade[top:hd["cut"]].copy()
        cols = np.nonzero(crop[..., 3].max(axis=0) > 0.5)[0]
        x0, x1 = int(cols.min()), int(cols.max()) + 1
        crop, sh = crop[:, x0:x1], sh[:, x0:x1]
        crop = nearest(crop, s)
        sh = nearest(sh[..., None].astype(np.float32), s)[..., 0].astype(np.int8)
        crop = finish(crop, sh)
        meta.append({"cx": round((hd["cx"] - x0) * s, 2), "top": round((hd["top"] - top) * s, 2),
                     "skull_w": round(hd["skull_w"] * s, 2), "cut": round((hd["cut"] - top) * s, 2)})
        crops.append(crop)
    pack(crops, meta, OUT / "heads" / f"{a.id}.png", OUT / "heads" / f"{a.id}.json",
         {"source": str(src.relative_to(cutout.ROOT))})
    print(f"head {a.id}: " + ", ".join(f"{n} {c.shape[1]}x{c.shape[0]}" for n, c in zip(rw.VIEWS5, crops)))


def hair_piece(a):
    """Hair or a beard: the magenta pixels, their ink outline and anything they enclose, placed against the
    skull of the base it was drawn on (found on the base itself, then moved by how the edit's lower body sits)."""
    src = SRC / f"{a.kind}_{a.id}.png"
    figs = figures(src)
    base = figures(SRC / f"{HAIR_BASE}.png")
    s = CELL / (1.12 * max(f.shape[0] for f in base))
    crops, meta = [], []
    for name, fig, bfig in zip(rw.VIEWS5, figs, base):
        _, bhd = keyed(bfig, bfig.shape[0])
        if bhd is None:
            raise SystemExit(f"base {HAIR_BASE}: no head found in the {name} view")
        fb, fcx = lower_body(fig)
        bb, bcx = lower_body(bfig)
        dx, dy = fcx - bcx, fb - bb
        hair = creator.hair_mask(fig)
        if not hair.any():
            crops.append(np.zeros((2, 2, 4), dtype=np.float32))
            meta.append({"cx": 1.0, "top": 1.0, "skull_w": bhd["skull_w"] * s, "cut": 2.0, "empty": True})
            continue
        _, _, val = creator.hsv(fig)
        ink = (fig[..., 3] > 0.5) & (val < 0.3) & creator.dilate(hair, 2)
        piece = creator.fill_holes(hair | ink) & (fig[..., 3] > 0.5)
        skin = creator.skin_mask(fig)
        piece &= ~skin
        shade = creator.shades(fig, hair)
        light = piece & ~hair & ~ink & (val >= 0.3)
        shade[light] = 3
        ys, xs = np.nonzero(piece)
        y0, y1, x0, x1 = int(ys.min()), int(ys.max()) + 1, int(xs.min()), int(xs.max()) + 1
        crop = fig[y0:y1, x0:x1].copy()
        crop[~piece[y0:y1, x0:x1]] = 0.0
        sh = shade[y0:y1, x0:x1].copy()
        sh[~piece[y0:y1, x0:x1]] = -1
        crop = nearest(crop, s)
        sh = nearest(sh[..., None].astype(np.float32), s)[..., 0].astype(np.int8)
        out = finish(crop, sh, hair=True)
        meta.append({"cx": round((bhd["cx"] + dx - x0) * s, 2), "top": round((bhd["top"] + dy - y0) * s, 2),
                     "skull_w": round(bhd["skull_w"] * s, 2), "cut": round((bhd["cut"] + dy - y0) * s, 2)})
        crops.append(out)
    folder = "hair" if a.kind == "hair" else "beards"
    pack(crops, meta, OUT / folder / f"{a.id}.png", OUT / folder / f"{a.id}.json",
         {"source": str(src.relative_to(cutout.ROOT))})
    print(f"{a.kind} {a.id}: " + ", ".join(f"{n} {c.shape[1]}x{c.shape[0]}" for n, c in zip(rw.VIEWS5, crops)))


def main():
    a = args()
    if a.kind == "body":
        body(a)
    elif a.kind == "head":
        head_piece(a)
    else:
        hair_piece(a)


if __name__ == "__main__":
    main()
