"""Builds the 3D set pieces (docs/art/models.md): furniture, fireplaces, stairs, doors and wall panelling modelled from
the 2D props they replace (art/sprites/props), in the palette's colours, exported one GLB each to art/models with
art/models/manifest.json. Characters and creatures stay 2D sprites.

blender -b --python blender/models_3d.py -- [--only bookcase desk ...] [--preview out.png]

Units are world units (one 5 ft square; a 6 ft person is 1.2). Blender -Y is a piece's front (Godot +Z after the
glTF axis change), +Z is up, and the origin is the middle of its footprint on the floor, except pieces that stand
against a wall or hang on it ("against_wall", "wall", "wall_face"), whose origin is the middle of their back, on the
wall face.

Material names say how the game draws each surface (world/look/model_piece.gd):
  pal_<colour>              flat cel colour from art/palette/palette.json
  glow_<colour>             the same colour, lit from within (flames, embers)
  tex_<theme>__<surface>    a texture set from art/textures (world-mapped, like the board's floors and walls)
"""
import argparse
import json
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "art" / "models"
PALETTE = json.loads((ROOT / "art" / "palette" / "palette.json").read_text())
TEXTURES = json.loads((ROOT / "art" / "textures" / "manifest.json").read_text())

MODELS = {}


def model(id_, mount, stands_for, **extra):
    """Registers a builder: mount is free | against_wall | wall | wall_face | stairs_up | stairs_down | door."""
    def wrap(fn):
        MODELS[id_] = {"build": fn, "mount": mount, "stands_for": stands_for, **extra}
        return fn
    return wrap


# --- Materials -------------------------------------------------------------------------------------------------

def _linear(hexstr):
    h = hexstr.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c] + [1.0]


def _hex_of(name):
    kind, _, rest = name.partition("_")
    if kind in ("pal", "glow"):
        return PALETTE[rest]
    theme, _, surface = rest.partition("__")
    info = TEXTURES["themes"][theme][surface]
    return PALETTE[info["palette"][0]]


def _preview_colour(name):
    """The colour Blender shows a surface in (the game draws its own): a palette colour, or a texture's average."""
    if name.startswith("spr_"):
        return [0.5, 0.5, 0.5, 1.0]
    if not name.startswith("tex_"):
        return _linear(_hex_of(name))
    theme, _, surface = name[4:].partition("__")
    img = bpy.data.images.load(str(ROOT / TEXTURES["themes"][theme][surface]["file"]))
    px = list(img.pixels)
    n = len(px) // 4
    avg = [sum(px[i::4]) / n for i in range(3)]   # sRGB values, as stored
    bpy.data.images.remove(img)
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in avg] + [1.0]


def material(name):
    m = bpy.data.materials.get(name)
    if m is not None:
        return m
    m = bpy.data.materials.new(name)
    col = _preview_colour(name)
    m.diffuse_color = col
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = col
    bsdf.inputs["Roughness"].default_value = 0.85
    if name.startswith("glow_"):
        bsdf.inputs["Emission Color"].default_value = col
        bsdf.inputs["Emission Strength"].default_value = 4.0
    return m


# --- Geometry --------------------------------------------------------------------------------------------------

def _rot(deg):
    return Euler(tuple(math.radians(a) for a in deg), "XYZ").to_matrix().to_4x4()


class Piece:
    """One model: primitives appended into a single mesh, a material slot per surface kind."""

    def __init__(self, id_, seed=1):
        self.id = id_
        self.bm = bmesh.new()
        self.mats = []
        self.sockets = {}
        self.rng = random.Random(seed)
        self._scratch = bpy.data.meshes.new("_scratch")

    def _append(self, t, mat, smooth):
        mi = self._slot(mat)
        for f in t.faces:
            f.material_index = mi
            f.smooth = smooth
        t.to_mesh(self._scratch)
        t.free()
        self.bm.from_mesh(self._scratch)

    def _slot(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def box(self, size, at, mat, rot=(0, 0, 0), soft=0.0):
        """A box `size` (x, y, z) centred on `at`, turned by `rot` degrees; `soft` rounds its edges (cushions)."""
        t = bmesh.new()
        bmesh.ops.create_cube(t, size=1.0)
        bmesh.ops.scale(t, vec=Vector(size), verts=t.verts)
        if soft > 0.0:
            bmesh.ops.bevel(t, geom=list(t.edges), offset=min(soft, min(size) * 0.45), segments=2, affect="EDGES",
                            profile=0.6)
        bmesh.ops.transform(t, matrix=Matrix.Translation(Vector(at)) @ _rot(rot), verts=t.verts)
        self._append(t, mat, soft > 0.0)

    def cyl(self, r, h, at, mat, r2=None, segs=12, rot=(0, 0, 0), smooth=True):
        """A cylinder (or cone) standing on `at` along its local z, turned by `rot` degrees about `at`."""
        t = bmesh.new()
        bmesh.ops.create_cone(t, cap_ends=True, cap_tris=False, segments=segs, radius1=r,
                              radius2=r if r2 is None else r2, depth=h)
        bmesh.ops.translate(t, vec=Vector((0, 0, h / 2.0)), verts=t.verts)
        bmesh.ops.transform(t, matrix=Matrix.Translation(Vector(at)) @ _rot(rot), verts=t.verts)
        self._append(t, mat, smooth)

    def lathe(self, profile, at, mat, segs=12, rot=(0, 0, 0), smooth=True):
        """A turned shape (legs, finials, candlesticks): `profile` is [(radius, z), ...] from the bottom up."""
        t = bmesh.new()
        rings = []
        for r, z in profile:
            if r <= 1e-5:
                rings.append([t.verts.new((0.0, 0.0, z))])
                continue
            rings.append([t.verts.new((r * math.cos(a), r * math.sin(a), z))
                          for a in (2 * math.pi * k / segs for k in range(segs))])
        for lo, hi in zip(rings, rings[1:]):
            for k in range(segs):
                quad = [lo[k % len(lo)], lo[(k + 1) % len(lo)], hi[(k + 1) % len(hi)], hi[k % len(hi)]]
                uniq = []
                for v in quad:
                    if v not in uniq:
                        uniq.append(v)
                if len(uniq) >= 3:
                    t.faces.new(uniq)
        for ring in (rings[0], rings[-1]):
            if len(ring) > 2:
                t.faces.new(ring)
        bmesh.ops.recalc_face_normals(t, faces=t.faces)
        bmesh.ops.transform(t, matrix=Matrix.Translation(Vector(at)) @ _rot(rot), verts=t.verts)
        self._append(t, mat, smooth)

    def prism(self, poly, thick, at, mat, rot=(0, 0, 0)):
        """A flat outline `poly` [(x, z), ...] (front view) given `thick` depth along y, centred on `at`."""
        t = bmesh.new()
        front = [t.verts.new((x, -thick / 2.0, z)) for x, z in poly]
        back = [t.verts.new((x, thick / 2.0, z)) for x, z in poly]
        t.faces.new(front)
        t.faces.new(list(reversed(back)))
        n = len(poly)
        for k in range(n):
            t.faces.new([front[k], front[(k + 1) % n], back[(k + 1) % n], back[k]])
        bmesh.ops.recalc_face_normals(t, faces=t.faces)
        bmesh.ops.transform(t, matrix=Matrix.Translation(Vector(at)) @ _rot(rot), verts=t.verts)
        self._append(t, mat, False)

    def tube(self, points, radius, mat, segs=6, smooth=True, radii=None):
        """A round bar swept along `points` (iron scrolls, handrails); `radii` tapers it (a branch, a thorn)."""
        t = bmesh.new()
        pts = [Vector(p) for p in points]
        rings = []
        for i, p in enumerate(pts):
            radius_i = radii[i] if radii else radius
            tan = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
            side = tan.cross(Vector((0, 0, 1)))
            if side.length < 1e-4:
                side = tan.cross(Vector((1, 0, 0)))
            side.normalize()
            up = side.cross(tan).normalized()
            rings.append([t.verts.new(p + (side * math.cos(a) + up * math.sin(a)) * max(radius_i, 0.0015))
                          for a in (2 * math.pi * k / segs for k in range(segs))])
        for lo, hi in zip(rings, rings[1:]):
            for k in range(segs):
                t.faces.new([lo[k], lo[(k + 1) % segs], hi[(k + 1) % segs], hi[k]])
        t.faces.new(rings[0])
        t.faces.new(rings[-1])
        bmesh.ops.recalc_face_normals(t, faces=t.faces)
        self._append(t, mat, smooth)

    def _append_faces(self, t, mat_of_face, smooth=False):
        """Appends bmesh `t` with each face's material from mat_of_face(face) (a rock's mossy top)."""
        for f in t.faces:
            f.material_index = self._slot(mat_of_face(f))
            f.smooth = smooth
        t.to_mesh(self._scratch)
        t.free()
        self.bm.from_mesh(self._scratch)

    def rock(self, at, size, mat, top=None, rough=0.18, subdiv=1, rot_z=0.0, bury=0.08, smooth=False, top_z=0.72, top_p=0.85):
        """A faceted stone: a jittered icosphere `size` (x, y, z) sitting on `at` (sunk `bury` of its height), its
        upward faces in `top` (moss, snow) where given."""
        t = bmesh.new()
        bmesh.ops.create_icosphere(t, subdivisions=subdiv, radius=1.0)
        rng = self.rng
        for v in t.verts:
            v.co = v.co.normalized() * (1.0 + rng.uniform(-rough, rough))
        bmesh.ops.scale(t, vec=Vector((size[0] / 2, size[1] / 2, size[2] / 2)), verts=t.verts)
        zmin = min(v.co.z for v in t.verts)
        bmesh.ops.translate(t, vec=Vector((0, 0, -zmin - bury * size[2])), verts=t.verts)
        bmesh.ops.transform(t, matrix=Matrix.Translation(Vector(at)) @ _rot((0, 0, rot_z)), verts=t.verts)
        t.normal_update()
        self._append_faces(t, lambda f: top if top and f.normal.z > top_z and rng.random() < top_p else mat, smooth)

    def tier(self, at, r, h, mat, under, points=9, jag=0.72, droop=0.06, twist=0.0):
        """One tier of a pine: a jagged star of branches drooping from a point, `r` across and `h` tall, `under` below."""
        t = bmesh.new()
        x, y, z = at
        apex = t.verts.new((x, y, z + h))
        rim = []
        n = points * 2
        for k in range(n):
            a = 2 * math.pi * k / n + twist
            rr = r * (1.0 if k % 2 == 0 else jag) * self.rng.uniform(0.92, 1.06)
            rim.append(t.verts.new((x + rr * math.cos(a), y + rr * math.sin(a), z - (droop if k % 2 == 0 else 0.0))))
        hub = t.verts.new((x, y, z + h * 0.25))
        tops, bottoms = [], []
        for k in range(n):
            tops.append(t.faces.new([rim[k], rim[(k + 1) % n], apex]))
            bottoms.append(t.faces.new([rim[(k + 1) % n], rim[k], hub]))
        bmesh.ops.recalc_face_normals(t, faces=t.faces)
        under_set = set(bottoms)
        self._append_faces(t, lambda f: under if f in under_set else mat, smooth=True)

    def socket(self, name, at):
        self.sockets[name] = at

    def finish(self):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-6)
        me = bpy.data.meshes.new(self.id)
        self.bm.to_mesh(me)
        self.bm.free()
        for name in self.mats:
            me.materials.append(material(name))
        ob = bpy.data.objects.new(self.id, me)
        bpy.context.scene.collection.objects.link(ob)
        bpy.data.meshes.remove(self._scratch)
        return ob


def curve(p0, p1, p2, n=8):
    """Points along a quadratic Bezier."""
    out = []
    for i in range(n + 1):
        s = i / n
        out.append(tuple((1 - s) ** 2 * a + 2 * (1 - s) * s * b + s * s * c for a, b, c in zip(p0, p1, p2)))
    return out


def arch(x0, x1, z0, rise, n=8, pointed=True):
    """The top edge of a gothic arch from (x0, z0) to (x1, z0): two arcs meeting in a point (or one round arch)."""
    out = []
    half = (x1 - x0) / 2.0
    for i in range(n + 1):
        s = i / n
        x = x0 + s * (x1 - x0)
        u = abs(x - (x0 + half)) / half
        z = z0 + rise * (math.sqrt(max(0.0, 1 - u * u)) if not pointed else (1 - u) ** 0.65)
        out.append((x, z))
    return out


# --- Library pieces --------------------------------------------------------------------------------------------

BOOKS = [("pal_blood", 3), ("pal_blood_deep", 2), ("pal_umber", 3), ("pal_walnut", 2), ("pal_leather", 2),
         ("pal_rust", 2), ("pal_moon_blue", 2), ("pal_night", 1), ("pal_bog", 2), ("pal_bone_dark", 2),
         ("pal_parchment", 1), ("pal_ash_violet", 1), ("pal_tan", 1)]


def _book_colour(rng):
    total = sum(w for _, w in BOOKS)
    r = rng.uniform(0, total)
    for c, w in BOOKS:
        r -= w
        if r <= 0:
            return c
    return BOOKS[0][0]


def shelf_of_books(p, x0, x1, zf, hmax, yback, dmax):
    """Fills one shelf from x0 to x1: upright books of mixed size, the odd gap, a flat stack, one leaning at the end."""
    rng = p.rng
    x = x0 + rng.uniform(0.0, 0.02)
    while x < x1 - 0.022:
        r = rng.random()
        room = x1 - x
        if r < 0.07:
            x += rng.uniform(0.04, 0.09)
            continue
        if r < 0.14 and room > 0.2:
            bw = rng.uniform(0.12, 0.16)
            z = zf
            for _ in range(rng.randint(2, 4)):
                tk = rng.uniform(0.022, 0.036)
                d = rng.uniform(0.11, 0.15)
                p.box((bw, d, tk), (x + bw / 2 + rng.uniform(-0.008, 0.008), yback - d / 2 - 0.01, z + tk / 2),
                      _book_colour(rng), rot=(0, 0, rng.uniform(-5, 5)))
                z += tk
            x += bw + 0.012
            continue
        w = rng.uniform(0.022, 0.048)
        h = rng.uniform(0.62, 0.98) * hmax
        d = rng.uniform(dmax - 0.08, dmax)
        col = _book_colour(rng)
        if room < 0.16 and r > 0.6:
            lean = rng.uniform(14, 24)
            a = math.radians(lean)
            px = x + h * math.sin(a)
            centre = (px + w / 2 * math.cos(a) - h / 2 * math.sin(a), yback - d / 2, zf + w / 2 * math.sin(a) + h / 2 * math.cos(a))
            if px + w * math.cos(a) < x1:
                p.box((w, d, h), centre, col, rot=(0, -lean, 0))
            break
        p.box((w, d, h), (x + w / 2, yback - d / 2, zf + h / 2), col)
        if w > 0.03 and rng.random() < 0.55:
            for f in (0.18, 0.8):
                p.box((w * 0.9, 0.004, 0.012), (x + w / 2, yback - d - 0.001, zf + h * f), "pal_tan")
        x += w + rng.uniform(0.0, 0.004)


@model("bookcase", "against_wall", ["book_shelf", "book_shelf_front", "bookshelf"], size_ft=7)
def bookcase(p):
    W, D, H = 0.9, 0.3, 1.4
    wood, dark, edge = "pal_umber", "pal_peat", "pal_walnut"
    yc = -D / 2.0   # the back is on the wall at y = 0
    p.box((W - 0.03, D - 0.03, 0.07), (0, yc + 0.015, 0.035), dark)                       # plinth
    for s in (-1, 1):
        p.box((0.045, D, H - 0.07), (s * (W / 2 - 0.0225), yc, (H - 0.07) / 2), wood)        # sides
        p.box((0.05, 0.012, H - 0.07), (s * (W / 2 - 0.025), yc - D / 2 - 0.004, (H - 0.07) / 2), edge)
    p.box((W - 0.09, 0.02, H - 0.17), (0, -0.01, 0.07 + (H - 0.17) / 2), dark)              # back
    p.box((W, 0.012, 0.07), (0, yc - D / 2 - 0.004, 0.035), edge)                           # bottom rail
    p.box((W - 0.09, D - 0.02, 0.03), (0, yc - 0.01, 0.085), wood)                           # bottom shelf
    p.box((W, D, 0.03), (0, yc, H - 0.085), wood)                                            # top
    p.box((W - 0.09, 0.02, 0.07), (0, yc - D / 2 + 0.01, H - 0.135), wood)                   # frieze
    p.box((W + 0.04, D + 0.02, 0.03), (0, yc - 0.01, H - 0.055), wood)                       # cornice
    p.box((W + 0.08, D + 0.04, 0.03), (0, yc - 0.02, H - 0.025), edge)
    z0, ztop, rows = 0.1, H - 0.17, 5
    pitch = (ztop - z0) / rows
    for i in range(rows):
        zf = z0 + i * pitch
        if i > 0:
            p.box((W - 0.09, D - 0.03, 0.022), (0, yc - 0.005, zf - 0.011), wood)
            p.box((W - 0.09, 0.014, 0.026), (0, yc - D / 2 + 0.012, zf - 0.013), edge)
        shelf_of_books(p, -W / 2 + 0.05, W / 2 - 0.05, zf, pitch - 0.035, -0.022, 0.25)


@model("desk", "against_wall", ["desk", "desk_front"], container=True)
def desk(p):
    W, D, H = 1.0, 0.55, 0.52
    top, trim, body, face, brass = "tex_interior__wood_planks", "pal_blood", "pal_ash_violet", "pal_grave", "pal_tan"
    yc = -D / 2.0 - 0.04   # a hand's breadth out from the wall
    p.box((W, D, 0.035), (0, yc, H - 0.0175), top)
    p.box((W - 0.02, D - 0.02, 0.02), (0, yc, H - 0.045), trim)
    pw = 0.3
    front = yc - (D - 0.06) / 2
    for s in (-1, 1):
        cx = s * (W / 2 - pw / 2 - 0.015)
        p.box((pw, D - 0.06, H - 0.11), (cx, yc, 0.05 + (H - 0.11) / 2), body)
        p.box((pw + 0.02, D - 0.04, 0.05), (cx, yc, 0.025), trim)
        for k in (-1, 1):
            p.box((0.025, 0.01, H - 0.11), (cx + k * (pw / 2 - 0.0125), front - 0.004, 0.05 + (H - 0.11) / 2), trim)
        if s > 0:
            for j in range(3):
                dz = 0.06 + j * 0.122
                p.box((pw - 0.07, 0.012, 0.108), (cx, front - 0.007, dz + 0.054), face)
                p.box((0.05, 0.012, 0.012), (cx, front - 0.016, dz + 0.07), brass)
        else:
            p.box((pw - 0.07, 0.012, H - 0.14), (cx, front - 0.007, 0.06 + (H - 0.14) / 2), face)
            p.box((pw - 0.13, 0.008, H - 0.22), (cx, front - 0.016, 0.06 + (H - 0.14) / 2), body)
            p.cyl(0.011, 0.014, (cx + pw / 2 - 0.06, front - 0.012, 0.26), brass, rot=(90, 0, 0), segs=8)
    mid = W - 2 * pw - 0.06
    p.box((mid, 0.03, 0.075), (0, front + 0.012, H - 0.09), body)
    p.box((mid - 0.03, 0.01, 0.055), (0, front - 0.006, H - 0.09), face)
    p.box((0.06, 0.012, 0.012), (0, front - 0.014, H - 0.09), brass)
    p.box((mid + 0.02, 0.02, H - 0.2), (0, yc + D / 2 - 0.06, 0.1 + (H - 0.2) / 2), body)
    # On the top: letters, an inkwell and quill, a candle, a closed book (the 2D desk's things).
    rng = p.rng
    for k, col in enumerate(["pal_vellum", "pal_parchment", "pal_ivory", "pal_vellum"]):
        p.box((0.15, 0.2, 0.003), (rng.uniform(-0.28, 0.05), yc + rng.uniform(-0.1, 0.06), H + 0.0016 + k * 0.0026),
              col, rot=(0, 0, rng.uniform(-35, 35)))
    ink = (0.24, yc + 0.08, H)
    p.lathe([(0.0, 0.0), (0.038, 0.0), (0.04, 0.012), (0.036, 0.04), (0.018, 0.05), (0.014, 0.056), (0.017, 0.064),
             (0.0, 0.064)], ink, "pal_void")
    feather = [(0.0, 0.0), (0.004, 0.06), (0.022, 0.12), (0.022, 0.17), (0.01, 0.21), (0.0, 0.215),
               (-0.005, 0.15), (-0.004, 0.07)]
    p.prism(feather, 0.004, (ink[0], ink[1], H + 0.04), "pal_ivory", rot=(-18, 0, 25))
    cand = (-0.36, yc + 0.13, H)
    p.lathe([(0.0, 0.0), (0.05, 0.0), (0.055, 0.008), (0.046, 0.014), (0.012, 0.018), (0.012, 0.04), (0.02, 0.044),
             (0.0, 0.046)], cand, brass)
    p.cyl(0.017, 0.085, (cand[0], cand[1], H + 0.044), "pal_ivory", segs=10)
    p.lathe([(0.0, 0.0), (0.009, 0.008), (0.011, 0.02), (0.006, 0.034), (0.0, 0.044)], (cand[0], cand[1], H + 0.132),
            "glow_flame", segs=8)
    p.socket("candle", (cand[0], cand[1], H + 0.15))
    bk = (-0.04, yc + 0.12)
    p.box((0.15, 0.205, 0.026), (bk[0], bk[1], H + 0.017), "pal_vellum", rot=(0, 0, 14))
    for dz in (0.003, 0.031):
        p.box((0.16, 0.22, 0.006), (bk[0], bk[1], H + dz), trim, rot=(0, 0, 14))


