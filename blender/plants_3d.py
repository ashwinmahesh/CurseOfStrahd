"""Builds the 3D trees and plants of the Modern look (Improvement Ideas W9, docs/art/plants.md): Barovian spruces of
drooping needle sprays round a trunk, dead trees of twisted bare branches tipped with twigs, ferns, bracken, grass
tufts, leafy undergrowth and reeds, each exported as one GLB to art/plants with art/plants/manifest.json.

  blender -b --python blender/plants_3d.py -- [--only spruce_a fern_a ...] [--preview out.png]

The leaves are cards (flat quads, bent) cut from the painted atlas art/plants/cards.png (tools/art/plant_cards.py,
which also writes the box each painting fills, art/plants/cards.json). Two materials: `leaf` (the atlas; the game's
shaders/atmosphere/foliage.gdshader) and `bark_<kind>` (shaders/atmosphere/bark.gdshader, its colour from
art/plants/flora.json). What the game needs from each vertex rides along in the file:
  - normals bent outward from the crown, so a tree is lit as one soft volume rather than card by card;
  - colour alpha: how much light reaches that part (inside and under the crown is darker), 1 where it's open;
  - a second UV set: x how freely the vertex moves in the wind (0 where it joins the trunk, 1 at a tip),
    y a phase of its own (0..1) so cards don't flutter in step.
Units are world units (one 5 ft square), +Z up, the origin at the foot of the trunk. A `_far` copy of each tree has
fewer cards for the land far from the map. Fixed seeds, so every build comes out the same.
"""
import argparse
import json
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "art" / "plants"
CARDS = json.loads((OUT_DIR / "cards.json").read_text())["cells"]

PLANTS = {}


def plant(id_, kind, stands_for=(), **extra):
    """Registers a builder. kind: tree | dead | fern | grass | bush | reeds."""
    def wrap(fn):
        PLANTS[id_] = {"build": fn, "kind": kind, "stands_for": list(stands_for), **extra}
        return fn
    return wrap


