"""Attack animation: keyframe strips -> 8-direction attack sheet + Godot SpriteFrames (docs/art/animation.md).

blender -b --python blender/render_attack.py -- --id <asset_id> [--cell 384] [--check]

--check only reads the strips and prints CHECK {"<view>": ["problem", ...]} for views whose strip should be drawn
again (tools/art/anim_keyframes.py --retry uses it): figures merged or clipped, or frame 1 not the standing view.

Reads the character's entry in art/anim/animations.json, its walk flags and turnaround from art/manifest.json (the
views the walk sheet is cut from) and one
attack strip per view, art/generated/anim/<id>/attack_<view>.png (tools/art/anim_keyframes.py): frame 1 redraws the
turnaround view, frame 2 is the wind-up and frame 3 the strike. Frame 1 sets the strip's scale, so the attack frames
line up with the walk sheet: same pixel size, same ground line, feet where they stood.

Six frames per direction, timed by per-frame durations: wind-up (squash), wind-up held (anticipation), strike (stretched,
leaning in: the hit frame), strike, strike settling, back to the standing view. Squash, stretch and lean are applied in
Blender on top of the drawn poses. Cells are as big as the widest and tallest pose needs (cropped evenly round the
walk cell's centre, at its pixel scale, so the figure keeps its size and ground line in game), at least 1.25x the
walk cell's width.

Writes art/sprites/<id>/attack.png (rows = directions, cols = frames) and attack.tres (attack_<dir>, not looping,
metadata hit_frame, and casts: the attack is a spell gesture, so the game also plays it when the character casts). The game merges attack.tres into walk.tres's animations (DirectionalSprite.frames_for).

HD, as render_walk.py: with an HD turnaround the standing frame is cut from it, cells are 768 px rendered at twice the
size, frames are trimmed and packed and the mirror-image directions left out (--grid for the earlier grid). The
wind-up and strike poses come from the same 1K strips, drawn at about the size they're shown.
"""
import argparse
import json
import math
import shutil
import sys
import tempfile
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "lib"))
sys.path.insert(0, str(HERE))
import anim  # noqa: E402
import cutout  # noqa: E402
import render_walk as rw  # noqa: E402

FPS = 12.0
# Attack cells are wider and taller than walk cells, with the same pixel scale and the same centre, so a swung
# weapon or a lunge fits and the figure stands on the same ground line (the game centres every frame). Frames are
# rendered at the largest size, then cropped evenly to the smallest cell that holds every frame.
MAX_WIDE = 2.5
MAX_TALL = 1.6
MIN_WIDE = 1.25
MARGIN = 6
# (pose, squash x, squash y, lean degrees forward, relative duration). Index 2 is the hit.
FRAMES = [
    ("windup", 1.04, 0.96, -2.0, 1.0),
    ("windup", 0.98, 1.03, -4.0, 1.5),
    ("strike", 1.07, 0.96, 6.0, 0.75),
    ("strike", 1.0, 1.0, 4.0, 1.0),
    ("strike", 1.01, 0.99, 2.0, 1.75),
    ("idle", 1.0, 1.0, 0.5, 1.0),
]
HIT_FRAME = 2
# How much of the lean shows in each view: none head-on (it would read as falling sideways).
LEAN = {"front": 0.0, "front34": 0.5, "side": 1.0, "back34": 0.5, "back": 0.0}
# Head-on, "forward" is toward or away from the camera: a touch bigger or smaller on the strike.
DEPTH = {"front": 0.03, "back": -0.03}


def args():
    p = argparse.ArgumentParser()
    p.add_argument("--id", required=True)
    p.add_argument("--cell", type=int, help="walk cell height (default 768 with an HD turnaround, else 384)")
    p.add_argument("--ss", type=int, help="render at this many times the size and area-average down (2 with HD)")
    p.add_argument("--grid", action="store_true", help="the full row-per-direction grid instead of the packed atlas")
    p.add_argument("--check", action="store_true")
    return p.parse_args(sys.argv[sys.argv.index("--") + 1:])


def figure_plane(name, kf, ppu, place_x):
    """A plane showing keyframe `kf` with its origin between the feet, standing at x = place_x."""
    return rw.make_plane(name, kf.crop, ppu, (kf.anchor, kf.h), (place_x, 0.0), 0.0, None)