def _chair_frame(p, x, y, face_deg, wood, seat_col, back_col, seat=0.33, width=0.42, depth=0.4, back_top=0.92,
                 crest=None, turned=True):
    """A straight-backed chair at (x, y) facing `face_deg` (0 = front, -y)."""
    m = Matrix.Translation((x, y, 0)) @ Matrix.Rotation(math.radians(face_deg), 4, "Z")

    def at(lx, ly, lz):
        return tuple(m @ Vector((lx, ly, lz)))
    hw, hd = width / 2, depth / 2
    for s in (-1, 1):
        if turned:
            p.lathe([(0.02, 0.0), (0.027, 0.015), (0.027, 0.03), (0.016, 0.06), (0.024, 0.11), (0.027, 0.15),
                     (0.018, 0.2), (0.015, seat - 0.12), (0.023, seat - 0.08), (0.026, seat - 0.05), (0.026, seat - 0.04)],
                    at(s * (hw - 0.03), -hd + 0.03, 0), wood, segs=10)
        else:
            p.box((0.035, 0.035, seat - 0.04), at(s * (hw - 0.03), -hd + 0.03, (seat - 0.04) / 2), wood, rot=(0, 0, face_deg))
        p.box((0.04, 0.04, back_top), at(s * (hw - 0.03), hd - 0.03, back_top / 2), wood, rot=(0, 0, face_deg))
        p.lathe([(0.022, 0.0), (0.026, 0.01), (0.012, 0.03), (0.018, 0.045), (0.0, 0.08)],
                at(s * (hw - 0.03), hd - 0.03, back_top), wood, segs=8)
        p.box((0.022, depth - 0.06, 0.022), at(s * (hw - 0.03), 0, 0.08), wood, rot=(0, 0, face_deg))
    p.box((width - 0.06, 0.022, 0.022), at(0, -hd + 0.03, 0.08), wood, rot=(0, 0, face_deg))
    p.box((width, depth, 0.06), at(0, 0, seat - 0.07), wood, rot=(0, 0, face_deg))
    apron = [(-hw, 0.0), (hw, 0.0), (hw, -0.05), (hw * 0.5, -0.035), (0.0, -0.06), (-hw * 0.5, -0.035), (-hw, -0.05)]
    p.prism(apron, 0.02, at(0, -hd - 0.008, seat - 0.04), wood, rot=(0, 0, face_deg))
    p.box((width - 0.03, depth - 0.03, 0.06), at(0, -0.01, seat - 0.02), seat_col, rot=(0, 0, face_deg), soft=0.014)
    p.box((width - 0.06, 0.035, 0.05), at(0, hd - 0.03, seat + 0.06), wood, rot=(0, 0, face_deg))
    ptop = back_top - 0.1
    p.box((width - 0.1, 0.03, ptop - seat - 0.09), at(0, hd - 0.035, seat + 0.09 + (ptop - seat - 0.09) / 2), back_col,
          rot=(0, 0, face_deg), soft=0.01)
    poly = crest or ([(-hw + 0.03, 0.0)] + arch(-hw + 0.03, hw - 0.03, 0.02, 0.1, n=10) + [(hw - 0.03, 0.0)])
    p.prism(poly, 0.036, at(0, hd - 0.03, ptop - 0.03), "pal_peat", rot=(0, 0, face_deg))


@model("chair_high", "free", ["chair_high"])
def chair_high(p):
    """The 2D high-backed chair: dark carved wood, red velvet seat and back, a crest of scrolls with a finial."""
    hw = 0.21
    crest = [(-hw + 0.03, 0.0), (hw - 0.03, 0.0), (hw - 0.03, 0.05), (0.15, 0.1), (0.12, 0.08), (0.08, 0.1),
             (0.04, 0.15), (0.0, 0.17), (-0.04, 0.15), (-0.08, 0.1), (-0.12, 0.08), (-0.15, 0.1), (-hw + 0.03, 0.05)]
    _chair_frame(p, 0, 0, 0, "pal_umber", "pal_blood", "pal_blood", crest=crest)
    p.lathe([(0.016, 0.0), (0.022, 0.012), (0.01, 0.03), (0.016, 0.045), (0.0, 0.075)], (0, 0.2 - 0.03, 0.92 - 0.13 + 0.17),
            "pal_peat", segs=8)
    for s in (-1, 1):
        p.prism([(0.0, 0.0), (0.03, 0.06), (0.025, 0.2), (0.0, 0.3), (-0.01, 0.15)], 0.02, (s * 0.165, 0.14, 0.42),
                "pal_peat", rot=(0, 0, 0 if s > 0 else 180))


@model("armchair", "free", ["armchair"])
def armchair(p):
    """The 2D red wingback: crimson velvet over a blood-red shell, rolled arms, cabriole legs."""
    W, D, L = 0.56, 0.54, 0.19   # L: the legs' height
    shell, cushion, wood = "pal_blood", "pal_crimson", "pal_umber"
    for sx in (-1, 1):
        for sy in (-1, 1):
            # Cabriole legs: a knee out at the corner, an ankle in, a small foot out again.
            x, y = sx * (W / 2 - 0.05), sy * (D / 2 - 0.05)
            ox, oy = sx * 0.025, sy * 0.025
            p.tube([(x, y, L), (x + ox, y + oy, L - 0.04), (x + ox * 0.4, y + oy * 0.4, L * 0.5), (x - ox * 0.3, y - oy * 0.3, 0.04),
                    (x + ox * 0.3, y + oy * 0.3, 0.008)], 0.019, wood, segs=8)
            p.cyl(0.022, 0.012, (x + ox * 0.3, y + oy * 0.3, 0.0), wood, segs=8)
    p.box((W + 0.01, D + 0.01, 0.035), (0, 0, L + 0.0175), wood)
    p.prism([(-W / 2, 0.0), (W / 2, 0.0), (W / 2, -0.045), (W * 0.2, -0.03), (0, -0.055), (-W * 0.2, -0.03),
             (-W / 2, -0.045)], 0.02, (0, -D / 2 - 0.006, L + 0.03), wood)
    p.box((W, D, 0.12), (0, 0, L + 0.095), shell, soft=0.02)
    p.box((W - 0.15, D - 0.12, 0.07), (0, -0.04, L + 0.185), cushion, soft=0.025)
    back = [(-W / 2 + 0.02, 0.0), (W / 2 - 0.02, 0.0)] + list(reversed(
        [(x, z) for x, z in arch(-W / 2 + 0.02, W / 2 - 0.02, 0.46, 0.08, n=10, pointed=False)]))
    p.prism(back, 0.13, (0, D / 2 - 0.075, L + 0.15), shell)
    p.box((W - 0.16, 0.06, 0.38), (0, D / 2 - 0.16, L + 0.38), cushion, soft=0.025, rot=(-6, 0, 0))
    wing = [(D / 2 - 0.02, 0.0), (D / 2 - 0.02, 0.52), (D / 2 - 0.14, 0.56), (0.02, 0.47), (-0.05, 0.36),
            (-0.03, 0.24), (-0.06, 0.19), (-0.12, 0.19), (-0.12, 0.0)]
    for s in (-1, 1):
        p.prism(wing, 0.06, (s * (W / 2 - 0.03), 0, L + 0.15), shell, rot=(0, 0, 90))
        p.box((0.09, D - 0.06, 0.15), (s * (W / 2 - 0.045), -0.01, L + 0.225), shell, soft=0.02)
        p.cyl(0.048, D - 0.08, (s * (W / 2 - 0.045), -D / 2 + 0.02, L + 0.3), shell, rot=(-90, 0, 0), segs=12)
        p.cyl(0.034, 0.012, (s * (W / 2 - 0.045), -D / 2 + 0.012, L + 0.3), wood, rot=(90, 0, 0), segs=12)


@model("settee", "against_wall", ["settee"])
def settee(p):
    W, D = 0.98, 0.46
    wood, carve, cushion = "pal_umber", "pal_peat", "pal_leather"
    yc = -D / 2 - 0.03
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.lathe([(0.016, 0.0), (0.024, 0.012), (0.018, 0.045), (0.026, 0.1), (0.03, 0.14)],
                    (sx * (W / 2 - 0.04), yc + sy * (D / 2 - 0.04), 0), wood, segs=10)
    p.box((W, D, 0.08), (0, yc, 0.18), wood)
    p.prism([(-W / 2, 0.0), (W / 2, 0.0), (W / 2, -0.06), (W * 0.3, -0.04), (W * 0.15, -0.065), (0, -0.04),
             (-W * 0.15, -0.065), (-W * 0.3, -0.04), (-W / 2, -0.06)], 0.02, (0, yc - D / 2 - 0.008, 0.22), carve)
    cw = (W - 0.16) / 2 - 0.01
    for s in (-1, 1):
        cx = s * (cw / 2 + 0.005)
        p.box((cw, D - 0.1, 0.08), (cx, yc - 0.03, 0.26), cushion, soft=0.025)
        p.box((cw - 0.03, 0.012, 0.012), (cx, yc - 0.03 - (D - 0.1) / 2 + 0.004, 0.292), wood)   # piping
        p.box((cw, 0.08, 0.3), (cx, yc + D / 2 - 0.1, 0.44), cushion, soft=0.025, rot=(-8, 0, 0))
        for dz in (-0.07, 0.07):                                                                 # buttoned back
            for dx in (-cw / 4, 0.0, cw / 4):
                y = yc + D / 2 - 0.1 - 0.04 * math.cos(math.radians(8)) + dz * math.sin(math.radians(8))
                p.box((0.02, 0.012, 0.02), (cx + dx, y - 0.002, 0.44 + dz), wood, rot=(-8, 0, 0))
    for s in (-1, 1):
        p.box((0.05, 0.05, 0.62), (s * (W / 2 - 0.03), yc + D / 2 - 0.03, 0.14 + 0.31), wood)
    p.box((W - 0.1, 0.03, 0.42), (0, yc + D / 2 - 0.03, 0.22 + 0.21), carve)
    for k in (-1, 0, 1):
        lancet = [(-0.09, 0.0), (0.09, 0.0)] + list(reversed(arch(-0.09, 0.09, 0.22, 0.1, n=8)))
        p.prism(lancet, 0.012, (k * 0.27, yc + D / 2 - 0.009, 0.28), wood)
    crest = [(-W / 2 + 0.02, 0.0), (W / 2 - 0.02, 0.0), (W / 2 - 0.02, 0.06), (W * 0.3, 0.085), (W * 0.12, 0.1),
             (0.05, 0.16), (0.0, 0.18), (-0.05, 0.16), (-W * 0.12, 0.1), (-W * 0.3, 0.085), (-W / 2 + 0.02, 0.06)]
    p.prism(crest, 0.04, (0, yc + D / 2 - 0.03, 0.62), wood)
    for s in (-1, 1):
        x = s * (W / 2 - 0.03)
        p.box((0.045, 0.045, 0.25), (x, yc - D / 2 + 0.04, 0.22 + 0.125), wood)
        p.box((0.06, D - 0.02, 0.04), (x, yc - 0.01, 0.47), wood)
        p.cyl(0.03, 0.05, (x, yc - D / 2 + 0.01, 0.46), wood, rot=(90, 0, 0), segs=10)
        side = [(-D / 2 + 0.06, 0.0), (D / 2 - 0.06, 0.0), (D / 2 - 0.06, 0.2), (0.0, 0.16), (-D / 2 + 0.06, 0.2)]
        p.prism(side, 0.02, (x, yc, 0.22), carve, rot=(0, 0, 90))


@model("table", "free", ["table", "table_back"])
def table(p):
    W, D, H = 0.95, 0.6, 0.5
    rng = p.rng
    for k, col in enumerate(["tex_interior__wood_planks"] * 3):
        p.box((W + rng.uniform(-0.01, 0.01), D / 3 - 0.008, 0.045), (rng.uniform(-0.006, 0.006), (k - 1) * D / 3,
              H - 0.0225 + rng.uniform(-0.003, 0.003)), col, rot=(0, 0, rng.uniform(-0.6, 0.6)))
    for s in (-1, 1):
        p.box((W - 0.16, 0.03, 0.08), (0, s * (D / 2 - 0.07), H - 0.085), "pal_umber")
        p.box((0.03, D - 0.16, 0.08), (s * (W / 2 - 0.08), 0, H - 0.085), "pal_umber")
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((0.075, 0.075, H - 0.045), (sx * (W / 2 - 0.09), sy * (D / 2 - 0.08), (H - 0.045) / 2), "pal_walnut")
        p.box((0.035, D - 0.2, 0.04), (sx * (W / 2 - 0.09), 0, 0.1), "pal_umber")
    p.box((W - 0.2, 0.035, 0.04), (0, 0, 0.1), "pal_umber")


@model("table_chairs", "free", ["table_chairs", "table_chairs_back"])
def table_chairs(p):
    H = 0.45
    p.cyl(0.24, 0.035, (0, 0, H - 0.035), "pal_rust", segs=20, smooth=False)
    p.cyl(0.23, 0.025, (0, 0, H - 0.06), "pal_umber", segs=20, smooth=False)
    p.lathe([(0.05, 0.06), (0.03, 0.09), (0.024, 0.16), (0.035, 0.2), (0.022, 0.24), (0.02, 0.36), (0.04, 0.39),
             (0.05, H - 0.06), (0.0, H - 0.06)], (0, 0, 0), "pal_peat", segs=12)
    for k in range(3):
        a = math.radians(90 + k * 120)
        p.tube([(0.03 * math.cos(a), 0.03 * math.sin(a), 0.09), (0.12 * math.cos(a), 0.12 * math.sin(a), 0.05),
                (0.17 * math.cos(a), 0.17 * math.sin(a), 0.015)], 0.02, "pal_peat")
    p.lathe([(0.0, 0.0), (0.045, 0.0), (0.05, 0.008), (0.04, 0.013), (0.012, 0.017), (0.012, 0.036), (0.018, 0.04),
             (0.0, 0.042)], (0, -0.02, H), "pal_pewter")
    p.cyl(0.017, 0.09, (0, -0.02, H + 0.04), "pal_ivory", segs=10)
    p.lathe([(0.0, 0.0), (0.009, 0.008), (0.011, 0.02), (0.006, 0.034), (0.0, 0.044)], (0, -0.02, H + 0.133),
            "glow_flame", segs=8)
    p.socket("candle", (0, -0.02, H + 0.15))
    lancet = [(-0.13, 0.0), (0.13, 0.0)] + list(reversed(arch(-0.13, 0.13, 0.42, 0.2, n=10)))
    inner = [(-0.09, 0.0), (0.09, 0.0)] + list(reversed(arch(-0.09, 0.09, 0.32, 0.15, n=10)))
    for s in (-1, 1):
        face = -90 * s   # each chair turns to the table
        _chair_frame(p, s * 0.36, 0.0, face, "pal_ash_violet", "pal_bone_dark", "pal_bone_dark", seat=0.3, width=0.3,
                     depth=0.28, back_top=0.62, crest=lancet, turned=False)
        m = Matrix.Translation((s * 0.36, 0, 0)) @ Matrix.Rotation(math.radians(face), 4, "Z")
        p.prism(inner, 0.012, tuple(m @ Vector((0, 0.14 - 0.03 - 0.03, 0.39))), "pal_bone_dark", rot=(0, 0, face))


@model("candelabra", "free", ["candelabra"])
def candelabra(p):
    """Wrought iron, five candles in a V like the 2D candelabra: a tripod of scrolled feet, a knopped shaft and two
    pairs of curling arms in the front plane."""
    iron = "pal_ink"
    for k in range(3):
        a = math.radians(90 + k * 120)
        c, s = math.cos(a), math.sin(a)
        p.tube([(0.02 * c, 0.02 * s, 0.16), (0.11 * c, 0.11 * s, 0.09), (0.18 * c, 0.18 * s, 0.03), (0.22 * c, 0.22 * s, 0.05),
                (0.21 * c, 0.21 * s, 0.085), (0.19 * c, 0.19 * s, 0.07)], 0.018, iron)
        p.cyl(0.03, 0.016, (0.18 * c, 0.18 * s, 0.0), iron, segs=8)
    p.lathe([(0.05, 0.12), (0.06, 0.15), (0.026, 0.2), (0.02, 0.42), (0.04, 0.44), (0.02, 0.47), (0.018, 0.64),
             (0.04, 0.66), (0.018, 0.69), (0.018, 0.9), (0.045, 0.93), (0.05, 0.95), (0.0, 0.95)], (0, 0, 0), iron, segs=10)
    for s in (-1, 1):
        p.tube(curve((0.0, 0.0, 0.3), (s * 0.09, 0.0, 0.26), (s * 0.07, 0.0, 0.36), n=8), 0.012, iron)
    cups = [((0, 0, 0.95), 0.14)]
    for s in (-1, 1):
        for r, zb, zt, h in ((0.15, 0.7, 0.86, 0.12), (0.28, 0.6, 0.76, 0.1)):
            p.tube(curve((0.0, 0.0, zb), (s * r * 0.95, 0.0, zb - 0.09), (s * r, 0.0, zt - 0.02), n=12), 0.014, iron)
            p.tube(curve((s * r * 0.55, 0.0, zb - 0.055), (s * r * 0.5, 0.0, zb + 0.03), (s * r * 0.3, 0.0, zb + 0.01), n=6),
                   0.009, iron)
            p.lathe([(0.0, 0.0), (0.05, 0.0), (0.056, 0.012), (0.02, 0.016), (0.02, 0.034), (0.0, 0.034)],
                    (s * r, 0.0, zt - 0.03), iron, segs=10)
            cups.append(((s * r, 0.0, zt), h))
    for i, (at, h) in enumerate(cups):
        x, y, z = at
        p.cyl(0.021, h, (x, y, z), "pal_ivory", segs=10)
        p.box((0.01, 0.01, 0.035), (x + 0.016, y - 0.01, z + h - 0.022), "pal_vellum")
        p.lathe([(0.0, 0.0), (0.012, 0.01), (0.014, 0.024), (0.008, 0.04), (0.0, 0.055)], (x, y, z + h + 0.004),
                "glow_flame", segs=8)
        p.socket("candle_%d" % i, (x, y, z + h + 0.025))


def _lay_stones(p, x0, x1, z0, z1, front, stones, hole=None, side=None):
    """Courses of stone blocks on a face at y = `front` from x0 to x1 and z0 to z1, each block a little proud and
    askew; `hole` (x0, x1, z_top) is an opening the courses stop at, `side` lays the two side faces too (at x = +-side)."""
    rng = p.rng

    def block(size, at):
        p.box(size, at, rng.choice(stones), rot=(rng.uniform(-2, 2), rng.uniform(-2, 2), rng.uniform(-1.5, 1.5)))
    z = z0
    while z < z1 - 0.04:
        rh = min(rng.uniform(0.09, 0.13), z1 - z)
        segs = [(x0, x1)]
        if hole and z < hole[2]:
            segs = [(x0, hole[0] - 0.005), (hole[1] + 0.005, x1)]
        for a, b in segs:
            x = a
            while x < b - 0.03:
                ln = min(rng.uniform(0.1, 0.22), b - x)
                dep = rng.uniform(0.028, 0.045)
                block((ln - 0.012, dep, rh - 0.012), (x + ln / 2, front - dep / 2 + 0.012, z + rh / 2))
                x += ln
        if side is not None:
            for sgn in (-1, 1):
                y = 0.0
                while y > front + 0.03:
                    ln = min(rng.uniform(0.1, 0.18), y - front)
                    dep = rng.uniform(0.02, 0.035)
                    block((dep, ln - 0.012, rh - 0.012), (sgn * (side + dep / 2 - 0.01), y - ln / 2, z + rh / 2))
                    y -= ln
        z += rh


def _fire(p, ow, front):
    """Andirons, three logs and glowing embers on the hearth floor of a firebox `ow` wide; the 2D flame goes at the
    `flame` socket."""
    rng = p.rng
    for s in (-1, 1):
        p.box((0.025, 0.16, 0.025), (s * 0.13, front / 2 - 0.02, 0.05), "pal_void")
        p.cyl(0.018, 0.05, (s * 0.13, front + 0.08, 0.03), "pal_void", segs=8)
    for ln, at, rz in [(0.34, (0, -0.13, 0.075), 6), (0.3, (0.02, -0.09, 0.11), -12), (0.24, (-0.04, -0.17, 0.12), 25)]:
        ln = min(ln, ow - 0.08)
        p.cyl(0.032, ln, (at[0] - ln / 2 * math.cos(math.radians(rz)), at[1] - ln / 2 * math.sin(math.radians(rz)), at[2]),
              "pal_umber", rot=(0, 90, rz), segs=8)
    for _ in range(14):
        sz = rng.uniform(0.025, 0.05)
        p.box((sz, sz, sz * 0.6), (rng.uniform(-ow / 2 + 0.07, ow / 2 - 0.07), rng.uniform(-0.2, -0.05), 0.035),
              rng.choice(["glow_ember", "glow_candle", "glow_ember"]), rot=(0, 0, rng.uniform(0, 90)))
    p.socket("flame", (0.0, -0.12, 0.07))