class Plant:
    """One plant: cards and tubes appended into one mesh, with a normal, a colour and wind data per vertex."""

    def __init__(self, id_, seed):
        self.id = id_
        self.rng = random.Random(seed)
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.uv2 = self.bm.loops.layers.uv.new("Wind")
        self.col = self.bm.loops.layers.float_color.new("Color")
        self.mats = []
        self.normals = []   # per vertex, in creation order

    def _slot(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def _vert(self, co, normal):
        v = self.bm.verts.new(co)
        self.normals.append(Vector(normal).normalized())
        return v

    def _face(self, verts, mat, uvs, winds, shades):
        f = self.bm.faces.new(verts)
        f.material_index = self._slot(mat)
        f.smooth = True
        for loop, uv, w, s in zip(f.loops, uvs, winds, shades):
            loop[self.uv].uv = uv
            loop[self.uv2].uv = w
            loop[self.col] = (1.0, 1.0, 1.0, s)
        return f

    def card(self, cell, grid, normal_fn, shade_fn, phase, flutter=(0.0, 1.0), along_u=True):
        """A bent card cut to atlas cell `cell`. `grid` is rows of points: grid[i][j] with i along the card's length
        (from its root to its tip) and j across it. The painting's length runs along u (`along_u`: a spray, root at
        its left) or up v (a frond or tuft, root at its bottom)."""
        u0, v0, u1, v1 = CARDS[cell]
        n_i, n_j = len(grid), len(grid[0])
        rows = []
        for i in range(n_i):
            row = []
            for j in range(n_j):
                p = Vector(grid[i][j])
                row.append((self._vert(p, normal_fn(p)), p))
            rows.append(row)
        for i in range(n_i - 1):
            for j in range(n_j - 1):
                quad = [rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]]
                uvs, winds, shades = [], [], []
                for (ii, jj) in ((i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j)):
                    t = ii / (n_i - 1)
                    s = jj / (n_j - 1)
                    if along_u:
                        u = u0 + (u1 - u0) * t
                        v = v0 + (v1 - v0) * s
                    else:
                        u = u0 + (u1 - u0) * s
                        v = v1 - (v1 - v0) * t
                    uvs.append((u, 1.0 - v))
                    winds.append((flutter[0] + (flutter[1] - flutter[0]) * t, phase))
                    shades.append(shade_fn(rows[ii][jj][1]))
                self._face([q[0] for q in quad], "leaf", uvs, winds, shades)

    def tube(self, path, radii, sides, mat, shade_fn, wind_fn, phase=0.0, cap=False):
        """A tube along `path` (points) with a radius per point, its normals pointing out from its axis."""
        n = len(path)
        frames = []
        t_prev = (Vector(path[1]) - Vector(path[0])).normalized()
        ref = Vector((1, 0, 0)) if abs(t_prev.x) < 0.9 else Vector((0, 1, 0))
        nrm = t_prev.cross(ref).normalized()
        for i in range(n):
            a = Vector(path[max(0, i - 1)])
            b = Vector(path[min(n - 1, i + 1)])
            t = (b - a).normalized()
            # Parallel transport of the side vector, so the tube doesn't twist.
            nrm = (nrm - t * nrm.dot(t)).normalized()
            frames.append((t, nrm, t.cross(nrm).normalized()))
        rings = []
        for i in range(n):
            t, nx, ny = frames[i]
            ring = []
            for k in range(sides):
                ang = math.tau * k / sides
                d = nx * math.cos(ang) + ny * math.sin(ang)
                p = Vector(path[i]) + d * radii[i]
                ring.append((self._vert(p, d), p, k))
            rings.append(ring)
        L = sum((Vector(path[i + 1]) - Vector(path[i])).length for i in range(n - 1))
        acc = [0.0]
        for i in range(n - 1):
            acc.append(acc[-1] + (Vector(path[i + 1]) - Vector(path[i])).length)
        for i in range(n - 1):
            for k in range(sides):
                k2 = (k + 1) % sides
                quad = [rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]]
                uvs = [(k / sides, acc[i] / 2.0), ((k + 1) / sides, acc[i] / 2.0),
                       ((k + 1) / sides, acc[i + 1] / 2.0), (k / sides, acc[i + 1] / 2.0)]
                winds = [(wind_fn(q[1]), phase) for q in quad]
                shades = [shade_fn(q[1]) for q in quad]
                self._face([q[0] for q in quad], mat, uvs, winds, shades)
        if cap:
            ring = rings[-1]
            c = Vector(path[-1])
            tip = self._vert(c + frames[-1][0] * radii[-1] * 0.5, frames[-1][0])
            for k in range(sides):
                k2 = (k + 1) % sides
                self._face([ring[k][0], ring[k2][0], tip], mat, [(0, 0), (1, 0), (0.5, 1)],
                           [(wind_fn(c), phase)] * 3, [shade_fn(c)] * 3)

    def finish(self):
        me = bpy.data.meshes.new(self.id)
        self.bm.to_mesh(me)
        self.bm.free()
        for name in self.mats:
            m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
            me.materials.append(m)
        me.normals_split_custom_set_from_vertices(self.normals)
        me.color_attributes.active_color = me.color_attributes["Color"]
        me.uv_layers.active = me.uv_layers["UVMap"]
        ob = bpy.data.objects.new(self.id, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


# --- Shared shapes -------------------------------------------------------------------------------------------------

def bezier(p0, p1, p2, t):
    a = Vector(p0).lerp(Vector(p1), t)
    b = Vector(p1).lerp(Vector(p2), t)
    return a.lerp(b, t)


def wobble_path(rng, base, direction, length, steps, wobble, up_bias=0.0):
    """A wandering path: starts at `base` heading `direction`, bending a little at each step."""
    pts = [Vector(base)]
    d = Vector(direction).normalized()
    seg = length / steps
    for i in range(steps):
        d = (d + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1) + up_bias)) * wobble).normalized()
        pts.append(pts[-1] + d * seg)
    return pts


