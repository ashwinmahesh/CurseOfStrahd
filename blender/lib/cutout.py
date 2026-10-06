"""Shared helpers for the sprite pipeline (plan §7 steps 4-6). Runs inside Blender's Python.

Images are numpy float arrays shaped (height, width, 4), top row first, RGBA in sRGB 0..1.
"""
import json
from pathlib import Path

import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[2]


# ---------- image io ----------

def load_rgba(path):
    img = bpy.data.images.load(str(path), check_existing=False)
    w, h = img.size
    arr = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(arr)
    bpy.data.images.remove(img)
    return np.flipud(arr.reshape(h, w, 4)).copy()


def to_bpy_image(arr, name):
    h, w = arr.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels.foreach_set(np.flipud(arr).astype(np.float32).ravel())
    img.pack()
    return img


def save_rgba(arr, path):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    img = to_bpy_image(arr, path.stem)
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


# ---------- cleanup ----------

def remove_background(arr, tolerance=0.12):
    """Makes the flat background transparent: flood-fills from the border through pixels close to
    the border's median colour. Used when the generator returns an opaque image."""
    if arr[..., 3].min() < 0.99:
        return arr
    rgb = arr[..., :3]
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    bg = np.median(border, axis=0)
    similar = np.linalg.norm(rgb - bg, axis=2) < tolerance
    mask = np.zeros_like(similar)
    mask[0, :] = similar[0, :]
    mask[-1, :] = similar[-1, :]
    mask[:, 0] = similar[:, 0]
    mask[:, -1] = similar[:, -1]
    while True:
        grown = mask.copy()
        grown[1:] |= mask[:-1]
        grown[:-1] |= mask[1:]
        grown[:, 1:] |= mask[:, :-1]
        grown[:, :-1] |= mask[:, 1:]
        grown &= similar
        if (grown == mask).all():
            break
        mask = grown
    out = arr.copy()
    out[mask, 3] = 0.0
    return out


def binarize_alpha(arr, threshold=0.5):
    out = arr.copy()
    out[..., 3] = (out[..., 3] >= threshold).astype(np.float32)
    out[out[..., 3] == 0] = 0.0
    return out


def load_palette():
    data = json.loads((ROOT / "art" / "palette" / "palette.json").read_text())
    return np.array([[int(h[i:i + 2], 16) / 255.0 for i in (1, 3, 5)] for h in data.values()], dtype=np.float32)


def quantize(arr, palette=None, chunk=200_000):
    """Snaps every visible pixel to the nearest palette colour (redmean distance, same as the shader)."""
    if palette is None:
        palette = load_palette()
    out = arr.copy()
    flat = out.reshape(-1, 4)
    idx = np.nonzero(flat[:, 3] > 0)[0]
    for start in range(0, len(idx), chunk):
        sel = idx[start:start + chunk]
        c = flat[sel, :3][:, None, :]
        p = palette[None, :, :]
        r = (c[..., 0] + p[..., 0]) * 0.5
        d = c - p
        dist = (2 + r) * d[..., 0] ** 2 + 4 * d[..., 1] ** 2 + (3 - r) * d[..., 2] ** 2
        flat[sel, :3] = palette[np.argmin(dist, axis=1)]
    return out


# ---------- layout ----------

def find_figures(arr, count=3, min_gap=6):
    """Finds the `count` widest figures laid out left to right (a turnaround sheet). Returns crops."""
    cols = arr[..., 3].max(axis=0) > 0.5
    runs, start = [], None
    for x, on in enumerate(np.append(cols, False)):
        if on and start is None:
            start = x
        elif not on and start is not None:
            runs.append([start, x])
            start = None
    merged = []
    for r in runs:
        if merged and r[0] - merged[-1][1] < min_gap:
            merged[-1][1] = r[1]
        else:
            merged.append(r)
    # Figures that touch (a boot overlapping the next figure) form one wide run. While we have one
    # fewer than asked for and a run is clearly wider than the rest, split it at its thinnest column.
    coverage = (arr[..., 3] > 0.5).sum(axis=0)
    if len(merged) == count - 1:
        widths = [r[1] - r[0] for r in merged]
        i = int(np.argmax(widths))
        others = [w for j, w in enumerate(widths) if j != i]
        if others and widths[i] > 1.5 * np.median(others):
            x0, x1 = merged[i]
            lo, hi = x0 + (x1 - x0) // 5, x1 - (x1 - x0) // 5
            cut = lo + int(np.argmin(coverage[lo:hi]))
            merged[i:i + 1] = [[x0, cut], [cut, x1]]
    merged = sorted(sorted(merged, key=lambda r: r[1] - r[0], reverse=True)[:count])
    crops = []
    for x0, x1 in merged:
        sub = arr[:, x0:x1]
        rows = np.nonzero(sub[..., 3].max(axis=1) > 0.5)[0]
        crops.append(sub[rows[0]:rows[-1] + 1].copy())
    return crops