def _stone_fireplace(p, W, D, HB, ow, oh, stones, mortar, lintel):
    """A stone surround HB high with a firebox `ow` x `oh`, a lintel and keystone over it, a hearth slab and a fire."""
    front = -(D - 0.03)
    pier = (W - ow) / 2
    for s in (-1, 1):
        p.box((pier, D - 0.03, HB), (s * (ow / 2 + pier / 2), front / 2, HB / 2), mortar)
    p.box((ow, D - 0.03, HB - oh), (0, front / 2, oh + (HB - oh) / 2), mortar)
    p.box((ow, 0.03, oh), (0, -0.015, oh / 2), "pal_ink")
    _lay_stones(p, -W / 2, W / 2, 0.0, HB, front, stones, hole=(-ow / 2, ow / 2, oh + 0.1), side=W / 2)
    p.box((ow + 0.16, 0.05, 0.1), (0, front - 0.012, oh + 0.05), lintel)
    p.prism([(-0.06, 0.0), (0.06, 0.0), (0.045, 0.13), (-0.045, 0.13)], 0.06, (0, front - 0.02, oh - 0.005), stones[0])
    p.box((W + 0.04, 0.22, 0.03), (0, front - 0.11, 0.015), lintel)
    p.box((ow, -front, 0.03), (0, front / 2, 0.015), mortar)
    _fire(p, ow, front)
    return front


@model("fireplace", "wall", ["fireplace"])
def fireplace(p):
    """The 2D stone fireplace: grey and violet stones, a wooden mantel on brackets."""
    W, D, HB = 0.96, 0.3, 0.86
    front = _stone_fireplace(p, W, D, HB, 0.5, 0.44, ["pal_stone", "pal_stone", "pal_slate", "pal_stone", "pal_ash_violet",
                                                      "pal_slate"], "pal_stone_deep", "pal_slate")
    p.box((W + 0.04, D + 0.02, 0.04), (0, -(D + 0.02) / 2, HB + 0.02), "pal_peat")
    p.box((W + 0.06, D + 0.07, 0.045), (0, -(D + 0.07) / 2, HB + 0.0625), "pal_umber")
    for s in (-1, 1):
        p.prism([(0.0, 0.0), (0.0, 0.1), (-0.07, 0.1), (-0.07, 0.07), (-0.02, 0.0)], 0.05,
                (s * (W / 2 - 0.03), front, HB - 0.1), "pal_peat", rot=(0, 0, 90))


@model("fireplace_windmill", "wall", ["fireplace_windmill"],
       decals=[{"art": "fireplace_windmill", "region": [67, 25, 141, 83], "socket": "picture", "width": 0.56}])
def fireplace_windmill(p):
    """The library hearth (2D fireplace_windmill): near-black stone, a stone mantel, and above it on the chimney
    breast the moonlit windmill painting, its canvas cut from the 2D art, in a carved frame."""
    W, D, HB = 0.96, 0.28, 0.56
    dark = ["pal_grave", "pal_ash_violet", "pal_stone_deep", "pal_grave", "pal_stone"]
    _stone_fireplace(p, W, D, HB, 0.5, 0.34, dark, "pal_void", "pal_stone_deep")
    p.box((W + 0.04, D + 0.03, 0.04), (0, -(D + 0.03) / 2, HB + 0.02), "pal_grave")
    p.box((W + 0.06, D + 0.07, 0.05), (0, -(D + 0.07) / 2, HB + 0.065), "pal_stone_deep")
    CW, CD, top = 0.8, 0.15, 1.15
    zb = HB + 0.09
    fb = -(CD - 0.02)
    cw, ch = 0.56, 0.56 * 83 / 141          # the canvas, as the 2D painting's proportions
    fw, fh = cw + 0.07, ch + 0.07
    fz = zb + 0.03 + fh / 2
    p.box((CW, CD - 0.02, top - zb), (0, fb / 2, zb + (top - zb) / 2), "pal_void")
    _lay_stones(p, -CW / 2, CW / 2, zb, top, fb, dark, hole=(-fw / 2, fw / 2, fz + fh / 2), side=CW / 2)
    yb = fb - 0.04                           # the frame's back, clear of the stones
    p.box((fw - 0.03, 0.012, fh - 0.03), (0, yb - 0.006, fz), "pal_void")
    for zz in (fz - fh / 2 + 0.0175, fz + fh / 2 - 0.0175):
        p.box((fw, 0.04, 0.035), (0, yb - 0.02, zz), "pal_umber")
        p.box((fw - 0.05, 0.01, 0.008), (0, yb - 0.041, zz + (0.012 if zz < fz else -0.012)), "pal_tan")
    for xx in (-fw / 2 + 0.0175, fw / 2 - 0.0175):
        p.box((0.035, 0.04, fh), (xx, yb - 0.02, fz), "pal_umber")
        p.box((0.008, 0.01, fh - 0.05), (xx + (0.012 if xx < 0 else -0.012), yb - 0.041, fz), "pal_tan")
    p.socket("picture", (0, yb - 0.014, fz))


@model("fireplace_dancers", "wall", ["fireplace_dancers"],
       decals=[{"art": "fireplace_dancers", "region": [22, 4, 256, 67], "socket": "figures", "width": 0.84,
                "anchor": "bottom", "split": [[23, 58], [66, 127], [133, 166], [174, 192], [200, 231], [241, 277]]}])
def fireplace_dancers(p):
    """The conservatory hearth (2D fireplace_dancers): pale marble pilasters and frieze, an arched firebox of
    voussoirs, and the dancing figurines on the mantel, cut from the 2D art."""
    W, D, H = 0.96, 0.26, 0.8
    marble, panel, deep = "pal_pewter", "pal_slate", "pal_stone"
    front = -D
    pw = 0.16
    for s in (-1, 1):
        x = s * (W / 2 - pw / 2)
        p.box((pw, D, H - 0.27), (x, -D / 2, 0.08 + (H - 0.27) / 2), marble)
        p.box((pw + 0.02, D + 0.02, 0.08), (x, -D / 2 - 0.01, 0.04), marble)
        p.box((pw - 0.06, 0.01, H - 0.45), (x, front - 0.004, 0.12 + (H - 0.45) / 2), panel)
        p.box((pw + 0.02, D + 0.02, 0.04), (x, -D / 2 - 0.01, H - 0.17), deep)
    inner = W / 2 - pw
    p.box((2 * inner + 0.002, D - 0.02, 0.15), (0, -(D - 0.02) / 2, H - 0.19 + 0.075), marble)
    for s in (-1, 1):
        p.box((0.24, 0.01, 0.08), (s * 0.17, -(D - 0.02) - 0.004, H - 0.115), panel)
    p.cyl(0.035, 0.012, (0, -(D - 0.02), H - 0.115), panel, rot=(90, 0, 0), segs=14)
    r, spring = 0.21, 0.24
    ow = 2 * r
    for s in (-1, 1):
        p.box((inner - r, D - 0.02, spring), (s * (r + (inner - r) / 2), -(D - 0.02) / 2, spring / 2), marble)
    arc = [(r * math.cos(math.pi * k / 12), spring + r * math.sin(math.pi * k / 12)) for k in range(13)]
    # The marble between the pilasters and over the arch: round the top, then back under the arch from left to right.
    spandrel = [(inner, spring), (inner, H - 0.19), (-inner, H - 0.19), (-inner, spring)] + list(reversed(arc))
    p.prism(spandrel, D - 0.02, (0, -(D - 0.02) / 2, 0), marble)
    for k in range(7):
        a0, a1 = math.pi * k / 7, math.pi * (k + 1) / 7
        r1, r2 = r, r + 0.06
        quad = [(r1 * math.cos(a0), spring + r1 * math.sin(a0)), (r2 * math.cos(a0), spring + r2 * math.sin(a0)),
                (r2 * math.cos(a1), spring + r2 * math.sin(a1)), (r1 * math.cos(a1), spring + r1 * math.sin(a1))]
        p.prism(quad, 0.03, (0, -(D - 0.02) - 0.012, 0), panel if k == 3 else marble)
    p.box((ow, 0.03, spring + r), (0, -0.015, (spring + r) / 2), "pal_ink")
    p.box((W + 0.04, D + 0.04, 0.03), (0, -(D + 0.04) / 2, H - 0.025 - 0.015), panel)
    p.box((W + 0.06, D + 0.07, 0.04), (0, -(D + 0.07) / 2, H - 0.02), marble)
    p.box((W + 0.04, 0.2, 0.025), (0, front - 0.1, 0.0125), marble)
    p.box((ow, D, 0.03), (0, -D / 2, 0.015), deep)
    _fire(p, ow, front)
    p.socket("figures", (0, -(D + 0.07) / 2 + 0.01, H))


# --- Containers and common furniture (rollout batch 1) ----------------------------------------------------------

WOOD = "tex_interior__wood_planks"


def _iron_bands(p, W, D, zs, mat, t=0.012, w=0.035):
    """Flat iron straps round a box W x D at heights zs (each band's centre)."""
    for z in zs:
        p.box((W + 2 * t, D + 2 * t, w), (0, 0, z), mat)


@model("barrel", "free", ["barrel"])
def barrel(p):
    """The 2D barrel: bellied oak staves, dark iron hoops, a lid of boards and a bung."""
    H = 0.72
    prof = [(0.0, 0.0), (0.2, 0.0), (0.225, 0.12), (0.24, H / 2), (0.225, H - 0.12), (0.2, H), (0.0, H)]
    p.lathe(prof, (0, 0, 0), "pal_walnut", segs=16, smooth=False)
    for z, r in ((0.05, 0.207), (0.17, 0.231), (H - 0.17, 0.231), (H - 0.05, 0.207)):
        p.lathe([(r, -0.018), (r + 0.008, -0.016), (r + 0.008, 0.016), (r, 0.018)], (0, 0, z), "pal_stone_deep", segs=16,
                smooth=False)
    p.cyl(0.185, 0.012, (0, 0, H - 0.02), "pal_umber", segs=16, smooth=False)
    for x in (-0.06, 0.06):
        p.box((0.004, 0.36, 0.004), (x, 0, H - 0.007), "pal_peat")
    p.cyl(0.02, 0.01, (0, -0.24, H / 2), "pal_peat", rot=(90, 0, 0), segs=8)


@model("crate", "free", ["crate"])
def crate(p):
    """The 2D crate: boards in a dark frame, an X brace on each side."""
    S = 0.6
    p.box((S - 0.02, S - 0.02, S - 0.02), (0, 0, S / 2), WOOD)
    e = 0.05
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((e, e, S), (sx * (S / 2 - e / 2), sy * (S / 2 - e / 2), S / 2), "pal_umber")
    for z in (e / 2, S - e / 2):
        for s in (-1, 1):
            p.box((S, e, e), (0, s * (S / 2 - e / 2), z), "pal_umber")
            p.box((e, S, e), (s * (S / 2 - e / 2), 0, z), "pal_umber")
    diag = math.degrees(math.atan2(S - 2 * e, S - 2 * e))
    for s in (-1, 1):
        for a in (diag, -diag):
            p.box((0.05, 0.018, (S - 2 * e) * 1.38), (0, s * (S / 2 + 0.004), S / 2), "pal_umber", rot=(0, a, 0))
            p.box((0.018, 0.05, (S - 2 * e) * 1.38), (s * (S / 2 + 0.004), 0, S / 2), "pal_umber", rot=(a, 0, 0))


def _chest(p, wood, band, lock):
    """A chest with a rounded lid: the body, the lid's half-round, iron straps over both, a hasp and padlock."""
    W, D, Hb = 0.72, 0.44, 0.3
    r = D / 2
    p.box((W, D, Hb), (0, 0, Hb / 2), wood)
    lid = [(-r, 0.0), (r, 0.0)] + [(r * math.cos(math.pi * k / 10), r * 0.62 * math.sin(math.pi * k / 10)) for k in range(1, 10)]
    p.prism(lid, W, (0, 0, Hb), wood, rot=(0, 0, 90))
    band_lid = [(-r - 0.012, 0.0), (r + 0.012, 0.0)] + [((r + 0.012) * math.cos(math.pi * k / 10),
                                                         (r * 0.62 + 0.012) * math.sin(math.pi * k / 10)) for k in range(1, 10)]
    for x in (-W / 2 + 0.06, 0.0, W / 2 - 0.06):
        p.prism(band_lid, 0.04, (x, 0, Hb), band, rot=(0, 0, 90))
        p.box((0.04, D + 0.024, 0.012), (x, 0, 0.006), band)
        for s in (-1, 1):
            p.box((0.04, 0.012, Hb), (x, s * (D / 2 + 0.006), Hb / 2), band)
    p.box((W + 0.024, D + 0.024, 0.03), (0, 0, Hb - 0.015), band)
    p.box((0.07, 0.016, 0.1), (0, -D / 2 - 0.012, Hb - 0.02), band)
    p.lathe([(0.0, 0.0), (0.035, 0.0), (0.04, 0.02), (0.035, 0.05), (0.0, 0.05)], (0, -D / 2 - 0.03, Hb - 0.14), lock,
            rot=(90, 0, 0), segs=10)
    p.tube(curve((-0.022, -D / 2 - 0.03, Hb - 0.07), (0.0, -D / 2 - 0.03, Hb - 0.02), (0.022, -D / 2 - 0.03, Hb - 0.07), n=6),
           0.006, lock)
    for s in (-1, 1):
        p.tube(curve((s * (W / 2 + 0.01), -0.06, Hb - 0.06), (s * (W / 2 + 0.04), 0.0, Hb - 0.1), (s * (W / 2 + 0.01), 0.06,
                     Hb - 0.06), n=6), 0.01, band)


@model("chest", "free", ["chest", "chest_back"], container=True)
def chest(p):
    _chest(p, WOOD, "pal_slate", "pal_stone_deep")


@model("chest_iron", "free", ["chest_iron", "chest_iron_back"], container=True)
def chest_iron(p):
    _chest(p, "pal_night", "pal_stone", "pal_stone_deep")


@model("strongbox", "free", ["strongbox", "strongbox_back"], container=True)
def strongbox(p):
    """The 2D strongbox: a squat iron box, red-painted, riveted grey edges and a keyhole plate."""
    W, D, H = 0.42, 0.36, 0.36
    p.box((W, D, H), (0, 0, H / 2), "pal_blood")
    e = 0.03
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((e, e, H + 0.006), (sx * (W / 2 - e / 2 + 0.003), sy * (D / 2 - e / 2 + 0.003), H / 2), "pal_pewter")
    for s in (-1, 1):
        p.box((W + 0.006, e, e), (0, s * (D / 2 - e / 2 + 0.003), H - e / 2 + 0.003), "pal_pewter")
        p.box((e, D + 0.006, e), (s * (W / 2 - e / 2 + 0.003), 0, H - e / 2 + 0.003), "pal_pewter")
    p.box((W - 0.06, D - 0.06, 0.012), (0, 0, H + 0.006), "pal_slate")
    p.box((0.09, 0.012, 0.12), (0, -D / 2 - 0.006, H * 0.55), "pal_stone_deep")
    p.cyl(0.012, 0.014, (0, -D / 2 - 0.006, H * 0.58), "pal_void", rot=(90, 0, 0), segs=8)
    for x in (-W / 2 + 0.06, W / 2 - 0.06):
        for z in (0.05, H - 0.06):
            p.cyl(0.009, 0.01, (x, -D / 2 - 0.002, z), "pal_silver", rot=(90, 0, 0), segs=6)


@model("trunk", "free", ["trunk", "trunk_back"], container=True)
def trunk(p):
    """The 2D travelling trunk: dark canvas over wood, leather straps, brass corners, a brass lock."""
    W, D, H = 0.76, 0.44, 0.44
    p.box((W, D, H - 0.12), (0, 0, (H - 0.12) / 2), "pal_stone", soft=0.01)
    p.box((W + 0.006, D + 0.006, 0.12), (0, 0, H - 0.06), "pal_stone", soft=0.02)
    p.box((W + 0.012, D + 0.012, 0.02), (0, 0, H - 0.12), "pal_peat")
    for x in (-W / 4, W / 4):
        p.box((0.05, D + 0.02, 0.008), (x, 0, H + 0.002), "pal_umber")
        for s in (-1, 1):
            p.box((0.05, 0.01, H - 0.02), (x, s * (D / 2 + 0.006), H / 2), "pal_umber")
        p.box((0.06, 0.014, 0.05), (x, -D / 2 - 0.012, H - 0.16), "pal_tan")
    for sx in (-1, 1):
        for sy in (-1, 1):
            for z in (0.03, H - 0.03):
                p.box((0.06, 0.06, 0.06), (sx * (W / 2 - 0.022), sy * (D / 2 - 0.022), z), "pal_tan", soft=0.012)
        p.tube(curve((sx * (W / 2 + 0.008), -0.07, H - 0.17), (sx * (W / 2 + 0.035), 0.0, H - 0.2), (sx * (W / 2 + 0.008),
                     0.07, H - 0.17), n=6), 0.012, "pal_peat")
    p.box((0.07, 0.016, 0.07), (0, -D / 2 - 0.008, H - 0.13), "pal_tan")


@model("footlocker", "free", ["footlocker", "footlocker_back"], container=True)
def footlocker(p):
    """The 2D footlocker: a plain board box with grey metal edging and a hasp."""
    W, D, H = 0.66, 0.4, 0.38
    p.box((W, D, H), (0, 0, H / 2), WOOD)
    e = 0.03
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((e, e, H + 0.004), (sx * (W / 2 - e / 2 + 0.002), sy * (D / 2 - e / 2 + 0.002), H / 2), "pal_slate")
    for s in (-1, 1):
        for z in (e / 2, H - e / 2):
            p.box((W + 0.004, e, e), (0, s * (D / 2 - e / 2 + 0.002), z), "pal_slate")
            p.box((e, D + 0.004, e), (s * (W / 2 - e / 2 + 0.002), 0, z), "pal_slate")
    p.box((W + 0.01, D + 0.01, 0.012), (0, 0, H - 0.07), "pal_stone_deep")
    p.box((0.06, 0.014, 0.12), (0, -D / 2 - 0.007, H - 0.08), "pal_stone_deep")
    p.cyl(0.014, 0.012, (0, -D / 2 - 0.012, H - 0.12), "pal_slate", rot=(90, 0, 0), segs=8)


def _bed_linen(p, W, L, z, blanket, stripes=None):
    """Mattress, a turned-down blanket (striped if given) and a pillow, on a bed W wide and L long whose head is at +y."""
    p.box((W - 0.04, L - 0.04, 0.1), (0, 0, z + 0.05), "pal_vellum", soft=0.02)
    bl = L * 0.68
    p.box((W - 0.02, bl, 0.03), (0, -L / 2 + bl / 2 + 0.01, z + 0.11), blanket, soft=0.012)
    for s in (-1, 1):
        p.box((0.015, bl, 0.12), (s * (W / 2 - 0.005), -L / 2 + bl / 2 + 0.01, z + 0.06), blanket)
    if stripes:
        for k in range(5):
            y = -L / 2 + 0.08 + k * bl / 5.5
            p.box((W - 0.01, 0.05, 0.006), (0, y, z + 0.127), stripes)
            for s in (-1, 1):
                p.box((0.004, 0.05, 0.12), (s * (W / 2 + 0.003), y, z + 0.06), stripes)
    p.box((W - 0.06, 0.06, 0.012), (0, -L / 2 + bl + 0.03, z + 0.105), "pal_vellum", soft=0.004)
    p.box((W * 0.7, 0.18, 0.07), (0, L / 2 - 0.13, z + 0.13), "pal_ivory", soft=0.025, rot=(-12, 0, 0))


@model("bed", "against_wall", ["bed", "bed_back"])
def bed(p):
    """The 2D wooden bed: a turned frame, a red and cream striped blanket, a pillow; the headboard on the wall."""
    W, L = 0.66, 0.96
    yc = -L / 2 - 0.02
    wood = "pal_walnut"
    for sx in (-1, 1):
        for sy, h in ((1, 0.62), (-1, 0.4)):
            p.box((0.05, 0.05, h), (sx * (W / 2 - 0.025), yc + sy * (L / 2 - 0.025), h / 2), wood)
            p.lathe([(0.03, 0.0), (0.034, 0.012), (0.016, 0.026), (0.022, 0.04), (0.0, 0.065)],
                    (sx * (W / 2 - 0.025), yc + sy * (L / 2 - 0.025), h), wood, segs=8)
        p.box((0.035, L - 0.1, 0.1), (sx * (W / 2 - 0.025), yc, 0.2), "pal_umber")
    p.box((W - 0.1, 0.04, 0.4), (0, yc + L / 2 - 0.025, 0.36), WOOD)
    p.box((W - 0.1, 0.04, 0.22), (0, yc - L / 2 + 0.025, 0.25), WOOD)
    _bed_linen_at(p, W - 0.1, L - 0.1, 0.22, yc, "pal_blood", "pal_vellum")