# --- Trees ----------------------------------------------------------------------------------------------------------

def spruce(p, H, tiers, spread=0.24, bare=0.18, droop=0.35, cards=8, segs=3, sides=7, far=False,
           sprays=("fir_spray_a", "fir_spray_b", "fir_spray_c"), lean=0.0):
    """A Barovian spruce: a tapering trunk under tiers of needle sprays that droop more toward their tips, broad at
    the bottom of the crown and narrowing to a spire. `bare` is the share of the trunk below the lowest tier."""
    rng = p.rng
    top = Vector((lean * H * 0.08, 0, H))
    r0 = max(0.07, H * 0.032)

    def axis(z):
        return Vector((lean * H * 0.08 * (z / H) ** 2, 0, z))

    def crown_normal(q):
        a = axis(q.z)
        rad = Vector((q.x - a.x, q.y - a.y, 0))
        if rad.length < 1e-4:
            return Vector((0, 0, 1))
        return (rad.normalized() + Vector((0, 0, 0.75))).normalized()

    h0 = H * bare
    span = H * 0.94 - h0

    def crown_r(z):
        k = max(0.0, (H - z) / (H - h0))
        return spread * H * k ** 0.9

    def shade(q):
        a = axis(q.z)
        rad = Vector((q.x - a.x, q.y - a.y, 0)).length
        R = max(crown_r(q.z), 0.05)
        inner = min(1.0, rad / R)
        return min(1.0, (0.3 + 0.7 * inner) * (0.62 + 0.38 * min(1.0, (q.z - h0) / max(span, 0.1))))

    # Trunk, with a flared foot.
    n = 4 if far else 7
    path = [axis(H * 0.9 * i / n) for i in range(n + 1)]
    radii = [r0 * (1.45 if i == 0 else 1.0) * (1.0 - 0.9 * i / n) + 0.01 for i in range(n + 1)]
    p.tube(path, radii, 5 if far else sides, "bark_spruce", lambda q: 0.55 + 0.45 * min(1.0, q.z / H),
           lambda q: 0.0)
    # Tiers of sprays.
    offset = rng.uniform(0, math.tau)
    for t in range(tiers):
        f = t / max(1, tiers - 1)
        z = h0 + span * f ** 0.92 + rng.uniform(-0.25, 0.25) * span / tiers
        R = crown_r(z) * rng.uniform(0.88, 1.12)
        if R < 0.1:
            continue
        count = max(3, min(cards, int(round(R * (9 if far else 13)))))
        offset += math.tau / count * 0.5 + rng.uniform(-0.3, 0.3)
        for c in range(count):
            az = offset + math.tau * c / count + rng.uniform(-0.25, 0.25)
            out = Vector((math.cos(az), math.sin(az), 0))
            side = Vector((-math.sin(az), math.cos(az), 0))
            dip = math.radians(rng.uniform(8, 22))
            L = R * rng.uniform(0.95, 1.15)
            u0, v0, u1, v1 = CARDS[rng.choice(sprays)]
            W = L * (v1 - v0) / max(u1 - u0, 1e-3) * rng.uniform(0.85, 1.05)
            roll = math.radians(rng.uniform(-18, 18))
            sideR = (side * math.cos(roll) + Vector((0, 0, 1)) * math.sin(roll))
            root = axis(z) + out * 0.03
            grid = []
            for i in range(segs + 1):
                s = i / segs
                centre = root + out * (L * s * math.cos(dip)) - Vector((0, 0, L * s * math.sin(dip) + droop * L * s * s))
                # The spray's sides curl down a little, so it reads as a drooping bough rather than a flat plate.
                row = []
                for j in range(3):
                    w = (j - 1) * W * 0.5
                    curl = -abs(j - 1) * W * 0.12 * s
                    row.append(centre + sideR * w + Vector((0, 0, curl)))
                grid.append(row)
            p.card(rng.choice(sprays), grid, crown_normal, shade, rng.random(), flutter=(0.05, 0.6 + 0.4 * f))
    # The leader: two crossed sprays standing up at the top.
    for k in range(2):
        az = offset + k * math.pi / 2
        side = Vector((math.cos(az), math.sin(az), 0))
        L = H * 0.15
        u0, v0, u1, v1 = CARDS["fir_top"]
        W = L * (v1 - v0) / max(u1 - u0, 1e-3) * 0.42
        base = axis(H * 0.86)
        grid = [[base + Vector((0, 0, L * i / 2)) + side * (j - 1) * W * 0.5 for j in range(3)] for i in range(3)]
        p.card("fir_top", grid, crown_normal, lambda q: 0.95, rng.random(), flutter=(0.1, 0.5))


