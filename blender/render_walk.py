"""Turnaround sheet -> 2D cutout rig -> 8-direction walk cycle -> sprite sheet + Godot SpriteFrames
(plan §7 steps 4-6).

blender -b --python blender/render_walk.py -- --turnaround <png> --id <asset_id>
        [--side-faces left] [--cell 384] [--frames 8] [--static] [--views 3|5] [--saturate K] [--no-clean]

The sheet shows views left to right: either 5 (front, front three-quarter, side, back three-quarter,
back — best, gives true diagonals) or 3 (front, side, back; diagonals reuse front/back turned 25
degrees; detected when the sheet holds three similar-width figures, or pass --views). Background is
removed if opaque; colours are snapped to the Strahd palette.

Clean pixel art (owner feedback 2026-10-06: no salt-and-pepper speckle in flat areas): the cut-out sheet is smoothed
with an edge-preserving filter before rendering (cutout.smooth_colours); after the palette snap, pixels unlike all but
one neighbour are despeckled (a neighbour in a near shade counts as alike, so thin outlines drawn in two dark shades
survive) and small same-coloured clumps merge into the near shade around them (cutout.merge_islands). --no-clean
renders the P4-09 way (plain despeckle only) for comparison.

Rig (v1): each view is cut into head, torso and legs by body proportion, and every part becomes a
textured plane pivoting at its joint (neck, hips). West-facing directions mirror the east ones.
Writes art/sprites/<id>/walk.png (rows = directions, cols = frames) and walk.tres.

--static (quadrupeds and other bodies the humanoid rig can't walk): each view is one still plane,
one frame per direction (the game adds a bob). Same cell, directions and animation names
(walk_<dir>, idle_<dir>), so DirectionalSprite loads it unchanged. Long bodies are scaled down to
fit the cell's width as well; the printed "height fill" is the tallest view's height as a fraction
of the band DirectionalSprite maps to height_units (1.0 for walk sheets).
"""
import argparse
import math
import shutil
import sys
import tempfile
from pathlib import Path

import bpy
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import cutout  # noqa: E402

DIRECTIONS = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]
VIEWS3 = ("front", "side", "back")
VIEWS5 = ("front", "front34", "side", "back34", "back")
# direction -> (view, mirrored, turn in degrees)
DIR_VIEW3 = {
    "s": ("front", False, 0), "se": ("front", False, -25), "e": ("side", False, 0),
    "ne": ("back", True, 25), "n": ("back", False, 0), "nw": ("back", False, -25),
    "w": ("side", True, 0), "sw": ("front", True, 25),
}
DIR_VIEW5 = {
    "s": ("front", False, 0), "se": ("front34", False, 0), "e": ("side", False, 0),
    "ne": ("back34", False, 0), "n": ("back", False, 0), "nw": ("back34", True, 0),
    "w": ("side", True, 0), "sw": ("front34", True, 0),
}
FIGURE_HEIGHT = 1.8  # world units in Blender; only ratios matter for the render
# Body proportions as fractions of figure height from the top.
HEAD = (0.0, 0.25)
TORSO = (0.17, 0.62)
LEGS = (0.56, 1.0)


def args():
    p = argparse.ArgumentParser()
    p.add_argument("--turnaround", required=True)
    p.add_argument("--id", required=True)
    p.add_argument("--side-faces", default="right", choices=["left", "right"])
    p.add_argument("--cell", type=int, default=384)
    p.add_argument("--frames", type=int, default=8)
    p.add_argument("--static", action="store_true", help="one still frame per direction, no rig")
    p.add_argument("--views", type=int, choices=[3, 5], help="views on the sheet (default: detect)")
    p.add_argument("--saturate", type=float, default=1.0, help="chroma boost before quantizing (cutout.saturate)")
    p.add_argument("--no-clean", action="store_true", help="skip the smoothing and island merge (comparison only)")
    return p.parse_args(sys.argv[sys.argv.index("--") + 1:])


def make_plane(name, crop, ppu, pivot_px, place, depth, parent):
    """A plane showing `crop`, with its origin at `pivot_px` (x, y in crop pixels), placed at
    `place` (x, z in figure units) and `depth` along Y (smaller = nearer the camera)."""
    h, w = crop.shape[:2]
    px, py = pivot_px
    verts = []
    for (cx, cy) in ((0, h), (w, h), (w, 0), (0, 0)):
        verts.append(((cx - px) / ppu, 0.0, (py - cy) / ppu))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], [(0, 1, 2, 3)])
    uv = mesh.uv_layers.new()
    for loop, coord in zip(uv.data, ((0, 0), (1, 0), (1, 1), (0, 1))):
        loop.uv = coord
    mesh.materials.append(cutout.flat_material(name, image=cutout.to_bpy_image(crop, name)))
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    obj.location = (place[0], depth, place[1])
    return obj