def _bed_linen_at(p, W, L, z, yc, blanket, stripes):
    """_bed_linen shifted to a bed centred at y = yc."""
    sub = Piece(p.id + "_linen", seed=7)
    _bed_linen(sub, W, L, z, blanket, stripes)
    sub.bm.transform(Matrix.Translation((0, yc, 0)))
    tmp = bpy.data.meshes.new("_linen")
    sub.bm.to_mesh(tmp)
    sub.bm.free()
    remap = [p._slot(m) for m in sub.mats]
    tb = bmesh.new()
    tb.from_mesh(tmp)
    for f in tb.faces:
        f.material_index = remap[f.material_index]
    tb.to_mesh(tmp)
    tb.free()
    p.bm.from_mesh(tmp)
    bpy.data.meshes.remove(tmp)
    bpy.data.meshes.remove(sub._scratch)


@model("bed_small", "against_wall", ["bed_small", "bed_small_back"])
def bed_small(p):
    """The 2D narrow iron bed: black iron bedstead, a grey blanket, a pillow."""
    W, L = 0.56, 0.96
    yc = -L / 2 - 0.02
    iron = "pal_ink"
    for sx in (-1, 1):
        for sy, h in ((1, 0.6), (-1, 0.42)):
            p.cyl(0.014, h, (sx * (W / 2 - 0.015), yc + sy * (L / 2 - 0.015), 0), iron, segs=8)
            p.lathe([(0.018, 0.0), (0.022, 0.01), (0.0, 0.03)], (sx * (W / 2 - 0.015), yc + sy * (L / 2 - 0.015), h), iron,
                    segs=8)
        p.box((0.02, L - 0.03, 0.03), (sx * (W / 2 - 0.015), yc, 0.2), iron)
    for sy, h in ((1, 0.6), (-1, 0.42)):
        y = yc + sy * (L / 2 - 0.015)
        for z in (0.24, h - 0.03):
            p.cyl(0.011, W - 0.03, (-W / 2 + 0.015, y, z), iron, rot=(0, 90, 0), segs=6)
        for k in range(1, 5):
            p.cyl(0.007, h - 0.27, (-W / 2 + 0.015 + k * (W - 0.03) / 5, y, 0.24), iron, segs=6)
    _bed_linen_at(p, W - 0.04, L - 0.06, 0.2, yc, "pal_slate", None)


@model("wardrobe", "against_wall", ["wardrobe", "wardrobe_front"])
def wardrobe(p):
    """The 2D wardrobe: a tall walnut press with two panelled doors, a moulded cornice, a plinth on bracket feet."""
    W, D, H = 0.92, 0.5, 1.4
    yc = -D / 2
    body, trim, panel = "pal_walnut", "pal_umber", "pal_rust"
    p.box((W, D - 0.02, H - 0.17), (0, yc + 0.01, 0.09 + (H - 0.17) / 2), body)
    p.box((W + 0.03, D + 0.01, 0.06), (0, yc - 0.005, 0.07), trim)
    for sx in (-1, 1):
        p.prism([(0.0, 0.0), (0.09, 0.0), (0.09, 0.04), (0.04, 0.04), (0.0, 0.06)], 0.05,
                (sx * (W / 2 - 0.0) - (0.09 if sx > 0 else 0.0), yc - D / 2 + 0.03, 0.0), trim)
    p.box((W + 0.04, D + 0.02, 0.04), (0, yc - 0.01, H - 0.06), trim)
    p.box((W + 0.08, D + 0.04, 0.04), (0, yc - 0.02, H - 0.02), body)
    p.prism([(-0.22, 0.0), (0.22, 0.0), (0.1, 0.06), (0.0, 0.08), (-0.1, 0.06)], 0.03, (0, yc - D / 2 + 0.005, H), trim)
    dw = (W - 0.08) / 2
    front = yc - (D - 0.02) / 2 - 0.004
    for s in (-1, 1):
        cx = s * (dw / 2 + 0.008)
        p.box((dw - 0.01, 0.014, H - 0.33), (cx, front, 0.13 + (H - 0.33) / 2), body)
        for z0, h in ((0.17, 0.42), (0.66, 0.5)):
            p.box((dw - 0.12, 0.012, h), (cx, front - 0.008, z0 + h / 2), "pal_peat")
            p.box((dw - 0.16, 0.02, h - 0.05), (cx, front - 0.012, z0 + h / 2), panel, soft=0.006)
        p.lathe([(0.0, 0.0), (0.012, 0.0), (0.016, 0.012), (0.0, 0.024)], (s * 0.03, front - 0.008, 0.66), "pal_tan",
                rot=(90, 0, 0), segs=8)


@model("sideboard", "against_wall", ["sideboard", "sideboard_front"])
def sideboard(p):
    """The 2D sideboard: dark walnut, a row of drawers over carved cupboard doors, a silver candelabrum on top."""
    W, D, H = 0.96, 0.42, 0.52
    yc = -D / 2 - 0.01
    body, trim, face = "pal_umber", "pal_peat", "pal_walnut"
    p.box((W, D, H - 0.1), (0, yc, 0.08 + (H - 0.1) / 2), body)
    p.box((W + 0.03, D + 0.03, 0.035), (0, yc - 0.01, H - 0.0025), WOOD)
    p.prism([(-W / 2, 0.0), (W / 2, 0.0), (W / 2, 0.08), (W / 2 - 0.06, 0.08), (W * 0.25, 0.04), (0.0, 0.06),
             (-W * 0.25, 0.04), (-W / 2 + 0.06, 0.08), (-W / 2, 0.08)], 0.03, (0, yc - D / 2 + 0.014, 0.0), trim)
    front = yc - D / 2 - 0.005
    for k in range(3):
        x = -W / 3 + k * W / 3
        p.box((W / 3 - 0.03, 0.012, 0.09), (x, front, H - 0.1), face)
        p.box((0.05, 0.01, 0.012), (x, front - 0.01, H - 0.1), "pal_tan")
    for s in (-1, 1):
        p.box((W / 2 - 0.05, 0.012, 0.26), (s * W / 4, front, 0.24), face)
        lancet = [(-0.08, 0.0), (0.08, 0.0)] + list(reversed(arch(-0.08, 0.08, 0.14, 0.07, n=8)))
        p.prism(lancet, 0.01, (s * W / 4, front - 0.01, 0.15), trim)
        p.cyl(0.01, 0.012, (s * 0.04, front - 0.006, 0.28), "pal_tan", rot=(90, 0, 0), segs=8)
    c = (0.0, yc + 0.02, H + 0.015)
    p.lathe([(0.05, 0.0), (0.055, 0.01), (0.02, 0.03), (0.012, 0.15), (0.03, 0.17), (0.0, 0.17)], c, "pal_silver", segs=10)
    for s in (-1, 0, 1):
        x = c[0] + s * 0.1
        z = c[2] + (0.19 if s == 0 else 0.15)
        if s:
            p.tube(curve((c[0], c[1], c[2] + 0.12), (x * 0.9, c[1], c[2] + 0.1), (x, c[1], z - 0.01), n=6), 0.007, "pal_silver")
        p.lathe([(0.0, 0.0), (0.028, 0.0), (0.03, 0.01), (0.0, 0.012)], (x, c[1], z - 0.012), "pal_silver", segs=8)
        p.cyl(0.013, 0.08, (x, c[1], z), "pal_ivory", segs=8)
        p.lathe([(0.0, 0.0), (0.009, 0.008), (0.011, 0.02), (0.006, 0.034), (0.0, 0.044)], (x, c[1], z + 0.084),
                "glow_flame", segs=8)


@model("shelves", "against_wall", ["shelves", "shelves_front"])
def shelves(p):
    """The 2D storage shelves: an open frame of five shelves stocked with jars, crocks, sacks and boxes."""
    W, D, H = 0.9, 0.36, 1.3
    yc = -D / 2
    rng = p.rng
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((0.045, 0.045, H), (sx * (W / 2 - 0.0225), yc + sy * (D / 2 - 0.0225), H / 2), "pal_umber")
    zs = [0.06 + k * (H - 0.08) / 4.6 for k in range(5)]
    for z in zs:
        p.box((W - 0.03, D - 0.02, 0.025), (0, yc, z), WOOD)
    for z0, z1 in zip(zs, zs[1:] + [H + 0.3]):
        room = min(z1 - z0 - 0.04, 0.26)
        x = -W / 2 + 0.06
        while x < W / 2 - 0.1:
            kind = rng.random()
            y = yc - rng.uniform(-0.04, 0.06)
            if kind < 0.4:
                r = rng.uniform(0.03, 0.05)
                h = rng.uniform(0.08, min(room, 0.18))
                col = rng.choice(["pal_moss", "pal_bone", "pal_moon_blue", "pal_rust", "pal_bone_dark", "pal_bog"])
                p.lathe([(0.0, 0.0), (r, 0.0), (r * 1.05, h * 0.7), (r * 0.6, h * 0.85), (r * 0.6, h), (0.0, h)],
                        (x + r, y, z0 + 0.0125), col, segs=10)
                if rng.random() < 0.5:
                    p.cyl(r * 0.65, 0.012, (x + r, y, z0 + 0.0125 + h), "pal_umber", segs=8)
                x += 2 * r + rng.uniform(0.01, 0.03)
            elif kind < 0.7:
                w = rng.uniform(0.12, 0.18)
                h = rng.uniform(0.09, min(room, 0.16))
                p.box((w, 0.14, h), (x + w / 2, y, z0 + 0.0125 + h / 2), rng.choice(["pal_tan", "pal_bone_dark", "pal_leather"]),
                      soft=min(0.03, h * 0.3), rot=(0, 0, rng.uniform(-8, 8)))
                x += w + 0.02
            elif kind < 0.85:
                w = rng.uniform(0.1, 0.16)
                h = rng.uniform(0.06, min(room, 0.12))
                p.box((w, 0.15, h), (x + w / 2, y, z0 + 0.0125 + h / 2), WOOD)
                x += w + 0.02
            else:
                x += rng.uniform(0.05, 0.12)


@model("pew", "free", ["pew", "pew_back"])
def pew(p):
    """The 2D church pew: a plank seat and tall back between carved end panels."""
    W, D = 0.98, 0.44
    wood = "pal_walnut"
    end = [(-D / 2, 0.0), (D / 2, 0.0), (D / 2, 0.82), (D / 2 - 0.04, 0.88), (D / 2 - 0.12, 0.86), (D / 2 - 0.1, 0.4),
           (-D / 2 + 0.06, 0.38), (-D / 2 + 0.02, 0.44), (-D / 2, 0.42)]
    for s in (-1, 1):
        p.prism(end, 0.05, (s * (W / 2 - 0.025), 0, 0), "pal_umber", rot=(0, 0, 90))
    p.box((W - 0.06, D - 0.12, 0.04), (0, -0.04, 0.34), WOOD)
    p.box((W - 0.06, 0.035, 0.46), (0, D / 2 - 0.08, 0.6), WOOD, rot=(-8, 0, 0))
    p.box((W - 0.06, 0.05, 0.04), (0, D / 2 - 0.05, 0.84), wood)
    p.box((W - 0.06, 0.03, 0.14), (0, -D / 2 + 0.06, 0.25), wood)
    p.box((W - 0.06, 0.12, 0.03), (0, D / 2 - 0.02, 0.6), "pal_umber")


@model("lectern", "free", ["lectern", "lectern_back"])
def lectern(p):
    """The 2D lectern: a red-panelled pedestal on a stepped base, a sloped desk with a great open book."""
    p.box((0.42, 0.36, 0.05), (0, 0, 0.025), "pal_peat")
    p.box((0.36, 0.3, 0.04), (0, 0, 0.07), "pal_umber")
    p.box((0.26, 0.22, 0.62), (0, 0, 0.09 + 0.31), "pal_peat")
    for s in (-1, 1):
        p.box((0.16, 0.012, 0.5), (0, s * 0.116, 0.4), "pal_blood")
        p.box((0.012, 0.15, 0.5), (s * 0.136, 0, 0.4), "pal_blood")
    p.box((0.3, 0.26, 0.04), (0, 0, 0.72), "pal_umber")
    p.box((0.46, 0.36, 0.035), (0, -0.01, 0.82), "pal_umber", rot=(-22, 0, 0))
    p.box((0.46, 0.02, 0.04), (0, -0.19, 0.76), "pal_peat", rot=(-22, 0, 0))
    for s in (-1, 1):
        p.box((0.2, 0.27, 0.025), (s * 0.105, -0.015, 0.852), "pal_vellum", rot=(-22, s * 6, 0), soft=0.005)
    p.box((0.42, 0.29, 0.006), (0, -0.015, 0.838), "pal_blood", rot=(-22, 0, 0))
    p.box((0.004, 0.24, 0.004), (0.0, -0.015, 0.866), "pal_peat", rot=(-22, 0, 0))


def _table_frame(p, W, D, H, top, legs):
    p.box((W, D, 0.04), (0, 0, H - 0.02), top)
    for s in (-1, 1):
        p.box((W - 0.14, 0.03, 0.07), (0, s * (D / 2 - 0.06), H - 0.075), legs)
        p.box((0.03, D - 0.14, 0.07), (s * (W / 2 - 0.07), 0, H - 0.075), legs)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((0.06, 0.06, H - 0.04), (sx * (W / 2 - 0.07), sy * (D / 2 - 0.06), (H - 0.04) / 2), legs)


@model("table_set", "free", ["table_set", "table_set_back"])
def table_set(p):
    """The 2D table laid for a meal: pewter plates and goblets, a three-branch candelabrum, a gnawed bone."""
    W, D, H = 0.98, 0.6, 0.5
    _table_frame(p, W, D, H, WOOD, "pal_umber")
    p.box((W - 0.2, 0.018, 0.04), (0, 0, 0.1), "pal_umber")
    for x, y in ((-0.3, -0.17), (0.25, -0.17), (-0.25, 0.17), (0.3, 0.17)):
        p.cyl(0.075, 0.01, (x, y, H), "pal_pewter", r2=0.085, segs=14, smooth=False)
        p.lathe([(0.0, 0.0), (0.03, 0.0), (0.008, 0.01), (0.008, 0.05), (0.03, 0.065), (0.032, 0.1), (0.0, 0.1)],
                (x + 0.1 * (1 if x < 0 else -1) * 0, y + (0.09 if y < 0 else -0.09), H), "pal_silver", segs=10)
    p.cyl(0.012, 0.14, (0.05, 0.02, H + 0.015), "pal_bone", rot=(0, 90, 30), segs=6)
    for s in (-1, 1):
        p.lathe([(0.0, 0.0), (0.016, 0.0), (0.02, 0.012), (0.0, 0.016)], (0.05 + s * 0.06 * math.cos(math.radians(30)),
                0.02 + s * 0.06 * math.sin(math.radians(30)), H + 0.008), "pal_bone", segs=6)
    c = (0.0, 0.0, H)
    p.lathe([(0.05, 0.0), (0.055, 0.01), (0.02, 0.03), (0.012, 0.15), (0.03, 0.17), (0.0, 0.17)], c, "pal_silver", segs=10)
    for s in (-1, 0, 1):
        x = s * 0.1
        z = H + (0.19 if s == 0 else 0.15)
        if s:
            p.tube(curve((0.0, 0.0, H + 0.12), (x * 0.9, 0.0, H + 0.1), (x, 0.0, z - 0.01), n=6), 0.007, "pal_silver")
        p.lathe([(0.0, 0.0), (0.028, 0.0), (0.03, 0.01), (0.0, 0.012)], (x, 0.0, z - 0.012), "pal_silver", segs=8)
        p.cyl(0.013, 0.08, (x, 0.0, z), "pal_ivory", segs=8)
        p.lathe([(0.0, 0.0), (0.009, 0.008), (0.011, 0.02), (0.006, 0.034), (0.0, 0.044)], (x, 0.0, z + 0.084),
                "glow_flame", segs=8)


@model("letters_table", "free", ["letters_table"])
def letters_table(p):
    """The 2D side table with a bundle of letters tied in violet ribbon and a guttering candle."""
    W, D, H = 0.5, 0.5, 0.5
    _table_frame(p, W, D, H, WOOD, "pal_umber")
    p.box((0.2, 0.15, 0.06), (-0.05, 0.0, H + 0.03), "pal_vellum", rot=(0, 0, 12), soft=0.004)
    for a, w in ((12, 0.022), (102, 0.022)):
        p.box((0.24 if a == 12 else 0.18, w, 0.064), (-0.05, 0.0, H + 0.031), "pal_plum", rot=(0, 0, a))
    p.lathe([(0.0, 0.0), (0.04, 0.0), (0.045, 0.008), (0.012, 0.012), (0.0, 0.012)], (0.14, 0.1, H), "pal_tan", segs=10)
    p.cyl(0.02, 0.07, (0.14, 0.1, H + 0.01), "pal_ivory", segs=10)
    p.box((0.012, 0.012, 0.04), (0.155, 0.09, H + 0.05), "pal_vellum")
    p.lathe([(0.0, 0.0), (0.009, 0.008), (0.011, 0.02), (0.006, 0.034), (0.0, 0.044)], (0.14, 0.1, H + 0.084),
            "glow_flame", segs=8)


@model("coffin", "free", ["coffin", "coffin_back"])
def coffin(p):
    """The 2D coffin on two trestles: a six-sided box of dark wood with a raised lid."""
    L, Wd, H = 0.96, 0.44, 0.2
    top = [(-0.12, -L / 2), (0.12, -L / 2), (Wd / 2, L * 0.18), (0.16, L / 2), (-0.16, L / 2), (-Wd / 2, L * 0.18)]
    zb = 0.32
    p.prism(top, H, (0, 0, zb + H / 2), "pal_ash_violet", rot=(90, 0, 0))
    lid = [(x * 1.06, y * 1.03) for x, y in top]
    p.prism(lid, 0.035, (0, 0, zb + H + 0.0175), WOOD, rot=(90, 0, 0))
    inner = [(x * 0.8, y * 0.85) for x, y in top]
    p.prism(inner, 0.02, (0, 0, zb + H + 0.045), "pal_grave", rot=(90, 0, 0))
    for y in (-L / 2 + 0.2, L / 2 - 0.22):
        p.box((0.5, 0.06, 0.05), (0, y, zb - 0.025), "pal_umber")
        for s in (-1, 1):
            p.tube([(s * 0.13, y, zb - 0.04), (s * 0.22, y, 0.0)], 0.022, "pal_umber", segs=4, smooth=False)


# --- Stairs and doors ------------------------------------------------------------------------------------------

STEPS, RISE, RUN, WIDTH = 7, 1.5, 1.0, 0.9   # as world/look/stairs.gd: 7.5 ft up over one square


def _steps(p, z_of, top_of):
    """Steps across one square from the entry (front, -y) to the back; z_of(i) is step i's top, top_of its block's base."""
    td = RUN / STEPS
    rise = abs(z_of(1) - z_of(0))
    for i in range(STEPS):
        zt = z_of(i)
        y0 = -RUN / 2 + td * i
        base = top_of(i)
        p.box((WIDTH - 0.06, td, zt - base), (0, y0 + td / 2, (zt + base) / 2), "pal_grave")
        p.box((WIDTH - 0.05, td + 0.02, 0.025), (0, y0 + td / 2 - 0.01, zt - 0.0125), "tex_interior__wood_planks")
        p.box((0.5, td + 0.012, 0.006), (0, y0 + td / 2 - 0.006, zt + 0.003), "pal_blood")
        p.box((0.5, 0.006, rise - 0.03), (0, y0 - 0.016, zt - 0.025 - (rise - 0.03) / 2), "pal_blood")
        for s in (-1, 1):
            p.box((0.016, td + 0.012, 0.007), (s * 0.24, y0 + td / 2 - 0.006, zt + 0.0035), "pal_tan")
        p.cyl(0.006, 0.54, (-0.27, y0 - 0.022, zt - rise + 0.012), "pal_tan", rot=(0, 90, 0), segs=6)