@plant("spruce_a", "tree", ["pine"], far="spruce_a_far")
def spruce_a(p):
    spruce(p, 4.2, 10, droop=0.5)


@plant("spruce_b", "tree", ["pine"], far="spruce_b_far")
def spruce_b(p):
    spruce(p, 4.8, 11, spread=0.22, bare=0.22, droop=0.6)


@plant("spruce_c", "tree", ["pine"], far="spruce_c_far")
def spruce_c(p):
    spruce(p, 3.6, 9, spread=0.27, bare=0.12, droop=0.45, lean=0.6)


@plant("spruce_young", "tree", ["pine"], far="spruce_young_far")
def spruce_young(p):
    spruce(p, 2.2, 7, spread=0.3, bare=0.08, droop=0.35)


@plant("spruce_a_far", "tree", far_of="spruce_a")
def spruce_a_far(p):
    spruce(p, 4.2, 7, droop=0.5, cards=6, segs=1, far=True)


@plant("spruce_b_far", "tree", far_of="spruce_b")
def spruce_b_far(p):
    spruce(p, 4.8, 8, spread=0.22, bare=0.22, droop=0.6, cards=6, segs=1, far=True)


@plant("spruce_c_far", "tree", far_of="spruce_c")
def spruce_c_far(p):
    spruce(p, 3.6, 6, spread=0.27, bare=0.12, droop=0.45, lean=0.6, cards=6, segs=1, far=True)


@plant("spruce_young_far", "tree", far_of="spruce_young")
def spruce_young_far(p):
    spruce(p, 2.2, 5, spread=0.3, bare=0.08, droop=0.35, cards=5, segs=1, far=True)


