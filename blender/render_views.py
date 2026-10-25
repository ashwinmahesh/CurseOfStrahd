"""Sourced model -> a set of orthographic views on a transparent background (for turnaround sheets).

blender -b --python blender/render_views.py -- --glb <file.glb> --out <prefix> [--yaws 0,45,...] [--size 768]
        [--elev 12] [--hide <regex of object names to leave out>] [--list]

Imports the glb, leaves out any object whose name matches --hide (a ground plane, a yard), fits an orthographic camera
to what is left and renders one PNG per yaw (degrees about the vertical axis; 0 looks at the model's -Y side, which is
the front for models made here) as <prefix>_<yaw>.png, same scale in every view. --list only prints the biggest
objects (no render), to choose --hide. Part of the wave 1 art, 2026-10-25 (Baba Lysaga's hut).
"""
import argparse
import math
import re
import sys

import bpy
from mathutils import Vector


def args():
    p = argparse.ArgumentParser()
    p.add_argument("--glb", required=True)
    p.add_argument("--out", default="")
    p.add_argument("--yaws", default="0,45,90,135,180,225,270,315")
    p.add_argument("--size", type=int, default=768)
    p.add_argument("--elev", type=float, default=12.0)
    p.add_argument("--hide", default="")
    p.add_argument("--list", action="store_true")
    p.add_argument("--sun", type=float, default=4.0, help="strength of the light that rides on the camera")
    p.add_argument("--ambient", type=float, default=1.6, help="strength of the even light all round")
    p.add_argument("--exposure", type=float, default=0.0, help="stops added to the standard colour transform")
    p.add_argument("--gamma", type=float, default=1.0, help="above 1 lifts the darks")
    p.add_argument("--ink", type=float, default=0.0, help="Freestyle outline width in pixels (0: none)")
    return p.parse_args(sys.argv[sys.argv.index("--") + 1:])


def bounds(objs):
    vs = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return lo, hi


def main():
    a = args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=a.glb)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if a.list:
        rows = []
        for o in meshes:
            lo, hi = bounds([o])
            rows.append((max(h - l for l, h in zip(lo, hi)), o.name, tuple(round(x) for x in (lo + hi) / 2),
                         tuple(round(h - l) for l, h in zip(lo, hi))))
        for r in sorted(rows, reverse=True)[:40]:
            print("OBJ", r)
        return
    if a.hide:
        rx = re.compile(a.hide, re.I)
        for o in meshes:
            if rx.search(o.name):
                o.hide_render = True
                o.hide_viewport = True
        meshes = [o for o in meshes if not o.hide_render]
    lo, hi = bounds(meshes)
    centre = (lo + hi) / 2
    radius = max((hi - lo).length / 2, 1e-3)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.film_transparent = True
    scene.render.resolution_x = scene.render.resolution_y = a.size
    scene.view_settings.view_transform = "Standard"   # no filmic dimming: the sprite pipeline snaps colours to a palette
    scene.view_settings.exposure = a.exposure
    scene.view_settings.gamma = a.gamma
    if a.ink > 0:   # black ink outlines, like the game's cartoon art
        scene.render.use_freestyle = True
        scene.render.line_thickness_mode = "ABSOLUTE"
        scene.render.line_thickness = a.ink
        vl = scene.view_layers[0]
        vl.use_freestyle = True
        ls = vl.freestyle_settings.linesets.new("ink")
        ls.select_silhouette = True
        ls.select_border = True
        ls.select_crease = True
        ls.select_by_visibility = True
        ls.linestyle.color = (0.02, 0.01, 0.02)
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.9, 0.88, 0.85, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = a.ambient
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = a.sun
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = radius * 2.05
    cam.data.clip_start, cam.data.clip_end = 0.01, radius * 10
    scene.collection.objects.link(cam)
    scene.camera = cam
    sun.parent = cam   # lit from the camera's upper right in every view, so the views match each other
    sun.rotation_euler = (math.radians(25), math.radians(20), 0)
    el = math.radians(a.elev)
    for ys in a.yaws.split(","):
        yaw = math.radians(float(ys))
        d = Vector((math.sin(yaw) * math.cos(el), -math.cos(yaw) * math.cos(el), math.sin(el)))
        cam.location = centre + d * radius * 4
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = "%s_%03d.png" % (a.out, int(float(ys)))
        bpy.ops.render.render(write_still=True)
        print("VIEW", scene.render.filepath)


main()