def main():
    a = args()
    s = anim.spec(a.id)
    flags = anim.walk_flags(a.id)
    # HD (as render_walk.py): the turnaround redrawn at twice the size when there is one, 768 px cells, packed frames.
    a.cell, a.ss = anim.hd_cell(flags["turnaround_hd"], a.cell, a.ss)
    sheet = anim.clean_source(cutout.load_rgba(cutout.ROOT / (flags["turnaround_hd"] or flags["turnaround"])))
    figures = cutout.find_figures(sheet, flags["views"] or rw.view_count(sheet))
    names, dir_view = (rw.VIEWS5, rw.DIR_VIEW5) if len(figures) == 5 else (rw.VIEWS3, rw.DIR_VIEW3)
    if flags["side_faces"] == "left":
        figures = [f if n in ("front", "back") else f[:, ::-1].copy() for n, f in zip(names, figures)]
    # The walk sheet's scale (render_walk.py main): the tallest view fills the band; bodies drawn
    # --static also fit the widest view.
    height_px = max(f.shape[0] for f in figures)
    ppu = height_px / rw.FIGURE_HEIGHT
    if flags["body"] != "humanoid" or flags["static"]:
        width_px = max(f.shape[1] for f in figures)
        ppu = max(ppu, width_px / (rw.FIGURE_HEIGHT * 1.12 * 0.94))

    warnings = []
    problems = {}
    strips = {}
    for name, fig in zip(names, figures):
        path = anim.strip_path(a.id, "attack", name)
        if not path.exists():
            problems[name] = ["missing"]
            continue
        kfs, found = anim.load_strip(path)
        if kfs is not None:
            k, more = anim.strip_scale(fig.shape[0], fig.shape[1], kfs[0])
            found += more
            strips[name] = (kfs, k)
        if found:
            problems[name] = found
    if a.check:
        print("CHECK " + json.dumps(problems))
        return
    if len(strips) < len(names):
        raise SystemExit(f"{a.id}: unusable strips: {json.dumps(problems)} (tools/art/anim_keyframes.py)")
    warnings += [f"{v}: {w}" for v, ws in problems.items() for w in ws]
    # Even sizes keep the walk cell's centre on a pixel boundary.
    ch, cw = 2 * int(round(a.cell * MAX_TALL / 2)), 2 * int(round(a.cell * MAX_WIDE / 2))
    scene = cutout.reset_scene(cw * a.ss, ch * a.ss)
    cam = cutout.ortho_camera(scene, (0, -10, rw.FIGURE_HEIGHT * 0.52), (math.radians(90), 0, 0),
                              rw.FIGURE_HEIGHT * 1.12 * ch / a.cell)
    cam.data.sensor_fit = "VERTICAL"
    views = {}
    for name, fig in zip(names, figures):
        idle = anim.Keyframe(fig)
        kfs, k = strips[name]
        crops = anim.match_colours([kf.crop for kf in kfs], kfs[0].crop, fig)
        for kf, crop in zip(kfs, crops):
            kf.crop = crop
        # The walk rig stands the view with its bounding box centred: keep the feet there.
        stand_x = (idle.anchor - idle.w / 2.0) / ppu
        root = bpy.data.objects.new(name, None)
        scene.collection.objects.link(root)
        planes = {"idle": figure_plane(f"{name}_idle", idle, ppu, stand_x),
                  "windup": figure_plane(f"{name}_windup", kfs[1], ppu / k, stand_x),
                  "strike": figure_plane(f"{name}_strike", kfs[2], ppu / k, stand_x)}
        for p in planes.values():
            p.parent = root
        views[name] = (root, planes)

    tmp = Path(tempfile.mkdtemp(prefix=f"attack_{a.id}_"))
    frames = []
    clipped = set()
    twins = {} if a.grid else anim.mirror_twins(dir_view)
    directions = [d for d in rw.DIRECTIONS if d not in twins]
    margin = int(round(MARGIN * a.cell / 384))
    for d in directions:
        view, mirrored, turn = dir_view[d]
        for name, (root, planes) in views.items():
            for p in planes.values():
                p.hide_render = True
        root, planes = views[view]
        root.scale = (-1.0 if mirrored else 1.0, 1.0, 1.0)
        root.rotation_euler = (0, 0, math.radians(turn))
        for i, (pose, sx, sy, lean, _dur) in enumerate(FRAMES):
            for key, p in planes.items():
                p.hide_render = key != pose
            p = planes[pose]
            depth = 1.0 + (DEPTH.get(view, 0.0) if pose == "strike" else 0.0)
            p.scale = (sx * depth, 1.0, sy * depth)
            p.rotation_euler = (0, math.radians(lean * LEAN.get(view, 0.5)), 0)
            path = tmp / f"{d}_{i}.png"
            scene.render.filepath = str(path)
            bpy.ops.render.render(write_still=True)
            frame = cutout.downsample(cutout.load_rgba(path), a.ss)
            edges = anim.edge_touch(frame)
            if edges:
                clipped.add(f"{d} ({edges})")
            frames.append(frame if a.grid else anim.trim(frame, margin))
    out_dir = cutout.ROOT / "art" / "sprites" / a.id
    out_dir.mkdir(parents=True, exist_ok=True)
    meta = {"hit_frame": HIT_FRAME, "casts": bool(s.get("casts", False))}
    if a.grid:
        frames, (cw, ch) = anim.crop_even(frames, a.cell, MIN_WIDE, margin)
        sheet_out = anim.finish_sheet(cutout.pack_grid(frames, len(FRAMES)), flags["saturate"])
        cutout.save_rgba(sheet_out, out_dir / "attack.png")
        anim.write_frames_tres(out_dir / "attack.tres", f"res://art/sprites/{a.id}/attack.png", (cw, ch),
                               rw.DIRECTIONS, [f[4] for f in FRAMES], "attack", FPS, False, meta)
    else:
        sheet_out, (cw, ch), rects = anim.pack_sheet(frames, (cw, ch), a.cell, MIN_WIDE, margin, flags["saturate"])
        cutout.save_rgba(sheet_out, out_dir / "attack.png")
        if twins:
            meta["mirrored"] = twins
        anim.write_sheet_tres(out_dir / "attack.tres", f"res://art/sprites/{a.id}/attack.png", (cw, ch), directions,
                              len(FRAMES), [("attack", list(range(len(FRAMES))), [f[4] for f in FRAMES], FPS, False)],
                              meta, rects)
    shutil.rmtree(tmp, ignore_errors=True)
    if clipped:
        warnings.append(f"frames reach the cell edge in {', '.join(sorted(clipped))}")
    for w in warnings:
        print(f"WARNING {a.id}: {w}")
    print(f"attack sheet: {out_dir / 'attack.png'} ({len(names)} views, {len(directions)} directions x "
          f"{len(FRAMES)} frames, {cw}x{ch} cells, {sheet_out.shape[1]}x{sheet_out.shape[0]} sheet)")


if __name__ == "__main__":
    main()