def dead_tree(p, H, lean, limbs=6, far=False, girth=1.0):
    """A dead tree: a leaning, twisting trunk splitting into bare limbs that fork twice, each tip a spray of twigs."""
    rng = p.rng
    sides = 4 if far else 7

    def wind_of(q):
        return min(1.0, max(0.0, (q.z / H - 0.35) * 1.2))

    def shade(q):
        return 0.55 + 0.45 * min(1.0, q.z / H)

    d = Vector((lean, rng.uniform(-0.2, 0.2), 1.0)).normalized()
    trunk = wobble_path(rng, (0, 0, 0), d, H * 0.82, 5 if far else 8, 0.12, up_bias=0.6)
    r0 = H * 0.05 * girth
    radii = [r0 * (1.5 if i == 0 else 1.0) * (1.0 - 0.75 * i / (len(trunk) - 1)) for i in range(len(trunk))]
    p.tube(trunk, radii, sides, "bark_dead", shade, wind_of, cap=True)
    tips = []

    def limb(base, direction, length, radius, depth):
        path = wobble_path(rng, base, direction, length, 3 if far else 5, 0.22, up_bias=0.15)
        rr = [radius * (1.0 - 0.7 * i / (len(path) - 1)) for i in range(len(path))]
        p.tube(path, rr, max(3, sides - 2 - depth), "bark_dead", shade, wind_of, phase=rng.random(), cap=True)
        if depth < (1 if far else 2):
            for k in range(2 if depth == 0 else rng.choice((1, 2))):
                q = rng.uniform(0.45, 0.85)
                i = int(q * (len(path) - 1))
                axis_d = (Vector(path[-1]) - Vector(path[0])).normalized()
                twist = Matrix.Rotation(rng.uniform(0.5, 0.9) * rng.choice((-1, 1)),
                                        3, axis_d.orthogonal().normalized())
                limb(path[i], twist @ axis_d, length * rng.uniform(0.45, 0.65), rr[i] * 0.7, depth + 1)
        tips.append((Vector(path[-1]), (Vector(path[-1]) - Vector(path[-2])).normalized(), length))

    for k in range(limbs):
        q = rng.uniform(0.38, 0.95)
        i = min(len(trunk) - 2, int(q * (len(trunk) - 1)))
        az = math.tau * k / limbs + rng.uniform(-0.4, 0.4)
        # Limbs reach up and out, as a dead tree's do; low ones spread wider.
        out = Vector((math.cos(az), math.sin(az), rng.uniform(0.9, 1.7) + q * 0.4)).normalized()
        limb(trunk[i], out, H * rng.uniform(0.24, 0.36), radii[i] * 0.55, 0)
    tips.append((Vector(trunk[-1]), (Vector(trunk[-1]) - Vector(trunk[-2])).normalized(), H * 0.3))
    # Twig sprays at the tips: two crossed cards along the limb's direction.
    for base, direction, length in tips:
        L = max(0.35, length * 0.8)
        side = direction.orthogonal().normalized()
        u0, v0, u1, v1 = CARDS["twigs"]
        W = L * (v1 - v0) / max(u1 - u0, 1e-3)
        for k in range(1 if far else 2):
            sd = Matrix.Rotation(k * math.pi / 2 + rng.uniform(-0.3, 0.3), 3, direction) @ side
            grid = [[base - direction * 0.05 + direction * L * i + sd * (j - 1) * W * 0.5 for j in range(3)]
                    for i in range(2)]
            p.card("twigs", grid, lambda q: (q - Vector((0, 0, H * 0.4))).normalized(), shade, rng.random(),
                   flutter=(0.3, 1.0))


@plant("dead_a", "dead", ["dead_tree"], far="dead_a_far")
def dead_a(p):
    dead_tree(p, 3.4, 0.25)


@plant("dead_b", "dead", ["dead_tree"], far="dead_b_far")
def dead_b(p):
    dead_tree(p, 3.9, -0.35, limbs=7)


@plant("dead_c", "dead", ["dead_tree"], far="dead_c_far")
def dead_c(p):
    dead_tree(p, 2.8, 0.5, limbs=5, girth=1.3)


@plant("dead_a_far", "dead", far_of="dead_a")
def dead_a_far(p):
    dead_tree(p, 3.4, 0.25, far=True)


@plant("dead_b_far", "dead", far_of="dead_b")
def dead_b_far(p):
    dead_tree(p, 3.9, -0.35, limbs=7, far=True)


@plant("dead_c_far", "dead", far_of="dead_c")
def dead_c_far(p):
    dead_tree(p, 2.8, 0.5, limbs=5, girth=1.3, far=True)


# --- Ground plants --------------------------------------------------------------------------------------------------