def pack_grid(frames, cols):
    """frames: list of equal-sized arrays, row-major. Returns the sheet."""
    h, w = frames[0].shape[:2]
    rows = (len(frames) + cols - 1) // cols
    sheet = np.zeros((rows * h, cols * w, 4), dtype=np.float32)
    for i, f in enumerate(frames):
        r, c = divmod(i, cols)
        sheet[r * h:(r + 1) * h, c * w:(c + 1) * w] = f
    return sheet


def write_sprite_frames(tres_path, texture_res_path, cell, directions, frames_per_dir, fps=10.0):
    """Writes a Godot 4 SpriteFrames resource: walk_<dir> (all frames) and idle_<dir> (frame 0)."""
    w, h = cell
    lines_sub, anims = [], []
    for row, d in enumerate(directions):
        ids = []
        for f in range(frames_per_dir):
            sid = f"{d}_{f}"
            ids.append(sid)
            lines_sub.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("1")\n'
                             f"region = Rect2({f * w}, {row * h}, {w}, {h})\n")
        walk = ", ".join(f'{{"duration": 1.0, "texture": SubResource("{i}")}}' for i in ids)
        anims.append(f'{{\n"frames": [{walk}],\n"loop": true,\n"name": &"walk_{d}",\n"speed": {fps}\n}}')
        anims.append(f'{{\n"frames": [{{"duration": 1.0, "texture": SubResource("{ids[0]}")}}],\n'
                     f'"loop": true,\n"name": &"idle_{d}",\n"speed": 1.0\n}}')
    text = ('[gd_resource type="SpriteFrames" format=3]\n\n'
            f'[ext_resource type="Texture2D" path="{texture_res_path}" id="1"]\n\n'
            + "\n".join(lines_sub)
            + "\n[resource]\nanimations = [" + ", ".join(anims) + "]\n")
    Path(tres_path).write_text(text)


# ---------- scene ----------

def reset_scene(res_x, res_y):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = res_x
    scene.render.resolution_y = res_y
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.filter_size = 0.0
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    world = bpy.data.worlds.new("World")
    world.color = (0, 0, 0)
    scene.world = world
    return scene


def ortho_camera(scene, location, rotation, scale):
    cam_data = bpy.data.cameras.new("Camera")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = scale
    cam = bpy.data.objects.new("Camera", cam_data)
    cam.location = location
    cam.rotation_euler = rotation
    scene.collection.objects.link(cam)
    scene.camera = cam
    return cam


def flat_material(name, rgb=None, image=None):
    """Unlit material: shows the colour or texture exactly, with hard alpha (no lighting drift)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit = nt.nodes.new("ShaderNodeEmission")
    if image is not None:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = image
        tex.interpolation = "Closest"
        nt.links.new(tex.outputs["Color"], emit.inputs["Color"])
        clip = nt.nodes.new("ShaderNodeMath")
        clip.operation = "GREATER_THAN"
        clip.inputs[1].default_value = 0.5
        nt.links.new(tex.outputs["Alpha"], clip.inputs[0])
        transp = nt.nodes.new("ShaderNodeBsdfTransparent")
        mix = nt.nodes.new("ShaderNodeMixShader")
        nt.links.new(clip.outputs[0], mix.inputs["Fac"])
        nt.links.new(transp.outputs[0], mix.inputs[1])
        nt.links.new(emit.outputs[0], mix.inputs[2])
        nt.links.new(mix.outputs[0], out.inputs["Surface"])
        mat.surface_render_method = "DITHERED"
    else:
        emit.inputs["Color"].default_value = (*srgb_to_linear(rgb), 1.0)
        nt.links.new(emit.outputs[0], out.inputs["Surface"])
    return mat


def srgb_to_linear(rgb):
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb)


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def palette_colour(name):
    data = json.loads((ROOT / "art" / "palette" / "palette.json").read_text())
    return hex_rgb(data[name])
