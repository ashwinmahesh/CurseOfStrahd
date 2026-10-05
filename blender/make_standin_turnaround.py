"""Renders a stand-in turnaround sheet (front, side, back) of a primitive Barovian villager, in the
same layout GPT Image is asked for. It lets the sprite pipeline run before generated art exists.

blender -b --python blender/make_standin_turnaround.py -- <out.png>
"""
import math
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import cutout  # noqa: E402

VIEW_W, VIEW_H = 512, 1024


def part(name, mesh_op, loc, scale, colour, rot=(0, 0, 0)):
    mesh_op()
    obj = bpy.context.active_object
    obj.name = name
    obj.location = loc
    obj.scale = scale
    obj.rotation_euler = rot
    obj.data.materials.append(cutout.flat_material(name, cutout.palette_colour(colour)))
    # Inverted-hull outline: a slightly bigger back-facing shell in ink.
    sol = obj.modifiers.new("Outline", "SOLIDIFY")
    sol.thickness = 0.025
    sol.offset = 1.0
    sol.use_flip_normals = True
    sol.material_offset = 1
    ink = cutout.flat_material(name + "_ink", cutout.palette_colour("void"))
    ink.use_backface_culling = True
    obj.data.materials.append(ink)
    return obj


def build_villager():
    root = bpy.data.objects.new("Villager", None)
    bpy.context.scene.collection.objects.link(root)
    cyl = lambda: bpy.ops.mesh.primitive_cylinder_add(vertices=16)
    sph = lambda: bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10)
    cube = bpy.ops.mesh.primitive_cube_add
    parts = [
        part("BootL", cube, (-0.12, -0.04, 0.06), (0.07, 0.12, 0.06), "leather"),
        part("BootR", cube, (0.12, -0.04, 0.06), (0.07, 0.12, 0.06), "leather"),
        part("LegL", cyl, (-0.12, 0, 0.42), (0.075, 0.075, 0.32), "bone_dark"),
        part("LegR", cyl, (0.12, 0, 0.42), (0.075, 0.075, 0.32), "bone_dark"),
        part("Tunic", cyl, (0, 0, 0.98), (0.25, 0.17, 0.3), "moss"),
        part("Belt", cyl, (0, 0, 0.74), (0.255, 0.175, 0.04), "rust"),
        part("ArmL", cyl, (-0.31, 0, 0.98), (0.06, 0.06, 0.27), "moss", (0, math.radians(-6), 0)),
        part("ArmR", cyl, (0.31, 0, 0.98), (0.06, 0.06, 0.27), "moss", (0, math.radians(6), 0)),
        part("HandL", sph, (-0.34, 0, 0.68), (0.055, 0.055, 0.055), "skin"),
        part("HandR", sph, (0.34, 0, 0.68), (0.055, 0.055, 0.055), "skin"),
        part("Head", sph, (0, 0, 1.47), (0.16, 0.15, 0.19), "skin"),
        part("Nose", sph, (0, -0.15, 1.45), (0.04, 0.06, 0.05), "skin_shadow"),
        part("EyeL", sph, (-0.06, -0.135, 1.5), (0.025, 0.02, 0.03), "void"),
        part("EyeR", sph, (0.06, -0.135, 1.5), (0.025, 0.02, 0.03), "void"),
        part("Cap", cyl, (0, 0.01, 1.62), (0.18, 0.18, 0.05), "leather"),
        part("CapTop", sph, (0, 0.02, 1.66), (0.15, 0.15, 0.07), "tan"),
        part("Patch", cube, (0.1, -0.165, 1.05), (0.06, 0.01, 0.06), "bone"),
    ]
    for p in parts:
        p.parent = root
    return root


def main():
    out = Path(sys.argv[sys.argv.index("--") + 1])
    scene = cutout.reset_scene(VIEW_W, VIEW_H)
    villager = build_villager()
    cutout.ortho_camera(scene, (0, -10, 0.88), (math.radians(90), 0, 0), 1.9)
    tmp = out.parent / "_views"
    views = []
    # Front faces the camera (-Y); side faces image-right (+X); back faces away.
    for name, rot in (("front", 0), ("side", 90), ("back", 180)):
        villager.rotation_euler = (0, 0, math.radians(rot))
        scene.render.filepath = str(tmp / f"{name}.png")
        bpy.ops.render.render(write_still=True)
        views.append(cutout.load_rgba(tmp / f"{name}.png"))
    sheet = cutout.pack_grid(views, 3)
    cutout.save_rgba(cutout.binarize_alpha(sheet), out)
    for f in tmp.glob("*.png"):
        f.unlink()
    tmp.rmdir()
    print("standin turnaround:", out)


main()