@model("stairs_up", "stairs_up", ["stair_riser", "stair_riser_back"])
def stairs_up(p):
    rh = RISE / STEPS
    td = RUN / STEPS
    _steps(p, lambda i: rh * (i + 1), lambda i: 0.0)
    side = [(-RUN / 2, 0.0), (RUN / 2, 0.0), (RUN / 2, RISE + 0.06), (RUN / 2 - td, RISE + 0.06), (-RUN / 2, rh + 0.06)]
    cap = [(-RUN / 2, rh + 0.03), (RUN / 2 - td, RISE + 0.03), (RUN / 2, RISE + 0.03), (RUN / 2, RISE + 0.08),
           (RUN / 2 - td, RISE + 0.08), (-RUN / 2, rh + 0.08)]
    for s in (-1, 1):
        x = s * (WIDTH / 2 - 0.02)
        p.prism(side, 0.04, (x, 0, 0), "pal_blood", rot=(0, 0, 90))
        p.prism(cap, 0.05, (x, 0, 0), "pal_walnut", rot=(0, 0, 90))
        p.box((0.065, 0.065, rh + 0.55), (x, -RUN / 2 + 0.035, (rh + 0.55) / 2), "pal_walnut")
        p.lathe([(0.03, 0.0), (0.038, 0.015), (0.02, 0.03), (0.032, 0.05), (0.0, 0.09)], (x, -RUN / 2 + 0.035, rh + 0.55),
                "pal_walnut", segs=10)
        p.box((0.06, 0.06, 0.5), (x, RUN / 2 - 0.03, RISE + 0.25), "pal_walnut")
        p.tube([(x, -RUN / 2 + 0.035, rh + 0.5), (x, RUN / 2 - 0.03, RISE + 0.46)], 0.022, "pal_walnut", segs=6)
        for i in range(1, STEPS - 1):
            y = -RUN / 2 + td * (i + 0.5)
            zt = rh * (i + 1)
            zr = rh + 0.5 + (y + RUN / 2 - 0.035) / (RUN - 0.065) * (RISE + 0.46 - rh - 0.5)
            p.lathe([(0.012, 0.0), (0.018, 0.02), (0.01, 0.05), (0.01, zr - zt - 0.06), (0.016, zr - zt - 0.03),
                     (0.012, zr - zt)], (x, y, zt + 0.05), "pal_umber", segs=6)


@model("stairs_down", "stairs_down", ["stair_down"])
def stairs_down(p):
    drop = 1.4
    rh = drop / STEPS
    _steps(p, lambda i: -rh * (i + 1), lambda i: -drop - 0.02)
    p.box((1.0, 1.0, 0.04), (0, 0, -drop - 0.04), "pal_void")
    p.box((1.0, 0.05, drop), (0, 0.475, -drop / 2), "pal_peat")
    for s in (-1, 1):
        p.box((0.05, 1.0, drop), (s * 0.475, 0, -drop / 2), "pal_peat")
        for z in (-0.12, -0.6):
            p.box((0.012, 0.95, 0.03), (s * 0.444, 0.0, z), "pal_umber")
    # A railing round the well on the three sides away from the entry.
    rail_h = 0.45
    corners = [(-0.46, -0.46), (0.46, -0.46), (-0.46, 0.46), (0.46, 0.46)]
    for x, y in corners:
        p.box((0.06, 0.06, rail_h), (x, y, rail_h / 2), "pal_walnut")
        p.lathe([(0.03, 0.0), (0.036, 0.015), (0.018, 0.03), (0.03, 0.05), (0.0, 0.085)], (x, y, rail_h), "pal_walnut")
    for a, b in [((-0.46, 0.46), (0.46, 0.46)), ((-0.46, -0.46), (-0.46, 0.46)), ((0.46, -0.46), (0.46, 0.46))]:
        p.tube([(a[0], a[1], rail_h - 0.02), (b[0], b[1], rail_h - 0.02)], 0.022, "pal_walnut", segs=6)
        for k in range(1, 7):
            t = k / 7
            x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
            p.lathe([(0.012, 0.0), (0.018, 0.02), (0.01, 0.05), (0.01, rail_h - 0.1), (0.016, rail_h - 0.06),
                     (0.012, rail_h - 0.03)], (x, y, 0.0), "pal_umber", segs=6)


STONE_WALL = "tex_dungeon__stone_wall"
STONE_FLOOR = "tex_dungeon__stone_floor"


def _stone_steps(p, z_of, top_of):
    """Worn stone steps across one square, each a block with a slightly darker riser, from the entry (front) back."""
    td = RUN / STEPS
    rng = p.rng
    for i in range(STEPS):
        zt = z_of(i)
        y0 = -RUN / 2 + td * i
        base = top_of(i)
        p.box((WIDTH - 0.04, td, zt - base - 0.03), (0, y0 + td / 2, (zt - 0.03 + base) / 2), "pal_stone_deep")
        p.box((WIDTH - 0.03, td + 0.015, 0.03), (rng.uniform(-0.005, 0.005), y0 + td / 2 - 0.0075, zt - 0.015), STONE_FLOOR,
              rot=(0, rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8)))


@model("stairs_up_stone", "stairs_up", ["stair_riser"])
def stairs_up_stone(p):
    """Stairs up in stone places (dungeons, churches, the castle): stone steps between two stone side walls."""
    rh = RISE / STEPS
    td = RUN / STEPS
    _stone_steps(p, lambda i: rh * (i + 1), lambda i: 0.0)
    side = [(-RUN / 2, 0.0), (RUN / 2, 0.0), (RUN / 2, RISE + 0.18), (RUN / 2 - td, RISE + 0.18), (-RUN / 2, rh + 0.18)]
    cap = [(-RUN / 2 - 0.01, rh + 0.16), (RUN / 2 - td, RISE + 0.16), (RUN / 2 + 0.01, RISE + 0.16), (RUN / 2 + 0.01, RISE + 0.22),
           (RUN / 2 - td, RISE + 0.22), (-RUN / 2 - 0.01, rh + 0.22)]
    for s in (-1, 1):
        x = s * (WIDTH / 2 + 0.01)
        p.prism(side, 0.08, (x, 0, 0), STONE_WALL, rot=(0, 0, 90))
        p.prism(cap, 0.1, (x, 0, 0), "pal_slate", rot=(0, 0, 90))


@model("stairs_down_stone", "stairs_down", ["stair_down"])
def stairs_down_stone(p):
    """A stair well down in stone places: stone steps into a shaft of stone, a low parapet round three sides."""
    drop = 1.4
    rh = drop / STEPS
    _stone_steps(p, lambda i: -rh * (i + 1), lambda i: -drop - 0.02)
    p.box((1.0, 1.0, 0.04), (0, 0, -drop - 0.04), "pal_void")
    p.box((1.0, 0.05, drop), (0, 0.475, -drop / 2), STONE_WALL)
    for s in (-1, 1):
        p.box((0.05, 1.0, drop), (s * 0.475, 0, -drop / 2), STONE_WALL)
    h = 0.3
    p.box((1.0, 0.1, h), (0, 0.45, h / 2), STONE_WALL)
    p.box((1.02, 0.12, 0.04), (0, 0.45, h + 0.02), "pal_slate")
    for s in (-1, 1):
        p.box((0.1, 0.9, h), (s * 0.45, 0.0, h / 2), STONE_WALL)
        p.box((0.12, 0.92, 0.04), (s * 0.45, 0.0, h + 0.02), "pal_slate")


@model("door_wood", "door", ["door_wood"])
def door_wood(p):
    """A plank door leaf with iron strap hinges and a ring pull (the 2D door_wood), 0.86 x 1.15 like the sprite leaf."""
    W, H, T = 0.86, 1.15, 0.055
    rng = p.rng
    n = 5
    pw = W / n
    for k in range(n):
        p.box((pw - 0.006, T, H - rng.uniform(0.0, 0.01)), (-W / 2 + pw * (k + 0.5), 0, H / 2), "tex_interior__wood_planks")
    for z in (0.22, 0.92):
        p.box((W - 0.12, 0.012, 0.055), (-0.04, -T / 2 - 0.006, z), "pal_void")
        p.cyl(0.03, 0.013, (W / 2 - 0.13, -T / 2 - 0.006, z), "pal_void", rot=(90, 0, 0), segs=10)
        for k in range(5):
            p.cyl(0.008, 0.008, (-W / 2 + 0.08 + k * 0.16, -T / 2 - 0.012, z), "pal_pewter", rot=(90, 0, 0), segs=6)
        p.box((W - 0.1, 0.03, 0.08), (0, T / 2 + 0.015, z), "pal_umber")
    p.box((0.05, 0.03, 0.82), (0, T / 2 + 0.015, 0.57), "pal_umber", rot=(0, 45, 0))
    ring = [(-W / 2 + 0.12 + 0.045 * math.sin(a), -T / 2 - 0.02, 0.56 - 0.045 * math.cos(a))
            for a in (2 * math.pi * k / 12 for k in range(13))]
    p.tube(ring, 0.007, "pal_void", segs=6)
    p.cyl(0.02, 0.012, (-W / 2 + 0.12, -T / 2 - 0.006, 0.6), "pal_void", rot=(90, 0, 0), segs=8)


@model("wainscot", "wall_face", ["interior/wainscot_wall"])
def wainscot(p):
    """One square's face of a panelled wall: skirting, two raised panels and a chair rail over the painted wainscot's
    lower half (the damask above the rail is the wall's own texture). Modules meet at their ends along a wall."""
    W = 1.0
    # The painted wainscot's own colours (art/textures/interior/wainscot_wall.png): peat panels with near-black
    # mouldings, so lamplight shows the panels' depth rather than a new colour.
    frame, field, rail = "pal_peat", "pal_peat", "pal_umber"
    p.box((W, 0.032, 0.075), (0, -0.016, 0.0375), "pal_ink")
    p.box((W, 0.04, 0.014), (0, -0.02, 0.082), rail)
    p.box((W, 0.016, 0.5), (0, -0.008, 0.075 + 0.25), frame)
    for s in (-1, 1):
        cx = s * 0.25
        p.box((0.36, 0.01, 0.34), (cx, -0.021, 0.32), "pal_ink")
        p.box((0.3, 0.02, 0.28), (cx, -0.026, 0.32), field, soft=0.008)
    p.box((W, 0.036, 0.03), (0, -0.018, 0.555), rail)
    p.box((W, 0.046, 0.016), (0, -0.023, 0.578), rail)


# --- Doors, gates, windows and wall trim (rollout batch 2) -------------------------------------------------------
# Door leaves are modelled at the 2D leaf's base size (0.86 x 1.15, centred in depth) and scaled to each opening
# (SetDressing.door); windows and facades hang on a wall face (origin on the face) and keep their 2D glass as a decal.

def _planks(p, W, H, T, n, cols, z0=0.0):
    pw = W / n
    for k in range(n):
        p.box((pw - 0.006, T, H - p.rng.uniform(0.0, 0.012)), (-W / 2 + pw * (k + 0.5), 0, z0 + H / 2), cols[k % len(cols)])


@model("door_house", "door", ["door_house"])
def door_house(p):
    """The 2D cottage door: grey weathered planks, two iron bands, a latch."""
    W, H, T = 0.86, 1.15, 0.055
    _planks(p, W, H, T, 5, ["pal_bone_dark", "pal_bone", "pal_bone_dark"])
    for z in (0.25, 0.9):
        p.box((W - 0.04, 0.012, 0.05), (0, -T / 2 - 0.006, z), "pal_stone_deep")
        p.box((W - 0.1, 0.03, 0.08), (0, T / 2 + 0.015, z), "pal_umber")
    p.box((0.1, 0.014, 0.025), (W / 2 - 0.12, -T / 2 - 0.007, 0.56), "pal_ink")
    p.box((0.02, 0.03, 0.06), (W / 2 - 0.08, -T / 2 - 0.02, 0.56), "pal_ink")


@model("door_double", "door", ["door_double"])
def door_double(p):
    """The 2D double doors: two walnut leaves of raised panels with brass pulls."""
    W, H, T = 0.86, 1.15, 0.055
    lw = W / 2
    for s in (-1, 1):
        cx = s * lw / 2
        p.box((lw - 0.008, T, H), (cx, 0, H / 2), WOOD)
        for z0, h in ((0.08, 0.42), (0.58, 0.48)):
            for face in (-1, 1):
                p.box((lw - 0.12, 0.01, h), (cx, face * (T / 2 + 0.003), z0 + h / 2), "pal_peat")
                p.box((lw - 0.17, 0.014, h - 0.05), (cx, face * (T / 2 + 0.008), z0 + h / 2), "pal_walnut", soft=0.005)
        p.lathe([(0.0, 0.0), (0.012, 0.0), (0.016, 0.014), (0.0, 0.028)], (s * 0.035, -T / 2 - 0.002, 0.55), "pal_tan",
                rot=(90, 0, 0), segs=8)


@model("door_carved", "door", ["door_carved"],
       decals=[{"art": "door_carved", "region": [40, 65, 120, 185], "socket": "hand", "width": 0.46}])
def door_carved(p):
    """The Death House's carved door: rough planks in a heavy frame, the carved hand cut from the 2D door."""
    W, H, T = 0.86, 1.15, 0.06
    _planks(p, W, H, T, 4, [WOOD])
    for s in (-1, 1):
        p.box((0.06, 0.02, H), (s * (W / 2 - 0.03), -T / 2 - 0.01, H / 2), "pal_umber")
    p.box((W, 0.02, 0.06), (0, -T / 2 - 0.01, H - 0.03), "pal_umber")
    p.socket("hand", (0, -T / 2 - 0.004, 0.62))


@model("church_doors", "wall", ["church_doors"],
       decals=[{"art": "church_doors", "region": [65, 40, 245, 180], "socket": "tympanum", "width": 0.6}])
def church_doors(p):
    """The 2D church doors: a pointed stone arch on pilasters, two iron-strapped plank leaves, and the rose window and
    tracery over them cut from the 2D doors."""
    W, H = 0.96, 1.9
    stone, dark = "pal_parchment", "pal_bone"
    spring = 1.12
    for s in (-1, 1):
        p.box((0.14, 0.18, spring), (s * (W / 2 - 0.07), -0.09, spring / 2), stone)
        p.box((0.17, 0.2, 0.08), (s * (W / 2 - 0.07), -0.1, spring + 0.04), dark)
        p.box((0.05, 0.01, spring - 0.3), (s * (W / 2 - 0.07), -0.185, 0.12 + (spring - 0.3) / 2), dark)
    outer = arch(-W / 2, W / 2, spring + 0.08, H - spring - 0.08, n=14)
    inner = arch(-W / 2 + 0.12, W / 2 - 0.12, spring + 0.08, H - spring - 0.22, n=14)
    ring = outer + list(reversed(inner))
    p.prism(ring, 0.16, (0, -0.08, 0), stone)
    p.prism(inner + [(W / 2 - 0.12, spring + 0.08)], 0.02, (0, -0.02, 0), "pal_stone_deep")
    lw = (W - 0.28) / 2
    for s in (-1, 1):
        cx = s * (lw / 2 + 0.002)
        p.box((lw - 0.006, 0.05, spring + 0.08), (cx, -0.06, (spring + 0.08) / 2), WOOD)
        for z in (0.18, 0.95):
            p.box((lw - 0.02, 0.012, 0.035), (cx, -0.091, z), "pal_ink")
        p.lathe([(0.0, 0.0), (0.014, 0.0), (0.018, 0.012), (0.0, 0.024)], (s * 0.05, -0.088, 0.58), "pal_ink",
                rot=(90, 0, 0), segs=8)
    p.box((0.03, 0.06, spring + 0.08), (0, -0.07, (spring + 0.08) / 2), stone)
    p.box((W + 0.1, 0.3, 0.05), (0, -0.15, 0.025), dark)
    p.socket("tympanum", (0, -0.035, spring + 0.08 + 0.3))


def _bar_gate(p, W, H, bars, iron, spikes=True, cross=(0.2, 0.6, 1.0)):
    for k in range(bars):
        x = -W / 2 + 0.03 + k * (W - 0.06) / (bars - 1)
        p.cyl(0.012, H - 0.02, (x, 0, 0.0), iron, segs=6)
        if spikes:
            p.lathe([(0.016, 0.0), (0.02, 0.01), (0.0, 0.07)], (x, 0, H - 0.02), iron, segs=6)
    for z in cross:
        p.box((W, 0.03, 0.03), (0, 0, z * H), iron)


@model("gate_iron", "door", ["gate_iron"])
def gate_iron(p):
    """The 2D wrought-iron gates: two leaves of spiked bars, scrolls at the top and bottom rails."""
    W, H = 0.86, 1.15
    iron = "pal_ink"
    for s in (-1, 1):
        cx = s * W / 4
        sub_w = W / 2 - 0.01
        for k in range(6):
            x = cx - sub_w / 2 + 0.03 + k * (sub_w - 0.06) / 5
            top = H - 0.12 + 0.08 * math.sin(math.pi * (abs(x) / (W / 2)))
            p.cyl(0.01, top, (x, 0, 0.0), iron, segs=6)
            p.lathe([(0.016, 0.0), (0.02, 0.012), (0.0, 0.07)], (x, 0, top), iron, segs=6)
        for z in (0.12, 0.62, H - 0.2):
            p.box((sub_w, 0.026, 0.026), (cx, 0, z), iron)
        for k in range(2):
            x0 = cx - sub_w / 4 + k * sub_w / 2
            pts = [(x0 + 0.08 * math.cos(a), 0.0, 0.37 + 0.12 * math.sin(a)) for a in (math.pi * j / 8 for j in range(17))]
            p.tube(pts, 0.007, iron, segs=5)
    p.cyl(0.03, 0.03, (0.0, -0.02, 0.6), "pal_stone_deep", rot=(90, 0, 0), segs=8)


@model("crypt_gate", "door", ["crypt_gate"])
def crypt_gate(p):
    """The 2D crypt gate: a frame of flat iron, upright bars and a great padlock."""
    W, H = 0.86, 1.15
    iron = "pal_ink"
    for s in (-1, 1):
        p.box((0.05, 0.04, H), (s * (W / 2 - 0.025), 0, H / 2), iron)
    for z in (0.025, 0.55, H - 0.025):
        p.box((W, 0.04, 0.05), (0, 0, z), iron)
    _bar_gate(p, W - 0.1, H, 8, iron, spikes=False, cross=())
    p.box((0.12, 0.05, 0.12), (0, -0.04, 0.55), "pal_stone_deep")
    p.tube(curve((-0.035, -0.06, 0.6), (0.0, -0.06, 0.68), (0.035, -0.06, 0.6), n=6), 0.01, "pal_stone_deep")


@model("portcullis", "door", ["portcullis"])
def portcullis(p):
    """The 2D portcullis: a grid of rusted iron bars with spikes along the foot."""
    W, H = 0.86, 1.15
    iron = "pal_rust"
    for k in range(6):
        x = -W / 2 + 0.05 + k * (W - 0.1) / 5
        p.box((0.035, 0.035, H - 0.08), (x, 0, 0.08 + (H - 0.08) / 2), iron)
        p.lathe([(0.0, 0.0), (0.024, 0.08)], (x, 0, 0.0), iron, segs=4, smooth=False)
    for k in range(6):
        p.box((W, 0.03, 0.035), (0, -0.03, 0.16 + k * (H - 0.22) / 5), iron)
    for k in range(6):
        for j in range(6):
            p.cyl(0.012, 0.012, (-W / 2 + 0.05 + k * (W - 0.1) / 5, -0.05, 0.16 + j * (H - 0.22) / 5), "pal_stone_deep",
                  rot=(90, 0, 0), segs=6)


@model("curtain", "door", ["curtain"])
def curtain(p):
    """The 2D curtain: heavy red drapes hanging in folds from a wooden rod."""
    W, H = 0.86, 1.15
    p.cyl(0.018, W + 0.08, (-W / 2 - 0.04, -0.02, H - 0.03), "pal_umber", rot=(0, 90, 0), segs=8)
    for s in (-1, 1):
        p.lathe([(0.0, 0.0), (0.026, 0.0), (0.03, 0.02), (0.0, 0.04)], (s * (W / 2 + 0.04), -0.02, H - 0.05), "pal_umber",
                rot=(0, s * 90, 0), segs=8)
    n = 28
    wave = []
    for i in range(n + 1):
        x = -W / 2 + i * W / n
        wave.append((x, -0.02 + 0.03 * math.sin(i * math.pi / 2.5)))
    band = wave + [(x, z + 0.025) for x, z in reversed(wave)]
    p.prism(band, H - 0.06, (0, 0, (H - 0.06) / 2), "pal_blood", rot=(90, 0, 0))
    p.box((W, 0.08, 0.04), (0, -0.02, H - 0.08), "pal_blood_deep")


def _window(p, W, H, depth, frame, sill, bottom):
    """A lancet window set into a wall face: a deep pointed-arch reveal round the 2D window (its glass and tracery, the
    `glass` decal, W x H, its foot at `bottom`), and a sill. Only the reveal is modelled, so the wall shows round it."""
    t = 0.05
    spring = bottom + H - W * 0.62
    for s in (-1, 1):
        p.box((t, depth, spring - bottom + 0.01), (s * (W / 2 + t / 2 - 0.01), -depth / 2, (spring + bottom) / 2), frame)
    outer = arch(-W / 2 - t + 0.01, W / 2 + t - 0.01, spring, W * 0.62 + t + 0.02, n=12)
    inner = arch(-W / 2 + 0.01, W / 2 - 0.01, spring, W * 0.62, n=12)
    p.prism(outer + list(reversed(inner)), depth, (0, -depth / 2, 0), frame)
    p.box((W + 2 * t + 0.06, depth + 0.05, 0.04), (0, -(depth + 0.05) / 2, bottom - 0.02), sill)
    p.socket("glass", (0, -0.012, bottom + H / 2))


@model("window_tall", "wall", ["window_tall"],
       decals=[{"art": "window_tall", "region": [0, 0, 136, 276], "socket": "glass", "width": 0.34}])
def window_tall(p):
    """The 2D lancet window, its moonlit glass and tracery kept, in a deep stone reveal with a sill."""
    _window(p, 0.34, 0.34 * 276 / 136, 0.08, "pal_slate", "pal_stone", 0.3)