def rows(fig, span):
    h = fig.shape[0]
    return int(span[0] * h), int(round(span[1] * h))


def build_view(name, fig, ppu):
    """Cuts one view into parts. Figure coords: x from figure centre, z up from the feet."""
    root = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(root)
    h, w = fig.shape[:2]
    cx = w / 2.0
    to_world = lambda x_px, y_px: ((x_px - cx) / ppu, (h - y_px) / ppu)
    parts = {"root": root}

    t0, t1 = rows(fig, TORSO)
    torso = fig[t0:t1]
    parts["torso"] = make_plane(f"{name}_torso", torso, ppu, (cx, torso.shape[0]),
                                to_world(cx, t1), 0.0, root)
    h0, h1 = rows(fig, HEAD)
    head = fig[h0:h1]
    parts["head"] = make_plane(f"{name}_head", head, ppu, (cx, head.shape[0]),
                               (0.0, (t1 - h1) / ppu), -0.01, parts["torso"])
    l0, l1 = rows(fig, LEGS)
    legs, props = cutout.split_props(fig[l0:l1])
    if props is not None:
        # A staff or blade tip below the hips stays with the body instead of swinging with a leg.
        parts["props"] = make_plane(f"{name}_props", props, ppu, (cx, 0), (0.0, (t1 - l0) / ppu), 0.005,
                                    parts["torso"])
    if name == "side":
        back = legs.copy()
        back[..., :3] *= 0.62  # far leg in shadow
        parts["leg_a"] = make_plane(f"{name}_leg_near", legs, ppu, (cx, 0), to_world(cx, l0), 0.01, root)
        parts["leg_b"] = make_plane(f"{name}_leg_far", back, ppu, (cx, 0), to_world(cx, l0), 0.02, root)
    else:
        # Each leg gets only its own half so the planes never overlap (overlap z-fights).
        half = int(cx)
        left, right = legs[:, :half].copy(), legs[:, half:].copy()
        hip_off = w / 8.0
        parts["leg_a"] = make_plane(f"{name}_leg_l", left, ppu, (cx - hip_off, 0), to_world(cx - hip_off, l0), 0.01, root)
        parts["leg_b"] = make_plane(f"{name}_leg_r", right, ppu, (hip_off, 0), to_world(cx + hip_off, l0), 0.012, root)
    for key in ("torso", "leg_a", "leg_b"):
        parts[key]["rest"] = tuple(parts[key].location)
    parts["head"]["rest"] = tuple(parts["head"].location)
    return parts


def build_static_view(name, fig, ppu):
    """--static: the whole view as one plane, feet on the ground, centred on its bounding box."""
    root = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(root)
    h, w = fig.shape[:2]
    make_plane(f"{name}_whole", fig, ppu, (w / 2.0, h), (0.0, 0.0), 0.0, root)
    return {"root": root}


def pose(parts, view, frame, frames, height):
    """Walk cycle: legs swing (side) or lift (front/back), the body bobs at the passing pose."""
    phase = 2.0 * math.pi * frame / frames
    s = math.sin(phase)
    bob = 0.018 * height * math.cos(2.0 * phase)
    tx, ty, tz = parts["torso"]["rest"]
    parts["torso"].location = (tx, ty, tz + bob)
    hx, hy, hz = parts["head"]["rest"]
    parts["head"].location = (hx, hy, hz)
    parts["head"].rotation_euler = (0, math.radians(2.5) * s, 0)
    for key, sign in (("leg_a", 1.0), ("leg_b", -1.0)):
        lx, ly, lz = parts[key]["rest"]
        if view == "side":
            parts[key].rotation_euler = (0, math.radians(26.0) * s * sign, 0)
            parts[key].location = (lx, ly, lz + bob * 0.5)
        else:
            lift = max(0.0, s * sign) * 0.05 * height
            parts[key].rotation_euler = (0, 0, 0)
            parts[key].location = (lx, ly, lz + lift + bob * 0.3)
            parts[key].scale = (1.0, 1.0, 1.0 - 0.08 * max(0.0, s * sign))
    parts["torso"].rotation_euler = (0, math.radians(1.5) * s, 0)


