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
    # Background enclosed by the figure (between a wolf's legs and tail, inside a bent arm) isn't
    # reached from the border: clear enclosed background-coloured patches too, unless they are tiny
    # (eye glints, highlights).
    min_hole = max(400, int(0.0004 * mask.size))
    for comp in label_components(similar & ~mask):
        if sum(x1 - x0 for _, x0, x1 in comp) >= min_hole:
            for y, x0, x1 in comp:
                mask[y, x0:x1] = True
    # Anti-aliased edges leave a light halo: drop edge pixels still close to the background colour.
    near = np.linalg.norm(rgb - bg, axis=2) < tolerance * 3
    for _ in range(2):
        edge = np.zeros_like(mask)
        edge[1:] |= mask[:-1]
        edge[:-1] |= mask[1:]
        edge[:, 1:] |= mask[:, :-1]
        edge[:, :-1] |= mask[:, 1:]
        mask |= edge & near
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
    if len(merged) != count:
        # Overlapping columns (a wolf's snout above the next wolf's tail) needn't mean touching:
        # separate the figures as 2-D connected shapes first.
        crops = figures_by_components(arr, count)
        if crops is not None:
            return crops
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
    if len(merged) < count:
        merged = split_merged_runs(merged, coverage, count)
    merged = sorted(sorted(merged, key=lambda r: r[1] - r[0], reverse=True)[:count])
    crops = []
    for i, (x0, x1) in enumerate(merged):
        sub = arr[:, x0:x1]
        # A run that was cut out of a touching pair shares its edge column with its neighbour.
        left_cut = i > 0 and merged[i - 1][1] == x0
        right_cut = i + 1 < len(merged) and merged[i + 1][0] == x1
        if left_cut or right_cut:
            sub = drop_cut_fragments(sub, left_cut, right_cut)
        rows = np.nonzero(sub[..., 3].max(axis=1) > 0.5)[0]
        crops.append(sub[rows[0]:rows[-1] + 1].copy())
    return crops


def label_components(mask):
    """4-connected components of a boolean mask (row runs + union-find; no scipy in Blender).
    Returns a list of components, each a list of (row, x0, x1) runs with x1 exclusive."""
    runs, parent = [], []

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    prev = []
    for y in range(mask.shape[0]):
        d = np.diff(np.concatenate(([0], mask[y].astype(np.int8), [0])))
        cur = []
        for x0, x1 in zip(np.nonzero(d == 1)[0], np.nonzero(d == -1)[0]):
            idx = len(runs)
            runs.append((y, int(x0), int(x1)))
            parent.append(idx)
            cur.append(idx)
            for p in prev:
                if runs[p][1] < x1 and x0 < runs[p][2]:
                    ra, rb = find(idx), find(p)
                    if ra != rb:
                        parent[ra] = rb
        prev = cur
    groups = {}
    for i in range(len(runs)):
        groups.setdefault(find(i), []).append(runs[i])
    return list(groups.values())


def figures_by_components(arr, count):
    """The `count` largest connected shapes, left to right, each cropped to its own pixels (bits of
    a neighbour inside its box are cleared). Small detached pieces (a crystal, a strand of hair)
    join the nearest figure. Returns None if the shapes don't look like `count` separate figures."""
    comps = label_components(arr[..., 3] > 0.5)
    sizes = [sum(r[2] - r[1] for r in c) for c in comps]
    order = np.argsort(sizes)[::-1]
    if len(comps) < count or sizes[order[count - 1]] < 0.2 * sizes[order[0]]:
        return None
    figs = [[comps[i]] for i in order[:count]]
    boxes = [(min(r[1] for r in c), max(r[2] for r in c)) for c in (f[0] for f in figs)]
    reach = 0.02 * arr.shape[1]
    for i in order[count:]:
        c = comps[i]
        cx = 0.5 * (min(r[1] for r in c) + max(r[2] for r in c))
        dist = [max(b[0] - cx, cx - b[1], 0.0) for b in boxes]
        j = int(np.argmin(dist))
        if dist[j] <= reach:
            figs[j].append(c)
    crops = []
    for parts in figs:
        mask = np.zeros(arr.shape[:2], dtype=bool)
        for c in parts:
            for y, x0, x1 in c:
                mask[y, x0:x1] = True
        ys, xs = np.nonzero(mask)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        crop = arr[y0:y1, x0:x1].copy()
        crop[~mask[y0:y1, x0:x1]] = 0.0
        crops.append((x0 + x1, crop))
    return [c for _, c in sorted(crops, key=lambda t: t[0])]