@model("window_stained", "wall", ["window_stained"],
       decals=[{"art": "window_stained", "region": [0, 0, 148, 288], "socket": "glass", "width": 0.34}])
def window_stained(p):
    """The 2D stained glass saint, kept whole, in a deep stone reveal with a sill."""
    _window(p, 0.34, 0.34 * 288 / 148, 0.08, "pal_parchment", "pal_bone", 0.3)


@model("window_shuttered", "wall", ["window_shuttered"])
def window_shuttered(p):
    """The 2D shuttered window: two plank shutters with iron hinges, closed, in a wooden frame with a sill."""
    W, H, zc = 0.62, 0.62, 0.62
    for s in (-1, 1):
        p.box((0.05, 0.06, H + 0.1), (s * (W / 2 + 0.025), -0.03, zc), "pal_umber")
    p.box((W + 0.1, 0.06, 0.05), (0, -0.03, zc + H / 2 + 0.025), "pal_umber")
    p.box((W + 0.16, 0.1, 0.04), (0, -0.05, zc - H / 2 - 0.02), "pal_umber")
    for s in (-1, 1):
        cx = s * W / 4
        for k in range(3):
            p.box((W / 6 - 0.005, 0.03, H), (cx - W / 6 + k * W / 6, -0.035, zc), WOOD)
        for z in (zc - H / 3, zc + H / 3):
            p.box((W / 2 - 0.04, 0.01, 0.03), (cx, -0.055, z), "pal_ink")


def _trim(p, colour, rail_z=None, stiles=False, cap=None):
    """Wall trim on one square's face: a skirting board, optionally a rail, stiles at each end and the middle, a cap."""
    p.box((1.0, 0.03, 0.07), (0, -0.015, 0.035), colour)
    p.box((1.0, 0.038, 0.014), (0, -0.019, 0.077), colour)
    if rail_z is not None:
        p.box((1.0, 0.03, 0.03), (0, -0.015, rail_z), colour)
        p.box((1.0, 0.038, 0.012), (0, -0.019, rail_z + 0.02), colour)
    if stiles:
        for x, w in ((-0.5 + 0.02, 0.04), (0.0, 0.07), (0.5 - 0.02, 0.04)):
            p.box((w, 0.02, 1.0), (x, -0.01, 0.084 + 0.5), colour)
    if cap is not None:
        p.box((1.0, 0.04, 0.05), (0, -0.02, cap - 0.025), colour)


@model("panelling", "wall_face", ["interior/wood_panel", "interior/carved_panel"])
def panelling(p):
    """Dark gothic panelling's frame in relief: skirting, stiles and a top rail over the carved panel texture."""
    _trim(p, "pal_stone_deep", rail_z=None, stiles=True, cap=1.12)


@model("wall_trim", "wall_face", ["interior/plaster_wall", "interior/wallpaper_green", "interior/wallpaper_nursery",
                                   "interior/damp_plaster", "interior/whitewash", "interior/kitchen_wall"])
def wall_trim(p):
    """A wooden skirting board and picture rail on papered and plastered walls."""
    _trim(p, "pal_umber", rail_z=0.92)


# --- Town and outdoor pieces (rollout batch 3) -----------------------------------------------------------------

def _wheel(p, at, r, axis_deg=0.0, spokes=8, wood="pal_umber", rim="pal_stone_deep"):
    """A spoked cart wheel standing at `at` (its hub), facing along x when axis_deg is 0."""
    x, y, z = at
    ring = [(x + 0.0, y + r * math.cos(a), z + r * math.sin(a)) for a in (2 * math.pi * k / 20 for k in range(21))]
    p.tube(ring, 0.03, wood, segs=6)
    ring2 = [(x + 0.0, y + (r + 0.02) * math.cos(a), z + (r + 0.02) * math.sin(a)) for a in (2 * math.pi * k / 20 for k in range(21))]
    p.tube(ring2, 0.012, rim, segs=5)
    for k in range(spokes):
        a = 2 * math.pi * k / spokes
        p.tube([(x, y, z), (x, y + r * math.cos(a), z + r * math.sin(a))], 0.012, wood, segs=5)
    p.cyl(0.05, 0.1, (x - 0.05, y, z), wood, rot=(0, 90, 0), segs=10)


@model("wagon", "free", ["wagon", "wagon_back"], big=True)
def wagon(p):
    """The 2D covered wagon: a plank bed on four spoked wheels, hooped white canvas over it, shafts in front."""
    L, W = 1.7, 0.8
    bed_z = 0.42
    p.box((L, W, 0.06), (0, 0, bed_z), WOOD)
    for s in (-1, 1):
        p.box((L, 0.04, 0.22), (0, s * (W / 2 - 0.02), bed_z + 0.11), "pal_umber")
        p.box((0.04, W, 0.22), (s * (L / 2 - 0.02), 0, bed_z + 0.11), "pal_umber")
    for sx in (-1, 1):
        for sy in (-1, 1):
            _wheel(p, (sx * (L / 2 - 0.3), sy * (W / 2 + 0.06), 0.36), 0.36)
        p.box((0.05, W + 0.12, 0.05), (sx * (L / 2 - 0.3), 0, 0.36), "pal_peat")
    hoops = 5
    for k in range(hoops):
        x = -L / 2 + 0.15 + k * (L - 0.3) / (hoops - 1)
        pts = [(x, (W / 2) * math.cos(a), bed_z + 0.22 + 0.55 * math.sin(a)) for a in (math.pi * j / 12 for j in range(13))]
        p.tube(pts, 0.015, "pal_umber", segs=5)
    cover = [((W / 2 + 0.01) * math.cos(a), bed_z + 0.22 + 0.56 * math.sin(a)) for a in (math.pi * j / 16 for j in range(17))]
    inner = [((W / 2 - 0.01) * math.cos(a), bed_z + 0.22 + 0.54 * math.sin(a)) for a in (math.pi * j / 16 for j in range(17))]
    p.prism(cover + list(reversed(inner)), L - 0.2, (0, 0, 0), "pal_vellum", rot=(0, 0, 90))
    for s in (-1, 1):
        p.tube([(-L / 2, s * 0.2, bed_z), (-L / 2 - 0.5, s * 0.25, 0.3)], 0.025, "pal_umber", segs=6)
    p.box((0.25, W - 0.1, 0.05), (-L / 2 + 0.18, 0, bed_z + 0.3), "pal_umber")


@model("market_stall", "free", ["market_stall", "market_stall_back"], big=True)
def market_stall(p):
    """The 2D market stall: a plank counter of jars and sacks under a red and white striped awning on four posts."""
    W, D, H = 1.4, 0.8, 1.6
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((0.06, 0.06, H if sy > 0 else H - 0.15), (sx * (W / 2 - 0.03), sy * (D / 2 - 0.03), (H if sy > 0 else H - 0.15) / 2),
                  "pal_umber")
    p.box((W, D * 0.6, 0.05), (0, -D * 0.15, 0.78), WOOD)
    p.box((W - 0.06, 0.04, 0.72), (0, -D / 2 + 0.06, 0.38), WOOD)
    stripes = 8
    for k in range(stripes):
        x = -W / 2 + (k + 0.5) * W / stripes
        col = "pal_crimson" if k % 2 == 0 else "pal_ivory"
        p.box((W / stripes, D + 0.2, 0.025), (x, -0.1, H - 0.08), col, rot=(-14, 0, 0))
        p.prism([(-W / stripes / 2, 0.0), (W / stripes / 2, 0.0), (W / stripes / 2, -0.08), (0.0, -0.13),
                 (-W / stripes / 2, -0.08)], 0.01, (x, -D / 2 - 0.2, H - 0.09 - (D + 0.2) / 2 * math.sin(math.radians(14))), col)
    rng = p.rng
    x = -W / 2 + 0.1
    while x < W / 2 - 0.12:
        if rng.random() < 0.5:
            r = rng.uniform(0.04, 0.06)
            p.lathe([(0.0, 0.0), (r, 0.0), (r * 1.1, 0.08), (r * 0.6, 0.12), (0.0, 0.12)], (x + r, -0.2 + rng.uniform(-0.05, 0.05), 0.805),
                    rng.choice(["pal_bone", "pal_moss", "pal_rust", "pal_moon_blue"]), segs=10)
            x += 2 * r + 0.04
        else:
            w = rng.uniform(0.12, 0.16)
            p.box((w, 0.14, 0.12), (x + w / 2, -0.15, 0.865), rng.choice(["pal_tan", "pal_bone_dark"]), soft=0.03)
            x += w + 0.04


@model("shop_counter", "against_wall", ["shop_counter", "shop_counter_back", "counter_front"])
def shop_counter(p):
    """The 2D shop counter: panelled walnut with a red cloth top, a brass balance, a ledger and boxes."""
    W, D, H = 0.98, 0.5, 0.56
    yc = -D / 2 - 0.02
    p.box((W, D, H - 0.04), (0, yc, (H - 0.04) / 2), "pal_walnut")
    p.box((W + 0.03, D + 0.03, 0.04), (0, yc, H - 0.02), WOOD)
    p.box((W - 0.1, D - 0.12, 0.006), (0, yc, H + 0.003), "pal_blood")
    front = yc - D / 2 - 0.005
    for k in range(3):
        x = -W / 3 + k * W / 3
        p.box((W / 3 - 0.08, 0.01, H - 0.16), (x, front, 0.06 + (H - 0.16) / 2), "pal_umber")
    b = (-0.26, yc, H)
    p.cyl(0.06, 0.012, b, "pal_tan", segs=12)
    p.cyl(0.008, 0.26, (b[0], b[1], b[2] + 0.01), "pal_tan", segs=6)
    p.box((0.3, 0.012, 0.012), (b[0], b[1], b[2] + 0.27), "pal_tan")
    for s in (-1, 1):
        p.cyl(0.003, 0.12, (b[0] + s * 0.14, b[1], b[2] + 0.15), "pal_tan", segs=4)
        p.lathe([(0.0, 0.0), (0.05, 0.03), (0.05, 0.035), (0.0, 0.035)], (b[0] + s * 0.14, b[1], b[2] + 0.12), "pal_tan", segs=10)
    p.box((0.18, 0.24, 0.04), (0.05, yc, H + 0.026), "pal_blood_deep", rot=(0, 0, 10))
    p.box((0.16, 0.22, 0.03), (0.05, yc, H + 0.026), "pal_vellum", rot=(0, 0, 10))
    for k, (x, h) in enumerate(((0.3, 0.09), (0.36, 0.06))):
        p.box((0.1, 0.1, h), (x, yc + 0.05, H + h / 2 + (0.0 if k == 0 else 0.09)), "pal_umber" if k == 0 else "pal_peat")


@model("bar_counter", "against_wall", ["bar_counter", "bar_counter_back"])
def bar_counter(p):
    """A tavern bar, one square of it: a planked top over a panelled front, a brass foot rail, a tankard."""
    W, D, H = 1.0, 0.5, 0.62
    yc = -D / 2 - 0.02
    p.box((W, D - 0.06, H - 0.05), (0, yc + 0.03, (H - 0.05) / 2), "pal_umber")
    p.box((W, D + 0.04, 0.05), (0, yc - 0.02, H - 0.025), WOOD)
    front = yc - D / 2 + 0.06 - 0.005
    for k in range(2):
        x = -W / 4 + k * W / 2
        p.box((W / 2 - 0.1, 0.012, H - 0.2), (x, front, 0.08 + (H - 0.2) / 2), "pal_walnut")
    p.cyl(0.012, W, (-W / 2, front - 0.08, 0.1), "pal_tan", rot=(0, 90, 0), segs=6)
    for x in (-W / 2 + 0.05, W / 2 - 0.05):
        p.box((0.02, 0.08, 0.02), (x, front - 0.04, 0.1), "pal_tan")
    p.lathe([(0.0, 0.0), (0.035, 0.0), (0.038, 0.1), (0.0, 0.1)], (0.25, yc - 0.05, H), "pal_pewter", segs=10)
    p.tube(curve((0.29, yc - 0.05, H + 0.08), (0.33, yc - 0.05, H + 0.05), (0.29, yc - 0.05, H + 0.02), n=5), 0.008,
           "pal_pewter")


@model("woodpile", "free", ["woodpile"])
def woodpile(p):
    """The 2D woodpile: split logs stacked in a pyramid, bark dark and the cut ends pale."""
    L = 0.8
    rows = [(4, 0.0), (3, 1.0), (2, 2.0)]
    r = 0.075
    rng = p.rng
    for n, row in rows:
        for k in range(n):
            y = (k - (n - 1) / 2) * 2 * r * 1.02
            z = r + row * 1.75 * r
            x0 = -L / 2 + rng.uniform(-0.04, 0.04)
            p.cyl(r * rng.uniform(0.9, 1.05), L, (x0, y, z), "pal_rust", rot=(0, 90, 0), segs=7, smooth=False)
            for s in (-1, 1):
                p.cyl(r * 0.92, 0.01, (x0 + (L + 0.003 if s > 0 else -0.013), y, z), "pal_tan", rot=(0, 90, 0), segs=7,
                      smooth=False)
    for s in (-1, 1):
        p.box((0.05, 0.05, 0.45), (s * (L / 2 + 0.04), 0.0, 0.225), "pal_umber")


@model("workbench", "against_wall", ["workbench", "workbench_back", "workbench_front"])
def workbench(p):
    """The 2D workbench: a thick top on square legs, a shelf below, tools, a vice and shavings."""
    W, D, H = 0.98, 0.5, 0.52
    yc = -D / 2 - 0.02
    p.box((W, D, 0.06), (0, yc, H - 0.03), WOOD)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((0.07, 0.07, H - 0.06), (sx * (W / 2 - 0.06), yc + sy * (D / 2 - 0.06), (H - 0.06) / 2), "pal_umber")
    p.box((W - 0.1, D - 0.1, 0.03), (0, yc, 0.12), WOOD)
    p.box((0.12, 0.1, 0.08), (W / 2 - 0.12, yc - D / 2 + 0.02, H + 0.02), "pal_stone_deep")
    p.cyl(0.008, 0.16, (W / 2 - 0.12, yc - D / 2 - 0.06, H + 0.02), "pal_slate", rot=(90, 0, 0), segs=6)
    p.box((0.22, 0.04, 0.03), (-0.2, yc + 0.05, H + 0.015), "pal_umber", rot=(0, 0, 20))
    p.box((0.06, 0.03, 0.05), (-0.1, yc + 0.08, H + 0.025), "pal_slate", rot=(0, 0, 20))
    p.box((0.3, 0.005, 0.08), (0.1, yc + 0.12, H + 0.04), "pal_pewter", rot=(0, 0, -8))
    for k in range(4):
        p.box((0.012, 0.13, 0.012), (-0.05 + k * 0.035, yc - 0.1, H + 0.006), "pal_umber" if k % 2 else "pal_slate")
    for k in range(8):
        p.box((0.03, 0.02, 0.004), (p.rng.uniform(-0.3, 0.3), yc + p.rng.uniform(-0.2, 0.2), 0.0025), "pal_tan",
              rot=(0, 0, p.rng.uniform(0, 180)))


@model("notice_board", "free", ["notice_board", "notice_board_back"])
def notice_board(p):
    """The 2D notice board: two posts, a board of pinned notices, a little shingled roof."""
    W, H = 0.8, 1.5
    for s in (-1, 1):
        p.box((0.07, 0.07, H), (s * (W / 2 + 0.035), 0, H / 2), "pal_umber")
    p.box((W, 0.04, 0.6), (0, 0, 0.95), WOOD)
    rng = p.rng
    for k in range(8):
        w, h = rng.uniform(0.1, 0.15), rng.uniform(0.12, 0.17)
        p.box((w, 0.004, h), (rng.uniform(-W / 2 + 0.12, W / 2 - 0.12), -0.024, rng.uniform(0.75, 1.15)),
              rng.choice(["pal_parchment", "pal_parchment", "pal_bone", "pal_vellum"]), rot=(0, rng.uniform(-8, 8), 0))
    for s in (-1, 1):
        p.box((W / 2 + 0.08, 0.36, 0.03), (s * (W / 4 + 0.04) * 0.98, 0.0, H + 0.04), "pal_slate", rot=(0, s * 24, 0))
    p.box((0.05, 0.4, 0.05), (0, 0, H + 0.13), "pal_umber")


def _tomb(p, W, D, H, stone, panel):
    p.box((W + 0.06, D + 0.06, 0.08), (0, 0, 0.04), stone)
    p.box((W, D, H - 0.14), (0, 0, 0.08 + (H - 0.14) / 2), stone)
    p.box((W + 0.05, D + 0.05, 0.07), (0, 0, H - 0.035), stone)
    for s in (-1, 1):
        p.box((W - 0.14, 0.01, H - 0.3), (0, s * (D / 2 + 0.004), 0.08 + (H - 0.14) / 2), panel)
        p.box((0.01, D - 0.14, H - 0.3), (s * (W / 2 + 0.004), 0, 0.08 + (H - 0.14) / 2), panel)


@model("crypt_small", "free", ["crypt_small", "crypt_small_back"])
def crypt_small(p):
    """The 2D small tomb: a pale stone chest-tomb with red-painted panels."""
    _tomb(p, 0.86, 0.5, 0.55, "pal_parchment", "pal_blood")


@model("crypt", "free", ["crypt", "crypt_back"])
def crypt(p):
    """The 2D sarcophagus: a grey stone tomb with red panels and a carved effigy lying on the lid."""
    W, D, H = 0.96, 0.58, 0.6
    _tomb(p, W, D, H, "pal_pewter", "pal_blood")
    p.box((0.62, 0.26, 0.08), (0.04, 0, H + 0.04), "pal_silver", soft=0.03)
    p.box((0.3, 0.2, 0.05), (0.12, 0, H + 0.1), "pal_silver", soft=0.02)
    p.lathe([(0.0, 0.0), (0.06, 0.01), (0.065, 0.05), (0.05, 0.09), (0.0, 0.1)], (-0.32, 0, H + 0.02), "pal_silver",
            rot=(0, 90, 0), segs=10)
    p.box((0.12, 0.2, 0.02), (-0.36, 0, H + 0.01), "pal_slate")


@model("gravestone", "free", ["gravestone", "gravestone_back"])
def gravestone(p):
    """The 2D gravestone: a round-topped slab on a plinth, mossy at the foot."""
    W, T, H = 0.5, 0.12, 0.75
    p.box((W + 0.12, T + 0.14, 0.08), (0, 0, 0.04), "pal_slate")
    slab = [(-W / 2, 0.0), (W / 2, 0.0)] + list(reversed(arch(-W / 2, W / 2, H - W / 2, W / 2, n=12, pointed=False)))
    p.prism(slab, T, (0, 0, 0.08), "pal_pewter")
    p.prism([(-0.14, 0.0), (0.14, 0.0), (0.14, 0.2), (-0.14, 0.2)], 0.01, (0, -T / 2 - 0.004, 0.32), "pal_slate")
    for k in range(4):
        p.box((0.1, T + 0.03, 0.04), (-W / 2 + 0.06 + k * 0.12, 0, 0.1), "pal_moss", soft=0.012)


@model("cask_rack", "against_wall", ["cask_rack", "cask_rack_front"])
def cask_rack(p):
    """The 2D cask rack: a timber frame holding two tiers of barrels on their sides."""
    W, D, H = 0.98, 0.5, 0.78
    yc = -D / 2 - 0.01
    for sx in (-1, 0, 1):
        for sy in (-1, 1):
            p.box((0.05, 0.05, H), (sx * (W / 2 - 0.025), yc + sy * (D / 2 - 0.025), H / 2), "pal_umber")
    for z in (0.04, 0.4):
        for sy in (-1, 1):
            p.box((W, 0.05, 0.04), (0, yc + sy * (D / 2 - 0.025), z), "pal_umber")
    prof = [(0.0, 0.0), (0.13, 0.0), (0.15, 0.12), (0.155, D / 2 - 0.02), (0.15, D - 0.16), (0.13, D - 0.04), (0.0, D - 0.04)]
    for row, zc in ((0, 0.2), (1, 0.56)):
        for k in range(3):
            x = -W / 3 + k * W / 3
            p.lathe(prof, (x, yc - D / 2 + 0.02, zc), "pal_walnut", rot=(-90, 0, 0), segs=14, smooth=False)
            for yy in (0.08, D - 0.12):
                p.lathe([(0.157, -0.012), (0.163, -0.01), (0.163, 0.01), (0.157, 0.012)], (x, yc - D / 2 + 0.02 + yy, zc),
                        "pal_stone_deep", rot=(-90, 0, 0), segs=14, smooth=False)


def _well_ring(p, R, H, stone):
    """A round well head of stone blocks."""
    rng = p.rng
    courses = 3
    for c in range(courses):
        n = 12
        for k in range(n):
            a = 2 * math.pi * (k + 0.5 * (c % 2)) / n
            p.box((0.13, 2 * math.pi * R / n - 0.012, H / courses - 0.012),
                  (R * math.cos(a), R * math.sin(a), (c + 0.5) * H / courses), rng.choice(stone),
                  rot=(0, 0, math.degrees(a)))
    p.cyl(R - 0.06, 0.02, (0, 0, H - 0.05), "pal_void", segs=16, smooth=False)


