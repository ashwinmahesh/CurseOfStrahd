"""Animation set v2 (docs/art/animation.md): drawn keyframe strips -> 8-direction sheets with several animations each.

blender -b --python blender/render_keys.py -- --id <asset_id> --kind walk8|attack10|hurt|ride|sneak|cast [--cell 768]
    [--ss 2] [--grid] [--check]

Each kind reads one strip per view, art/generated/anim/<id>/<kind>_<view>.png (tools/art/anim_keyframes.py --kind <kind>):
frame 1 redraws the turnaround view and sets the strip's scale and colours, the rest are drawn poses. A plan below
turns them into rendered frames (a pose plus a little squash, stretch, lean and offset, for in-betweens and weight) and
the frames into animations:

  walk4    walk.png/.tres     walk_<dir> (four drawn steps, eight frames with the body's rise and fall), idle_<dir>
                              (breathing, from the standing view). Cells keep the walk cell's height: the game sizes a
                              sprite by its standing frame.
  attack5  attack.png/.tres   attack_<dir>: ready, anticipation, wind-up, strike with a smear (the hit), follow-through
  hurt     hurt.png/.tres     hurt_<dir> (flinch and back), die_<dir> (flinch, stagger, fall, lying), down_<dir> (lying)
  ride     ride.png/.tres     ride_idle_<dir> (seated astride, breathing; drawn with the seat at the sprite's feet so it
                              sits on a mount's back), ride_attack_<dir>
  sneak    sneak.png/.tres    sneak_idle_<dir>, sneak_walk_<dir>
  cast     cast.png/.tres     cast_<dir>: gather, release (the hit), settle

Every sheet's .tres carries metadata hit_frames ({animation: frame}) for the one-shots that land a blow.

HD (owner 2026-10-07: "crystal clear, higher-res when zoomed in"): cells are 768 px tall, cut from the turnaround
redrawn at twice the resolution (<turnaround>_hd.png) when there is one, rendered at --ss times the size and
area-averaged down (even, sharp edges). Each frame is trimmed to its figure and the trimmed frames are packed into one
atlas; each frame's AtlasTexture margin restores the full cell, so the game sees whole cells and the sheet holds only
the figures (--grid writes the plain row-per-direction grid instead). The directions drawn as mirror images of others
(w of e and so on, render_walk.DIR_VIEW*) are left out: metadata "mirrored" names each one's twin and the game shows
the twin flipped (DirectionalSprite.anim_for), which is the same picture.
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

# A rendered frame: (pose, scale x, scale y, lean degrees forward, forward offset, vertical offset), offsets as a
# fraction of the figure's standing height. Pose "base" is the turnaround view; numbers are strip figures (1 = the
# first drawn pose after the reference).
BREATH = [("{p}", 1.0, 1.0, 0, 0, 0), ("{p}", 0.997, 1.007, 0, 0, 0), ("{p}", 0.995, 1.012, 0, 0, 0),
          ("{p}", 0.997, 1.007, 0, 0, 0)]


def breathing(pose):
    return [(pose if p == "{p}" else p, sx, sy, lean, dx, dy) for p, sx, sy, lean, dx, dy in BREATH]


SEAT = -0.3   # a rider's seat sits this far below the feet of the standing figure (the token stands on the saddle)
PLANS = {
    "walk4": {
        "file": "walk", "fixed_height": True,
        "frames": [(1, 1.0, 1.0, 1, 0, -0.004), (1, 1.015, 0.98, 1, 0, -0.014), (2, 1.0, 1.0, 1, 0, 0.006),
                   (2, 0.99, 1.012, 1, 0, 0.012), (3, 1.0, 1.0, 1, 0, -0.004), (3, 1.015, 0.98, 1, 0, -0.014),
                   (4, 1.0, 1.0, 1, 0, 0.006), (4, 0.99, 1.012, 1, 0, 0.012)] + breathing("base"),
        "anims": [("walk", list(range(8)), [1] * 8, 10.0, True), ("idle", [8, 9, 10, 11], [1] * 4, 4.0, True)],
    },
    # Doubled keys: two strips each ("strips"); poses named <strip letter><n> (a1 = the first strip's first pose).
    "walk8": {
        "file": "walk", "fixed_height": True, "strips": ["walk8a", "walk8b"],
        "frames": [("a1", 1.0, 1.0, 1, 0, 0), ("a1", 1.01, 0.99, 1, 0, -0.004), ("a2", 1.015, 0.98, 1, 0, -0.012),
                   ("a2", 1.01, 0.99, 1, 0, -0.008), ("a3", 1.0, 1.0, 1, 0, 0.004), ("a3", 0.995, 1.006, 1, 0, 0.008),
                   ("a4", 0.99, 1.012, 1, 0, 0.012), ("a4", 0.995, 1.006, 1, 0, 0.006),
                   ("b1", 1.0, 1.0, 1, 0, 0), ("b1", 1.01, 0.99, 1, 0, -0.004), ("b2", 1.015, 0.98, 1, 0, -0.012),
                   ("b2", 1.01, 0.99, 1, 0, -0.008), ("b3", 1.0, 1.0, 1, 0, 0.004), ("b3", 0.995, 1.006, 1, 0, 0.008),
                   ("b4", 0.99, 1.012, 1, 0, 0.012), ("b4", 0.995, 1.006, 1, 0, 0.006)]
        + [("base", 1.0, 1.0, 0, 0, 0), ("base", 0.998, 1.004, 0, 0, 0), ("base", 0.997, 1.007, 0, 0, 0),
           ("base", 0.995, 1.012, 0, 0, 0), ("base", 0.997, 1.007, 0, 0, 0), ("base", 0.998, 1.004, 0, 0, 0)],
        "anims": [("walk", list(range(16)), [1] * 16, 20.0, True), ("idle", list(range(16, 22)), [1] * 6, 6.0, True)],
    },
    "attack10": {
        "file": "attack", "strips": ["attack10a", "attack10b"],
        "frames": [("a1", 1.0, 1.0, 0, 0, 0), ("a2", 1.0, 1.0, -1, -0.005, 0), ("a3", 1.02, 0.98, -2, -0.01, 0),
                   ("a4", 1.02, 0.98, -3, -0.012, 0), ("a5", 0.98, 1.03, -4, -0.015, 0), ("b1", 1.05, 0.97, 4, 0.025, 0),
                   ("b2", 1.07, 0.96, 6, 0.04, 0), ("b3", 1.02, 0.99, 4, 0.03, 0), ("b4", 1.0, 1.0, 2, 0.015, 0),
                   ("b5", 1.0, 1.0, 1, 0.005, 0), ("base", 1.0, 1.0, 0, 0, 0)],
        "anims": [("attack", list(range(11)), [1, 1, 1, 1, 1.75, 0.6, 0.75, 1.5, 1, 1, 1], 16.0, False)],
        "hits": {"attack": 6},
    },
    "attack5": {
        "file": "attack",
        "frames": [(1, 1.0, 1.0, 0, 0, 0), (2, 1.03, 0.97, -2, -0.01, 0), (3, 0.98, 1.03, -4, -0.015, 0),
                   (4, 1.07, 0.96, 6, 0.04, 0), (4, 1.02, 0.99, 4, 0.03, 0), (5, 1.0, 1.0, 3, 0.03, 0),
                   (5, 1.0, 1.0, 1, 0.015, 0), (1, 1.0, 1.0, 0, 0, 0)],
        "anims": [("attack", list(range(8)), [1, 1.25, 1.25, 0.75, 0.75, 1.5, 1, 1], 12.0, False)],
        "hits": {"attack": 3},
    },
    "hurt": {
        "file": "hurt",
        "frames": [(1, 0.97, 1.02, -5, -0.05, 0), (1, 1.0, 1.0, -3, -0.03, 0), (2, 1.0, 1.0, 0, -0.02, 0),
                   (3, 1.0, 1.0, 0, -0.03, 0), (4, 1.0, 1.0, 0, -0.03, 0), ("base", 1.0, 1.0, 0, 0, 0)],
        "anims": [("hurt", [0, 1, 5], [1.5, 1.5, 1], 12.0, False), ("die", [0, 2, 3, 4], [1, 1.5, 1.5, 2], 10.0, False),
                  ("down", [4], [1], 1.0, True)],
    },
    "ride": {
        "file": "ride",
        "frames": [(p, sx, sy, lean, dx, dy + SEAT) for p, sx, sy, lean, dx, dy in breathing(1)]
        + [(2, 0.98, 1.03, -3, 0, SEAT), (3, 1.05, 0.97, 5, 0.02, SEAT), (3, 1.0, 1.0, 3, 0.01, SEAT)],
        "anims": [("ride_idle", [0, 1, 2, 3], [1] * 4, 4.0, True),
                  ("ride_attack", [4, 5, 6, 0], [1.5, 0.75, 1.5, 1], 12.0, False)],
        "hits": {"ride_attack": 1},
    },
    "sneak": {
        "file": "sneak",
        "frames": breathing(1) + [(2, 1.0, 1.0, 1, 0, -0.004), (2, 1.01, 0.985, 1, 0, -0.01),
                                  (3, 1.0, 1.0, 1, 0, -0.004), (3, 1.01, 0.985, 1, 0, -0.01)],
        "anims": [("sneak_idle", [0, 1, 2, 3], [1] * 4, 4.0, True),
                  ("sneak_walk", [4, 5, 0, 6, 7, 0], [1] * 6, 8.0, True)],
    },
    "cast": {
        "file": "cast",
        "frames": [(1, 1.0, 1.02, -1, 0, 0), (1, 1.01, 1.0, -2, -0.005, 0), (2, 1.04, 0.98, 4, 0.03, 0),
                   (2, 1.0, 1.0, 2, 0.015, 0), ("base", 1.0, 1.0, 0, 0, 0)],
        "anims": [("cast", [0, 1, 2, 3, 4], [1.25, 1.25, 0.75, 1.5, 1], 12.0, False)],
        "hits": {"cast": 2},
    },
}
# How much of a lean and a forward shift shows per view (none head-on, where it would read as tipping sideways), and
# how much bigger or smaller "forward" makes the figure head-on.
LEAN = {"front": 0.0, "front34": 0.6, "side": 1.0, "back34": 0.6, "back": 0.0}
DEPTH = {"front": 0.6, "back": -0.6}
MAX_WIDE, MAX_TALL, MIN_WIDE, MARGIN = 3.0, 1.8, 1.0, 6   # MARGIN: pixels at a 384 cell (scaled with the cell)


def args():
    p = argparse.ArgumentParser()
    p.add_argument("--id", required=True)
    p.add_argument("--kind", required=True, choices=list(PLANS) + [k for pl in PLANS.values() for k in pl.get("strips", [])])
    p.add_argument("--cell", type=int, default=768)
    p.add_argument("--ss", type=int, default=2, help="render at this many times the size and area-average down")
    p.add_argument("--grid", action="store_true", help="a plain grid sheet instead of the packed atlas")
    p.add_argument("--check", action="store_true")
    return p.parse_args(sys.argv[sys.argv.index("--") + 1:])


def strip_count(kind, strip=None):
    """Figures on one strip of `kind` (the reference redraw included); `strip` picks one of a multi-strip kind."""
    plan = PLANS[kind]
    if "strips" in plan:
        letter = "ab"[plan["strips"].index(strip)]
        return 1 + max(int(p[1:]) for p, *_ in plan["frames"] if isinstance(p, str) and p[0] == letter and p != "base")
    return 1 + max(p for p, *_ in plan["frames"] if isinstance(p, int))


# Strip kinds that feed a multi-strip plan, so --check and anim_keyframes.py can ask about one strip.
STRIP_OF = {k: (plan_name, k) for plan_name, plan in PLANS.items() for k in plan.get("strips", [])}


def main():
    a = args()
    only_strip = None
    if a.kind in STRIP_OF:
        # One strip of a two-strip plan: checked on its own (rendering takes the plan's name).
        a.kind, only_strip = STRIP_OF[a.kind]
    plan = PLANS[a.kind]
    strip_kinds = plan.get("strips", [a.kind])
    if only_strip:
        strip_kinds = [only_strip]
    flags = anim.walk_flags(a.id)
    sheet = anim.clean_source(cutout.load_rgba(cutout.ROOT / (flags["turnaround_hd"] or flags["turnaround"])))
    figures = cutout.find_figures(sheet, flags["views"] or rw.view_count(sheet))
    names, dir_view = (rw.VIEWS5, rw.DIR_VIEW5) if len(figures) == 5 else (rw.VIEWS3, rw.DIR_VIEW3)
    if flags["side_faces"] == "left":
        figures = [f if n in ("front", "back") else f[:, ::-1].copy() for n, f in zip(names, figures)]
    height_px = max(f.shape[0] for f in figures)
    ppu = height_px / rw.FIGURE_HEIGHT
    if flags["body"] != "humanoid" or flags["static"]:
        ppu = max(ppu, max(f.shape[1] for f in figures) / (rw.FIGURE_HEIGHT * 1.12 * 0.94))

    problems, strips = {}, {}
    for name, fig in zip(names, figures):
        got = []
        for si, sk in enumerate(strip_kinds):
            count = strip_count(a.kind, sk if "strips" in plan else None)
            path = anim.strip_path(a.id, sk, name)
            if not path.exists():
                problems.setdefault(name, []).append(f"{sk} missing" if len(strip_kinds) > 1 else "missing")
                continue
            kfs, found = anim.load_strip(path, count, key_magenta=(a.kind == "ride"))
            if kfs is not None:
                k, more = anim.strip_scale(fig.shape[0], fig.shape[1], kfs[0])
                found += more + anim.colour_drift(kfs, skip=(count,) if a.kind == "hurt" else ())
                letter = "ab"[plan["strips"].index(sk)] if "strips" in plan else ""
                got.append((letter, kfs, k))
            if found:
                problems.setdefault(name, []).extend(f"{sk}: {w}" if len(strip_kinds) > 1 else w for w in found)
        if len(got) == len(strip_kinds):
            strips[name] = got
    if a.check:
        print("CHECK " + json.dumps(problems))
        return
    if len(strips) < len(names):
        raise SystemExit(f"{a.id} {a.kind}: unusable strips: {json.dumps(problems)} (tools/art/anim_keyframes.py)")

    fixed = plan.get("fixed_height", False)
    ch = a.cell if fixed else 2 * int(round(a.cell * MAX_TALL / 2))
    cw = 2 * int(round(a.cell * MAX_WIDE / 2))
    margin = int(round(MARGIN * a.cell / 384))
    scene = cutout.reset_scene(cw * a.ss, ch * a.ss)
    cam = cutout.ortho_camera(scene, (0, -10, rw.FIGURE_HEIGHT * 0.52), (math.radians(90), 0, 0),
                              rw.FIGURE_HEIGHT * 1.12 * ch / a.cell)
    cam.data.sensor_fit = "VERTICAL"
    views = {}
    for name, fig in zip(names, figures):
        base = anim.Keyframe(fig)
        stand_x = (base.anchor - base.w / 2.0) / ppu
        root = bpy.data.objects.new(name, None)
        scene.collection.objects.link(root)
        planes = {"base": rw.make_plane(f"{name}_base", base.crop, ppu, (base.anchor, base.h), (stand_x, 0.0), 0.0, root)}
        for letter, kfs, k in strips[name]:
            for kf, crop in zip(kfs, anim.match_colours([kf.crop for kf in kfs], kfs[0].crop, fig)):
                kf.crop = crop
            for i, kf in enumerate(kfs[1:], start=1):
                key = f"{letter}{i}" if letter else i
                planes[key] = rw.make_plane(f"{name}_{key}", kf.crop, ppu / k, (kf.anchor, kf.h), (stand_x, 0.0), 0.0,
                                            root)
        views[name] = (root, planes)

    twins = {} if a.grid else anim.mirror_twins(dir_view)
    directions = [d for d in rw.DIRECTIONS if d not in twins]
    tmp = Path(tempfile.mkdtemp(prefix=f"{a.kind}_{a.id}_"))
    frames, clipped = [], set()
    for d in directions:
        view, mirrored, turn = dir_view[d]
        for name, (root, planes) in views.items():
            for p in planes.values():
                p.hide_render = True
        root, planes = views[view]
        root.scale = (-1.0 if mirrored else 1.0, 1.0, 1.0)
        root.rotation_euler = (0, 0, math.radians(turn))
        for i, (pose, sx, sy, lean, dx, dy) in enumerate(plan["frames"]):
            for key, p in planes.items():
                p.hide_render = key != pose
            p = planes[pose]
            depth = 1.0 + DEPTH.get(view, 0.0) * dx
            p.scale = (sx * depth, 1.0, sy * depth)
            p.rotation_euler = (0, math.radians(lean * LEAN.get(view, 0.5)), 0)
            x0 = p.get("x0", p.location[0])
            p["x0"] = x0
            p.location = (x0 + dx * rw.FIGURE_HEIGHT * LEAN.get(view, 0.5), p.location[1], dy * rw.FIGURE_HEIGHT)
            path = tmp / f"{d}_{i}.png"
            scene.render.filepath = str(path)
            bpy.ops.render.render(write_still=True)
            frame = cutout.downsample(cutout.load_rgba(path), a.ss)
            edges = anim.edge_touch(frame)
            if edges:
                clipped.add(f"{d} ({edges})")
            # Packed sheets keep only the trimmed figure (a whole 768 render is ~30 MB of floats per frame).
            frames.append(frame if a.grid else anim.trim(frame, margin))
    cols = len(plan["frames"])
    out_dir = cutout.ROOT / "art" / "sprites" / a.id
    out_dir.mkdir(parents=True, exist_ok=True)
    stem = plan["file"]
    rects = None
    if a.grid:
        frames, (cw, ch) = anim.crop_even(frames, a.cell, MIN_WIDE, margin)
        sheet_out = anim.finish_sheet(cutout.pack_grid(frames, cols), flags["saturate"])
    else:
        sheet_out, (cw, ch), rects = anim.pack_sheet(frames, (cw, ch), a.cell, MIN_WIDE, margin, flags["saturate"])
    cutout.save_rgba(sheet_out, out_dir / f"{stem}.png")
    s = anim.spec(a.id)
    meta = {"hit_frames": plan.get("hits", {}), "anim_set": 2}
    if twins:
        meta["mirrored"] = twins
    if a.kind in ("attack5", "attack10"):
        meta.update(hit_frame=plan["hits"]["attack"], casts=bool(s.get("casts", False)))
    anim.write_sheet_tres(out_dir / f"{stem}.tres", f"res://art/sprites/{a.id}/{stem}.png", (cw, ch), directions, cols,
               plan["anims"], meta, rects)
    shutil.rmtree(tmp, ignore_errors=True)
    for v, ws in problems.items():
        for w in ws:
            print(f"WARNING {a.id} {a.kind}: {v}: {w}")
    if clipped:
        print(f"WARNING {a.id} {a.kind}: frames reach the render's edge in {', '.join(sorted(clipped))}")
    print(f"{a.kind} sheet: {out_dir / (stem + '.png')} ({len(names)} views, {len(directions)} directions, {cols} frames each, {cw}x{ch} cells, "
          f"{sheet_out.shape[1]}x{sheet_out.shape[0]} sheet)")


if __name__ == "__main__":
    main()