def split_merged_runs(runs, coverage, count):
    """Several touching figures (a shield against the next figure's mace) form one wide run. The
    sheet is laid out in `count` roughly even slots, so a run spanning k slots is cut into k pieces at
    the emptiest column near each of its k-1 inner boundaries."""
    runs = [list(r) for r in runs]
    slot = (runs[-1][1] - runs[0][0]) / float(count)
    while len(runs) < count:
        ratios = [(r[1] - r[0]) / slot for r in runs]
        i = int(np.argmax(ratios))
        if ratios[i] < 1.4:
            break
        x0, x1 = runs[i]
        k = min(max(2, int(round(ratios[i]))), count - len(runs) + 1)
        part = (x1 - x0) / float(k)
        edges = [x0]
        for j in range(1, k):
            lo = int(x0 + part * (j - 0.3))
            hi = int(x0 + part * (j + 0.3))
            lo, hi = max(lo, edges[-1] + 1), min(hi, x1 - 1)
            edges.append(lo + int(np.argmin(coverage[lo:hi])))
        edges.append(x1)
        runs[i:i + 1] = [[edges[j], edges[j + 1]] for j in range(k)]
    return runs


def _grow(seed, allowed):
    """4-connected flood fill of `seed` inside `allowed` (boolean masks)."""
    mask = seed & allowed
    while True:
        grown = mask.copy()
        grown[1:] |= mask[:-1]
        grown[:-1] |= mask[1:]
        grown[:, 1:] |= mask[:, :-1]
        grown[:, :-1] |= mask[:, 1:]
        grown &= allowed
        if (grown == mask).all():
            return mask
        mask = grown


def drop_cut_fragments(sub, left_cut, right_cut):
    """After splitting touching figures, bits of the neighbour (a mace head, a shield rim) hang on
    at the cut edge. Removes opaque pieces that touch a cut edge but aren't connected to the figure
    (the component through the crop's fullest column)."""
    opaque = sub[..., 3] > 0.5
    seed = np.zeros_like(opaque)
    seed[:, int(np.argmax(opaque.sum(axis=0)))] = True
    body = _grow(seed, opaque)
    edge = np.zeros_like(opaque)
    if left_cut:
        edge[:, 0] = True
    if right_cut:
        edge[:, -1] = True
    stray = _grow(edge, opaque & ~body)
    out = sub.copy()
    out[stray] = 0.0
    return out


def column_runs(mask_cols):
    """[start, end) runs of True in a 1-D boolean array."""
    runs, start = [], None
    for x, on in enumerate(np.append(mask_cols, False)):
        if on and start is None:
            start = x
        elif not on and start is not None:
            runs.append((start, x))
            start = None
    return runs


def split_props(crop, max_frac=0.15, max_of_main=0.25):
    """Separates thin things in a leg crop that don't touch the legs (a staff held at the side, a
    sword tip) so they can ride with the torso instead of swinging with a leg. A prop is a column
    run narrower than `max_frac` of the crop and `max_of_main` of the main mass (so a second leg
    standing apart is never one). Returns (legs, props or None); both keep the crop's size."""
    runs = column_runs(crop[..., 3].max(axis=0) > 0.5)
    if len(runs) < 2:
        return crop, None
    weights = [crop[:, a:b, 3].sum() for a, b in runs]
    main = int(np.argmax(weights))
    w = crop.shape[1]
    main_w = runs[main][1] - runs[main][0]
    prop_runs = [r for i, r in enumerate(runs)
                 if i != main and (r[1] - r[0]) < max_frac * w and (r[1] - r[0]) < max_of_main * main_w]
    if not prop_runs:
        return crop, None
    legs, props = crop.copy(), np.zeros_like(crop)
    for a, b in prop_runs:
        props[:, a:b] = crop[:, a:b]
        legs[:, a:b] = 0.0
    return legs, props


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