@model("well_stone", "free", ["well_stone"])
def well_stone(p):
    """The 2D stone well: a ring of grey-blue blocks, a timber frame with a winch, a rope and a bucket."""
    R, H = 0.34, 0.42
    _well_ring(p, R, H, ["pal_slate", "pal_stone", "pal_pewter"])
    for s in (-1, 1):
        p.box((0.06, 0.06, 0.6), (s * (R + 0.04), 0, H + 0.3 - 0.1), "pal_umber")
    p.cyl(0.035, 2 * R + 0.16, (-R - 0.08, 0, H + 0.42), "pal_walnut", rot=(0, 90, 0), segs=10)
    p.tube([(R + 0.08, 0, H + 0.42), (R + 0.12, 0, H + 0.42), (R + 0.12, 0, H + 0.3)], 0.012, "pal_stone_deep", segs=5)
    p.cyl(0.008, 0.3, (0, 0, H + 0.1), "pal_tan", segs=5)
    p.lathe([(0.0, 0.0), (0.07, 0.0), (0.08, 0.1), (0.0, 0.1)], (0, 0, H + 0.02), "pal_umber", segs=10)


@model("well", "free", ["well"])
def well(p):
    """The 2D village well: a stone ring under a little shingled roof on two posts, with a bucket on a rope."""
    R, H = 0.34, 0.42
    _well_ring(p, R, H, ["pal_stone", "pal_slate", "pal_blood_deep", "pal_stone"])
    for s in (-1, 1):
        p.box((0.07, 0.07, 1.1), (s * (R + 0.02), 0, H - 0.05 + 0.55), "pal_umber")
        p.box((R + 0.18, 0.75, 0.035), (s * (R + 0.18) / 2 * 0.95, 0, H + 1.12), WOOD, rot=(0, s * 32, 0))
    p.cyl(0.035, 2 * R + 0.12, (-R - 0.06, 0, H + 0.62), "pal_walnut", rot=(0, 90, 0), segs=10)
    p.cyl(0.008, 0.4, (0, 0, H + 0.2), "pal_tan", segs=5)
    p.lathe([(0.0, 0.0), (0.08, 0.0), (0.09, 0.12), (0.0, 0.12)], (0, 0, H + 0.08), "pal_umber", segs=10)


@model("bridge_parapet", "free", ["bridge_parapet", "bridge_parapet_back"])
def bridge_parapet(p):
    """The 2D bridge parapet: a low wall of pale coursed stone with a red-banded pier at one end."""
    W, T, H = 1.0, 0.24, 0.5
    rng = p.rng
    for c in range(3):
        x = -W / 2 + (0.1 if c % 2 else 0.0)
        while x < W / 2 - 0.2:
            ln = min(rng.uniform(0.18, 0.3), W / 2 - 0.2 - x)
            p.box((ln - 0.01, T, H / 3 - 0.01), (x + ln / 2, 0, (c + 0.5) * H / 3), rng.choice(["pal_parchment", "pal_bone"]))
            x += ln
    p.box((W - 0.16, T + 0.04, 0.05), (-0.08, 0, H + 0.025), "pal_parchment")
    p.box((0.22, T + 0.08, H + 0.18), (W / 2 - 0.11, 0, (H + 0.18) / 2), "pal_parchment")
    p.box((0.24, T + 0.1, 0.05), (W / 2 - 0.11, 0, 0.2), "pal_blood")
    p.box((0.26, T + 0.12, 0.05), (W / 2 - 0.11, 0, H + 0.2), "pal_bone")


@model("signpost", "free", ["signpost", "signpost_back"])
def signpost(p):
    """The 2D signpost: a leaning post with two arrow boards pointing different ways."""
    p.box((0.08, 0.08, 1.5), (0, 0, 0.75), "pal_umber", rot=(0, 3, 0))
    arrow = [(-0.32, -0.08), (0.22, -0.08), (0.34, 0.0), (0.22, 0.08), (-0.32, 0.08)]
    p.prism(arrow, 0.03, (0.18, -0.05, 1.32), WOOD, rot=(0, 0, 8))
    p.prism([(-x, z) for x, z in arrow], 0.03, (-0.16, -0.05, 1.1), WOOD, rot=(0, 0, -12))
    p.box((0.2, 0.2, 0.05), (0, 0, 0.025), "pal_stone")


@model("cart_broken", "free", ["cart_broken", "cart_broken_back"], big=True)
def cart_broken(p):
    """The 2D broken hand cart: a plank bed tipped on one good wheel, a wheel fallen flat, straw spilling out."""
    L, W = 1.0, 0.6
    p.box((L, W, 0.05), (0, 0, 0.3), WOOD, rot=(0, -8, 0))
    for s in (-1, 1):
        p.box((L, 0.035, 0.18), (0, s * (W / 2 - 0.018), 0.4), "pal_umber", rot=(0, -8, 0))
    _wheel(p, (0.1, W / 2 + 0.06, 0.3), 0.3)
    p.box((0.05, 0.6, 0.04), (0.02, 0.0, 0.07), "pal_peat")
    for s in (-1, 1):
        p.tube([(-L / 2, s * 0.2, 0.32), (-L / 2 - 0.4, s * 0.24, 0.04)], 0.025, "pal_umber", segs=6)
    for k in range(10):
        p.box((0.24, 0.012, 0.012), (p.rng.uniform(-0.35, 0.3), p.rng.uniform(-0.2, 0.2), 0.34 + p.rng.uniform(0, 0.08)),
              "pal_tan", rot=(p.rng.uniform(-20, 20), p.rng.uniform(-15, 15), p.rng.uniform(0, 180)))


# --- Nature (rollout batch 5) ----------------------------------------------------------------------------------
# Trees, brambles and stones come in a few variants each (the catalog lists them; the board picks one by place) and
# are free to turn (manifest "turns"): the board gives each copy its own heading, as nature has no front.

def _pine(p, H, tiers, bare=0.45, crown="pal_bog_deep", crown_hi="pal_bog", trunk="pal_peat", width=0.62, trunk_r=0.11):
    rng = p.rng
    p.lathe([(trunk_r, 0.0), (trunk_r * 0.75, 0.15), (trunk_r * 0.65, bare + 0.3), (trunk_r * 0.35, H * 0.8), (0.0, H * 0.85)],
            (0, 0, 0), trunk, segs=8, smooth=False)
    for k in range(4):
        a = rng.uniform(0, 2 * math.pi)
        p.tube([(0.06 * math.cos(a), 0.06 * math.sin(a), 0.1), (0.2 * math.cos(a), 0.2 * math.sin(a), -0.02)],
               0.03, trunk, segs=5, radii=[0.04, 0.012])
    span = H - bare
    for i in range(tiers):
        f = i / (tiers - 1)
        z = bare + f * span * 0.82
        r = width * (1.0 - f * 0.82) * rng.uniform(0.92, 1.05)
        h = span * 0.32 * (1.0 - f * 0.35)
        p.tier((rng.uniform(-0.02, 0.02), rng.uniform(-0.02, 0.02), z), r, h, crown if i % 2 == 0 else crown_hi, "pal_void",
               points=rng.choice([7, 8, 9]), droop=0.05 + 0.05 * (1 - f), twist=rng.uniform(0, 1))
    p.lathe([(0.05, 0.0), (0.0, 0.25)], (0, 0, bare + span * 0.82 + span * 0.2), crown_hi, segs=6, smooth=False)


@model("pine_a", "free", ["pine"], turns=True)
def pine_a(p):
    """The 2D Barovian pine: a dark trunk under stacked tiers of drooping, jagged branches."""
    _pine(p, 3.0, 7)


@model("pine_b", "free", ["pine"], turns=True)
def pine_b(p):
    _pine(p, 3.3, 8, bare=0.55)


@model("pine_c", "free", ["pine"], turns=True)
def pine_c(p):
    _pine(p, 2.7, 6, bare=0.35, crown="pal_bog", crown_hi="pal_bog_deep")


@model("pine_clawed", "free", ["pine_clawed"], turns=True)
def pine_clawed(p):
    """The 2D clawed pine: a tall bare trunk raked by claws, a sparse crown high up."""
    _pine(p, 3.4, 5, bare=1.6, crown="pal_night", crown_hi="pal_moon_blue", trunk="pal_ash_violet", width=0.8, trunk_r=0.26)
    for k in range(4):
        p.box((0.02, 0.012, 0.5), (-0.05 + k * 0.035, -0.19, 1.0), "pal_parchment", rot=(0, 12, 0))


def _dead_tree(p, H, lean):
    rng = p.rng
    bark = "pal_ash_violet"
    pts, radii = [], []
    n = 7
    for i in range(n):
        f = i / (n - 1)
        pts.append((lean * math.sin(f * math.pi * 1.2) + rng.uniform(-0.04, 0.04) * f, rng.uniform(-0.05, 0.05) * f, f * H))
        radii.append(0.2 * (1 - f) ** 1.3 + 0.025)
    p.tube(pts, 0.1, bark, segs=7, radii=radii, smooth=False)
    for k in range(3):
        a = rng.uniform(0, 2 * math.pi)
        p.tube([(0.05 * math.cos(a), 0.05 * math.sin(a), 0.15), (0.3 * math.cos(a), 0.3 * math.sin(a), -0.02)], 0.04, bark,
               segs=5, radii=[0.07, 0.015], smooth=False)

    def branch(start, direction, length, radius, depth):
        end = Vector(start) + Vector(direction).normalized() * length
        mid = (Vector(start) + end) / 2 + Vector((rng.uniform(-0.08, 0.08), rng.uniform(-0.08, 0.08), rng.uniform(0, 0.08)))
        p.tube([tuple(start), tuple(mid), tuple(end)], radius, bark, segs=5, radii=[radius, radius * 0.6, radius * 0.25],
               smooth=False)
        if depth > 0:
            for _ in range(2):
                d = Vector(direction).normalized() + Vector((rng.uniform(-0.7, 0.7), rng.uniform(-0.7, 0.7), rng.uniform(0.0, 0.6)))
                branch(tuple(end), tuple(d), length * 0.6, radius * 0.5, depth - 1)
    for i in range(2, n):
        f = i / (n - 1)
        for _ in range(2 if i < n - 1 else 3):
            a = rng.uniform(0, 2 * math.pi)
            branch(pts[i], (math.cos(a), math.sin(a), rng.uniform(0.3, 1.0)), H * 0.3 * (1.15 - f * 0.5), radii[i] * 0.65, 2)
    for k in range(3):
        z = rng.uniform(0.3, H * 0.6)
        p.box((0.03, 0.012, 0.3), (lean * math.sin(z / H * math.pi * 1.2) + 0.04, -0.17 + z * 0.03, z), "pal_blood",
              rot=(0, rng.uniform(-10, 10), 0))


@model("dead_tree_a", "free", ["dead_tree"], turns=True)
def dead_tree_a(p):
    """The 2D dead tree: a twisted grey-violet trunk streaked red, bare branches clawing upward."""
    _dead_tree(p, 2.3, 0.25)


@model("dead_tree_b", "free", ["dead_tree"], turns=True)
def dead_tree_b(p):
    _dead_tree(p, 2.6, -0.3)


def _thorns(p, n, height, spread, stem, leaf=None):
    rng = p.rng
    for _ in range(n):
        a = rng.uniform(0, 2 * math.pi)
        r0 = rng.uniform(0.0, spread * 0.4)
        start = (r0 * math.cos(a), r0 * math.sin(a), 0.0)
        b = a + rng.uniform(-1.2, 1.2)
        r1 = rng.uniform(spread * 0.5, spread)
        end = (r1 * math.cos(b), r1 * math.sin(b), rng.uniform(0.0, height * 0.4))
        top = ((start[0] + end[0]) / 2, (start[1] + end[1]) / 2, height * rng.uniform(0.7, 1.1))
        pts = curve(start, top, end, n=6)
        p.tube(pts, 0.016, stem, segs=4, radii=[0.022, 0.019, 0.016, 0.013, 0.01, 0.007, 0.004])
        if leaf:
            for j in (2, 4):
                x, y, z = pts[j]
                p.prism([(0.0, 0.0), (0.03, 0.025), (0.0, 0.07), (-0.03, 0.025)], 0.006, (x, y, z), leaf,
                        rot=(rng.uniform(-60, 60), rng.uniform(-60, 60), rng.uniform(0, 180)))


@model("bramble_a", "free", ["bramble_a"], turns=True)
def bramble_a(p):
    """The 2D bramble: arching thorny canes, dark leaves."""
    _thorns(p, 26, 0.5, 0.45, "pal_umber", "pal_bruise")


@model("bramble_b", "free", ["bramble_b"], turns=True)
def bramble_b(p):
    """The 2D dead bramble: dry grey canes and dead grass."""
    _thorns(p, 18, 0.45, 0.42, "pal_stone")
    rng = p.rng
    for _ in range(18):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0, 0.3)
        h = rng.uniform(0.2, 0.42)
        p.prism([(-0.012, 0.0), (0.012, 0.0), (0.0, h)], 0.004, (r * math.cos(a), r * math.sin(a), 0.0),
                rng.choice(["pal_bone", "pal_bone_dark", "pal_stone"]), rot=(rng.uniform(-15, 15), rng.uniform(-15, 15),
                                                                         rng.uniform(0, 180)))


@model("boulder_a", "free", ["boulder"], turns=True)
def boulder_a(p):
    """The 2D boulder: a grey stone, moss on its crown."""
    p.rock((0, 0, 0), (0.95, 0.8, 0.68), "pal_slate", top="pal_moss", rough=0.12, subdiv=2, top_z=0.9, top_p=0.5)


@model("boulder_b", "free", ["boulder"], turns=True)
def boulder_b(p):
    p.rock((0, 0, 0), (0.9, 0.85, 0.58), "pal_pewter", top="pal_slate", rough=0.14, subdiv=2, top_z=0.85, top_p=0.6)
    p.rock((0.32, -0.22, 0), (0.32, 0.28, 0.22), "pal_slate", rough=0.2, subdiv=1)


@model("log", "free", ["log"], turns=True)
def log(p):
    """The 2D fallen log: rough bark, a hollow end, moss along its back, a broken-off branch."""
    L, R = 0.85, 0.16
    p.cyl(R, L, (-L / 2, 0, R), "pal_rust", rot=(0, 90, 0), segs=9, smooth=False)
    p.cyl(R * 0.7, 0.01, (L / 2 - 0.002, 0, R), "pal_void", rot=(0, 90, 0), segs=9, smooth=False)
    p.cyl(R * 0.98, 0.01, (-L / 2 - 0.008, 0, R), "pal_tan", rot=(0, 90, 0), segs=9, smooth=False)
    p.box((L * 0.7, 0.12, 0.03), (-0.05, 0.02, 2 * R - 0.005), "pal_moss", soft=0.01)
    p.tube([(0.1, 0.0, 2 * R - 0.02), (0.18, 0.05, 2 * R + 0.12)], 0.03, "pal_rust", segs=5, radii=[0.035, 0.02])


@model("stump", "free", ["stump"], turns=True)
def stump(p):
    """The 2D stump: a flared trunk snapped off jaggedly, roots gripping the ground."""
    rng = p.rng
    p.lathe([(0.24, 0.0), (0.18, 0.08), (0.16, 0.2), (0.16, 0.38), (0.0, 0.38)], (0, 0, 0), "pal_slate", segs=10, smooth=False)
    p.cyl(0.135, 0.012, (0, 0, 0.38), "pal_rust", segs=10, smooth=False)
    for k in range(5):
        a = 2 * math.pi * k / 5 + rng.uniform(-0.3, 0.3)
        h = rng.uniform(0.06, 0.18)
        p.prism([(-0.05, 0.0), (0.05, 0.0), (0.0, h)], 0.03, (0.13 * math.cos(a), 0.13 * math.sin(a), 0.38), "pal_slate",
                rot=(0, 0, math.degrees(a) + 90))
    for k in range(5):
        a = 2 * math.pi * k / 5 + rng.uniform(-0.2, 0.2)
        p.tube(curve((0.12 * math.cos(a), 0.12 * math.sin(a), 0.12), (0.28 * math.cos(a), 0.28 * math.sin(a), 0.02),
                     (0.42 * math.cos(a), 0.42 * math.sin(a), 0.0), n=5), 0.04, "pal_slate", segs=6,
               radii=[0.07, 0.055, 0.042, 0.03, 0.02, 0.01], smooth=False)


@model("rubble", "free", ["rubble"], turns=True)
def rubble(p):
    """The 2D rubble: broken stone blocks and chips scattered over a square."""
    rng = p.rng
    for _ in range(4):
        s = rng.uniform(0.16, 0.26)
        p.box((s, s * rng.uniform(0.6, 1.0), s * rng.uniform(0.4, 0.7)), (rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), s * 0.25),
              rng.choice(["pal_slate", "pal_stone", "pal_pewter"]), rot=(rng.uniform(-15, 15), rng.uniform(-15, 15), rng.uniform(0, 90)))
    for _ in range(10):
        p.rock((rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), 0), (rng.uniform(0.06, 0.12),) * 3, rng.choice(["pal_slate", "pal_stone"]),
               rough=0.3, subdiv=0)


@model("cairn", "free", ["cairn"], turns=True)
def cairn(p):
    """The 2D cairn: a cone of stacked grey stones."""
    rng = p.rng
    z = 0.0
    for ring, (r, n) in enumerate(((0.26, 7), (0.18, 5), (0.1, 4), (0.0, 1), (0.0, 1))):
        h = 0.17 - ring * 0.02
        for k in range(n):
            a = 2 * math.pi * k / n + ring
            p.rock((r * math.cos(a), r * math.sin(a), z), (0.26 - ring * 0.03, 0.22 - ring * 0.025, h), rng.choice(
                ["pal_slate", "pal_pewter", "pal_slate"]), rough=0.12, subdiv=1, bury=0.0)
        z += h * 0.75


@model("snowdrift", "free", ["snowdrift"], turns=True)
def snowdrift(p):
    """The 2D snowdrift: a soft heap of snow, blue in its hollows."""
    p.rock((0, 0, 0), (0.95, 0.8, 0.3), "pal_moonlight", top="pal_frost", rough=0.08, subdiv=2, bury=0.35, smooth=True, top_z=0.5, top_p=1.0)
    p.rock((0.25, 0.2, 0), (0.4, 0.35, 0.18), "pal_moonlight", top="pal_frost", rough=0.1, subdiv=2, bury=0.3, smooth=True,
           top_z=0.5, top_p=1.0)


@model("ice_patch", "free", ["ice_patch"], turns=True)
def ice_patch(p):
    """The 2D ice patch: a thin glassy sheet with white cracks."""
    rng = p.rng
    outline = [((0.42 + rng.uniform(-0.06, 0.04)) * math.cos(a), (0.4 + rng.uniform(-0.06, 0.04)) * math.sin(a))
               for a in (2 * math.pi * k / 14 for k in range(14))]
    p.prism(outline, 0.02, (0, 0, 0.01), "pal_moonlight", rot=(90, 0, 0))
    for _ in range(5):
        a = rng.uniform(0, 2 * math.pi)
        p.box((rng.uniform(0.15, 0.32), 0.008, 0.004), (0.1 * math.cos(a), 0.1 * math.sin(a), 0.022), "pal_frost",
              rot=(0, 0, math.degrees(a)))


@model("reeds", "free", ["reeds"], turns=True)
def reeds(p):
    """The 2D reeds: a clump of tall blades and bulrush heads."""
    rng = p.rng
    for _ in range(22):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0, 0.22)
        h = rng.uniform(0.45, 0.85)
        p.prism([(-0.014, 0.0), (0.014, 0.0), (0.0, h)], 0.004, (r * math.cos(a), r * math.sin(a), 0.0),
                rng.choice(["pal_moss", "pal_bog", "pal_sickly"]), rot=(rng.uniform(-10, 10), rng.uniform(-10, 10),
                                                                     rng.uniform(0, 180)))
    for _ in range(6):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0, 0.18)
        h = rng.uniform(0.55, 0.8)
        x, y = r * math.cos(a), r * math.sin(a)
        p.cyl(0.005, h, (x, y, 0.0), "pal_bog", segs=4)
        p.cyl(0.018, 0.1, (x, y, h - 0.04), "pal_rust", segs=6)


@model("leaves", "free", ["leaves"], turns=True)
def leaves(p):
    """The 2D fallen leaves: a drift of curled brown and red leaves on the ground."""
    rng = p.rng
    for _ in range(26):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0, 0.42)
        s = rng.uniform(0.05, 0.08)
        p.prism([(0.0, -s), (s * 0.5, -s * 0.2), (s * 0.35, s * 0.6), (0.0, s), (-s * 0.35, s * 0.6), (-s * 0.5, -s * 0.2)], 0.004,
                (r * math.cos(a), r * math.sin(a), 0.006), rng.choice(["pal_rust", "pal_ember", "pal_umber", "pal_blood"]),
                rot=(90 + rng.uniform(-20, 20), rng.uniform(-20, 20), rng.uniform(0, 180)))