def rosette(p, cells, fronds, length, rise=(50, 70), arch=0.55, segs=4, width_scale=1.0):
    """Fronds springing from one crown and arching out over the ground (ferns, bracken)."""
    rng = p.rng
    centre = Vector((0, 0, -length * 0.35))

    def normal(q):
        return ((q - centre).normalized() + Vector((0, 0, 0.6))).normalized()

    def shade(q):
        return min(1.0, 0.45 + 0.55 * (q - Vector((0, 0, 0))).length / length)

    offset = rng.uniform(0, math.tau)
    for k in range(fronds):
        az = offset + math.tau * k / fronds + rng.uniform(-0.3, 0.3)
        out = Vector((math.cos(az), math.sin(az), 0))
        side = Vector((-math.sin(az), math.cos(az), 0))
        L = length * rng.uniform(0.75, 1.1)
        up = math.radians(rng.uniform(*rise))
        cell = rng.choice(cells)
        u0, v0, u1, v1 = CARDS[cell]
        W = L * (u1 - u0) / max(v1 - v0, 1e-3) * width_scale
        p0 = Vector((0, 0, 0.01)) + out * 0.03
        p1 = p0 + (out * math.cos(up) + Vector((0, 0, math.sin(up)))) * L * 0.55
        p2 = p0 + out * L * 0.95 + Vector((0, 0, L * (1.0 - arch) * 0.55))
        roll = math.radians(rng.uniform(-25, 25))
        grid = []
        for i in range(segs + 1):
            s = i / segs
            c = bezier(p0, p1, p2, s)
            tang = (bezier(p0, p1, p2, min(1.0, s + 0.05)) - bezier(p0, p1, p2, max(0.0, s - 0.05))).normalized()
            sd = Matrix.Rotation(roll, 3, tang) @ side
            # The pinnae spread flat near the tip, narrower where the frond rises from the crown.
            w = W * (0.55 + 0.45 * min(1.0, s * 2.0))
            grid.append([c + sd * (j - 1) * w * 0.5 + Vector((0, 0, -abs(j - 1) * w * 0.1)) for j in range(3)])
        p.card(cell, grid, normal, shade, rng.random(), flutter=(0.0, 1.0), along_u=False)


@plant("fern_a", "fern")
def fern_a(p):
    rosette(p, ["fern_a", "fern_b"], 9, 0.55)


@plant("fern_b", "fern")
def fern_b(p):
    rosette(p, ["fern_a", "fern_b", "fern_brown"], 7, 0.45, rise=(45, 65))


@plant("fern_small", "fern")
def fern_small(p):
    rosette(p, ["fern_b"], 6, 0.3, rise=(40, 60), segs=3)


@plant("bracken", "fern")
def bracken(p):
    rosette(p, ["bracken", "fern_brown"], 6, 0.75, rise=(60, 78), arch=0.4, width_scale=1.1)


def tuft(p, cells, blades, height, width, lean=0.18, segs=2):
    """Crossed upright cards of blades from one root (grass, sedge, reeds)."""
    rng = p.rng

    def normal(q):
        return (Vector((q.x, q.y, 0)) * 0.6 + Vector((0, 0, 1))).normalized()

    offset = rng.uniform(0, math.pi)
    for k in range(blades):
        az = offset + math.pi * k / blades + rng.uniform(-0.2, 0.2)
        side = Vector((math.cos(az), math.sin(az), 0))
        tilt = Vector((-math.sin(az), math.cos(az), 0)) * rng.uniform(-lean, lean)
        h = height * rng.uniform(0.8, 1.15)
        w = width * rng.uniform(0.85, 1.1)
        cell = rng.choice(cells)
        grid = []
        for i in range(segs + 1):
            s = i / segs
            c = Vector((0, 0, h * s)) + tilt * h * s * s
            grid.append([c + side * (j - 1) * w * 0.5 * (1.0 + 0.25 * s) for j in range(3)])
        p.card(cell, grid, normal, lambda q: min(1.0, 0.55 + 0.45 * q.z / height), rng.random(),
               flutter=(0.0, 1.0), along_u=False)


@plant("grass_a", "grass")
def grass_a(p):
    tuft(p, ["grass_a", "grass_b"], 3, 0.3, 0.42)


@plant("grass_b", "grass")
def grass_b(p):
    tuft(p, ["grass_b", "grass_dry"], 3, 0.22, 0.36)


@plant("grass_dry", "grass")
def grass_dry(p):
    tuft(p, ["grass_dry", "grass_a"], 3, 0.34, 0.46)


