"""2D views of 3D set pieces that were modelled first (docs/art/interiors.md): the Classic look and every 2D path still
need a sprite for each piece, so this renders a model from blender/models_3d.py on flat white, from the front with
that side toward the lower right (and with --back from behind, the same way), for blender/prop_sprite.py to cut out
and snap to the palette like a painted prop. No image model is used.

blender -b --python blender/model_sprites.py -- --only reading_table cushions --out DIR [--back reading_table cushions]

Writes DIR/<id>.png and DIR/<id>_back.png; then for each: make prop SRC=DIR/<id>.png ID=<id> HEIGHT=<units>.
"""
import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import models_3d as m3  # noqa: E402


def render(ob, out, yaw_deg):
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.get("sprite_cam") or bpy.data.cameras.new("sprite_cam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.get("sprite_cam") or bpy.data.objects.new("sprite_cam", cam_data)
    if cam.name not in scene.collection.objects:
        scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.engine = "BLENDER_WORKBENCH"
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "MATERIAL"
    shading.show_object_outline = True
    shading.object_outline_color = (0.1, 0.07, 0.12)
    shading.show_cavity = True
    shading.cavity_type = "WORLD"
    scene.display.shading.background_type = "VIEWPORT"
    scene.display.shading.background_color = (1.0, 1.0, 1.0)
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x = 1024
    scene.render.resolution_y = 1024
    lo, hi = m3.bounds(ob)
    size = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z)
    yaw, pitch = math.radians(yaw_deg), math.radians(30)
    offset = Vector((math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch), math.sin(pitch))) * 30
    centre = (lo + hi) / 2
    cam_data.ortho_scale = size * 1.35
    cam.location = centre + offset
    cam.rotation_euler = (offset * -1).to_track_quat("-Z", "Y").to_euler()
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.hide_render = o is not ob
    scene.render.filepath = str(out)
    bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="+", required=True)
    ap.add_argument("--back", nargs="*", default=[])
    ap.add_argument("--out", required=True)
    a = ap.parse_args(argv)
    built = m3.build(a.only)
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    for id_, (ob, _) in built.items():
        render(ob, out / f"{id_}.png", -35.0)       # front toward the lower right
        if id_ in a.back:
            render(ob, out / f"{id_}_back.png", 145.0)   # its back, the same way


main()