@model("grave_mound", "free", ["grave_mound"])
def grave_mound(p):
    """The 2D fresh grave: a long mound of earth, a crude wooden cross at its head."""
    p.rock((0, -0.05, 0), (0.42, 0.85, 0.22), "pal_rust", top="pal_leather", rough=0.08, subdiv=2, bury=0.3, smooth=True,
           top_z=0.8, top_p=0.7)
    p.box((0.05, 0.05, 0.5), (0, 0.42, 0.25), "pal_walnut", rot=(0, 6, 0))
    p.box((0.26, 0.04, 0.05), (0, 0.42, 0.4), "pal_walnut", rot=(0, 6, 0))


@model("hay_bale", "free", ["hay_bale"])
def hay_bale(p):
    """The 2D hay bale: a squared bale of straw bound with twine."""
    p.box((0.75, 0.42, 0.42), (0, 0, 0.21), "pal_parchment", soft=0.04)
    for x in (-0.2, 0.2):
        p.box((0.025, 0.44, 0.44), (x, 0, 0.21), "pal_bone_dark", soft=0.01)
    rng = p.rng
    for _ in range(12):
        p.box((0.12, 0.006, 0.006), (rng.uniform(-0.35, 0.35), rng.uniform(-0.22, 0.22), 0.43), "pal_parchment",
              rot=(0, rng.uniform(-20, 20), rng.uniform(0, 180)))


@model("garden_bed", "free", ["garden_bed"])
def garden_bed(p):
    """The 2D garden bed: a low frame of dark soil, frost-bitten cabbages and dead stalks."""
    rng = p.rng
    p.box((0.92, 0.92, 0.08), (0, 0, 0.04), "pal_peat")
    for s in (-1, 1):
        p.box((0.96, 0.04, 0.1), (0, s * 0.46, 0.05), "pal_umber")
        p.box((0.04, 0.96, 0.1), (s * 0.46, 0, 0.05), "pal_umber")
    for x in (-0.25, 0.0, 0.25):
        for y in (-0.25, 0.1):
            p.rock((x + rng.uniform(-0.04, 0.04), y + rng.uniform(-0.04, 0.04), 0.08), (0.16, 0.16, 0.12), "pal_mist_blue",
                   top="pal_moonlight", rough=0.12, subdiv=2, bury=0.1, smooth=True, top_z=0.8, top_p=1.0)
    for _ in range(6):
        p.cyl(0.008, rng.uniform(0.15, 0.3), (rng.uniform(-0.38, 0.38), rng.uniform(0.25, 0.4), 0.08), "pal_bone_dark", segs=4)


@model("vines", "free", ["vines"])
def vines(p):
    """The 2D vine row: posts and wires carrying gnarled vines, dark leaves and bunches of grapes."""
    rng = p.rng
    for x in (-0.46, 0.46):
        p.box((0.06, 0.06, 1.0), (x, 0, 0.5), "pal_umber")
    for z in (0.45, 0.85):
        p.cyl(0.004, 0.92, (-0.46, 0, z), "pal_stone_deep", rot=(0, 90, 0), segs=4)
    for x0 in (-0.22, 0.22):
        p.tube([(x0, 0, 0.0), (x0 + 0.03, 0, 0.3), (x0 - 0.02, 0, 0.45), (x0 + 0.18, 0, 0.5), (x0 + 0.24, 0, 0.82)], 0.03,
               "pal_umber", segs=5, radii=[0.04, 0.03, 0.025, 0.02, 0.012])
        p.tube([(x0 - 0.02, 0, 0.45), (x0 - 0.2, 0, 0.5), (x0 - 0.24, 0, 0.85)], 0.02, "pal_umber", segs=5, radii=[0.025, 0.018, 0.01])
    for _ in range(22):
        p.prism([(0.0, 0.0), (0.04, 0.04), (0.0, 0.09), (-0.04, 0.04)], 0.006,
                (rng.uniform(-0.42, 0.42), rng.uniform(-0.05, 0.05), rng.uniform(0.4, 0.95)), rng.choice(["pal_bog", "pal_bog_deep", "pal_moss"]),
                rot=(rng.uniform(-40, 40), rng.uniform(-40, 40), rng.uniform(0, 180)))
    for _ in range(5):
        x, z = rng.uniform(-0.38, 0.38), rng.uniform(0.38, 0.7)
        for k in range(6):
            p.rock((x + rng.uniform(-0.025, 0.025), -0.05 + rng.uniform(-0.02, 0.02), z - k * 0.018), (0.035, 0.035, 0.035),
                   "pal_plum", rough=0.05, subdiv=1, bury=0.0)


# --- Depth from the 2D art (rollout batch 6) -------------------------------------------------------------------
# Figurative pieces (statues, stuffed animals, skeletons, dolls) are sculpted from their own 2D art: the sprite's
# silhouette becomes a solid whose front swells toward its middle, painted with the sprite (its back with the 2D back
# view where there is one, else the front mirrored). They take light and shadow and have real thickness from every side.

PROPS = json.loads((ROOT / "art" / "sprites" / "props" / "manifest.json").read_text())["props"]


def _alpha_grid(art, rows):
    """The sprite's coverage on a grid `rows` tall: grid[r][c] True where it's painted (r from the bottom)."""
    info = PROPS[art]
    img = bpy.data.images.load(str(ROOT / info["file"]))
    w, h = img.size
    px = img.pixels[:]
    bpy.data.images.remove(img)
    cols = max(2, round(rows * w / h))
    grid = []
    for r in range(rows):
        row = []
        for c in range(cols):
            x = min(w - 1, int((c + 0.5) * w / cols))
            y = min(h - 1, int((r + 0.5) * h / rows))
            row.append(px[(y * w + x) * 4 + 3] > 0.5)
        grid.append(row)
    return grid, cols


def _distance(grid, rows, cols):
    """Chamfer distance from each painted cell to the nearest empty one (outside counts as empty)."""
    INF = 10 ** 6
    d = [[0 if not grid[r][c] else INF for c in range(cols)] for r in range(rows)]

    def at(r, c):
        return d[r][c] if 0 <= r < rows and 0 <= c < cols else 0
    for r in range(rows):
        for c in range(cols):
            if d[r][c]:
                d[r][c] = min(d[r][c], at(r - 1, c) + 1, at(r, c - 1) + 1, at(r - 1, c - 1) + 1.4, at(r - 1, c + 1) + 1.4)
    for r in reversed(range(rows)):
        for c in reversed(range(cols)):
            if d[r][c]:
                d[r][c] = min(d[r][c], at(r + 1, c) + 1, at(r, c + 1) + 1, at(r + 1, c + 1) + 1.4, at(r + 1, c - 1) + 1.4)
    return d


def inflate(p, art, height, depth=0.3, rows=56, back=None, at=(0.0, 0.0, 0.0), rim="pal_ink"):
    """A solid `height` tall sculpted from 2D `art` (its silhouette, swelling to `depth` thick at its widest part),
    standing on `at` and facing -y; the front painted with the sprite, the back with `back` (or the front mirrored)."""
    grid, cols = _alpha_grid(art, rows)
    d = _distance(grid, rows, cols)
    dmax = max(max(row) for row in d) or 1
    cell = height / rows
    width = cell * cols
    half = depth / 2.0

    def hc(r, c):
        """Thickness at the corner (r, c): the mean swell of the four cells round it (outside cells count as flat)."""
        vals = []
        for rr in (r - 1, r):
            for cc in (c - 1, c):
                vals.append(math.sqrt(min(1.0, d[rr][cc] / (dmax * 0.6))) if 0 <= rr < rows and 0 <= cc < cols and grid[rr][cc] else 0.0)
        return half * (0.15 + 0.85 * sum(vals) / 4.0)
    t = bmesh.new()
    uv = t.loops.layers.uv.new("UVMap")
    front_v, back_v = {}, {}

    def vert(store, r, c, sign):
        if (r, c) not in store:
            x = at[0] - width / 2 + c * cell
            z = at[2] + r * cell
            store[(r, c)] = t.verts.new((x, at[1] - sign * hc(r, c), z))
        return store[(r, c)]
    fronts, backs, rims = [], [], []
    for r in range(rows):
        for c in range(cols):
            if not grid[r][c]:
                continue
            q = [(r, c), (r, c + 1), (r + 1, c + 1), (r + 1, c)]
            f = t.faces.new([vert(front_v, rr, cc, 1) for rr, cc in q])
            for loop, (rr, cc) in zip(f.loops, q):
                loop[uv].uv = (cc / cols, rr / rows)
            fronts.append(f)
            b = t.faces.new([vert(back_v, rr, cc, -1) for rr, cc in reversed(q)])
            for loop, (rr, cc) in zip(b.loops, reversed(q)):
                loop[uv].uv = ((cols - cc) / cols if back is None else (cols - cc) / cols, rr / rows)
            backs.append(b)
            for (dr, dc), (a, bb) in (((-1, 0), ((r, c), (r, c + 1))), ((1, 0), ((r + 1, c + 1), (r + 1, c))),
                                       ((0, -1), ((r + 1, c), (r, c))), ((0, 1), ((r, c + 1), (r + 1, c + 1)))):
                nr, nc = r + dr, c + dc
                if 0 <= nr < rows and 0 <= nc < cols and grid[nr][nc]:
                    continue
                rf = t.faces.new([vert(front_v, *a, 1), vert(back_v, *a, -1), vert(back_v, *bb, -1), vert(front_v, *bb, 1)])
                rims.append(rf)
    bmesh.ops.recalc_face_normals(t, faces=t.faces)
    front_set, back_set = set(fronts), set(backs)
    p._append_faces(t, lambda f: ("spr_" + art) if f in front_set else (("spr_" + (back or art)) if f in back_set else rim),
                    smooth=True)


# Sculpted from their 2D art: art -> (height in world units, thickness as a share of the width).
SCULPTED = {
    "statue_knight": (1.4, 0.45), "armor_stand": (1.2, 0.45), "armor_wolf_helm": (1.4, 0.45), "statue_saint": (1.8, 0.42),
    "statue_strahd": (1.4, 0.4), "statue_head": (0.3, 0.8), "statue_mother_night": (1.6, 0.4), "scarecrow": (1.4, 0.3),
    "scarecrow_stitched": (1.4, 0.3), "stuffed_wolf": (0.8, 0.5), "horse": (1.4, 0.35), "carcass": (0.5, 0.5),
    "skeleton_leather": (0.7, 0.35), "doll": (0.4, 0.45), "doll_yellow": (0.4, 0.45), "poppet": (0.3, 0.45),
    "crow_barrel": (0.8, 0.8), "charms": (1.2, 0.15), "soul_bags": (1.2, 0.3), "frozen_traveller": (0.8, 0.5),
    "frozen_birds": (0.6, 0.35), "roc_nest": (0.7, 0.8), "dragon_bones": (1.6, 0.5), "mobile": (1.2, 0.15),
    "coats": (1.2, 0.25), "sheeted_furniture": (1.1, 0.6), "refuse_mound": (0.6, 0.8), "bones": (0.4, 0.6),
    "sword_leaning": (0.8, 0.15), "jewel_box": (0.7, 0.7), "music_box": (0.7, 0.7), "cage_hanging": (1.4, 0.6),
    "wicker_cage": (1.4, 0.6),
}
BIG_SCULPTED = {"horse", "dragon_bones"}


def _sculpt_builder(art, height, share):
    def build(p):
        info = PROPS[art]
        aspect = float(info.get("world_width", 1.0)) / float(info.get("world_height", 1.0))
        h = height
        if art not in BIG_SCULPTED and h * aspect > 0.98:
            h = 0.98 / aspect   # no wider than its square, as the 2D pieces were squeezed to fit
        rows = max(28, min(56, int(52 * min(1.0, math.sqrt(1.0 / aspect)))))
        inflate(p, art, h, depth=max(0.04, share * h * aspect), rows=rows, back=info.get("back"))
    build.__doc__ = "%s, sculpted from its 2D art." % art
    return build


for _art, (_h, _share) in SCULPTED.items():
    _back = PROPS.get(_art, {}).get("back")
    model(_art, "free", [_art] + ([_back] if _back else []), big=_art in BIG_SCULPTED, sculpted=True)(
        _sculpt_builder(_art, _h, _share))


# Wall pictures and fittings: art -> how it's mounted. The picture itself stays the 2D art (a painting, a carving's
# design, a notice), set in real depth: a moulded frame, a board, a stone slab, a rod it hangs from; fittings with
# a shape of their own (trophies, chains, shelves of jars) are sculpted from their art against the wall.
WALL_ART = {
    "painting": "frame", "painting_row": "frame", "family_portrait": "frame", "portrait_couple": "frame",
    "mirror": "frame", "mirror_full": "frame",
    "tally_board": "board", "notes_wall": "board", "notice_papers": "board", "hanging_sign": "board", "drawings": "board",
    "relief": "slab", "arch_carved": "slab", "carved_paneling": "slab", "wall_alcoves": "slab", "brick_wall": "slab",
    "sunburst": "slab",
    "tapestry": "cloth", "banner_dragon": "cloth",
    "stag_head": "sculpt", "trophy_wolf": "sculpt", "skeleton_shackles": "sculpt", "wall_chains": "sculpt", "jars": "sculpt",
    "gear_brake": "sculpt", "winch": "sculpt", "dumbwaiter": "sculpt", "robe_pegs": "sculpt", "uniforms": "sculpt",
    "crest": "sculpt", "shelves_wall": "sculpt",
}


def _wall_fit(art):
    """The picture's size on a wall face (no wider than the face) and its foot: tall pieces stand on the floor, small
    ones hang at about eye level (SetDressing._hang's rule)."""
    info = PROPS[art]
    w, h = float(info.get("world_width", 1.0)), float(info.get("world_height", 1.0))
    fit = min(1.0, 0.92 / w)
    w, h = w * fit, h * fit
    bottom = 0.0 if h >= 0.85 else max(0.0, 0.7 - h / 2)
    return w, h, bottom


def _wall_art_builder(art, style):
    def build(p):
        w, h, bottom = _wall_fit(art)
        zc = bottom + h / 2
        if style == "sculpt":
            depth = min(0.22, 0.35 * w)
            inflate(p, art, h, depth=depth, rows=44, at=(0.0, -depth / 2 - 0.004, bottom))
            return
        lift = 0.0
        if style == "frame":
            t, d = 0.035, 0.05
            p.box((w + 0.01, 0.012, h + 0.01), (0, -0.006, zc), "pal_peat")
            for s in (-1, 1):
                p.box((w + 2 * t, d, t), (0, -d / 2, zc + s * (h / 2 + t / 2)), "pal_umber")
                p.box((t, d, h + 2 * t), (s * (w / 2 + t / 2), -d / 2, zc), "pal_umber")
                p.box((w + 2 * t - 0.02, 0.008, 0.008), (0, -d - 0.004, zc + s * (h / 2 + t / 2)), "pal_tan")
            lift = 0.014
        elif style == "board":
            p.box((w + 0.06, 0.03, h + 0.06), (0, -0.015, zc), WOOD)
            lift = 0.032
        elif style == "slab":
            p.box((w + 0.04, 0.05, h + 0.04), (0, -0.025, zc), "pal_slate")
            p.box((w + 0.08, 0.06, 0.04), (0, -0.03, zc + h / 2 + 0.02), "pal_stone")
            lift = 0.052
        elif style == "cloth":
            p.cyl(0.014, w + 0.12, (-w / 2 - 0.06, -0.04, zc + h / 2 + 0.015), "pal_umber", rot=(0, 90, 0), segs=8)
            for s in (-1, 1):
                p.lathe([(0.0, 0.0), (0.02, 0.0), (0.025, 0.015), (0.0, 0.035)], (s * (w / 2 + 0.06), -0.04, zc + h / 2 + 0.015),
                        "pal_tan", rot=(0, s * 90, 0), segs=8)
                p.box((0.02, 0.04, 0.03), (s * (w / 2 - 0.05), -0.02, zc + h / 2 + 0.015), "pal_umber")
            lift = 0.03
        else:
            lift = 0.006
        p.socket("art", (0.0, -lift, zc))
    build.__doc__ = "%s on a wall: %s." % (art, style)
    return build


for _art, _style in WALL_ART.items():
    _w, _h, _b = _wall_fit(_art)
    model(_art, "wall", [_art], sculpted=_style == "sculpt",
          decals=None if _style == "sculpt" else [{"art": _art, "region": [0, 0, PROPS[_art]["width_px"], PROPS[_art]["height_px"]],
                                                   "socket": "art", "width": round(_w, 4)}])(_wall_art_builder(_art, _style))


# --- Export and preview ----------------------------------------------------------------------------------------

def bounds(ob):
    vs = [ob.matrix_world @ v.co for v in ob.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return lo, hi


def godot(v):
    """Blender (x, y, z) -> Godot (x, z, -y), rounded."""
    return [round(v[0], 4), round(v[2], 4), round(-v[1], 4)]


def build(ids):
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)
    built = {}
    for id_ in ids:
        spec = MODELS[id_]
        p = Piece(id_, seed=sum(ord(c) for c in id_))
        spec["build"](p)
        sockets = dict(p.sockets)
        ob = p.finish()
        built[id_] = (ob, sockets)
    return built


def export(built):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    path = OUT_DIR / "manifest.json"
    data = json.loads(path.read_text()) if path.exists() else {}
    data["about"] = ("3D set pieces from blender/models_3d.py (docs/art/models.md). size is [width, height, depth] in "
                     "world units; sockets are in Godot axes (x, y up, z toward the front).")
    models = data.setdefault("models", {})
    for id_, (ob, sockets) in built.items():
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        out = OUT_DIR / (id_ + ".glb")
        bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB", use_selection=True, export_yup=True,
                                  export_apply=True, export_texcoords=True, export_materials="EXPORT")
        lo, hi = bounds(ob)
        spec = MODELS[id_]
        entry = {"file": "art/models/%s.glb" % id_, "mount": spec["mount"], "stands_for": spec["stands_for"],
                 "size": [round(hi.x - lo.x, 3), round(hi.z - lo.z, 3), round(hi.y - lo.y, 3)],
                 "materials": sorted({m.name for m in ob.data.materials}),
                 "triangles": sum(len(f.vertices) - 2 for f in ob.data.polygons)}
        if sockets:
            entry["sockets"] = {k: godot(v) for k, v in sockets.items()}
        if spec.get("container"):
            entry["container"] = True
        if spec.get("decals"):
            entry["decals"] = spec["decals"]
        if spec.get("big"):
            entry["big"] = True
        if spec.get("turns"):
            entry["turns"] = True
        if spec.get("sculpted"):
            entry["sculpted"] = True
        models[id_] = entry
        print("model %s: %s, %d triangles" % (id_, entry["size"], entry["triangles"]))
    path.write_text(json.dumps(data, indent=2) + "\n")


def preview(built, out, yaw_deg=45.0):
    """One image per piece from the game's opening camera (south-east, 40 degrees down) beside a 6 ft figure,
    workbench-lit: out_<id>.png, so shapes can be checked against the 2D art without the game."""
    scene = bpy.context.scene
    man = bpy.data.meshes.new("figure")
    t = bmesh.new()
    bmesh.ops.create_cone(t, cap_ends=True, segments=12, radius1=0.16, radius2=0.12, depth=1.2)
    bmesh.ops.translate(t, vec=Vector((0, 0, 0.6)), verts=t.verts)
    t.to_mesh(man)
    fig = bpy.data.objects.new("figure", man)
    scene.collection.objects.link(fig)
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.engine = "BLENDER_WORKBENCH"
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "MATERIAL"
    sprites = [m for m in bpy.data.materials if m.name.startswith("spr_")]
    for m in sprites:
        # Show the sculpted pieces painted (only in these renders: the exported files carry no images).
        img = bpy.data.images.load(str(ROOT / PROPS[m.name[4:]]["file"]))
        node = m.node_tree.nodes.new("ShaderNodeTexImage")
        node.image = img
        m.node_tree.nodes.active = node
        m.node_tree.links.new(node.outputs["Color"], m.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    if sprites:
        shading.color_type = "TEXTURE"
    shading.show_object_outline = True
    shading.show_cavity = False
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.world = scene.world or bpy.data.worlds.new("w")
    yaw, pitch = math.radians(yaw_deg), math.radians(40)
    offset = Vector((math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch), math.sin(pitch))) * 30
    right = Vector((math.cos(yaw), math.sin(yaw), 0))
    for ob, _ in built.values():
        ob.hide_render = True
    for id_, (ob, _) in built.items():
        ob.hide_render = False
        lo, hi = bounds(ob)
        size = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z, 1.2)
        fig.location = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, 0)) - right * (size * 0.5 + 0.35)
        centre = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, (lo.z + hi.z) / 2)) - right * 0.2
        cam_data.ortho_scale = size * 1.7
        cam.location = centre + offset
        cam.rotation_euler = (offset * -1).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = out.replace(".png", "_%s.png" % id_)
        bpy.ops.render.render(write_still=True)
        ob.hide_render = True


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", default=[])
    ap.add_argument("--preview", default="")
    ap.add_argument("--yaw", type=float, default=45.0)
    ap.add_argument("--no-export", action="store_true")
    a = ap.parse_args(argv)
    ids = a.only or list(MODELS)
    built = build(ids)
    if not a.no_export:
        export(built)
    if a.preview:
        preview(built, a.preview, a.yaw)


main()