@plant("sedge", "grass")
def sedge(p):
    tuft(p, ["sedge"], 3, 0.38, 0.4)


@plant("reeds", "reeds")
def reeds(p):
    tuft(p, ["reeds"], 4, 0.95, 0.55, lean=0.08)


def bush(p, cells, radius, cards, squash=0.75):
    """Undergrowth: leafy cards facing out round a low dome, lit as one round clump."""
    rng = p.rng
    centre = Vector((0, 0, radius * 0.25))

    def normal(q):
        return (q - centre).normalized()

    golden = math.pi * (3 - math.sqrt(5))
    for k in range(cards):
        y = 1 - (k / max(1, cards - 1)) * 0.95
        r = math.sqrt(max(0.0, 1 - y * y))
        th = golden * k + rng.uniform(-0.2, 0.2)
        d = Vector((math.cos(th) * r, math.sin(th) * r, y * squash)).normalized()
        c = centre + Vector((d.x * radius * 0.75, d.y * radius * 0.75, d.z * radius * 0.6))
        size = radius * rng.uniform(0.85, 1.15)
        t1 = d.orthogonal().normalized()
        t1 = Matrix.Rotation(rng.uniform(0, math.tau), 3, d) @ t1
        t2 = d.cross(t1).normalized()
        grid = [[c + t1 * (i - 0.5) * size + t2 * (j - 1) * size * 0.5 for j in range(3)] for i in range(2)]
        p.card(rng.choice(cells), grid, normal, lambda q: min(1.0, 0.4 + 0.6 * q.z / (radius * 0.9)),
               rng.random(), flutter=(0.2, 0.6))


@plant("bush_a", "bush")
def bush_a(p):
    bush(p, ["leaves_a"], 0.42, 14)


@plant("bush_b", "bush")
def bush_b(p):
    bush(p, ["leaves_a", "leaves_b"], 0.34, 11)


# --- Export and preview ----------------------------------------------------------------------------------------

def bounds(ob):
    vs = [ob.matrix_world @ v.co for v in ob.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return lo, hi


def build(ids):
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)
    built = {}
    for id_ in ids:
        p = Plant(id_, seed=sum(ord(c) * (i + 1) for i, c in enumerate(id_)))
        PLANTS[id_]["build"](p)
        built[id_] = p.finish()
    return built


def export(built):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    path = OUT_DIR / "manifest.json"
    data = json.loads(path.read_text()) if path.exists() else {}
    data["about"] = ("3D trees and plants from blender/plants_3d.py (docs/art/plants.md). size is [width, height, "
                     "depth] in world units; far is the lighter copy for the land far from the map.")
    plants = data.setdefault("plants", {})
    for id_, ob in built.items():
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        out = OUT_DIR / (id_ + ".glb")
        bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB", use_selection=True, export_yup=True,
                                  export_apply=True, export_texcoords=True, export_normals=True,
                                  export_vertex_color="ACTIVE", export_materials="EXPORT")
        lo, hi = bounds(ob)
        spec = PLANTS[id_]
        entry = {"file": "art/plants/%s.glb" % id_, "kind": spec["kind"],
                 "size": [round(hi.x - lo.x, 3), round(hi.z - lo.z, 3), round(hi.y - lo.y, 3)],
                 "triangles": sum(len(f.vertices) - 2 for f in ob.data.polygons)}
        if spec["stands_for"]:
            entry["stands_for"] = spec["stands_for"]
        for k in ("far", "far_of"):
            if spec.get(k):
                entry[k] = spec[k]
        plants[id_] = entry
        print("plant %s: %s, %d triangles" % (id_, entry["size"], entry["triangles"]))
    path.write_text(json.dumps(data, indent=2) + "\n")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", default=[])
    ap.add_argument("--no-export", action="store_true")
    a = ap.parse_args(argv)
    ids = a.only or list(PLANTS)
    built = build(ids)
    if not a.no_export:
        export(built)


main()