def view_count(sheet):
    """5 unless the sheet is clearly three separate figures of similar width: wide bodies on a 3-view sheet
    (a rat swarm) would otherwise be cut into five by the touching-figure split in find_figures."""
    runs = cutout.column_runs(sheet[..., 3].max(axis=0) > 0.5)
    merged = []
    for r in runs:
        if merged and r[0] - merged[-1][1] < 6:
            merged[-1] = (merged[-1][0], r[1])
        else:
            merged.append(r)
    widths = [b - a for a, b in merged if b - a >= 0.03 * sheet.shape[1]]
    return 3 if len(widths) == 3 and max(widths) < 1.6 * min(widths) else 5


def main():
    a = args()
    out_dir = cutout.ROOT / "art" / "sprites" / a.id
    out_dir.mkdir(parents=True, exist_ok=True)
    sheet = cutout.load_rgba(a.turnaround)
    sheet = cutout.binarize_alpha(cutout.remove_background(sheet))
    if not a.no_clean:
        sheet = cutout.smooth_colours(sheet)
    figures = cutout.find_figures(sheet, a.views or view_count(sheet))
    if len(figures) == 5:
        names, dir_view = VIEWS5, DIR_VIEW5
    elif len(figures) == 3:
        names, dir_view = VIEWS3, DIR_VIEW3
    else:
        raise SystemExit(f"expected 3 or 5 figures in the turnaround, found {len(figures)}")
    if a.side_faces == "left":
        # Every profile-ish view faces the same way; flip them all so they face image-right.
        for i, n in enumerate(names):
            if n not in ("front", "back"):
                figures[i] = figures[i][:, ::-1].copy()
    height_px = max(f.shape[0] for f in figures)
    ppu = height_px / FIGURE_HEIGHT
    frames_per_dir = a.frames
    if a.static:
        # A wolf in profile is longer than it is tall: every view keeps one scale, so the widest
        # view must fit the cell too (6% margin).
        width_px = max(f.shape[1] for f in figures)
        ppu = max(ppu, width_px / (FIGURE_HEIGHT * 1.12 * 0.94))
        frames_per_dir = 1
    height_fill = height_px / ppu / FIGURE_HEIGHT

    scene = cutout.reset_scene(a.cell, a.cell)
    cutout.ortho_camera(scene, (0, -10, FIGURE_HEIGHT * 0.52), (math.radians(90), 0, 0), FIGURE_HEIGHT * 1.12)
    build = build_static_view if a.static else build_view
    views = {name: build(name, fig, ppu) for name, fig in zip(names, figures)}

    # Frames go outside the project so an open Godot editor doesn't import them (and leave .import files).
    tmp = Path(tempfile.mkdtemp(prefix=f"walk_{a.id}_"))
    frames = []
    for d in DIRECTIONS:
        view, mirrored, turn = dir_view[d]
        for name, parts in views.items():
            hidden = name != view
            for obj in parts["root"].children_recursive:
                obj.hide_render = hidden
        root = views[view]["root"]
        root.scale = (-1.0 if mirrored else 1.0, 1.0, 1.0)
        root.rotation_euler = (0, 0, math.radians(turn))
        for f in range(frames_per_dir):
            if not a.static:
                pose(views[view], view, f, frames_per_dir, FIGURE_HEIGHT)
            path = tmp / f"{d}_{f}.png"
            scene.render.filepath = str(path)
            bpy.ops.render.render(write_still=True)
            frames.append(cutout.load_rgba(path))
    walk = cutout.pack_grid(frames, frames_per_dir)
    walk = cutout.saturate(cutout.binarize_alpha(walk), a.saturate)
    walk = cutout.quantize(walk, neutral_area=0.0 if a.no_clean else 0.5)
    if a.no_clean:
        walk = cutout.despeckle(walk)
    else:
        walk = cutout.merge_islands(cutout.despeckle(walk, near=0.3, ring=True))
    cutout.save_rgba(walk, out_dir / "walk.png")
    cutout.write_sprite_frames(out_dir / "walk.tres", f"res://art/sprites/{a.id}/walk.png",
                               (a.cell, a.cell), DIRECTIONS, frames_per_dir)
    shutil.rmtree(tmp, ignore_errors=True)
    print(f"walk sheet: {out_dir / 'walk.png'} ({len(names)} views, {len(DIRECTIONS)} directions x "
          f"{frames_per_dir} frames{', static' if a.static else ''}, height fill {height_fill:.2f})")


main()
