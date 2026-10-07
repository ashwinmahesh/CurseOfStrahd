"""The building kit (Improvement Ideas W7, docs/art/building_kit.md): the modules TownBuilder puts a town's houses
together from, one style per region, in place of textured boxes.

blender -b --python blender/building_kit.py -- [--only kit_timber_low_a ...] [--preview out.png]

Styles:
  timber     Barovian half-timbering: dark oak posts, rails and braces over cracked plaster, a fieldstone footing,
             deep thatch (small houses) or slate (grand ones)
  clapboard  Vallaki's painted clapboard: lapped boards, corner boards and window casings, a stone footing, steep
             slate roofs with carved bargeboards
  stone      Krezk, the Abbey and the manors: coursed stone with quoins, a moulded plinth and string course, dressed
             window surrounds, slate roofs

A wall module is one square's face, 1 unit wide, and stands on the wall face: Blender -Y (Godot +Z) points out of the
house, the origin is the bottom middle of the face, and a module reaches only a few centimetres into the wall. The
house's core (plaster, boards or stone) is TownBuilder's own box behind it. Lower modules run from the ground to
LOW_TOP and are never scaled; upper modules run from LOW_TOP to the nominal eaves H and are stretched to each house's
height. Roof modules are one unit of a roof along its ridge, made for every span a house can have (w1 ... w12): the
`_end` pieces close a roof over a gable. Gable modules frame the triangle under the roof at a gable end.

Materials follow blender/models_3d.py (pal_<colour>, glow_<colour>, tex_<theme>__<surface>). A manifest entry's
`paint` names the colour a house repaints (clapboard: each house its own colour).
"""
import argparse
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import models_3d as m3  # noqa: E402  (the pieces, materials and export; its own main() doesn't run on import)
from models_3d import Piece, arch  # noqa: E402

OUT = "kit"                 # art/models/kit/
H = 2.2                     # nominal eaves height (TownBuilder.HOUSE_H): upper modules are stretched from it
LOW_TOP = 1.09              # the top of the lower modules (the window-sill rail)
FOOT = 0.34                 # the stone footing's height
SPANS = range(1, 13)        # roof spans (a house's short side, in squares)
EAVE = 0.3                  # how far a roof reaches past the walls at the eaves
VERGE = 0.22                # and past a gable end

KIT = {}


def kit(id_, **extra):
    def wrap(fn):
        KIT[id_] = {"build": fn, "mount": "kit", "stands_for": [], **extra}
        return fn
    return wrap


def pitch(style):
    """Rise over half-span: Barovian thatch about 42 degrees, slate a little steeper, Vallaki's steeper still, and a
    church's steepest of all."""
    return {"timber": 0.9, "clapboard": 1.15, "stone": 1.0, "church": 1.4}[style]


def rise_of(style, w):
    """How high a roof over a span of w squares climbs above the eaves (TownBuilder uses the same numbers)."""
    return max(0.55, min(w / 2.0 * pitch(style), 3.2))


# --- Shared shapes ----------------------------------------------------------------------------------------------

def beam(p, a, b, w, mat, d=0.055, y=0.0, jitter=0.0):
    """A squared timber on the face from a to b (x, z), w wide, standing d proud of the wall (to y - d)."""
    (x0, z0), (x1, z1) = a, b
    if jitter:
        x0 += p.rng.uniform(-jitter, jitter)
        x1 += p.rng.uniform(-jitter, jitter)
    dx, dz = x1 - x0, z1 - z0
    ln = math.hypot(dx, dz)
    nx, nz = -dz / ln * w / 2, dx / ln * w / 2
    poly = [(x0 + nx, z0 + nz), (x1 + nx, z1 + nz), (x1 - nx, z1 - nz), (x0 - nx, z0 - nz)]
    p.prism(poly, d + 0.012, (0, y - d / 2 + 0.006, 0), mat)


def brace(p, x0, z0, x1, z1, w, mat, d=0.05):
    """A diagonal brace between two rails: a parallelogram with level ends, so it meets the rails cleanly."""
    h = w / max(0.2, math.cos(math.atan2(abs(z1 - z0), abs(x1 - x0))))   # keep its true width as it tilts
    poly = [(x0 - h / 2, z0), (x0 + h / 2, z0), (x1 + h / 2, z1), (x1 - h / 2, z1)]
    p.prism(poly, d + 0.012, (0, -d / 2 + 0.006, 0), mat)


def stones(p, x0, x1, z0, z1, mats, proud, course=0.12, joint=0.014, mortar="pal_stone_deep", rough=2.0, y0=0.0, out=-1,
           soft=0.012, lengths=(0.16, 0.3)):
    """Coursed rubble between x0..x1 and z0..z1 on a face: stones of random length in courses, set in mortar. The face
    is the plane y = y0 and the stones stand out from it toward `out` (-1: -y, the module's front)."""
    rng = p.rng
    if mortar:
        p.box((x1 - x0, proud * 0.6, z1 - z0), ((x0 + x1) / 2, y0 + out * (proud * 0.3 - 0.004), (z0 + z1) / 2), mortar)
    n = max(1, round((z1 - z0) / course))
    ch = (z1 - z0) / n
    for c in range(n):
        x = x0 + (rng.uniform(0.0, 0.12) if c % 2 else 0.0)
        if x > x0:
            ln = x - x0
            p.box((ln - joint, proud, ch - joint), (x0 + ln / 2, y0 + out * proud / 2, z0 + (c + 0.5) * ch), rng.choice(mats),
                  soft=soft, segs=1)
        while x < x1 - 0.02:
            ln = min(rng.uniform(*lengths), x1 - x)
            if x1 - (x + ln) < 0.07:
                ln = x1 - x
            p.box((ln - joint, proud * rng.uniform(0.85, 1.0), ch - joint * rng.uniform(0.8, 1.4)),
                  (x + ln / 2, y0 + out * proud / 2, z0 + (c + 0.5) * ch), rng.choice(mats),
                  rot=(rng.uniform(-rough, rough), 0, rng.uniform(-rough, rough)), soft=soft * 1.15, segs=1)
            x += ln


# --- Timber (Barovia) -------------------------------------------------------------------------------------------

OAK = "pal_peat"
OAK_LIGHT = "pal_umber"
FIELD = ["pal_stone", "pal_slate", "pal_stone", "pal_bone_dark", "pal_slate"]
TW = 0.12      # a timber's width on the face


def _timber_lower(p, kind):
    """Footing course top, the sill beam, the mid rail and the left post, and the lower panel's own timbers."""
    beam(p, (-0.5, FOOT + 0.05), (0.5, FOOT + 0.05), 0.1, OAK, d=0.06)                 # sill beam
    beam(p, (-0.5, LOW_TOP - 0.045), (0.5, LOW_TOP - 0.045), 0.09, OAK, d=0.06)       # mid rail
    beam(p, (-0.5, 0.0), (-0.5, LOW_TOP), TW, OAK, d=0.065)                            # post (the next bay's is its right)
    lo, hi = FOOT + 0.1, LOW_TOP - 0.09
    if kind == "a":
        beam(p, (0.0, lo), (0.0, hi), 0.09, OAK, jitter=0.01)
    elif kind == "b":
        brace(p, -0.42, lo, 0.36, hi, 0.09, OAK)
    elif kind == "c":
        brace(p, 0.42, lo, -0.36, hi, 0.09, OAK)
    elif kind == "d":
        for s in (-1, 1):
            beam(p, (s * 0.2, lo), (s * 0.2, hi), 0.08, OAK, jitter=0.008)


def _timber_upper(p, kind):
    """The upper panel from the mid rail to the wall plate, made for nominal H and stretched to the house."""
    lo, hi = LOW_TOP, H - 0.12
    beam(p, (-0.5, LOW_TOP), (-0.5, H), TW, OAK, d=0.065)
    beam(p, (-0.5, H - 0.06), (0.5, H - 0.06), 0.12, OAK, d=0.07)                     # wall plate
    if kind == "a":
        beam(p, (0.0, lo), (0.0, hi), 0.09, OAK, jitter=0.01)
    elif kind == "b":    # St Andrew's cross
        brace(p, -0.42, lo, 0.42, hi, 0.085, OAK)
        brace(p, 0.42, lo, -0.42, hi, 0.085, OAK, d=0.045)
    elif kind == "c":    # a chevron rising to a middle post
        beam(p, (0.0, lo), (0.0, hi), 0.09, OAK)
        brace(p, -0.42, lo, -0.06, hi - 0.25, 0.08, OAK)
        brace(p, 0.42, lo, 0.06, hi - 0.25, 0.08, OAK)
    elif kind == "d":    # two posts and a short rail between
        for s in (-1, 1):
            beam(p, (s * 0.2, lo), (s * 0.2, hi), 0.08, OAK, jitter=0.008)
        beam(p, (-0.2, (lo + hi) / 2), (0.2, (lo + hi) / 2), 0.07, OAK)
    elif kind == "win":  # the window's opening: jamb studs, a sill and a head
        for s in (-1, 1):
            beam(p, (s * 0.33, lo), (s * 0.33, hi), 0.08, OAK)
        beam(p, (-0.33, 1.84), (0.33, 1.84), 0.08, OAK)


for _k in "abcd":
    kit("kit_timber_low_" + _k, part="low")(lambda p, k=_k: (_timber_lower(p, k), _footing(p, FIELD)))
for _k in ("a", "b", "c", "d", "win"):
    kit("kit_timber_up_" + _k, part="up")(lambda p, k=_k: _timber_upper(p, k))


def _footing(p, mats, proud=0.07, top="pal_stone_deep"):
    stones(p, -0.5, 0.5, 0.0, FOOT, mats, proud, course=0.115)
    p.box((1.0, proud + 0.02, 0.03), (0, -(proud + 0.02) / 2 + 0.004, FOOT - 0.012), top)


@kit("kit_timber_door", part="door")
def kit_timber_door(p):
    """A door bay: jambs either side of the opening and a heavy head beam over it, a step and the footing's ends."""
    for s in (-1, 1):
        beam(p, (s * 0.47, 0.0), (s * 0.47, 2.04), 0.12, OAK, d=0.07)
    beam(p, (-0.5, 1.98), (0.5, 1.98), 0.14, OAK, d=0.075)
    p.box((0.86, 0.22, 0.08), (0, -0.11, 0.04), "pal_slate", soft=0.015)               # the step
    for x0 in (-0.5, 0.4):
        stones(p, x0, x0 + 0.1, 0.0, FOOT, FIELD, 0.07, course=0.115)


@kit("kit_timber_door_top", part="door_top")
def kit_timber_door_top(p):
    """Over a door bay: the wall plate (and the head of the jambs), stretched like an upper module from 2.04."""
    beam(p, (-0.5, H - 0.06), (0.5, H - 0.06), 0.12, OAK, d=0.07)
    for s in (-1, 1):
        beam(p, (s * 0.47, 2.04), (s * 0.47, H), 0.12, OAK, d=0.07)


@kit("kit_timber_corner", part="corner")
def kit_timber_corner(p):
    """A corner post standing on a quoin of the footing (origin on the corner; it reaches 0.09 out on both faces)."""
    p.box((0.18, 0.18, H), (0.02, 0.02, H / 2), OAK)
    p.box((0.22, 0.22, FOOT + 0.02), (0.04, 0.04, (FOOT + 0.02) / 2), "pal_slate", soft=0.02)


def _shutter(p, x_hinge, side, z0, h, w, mat, open_deg=160):
    """A plank shutter hung at x_hinge on the window's side (-1 left, +1 right), swung open `open_deg` so it lies
    nearly back against the wall beside the window."""
    a = math.radians(180 - open_deg)          # its angle off the wall
    ux, uy = side * math.cos(a), -math.sin(a)  # along its width, from the hinge outward
    for k in range(3):
        d = (k + 0.5) * w / 3
        p.box((w / 3 - 0.006, 0.025, h), (x_hinge + ux * d, uy * d - 0.03, z0 + h / 2), mat,
              rot=(0, 0, -side * math.degrees(a)))
    for z in (z0 + 0.12, z0 + h - 0.12):
        p.box((w * 0.9, 0.012, 0.035), (x_hinge + ux * w / 2, uy * w / 2 - 0.046, z), "pal_ink",
              rot=(0, 0, -side * math.degrees(a)))


def _casement(p, W, Hh, z0, frame, glass, sill_mat, shutters=None, mullion=True, depth=0.06):
    """A window on the face: a frame W x Hh from z0, a projecting sill, glass set back, a mullion and transom, and
    plank shutters opened back against the wall."""
    t = 0.06
    for s in (-1, 1):
        p.box((t, depth, Hh + t), (s * (W / 2 + t / 2), -depth / 2, z0 + Hh / 2), frame)
    p.box((W + 2 * t, depth, t), (0, -depth / 2, z0 + Hh + t / 2), frame)
    p.box((W + 2 * t + 0.08, depth + 0.06, 0.05), (0, -(depth + 0.06) / 2 + 0.01, z0 - 0.025), sill_mat)
    p.box((W, 0.02, Hh), (0, 0.004, z0 + Hh / 2), glass)
    if mullion:
        p.box((0.035, 0.03, Hh), (0, -0.012, z0 + Hh / 2), frame)
        p.box((W, 0.03, 0.03), (0, -0.012, z0 + Hh * 0.62), frame)
        for k in (1, 2):   # leading
            p.box((W, 0.014, 0.008), (0, -0.004, z0 + Hh * k / 3.2), "pal_ink")
    if shutters:
        for s in (-1, 1):
            _shutter(p, s * (W / 2 + t), s, z0 - 0.01, Hh + 0.02, W / 2 + 0.02, shutters)
    p.socket("glass", (0, -0.03, z0 + Hh / 2))


@kit("kit_timber_window", part="window")
def kit_timber_window(p):
    """A small casement in the upper panel (between the jamb studs), dark glass, shutters open."""
    _casement(p, 0.48, 0.58, 1.2, OAK, "pal_night_deep", OAK_LIGHT, shutters="tex_interior__wood_planks")


@kit("kit_timber_window_lit", part="window")
def kit_timber_window_lit(p):
    """The same casement with candlelight behind the glass."""
    _casement(p, 0.48, 0.58, 1.2, OAK, "glow_candle", OAK_LIGHT, shutters="tex_interior__wood_planks")


@kit("kit_timber_window_shut", part="window")
def kit_timber_window_shut(p):
    """The casement with its shutters closed over it."""
    _casement(p, 0.48, 0.58, 1.2, OAK, "pal_night_deep", OAK_LIGHT)
    for s in (-1, 1):
        for k in range(3):
            p.box((0.08 - 0.005, 0.03, 0.6), (s * 0.12 + (k - 1) * 0.08, -0.07, 1.49), "tex_interior__wood_planks")
        for z in (1.32, 1.66):
            p.box((0.22, 0.012, 0.03), (s * 0.12, -0.09, z), "pal_ink")


# --- Clapboard (Vallaki) ----------------------------------------------------------------------------------------

PAINT = "pal_moon_blue"      # repainted per house (manifest "paint")
TRIM = "pal_bone"
VFOOT = 0.3


def _boards(p, z0, z1, x0=-0.5, x1=0.5, step=0.105, mat=PAINT):
    """Lapped clapboards from z0 to z1: each board a wedge, proud at its foot and flush at its head under the next,
    so every board throws a shadow line."""
    n = max(1, round((z1 - z0) / step))
    s = (z1 - z0) / n
    for k in range(n):
        z = z0 + k * s
        # The board's section (y out of the wall, z up), run along x (the prism's depth after the turn).
        sec = [(0.004, z), (-0.042, z), (-0.008, z + s + 0.012), (0.004, z + s + 0.012)]
        p.prism(sec, x1 - x0, ((x0 + x1) / 2, 0, 0), mat, rot=(0, 0, 90))
        # The shadow under each lap, drawn in, so the boards read in any light.
        p.box((x1 - x0, 0.012, 0.016), ((x0 + x1) / 2, -0.036, z + 0.006), "pal_stone_deep")


def _clap_lower(p, kind):
    _footing(p, ["pal_stone", "pal_slate", "pal_pewter"], proud=0.06, top="pal_slate")
    p.box((1.0, 0.05, 0.1), (0, -0.025, VFOOT + 0.05), TRIM)                            # skirt board
    _boards(p, VFOOT + 0.1, LOW_TOP)
    if kind == "b":
        # A cellar vent in the footing: a dark opening with three iron bars.
        p.box((0.3, 0.07, 0.14), (0.1, -0.03, 0.17), "pal_void")
        for k in range(3):
            p.box((0.016, 0.02, 0.14), (0.0 + k * 0.1, -0.07, 0.17), "pal_ink")


def _clap_upper(p, kind):
    _boards(p, LOW_TOP, H - 0.18)
    p.box((1.0, 0.05, 0.16), (0, -0.025, H - 0.08), TRIM)                                # frieze board under the eaves
    p.box((1.0, 0.07, 0.03), (0, -0.035, H - 0.17), TRIM)
    if kind == "win":
        pass


for _k in "ab":
    kit("kit_clap_low_" + _k, part="low", paint=PAINT)(lambda p, k=_k: _clap_lower(p, k))
for _k in ("a", "win"):
    kit("kit_clap_up_" + _k, part="up", paint=PAINT)(lambda p, k=_k: _clap_upper(p, k))


@kit("kit_clap_door", part="door", paint=PAINT)
def kit_clap_door(p):
    """A door bay: a moulded casing round the opening, a little pediment over it, boards to either side."""
    for x0 in (-0.5, 0.4):
        stones(p, x0, x0 + 0.1, 0.0, FOOT, ["pal_stone", "pal_slate"], 0.06)
    for s in (-1, 1):
        p.box((0.06, 0.05, 1.98), (s * 0.465, -0.03, 0.99), TRIM)
    _boards(p, 1.99, 2.04)
    p.box((1.0, 0.07, 0.07), (0, -0.04, 2.0), TRIM)
    p.prism([(-0.5, 2.04), (0.5, 2.04), (0, 2.16)], 0.05, (0, -0.06, 0), TRIM)
    p.box((0.86, 0.24, 0.08), (0, -0.12, 0.04), "pal_slate", soft=0.015)


@kit("kit_clap_door_top", part="door_top", paint=PAINT)
def kit_clap_door_top(p):
    _boards(p, 2.04, H - 0.18)
    p.box((1.0, 0.05, 0.16), (0, -0.025, H - 0.08), TRIM)


@kit("kit_clap_corner", part="corner")
def kit_clap_corner(p):
    """Corner boards on both faces over a stone quoin (the house is +x, +y of the corner)."""
    up = H - VFOOT
    p.box((0.17, 0.05, up), (0.035, -0.025, VFOOT + up / 2), TRIM)
    p.box((0.05, 0.17, up), (-0.025, 0.035, VFOOT + up / 2), TRIM)
    p.box((0.2, 0.2, FOOT + 0.01), (0.06, 0.06, (FOOT + 0.01) / 2), "pal_slate", soft=0.02)


def _clap_window(p, glass):
    W, Hh, z0 = 0.44, 0.66, 1.18
    _casement(p, W, Hh, z0, TRIM, glass, TRIM, shutters=PAINT, mullion=True, depth=0.05)
    p.box((W + 0.24, 0.07, 0.06), (0, -0.04, z0 + Hh + 0.1), TRIM)                      # a cornice over the casing
    p.prism([(-W / 2 - 0.1, z0 + Hh + 0.13), (W / 2 + 0.1, z0 + Hh + 0.13), (0, z0 + Hh + 0.24)], 0.04, (0, -0.05, 0), TRIM)


kit("kit_clap_window", part="window", paint=PAINT)(lambda p: _clap_window(p, "pal_night_deep"))
kit("kit_clap_window_lit", part="window", paint=PAINT)(lambda p: _clap_window(p, "glow_candle"))
kit("kit_clap_window_shut", part="window", paint=PAINT)(lambda p: _clap_window(p, "pal_night_deep"))


# --- Stone (Krezk, the Abbey, manors) ---------------------------------------------------------------------------

DRESSED = "pal_pewter"
DRESSED_DARK = "pal_slate"


def _stone_lower(p, kind):
    p.box((1.0, 0.09, FOOT), (0, -0.045 + 0.004, FOOT / 2), DRESSED_DARK)                 # plinth course
    p.box((1.0, 0.07, 0.07), (0, -0.045, FOOT - 0.005), DRESSED_DARK, rot=(45, 0, 0))   # its chamfered top
    if kind == "b":
        p.box((0.16, 0.06, LOW_TOP - FOOT), (0, -0.03, (LOW_TOP + FOOT) / 2), DRESSED_DARK)   # a pilaster strip


def _stone_upper(p, kind):
    p.box((1.0, 0.07, 0.09), (0, -0.035, LOW_TOP + 0.05), DRESSED)                        # string course
    p.box((1.0, 0.1, 0.14), (0, -0.05, H - 0.07), DRESSED)                                # eaves cornice
    p.box((1.0, 0.14, 0.05), (0, -0.07, H - 0.02), DRESSED)


for _k in "ab":
    kit("kit_stone_low_" + _k, part="low")(lambda p, k=_k: _stone_lower(p, k))
for _k in ("a", "win"):
    kit("kit_stone_up_" + _k, part="up")(lambda p, k=_k: _stone_upper(p, k))


@kit("kit_stone_door", part="door")
def kit_stone_door(p):
    """A door bay: dressed jambs and a round-arched head with a keystone, a worn step."""
    p.box((1.0, 0.09, FOOT), (0, -0.045 + 0.004, FOOT / 2), DRESSED_DARK)
    for s in (-1, 1):
        for k in range(6):
            z = k * 0.31
            wide = 0.16 if k % 2 == 0 else 0.11
            p.box((wide, 0.08, 0.29), (s * (0.43 + wide / 2 - 0.05), -0.04, z + 0.155), DRESSED, soft=0.01)
    outer = arch(-0.56, 0.56, 1.62, 0.42, n=12, pointed=False)
    inner = arch(-0.43, 0.43, 1.62, 0.32, n=12, pointed=False)
    p.prism(outer + list(reversed(inner)), 0.09, (0, -0.045, 0), DRESSED)
    p.box((0.12, 0.1, 0.18), (0, -0.05, 1.98), DRESSED_DARK)                              # keystone
    p.box((0.9, 0.26, 0.08), (0, -0.13, 0.04), DRESSED_DARK, soft=0.02)


@kit("kit_stone_door_top", part="door_top")
def kit_stone_door_top(p):
    p.box((1.0, 0.1, 0.14), (0, -0.05, H - 0.07), DRESSED)
    p.box((1.0, 0.14, 0.05), (0, -0.07, H - 0.02), DRESSED)


@kit("kit_stone_corner", part="corner")
def kit_stone_corner(p):
    """Quoins: long and short dressed blocks in turn up the corner, proud of both faces."""
    p.box((0.2, 0.2, FOOT), (0.06, 0.06, FOOT / 2), DRESSED_DARK)
    z = FOOT
    k = 0
    while z < H - 0.05:
        h = min(0.22, H - z)
        a, b = (0.34, 0.2) if k % 2 == 0 else (0.2, 0.34)
        p.box((a, b, h - 0.015), (a / 2 - 0.035, b / 2 - 0.035, z + h / 2), DRESSED, soft=0.012, segs=1)
        z += h
        k += 1


def _stone_window(p, glass):
    W, Hh, z0 = 0.42, 0.62, 1.2
    t = 0.09
    for s in (-1, 1):
        p.box((t, 0.1, Hh), (s * (W / 2 + t / 2), -0.05, z0 + Hh / 2), DRESSED, soft=0.01)
    p.box((W + 2 * t + 0.06, 0.12, 0.12), (0, -0.06, z0 + Hh + 0.06), DRESSED, soft=0.01)   # lintel
    p.box((0.1, 0.13, 0.15), (0, -0.065, z0 + Hh + 0.07), DRESSED_DARK)                       # keystone
    p.box((W + 2 * t + 0.1, 0.16, 0.06), (0, -0.08, z0 - 0.03), DRESSED, soft=0.01)        # sill
    p.box((W, 0.02, Hh), (0, 0.02, z0 + Hh / 2), glass)
    p.box((0.035, 0.03, Hh), (0, 0.005, z0 + Hh / 2), "pal_ink")
    p.box((W, 0.03, 0.035), (0, 0.005, z0 + Hh * 0.6), "pal_ink")
    p.socket("glass", (0, -0.02, z0 + Hh / 2))


kit("kit_stone_window", part="window")(lambda p: _stone_window(p, "pal_night_deep"))
kit("kit_stone_window_lit", part="window")(lambda p: _stone_window(p, "glow_candle"))
kit("kit_stone_window_shut", part="window")(lambda p: _stone_window(p, "pal_night_deep"))


# --- Church stone (the village church, St. Andral's) -------------------------------------------------------------

CFOOT = 0.44


def _church_plinth(p):
    p.box((1.0, 0.12, CFOOT), (0, -0.06 + 0.004, CFOOT / 2), DRESSED_DARK)
    p.box((1.0, 0.09, 0.09), (0, -0.07, CFOOT - 0.01), DRESSED_DARK, rot=(45, 0, 0))


def _buttress(p, z0, z1, depth, w=0.3, top=False):
    """A buttress pier on the face from z0 to z1, `depth` proud; `top` ends it in a sloped weathering."""
    p.box((w, depth, z1 - z0), (0, -depth / 2 + 0.01, (z0 + z1) / 2), DRESSED)
    if top:
        p.prism([(0.0, z1), (-depth, z1), (0.0, z1 + depth * 0.9)], w, (0, 0, 0), DRESSED_DARK, rot=(0, 0, 90))


def _church_lower(p, kind):
    _church_plinth(p)
    if kind == "b":
        _buttress(p, 0.0, CFOOT + 0.02, 0.5, w=0.36)
        _buttress(p, CFOOT, LOW_TOP, 0.42)


def _church_upper(p, kind):
    p.box((1.0, 0.09, 0.08), (0, -0.045, LOW_TOP + 0.04), DRESSED)                        # string course
    for k in range(4):                                                                      # corbel table
        p.box((0.09, 0.09, 0.1), (-0.375 + k * 0.25, -0.045, H - 0.2), DRESSED)
    p.box((1.0, 0.13, 0.12), (0, -0.065, H - 0.08), DRESSED)
    if kind == "b":
        _buttress(p, LOW_TOP, H - 0.55, 0.34)
        _buttress(p, H - 0.55, H - 0.3, 0.2, top=True)


def _church_lancet(p, W, z0, Hh, glass):
    """A lancet: a deep dressed reveal with a pointed head, a Y-mullion, and the glass set back in it."""
    spring = z0 + Hh - W * 0.75
    t = 0.07
    for sx in (-1, 1):
        p.box((t, 0.12, spring - z0), (sx * (W / 2 + t / 2), -0.06, (spring + z0) / 2), DRESSED)
    outer = arch(-W / 2 - t, W / 2 + t, spring, W * 0.75 + t, n=12)
    inner = arch(-W / 2, W / 2, spring, W * 0.75, n=12)
    p.prism(outer + list(reversed(inner)), 0.12, (0, -0.06, 0), DRESSED)
    p.prism(inner, 0.02, (0, 0.012, 0), glass)
    p.box((W, 0.02, spring - z0), (0, 0.012, (spring + z0) / 2), glass)
    p.box((0.025, 0.03, spring - z0 + 0.05), (0, -0.005, (spring + z0) / 2), "pal_ink")
    for k in (1, 2, 3):
        p.box((W, 0.025, 0.012), (0, -0.002, z0 + k * (spring - z0) / 4), "pal_ink")
    p.box((W + 2 * t + 0.08, 0.16, 0.06), (0, -0.08, z0 - 0.03), DRESSED_DARK)              # sill
    # A hood mould over the head.
    hood = arch(-W / 2 - t - 0.05, W / 2 + t + 0.05, spring, W * 0.75 + t + 0.06, n=12)
    hood_in = arch(-W / 2 - t - 0.01, W / 2 + t + 0.01, spring, W * 0.75 + t + 0.02, n=12)
    p.prism(hood + list(reversed(hood_in)), 0.05, (0, -0.135, 0), DRESSED_DARK)
    p.socket("glass", (0, -0.02, (z0 + spring) / 2))


for _k in "ab":
    kit("kit_church_low_" + _k, part="low")(lambda p, k=_k: _church_lower(p, k))
    kit("kit_church_up_" + _k, part="up")(lambda p, k=_k: _church_upper(p, k))
kit("kit_church_up_win", part="up")(lambda p: _church_upper(p, "a"))
kit("kit_church_window", part="window")(lambda p: _church_lancet(p, 0.34, 0.95, 1.05, "pal_moon_blue"))
kit("kit_church_window_lit", part="window")(lambda p: _church_lancet(p, 0.34, 0.95, 1.05, "glow_candle"))
kit("kit_church_window_shut", part="window")(lambda p: _church_lancet(p, 0.34, 0.95, 1.05, "pal_plum"))
kit("kit_church_foot", part="foot")(lambda p: _church_plinth(p))


@kit("kit_church_door", part="door")
def kit_church_door(p):
    """A side door: a pointed arch of two recessed orders over the opening, a hood mould and a worn step."""
    _church_plinth(p)
    for order, (w, d) in enumerate(((0.58, 0.14), (0.5, 0.08))):
        for sx in (-1, 1):
            p.box((0.08, d, 1.45), (sx * (w - 0.04 * order), -d / 2, 0.725), DRESSED if order == 0 else DRESSED_DARK)
        outer = arch(-w - 0.04, w + 0.04, 1.45, 0.62, n=12)
        inner = arch(-w + 0.04, w - 0.04, 1.45, 0.55, n=12)
        p.prism(outer + list(reversed(inner)), d, (0, -d / 2, 0), DRESSED if order == 0 else DRESSED_DARK)
    p.box((0.96, 0.28, 0.08), (0, -0.14, 0.04), DRESSED_DARK, soft=0.02)


@kit("kit_church_door_top", part="door_top")
def kit_church_door_top(p):
    for k in range(4):
        p.box((0.09, 0.09, 0.1), (-0.375 + k * 0.25, -0.045, H - 0.2), DRESSED)
    p.box((1.0, 0.13, 0.12), (0, -0.065, H - 0.08), DRESSED)


@kit("kit_church_corner", part="corner")
def kit_church_corner(p):
    """Angle buttresses: one on each face at the corner, stepping back twice and weathered at the top."""
    for (ax, ay) in ((1, 0), (0, 1)):
        # The buttress on the face y=0 runs out along -y; the one on x=0 out along -x.
        for z0, z1, dep, w in ((0.0, CFOOT + 0.02, 0.56, 0.4), (CFOOT, 1.3, 0.48, 0.34), (1.3, H - 0.45, 0.36, 0.3)):
            if ax:
                p.box((w, dep, z1 - z0), (0.12 + w / 2 - 0.12, -dep / 2 + 0.01, (z0 + z1) / 2), DRESSED)
            else:
                p.box((dep, w, z1 - z0), (-dep / 2 + 0.01, 0.12 + w / 2 - 0.12, (z0 + z1) / 2), DRESSED)
    p.box((0.3, 0.3, H), (0.05, 0.05, H / 2), DRESSED_DARK)


@kit("kit_church_tower", part="tower")
def kit_church_tower(p):
    """The bell tower that rises from the roof over the church doors (origin at the middle of its foot, at the eaves):
    a square shaft of dressed stone with clasping buttresses, a belfry with paired louvred lancets on each face, a
    corbelled parapet, and a slated octagonal spire with a cross."""
    S = 1.5
    shaft = 3.6
    p.box((S, S, shaft), (0, 0, shaft / 2), "tex_church__stone_wall")
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((0.26, 0.26, shaft - 0.3), (sx * (S / 2 + 0.02), sy * (S / 2 + 0.02), (shaft - 0.3) / 2), DRESSED)
    for z in (1.4, shaft - 1.25):
        p.box((S + 0.1, S + 0.1, 0.08), (0, 0, z), DRESSED)
    belfry = shaft - 1.15
    for k in range(4):
        rot = k * 90
        rx, ry = math.sin(math.radians(rot)), -math.cos(math.radians(rot))
        for off in (-0.26, 0.26):   # paired louvred openings on each face
            cx, cy = rx * (S / 2 + 0.005) + math.cos(math.radians(rot)) * off, ry * (S / 2 + 0.005) + math.sin(math.radians(rot)) * off
            p.box((0.22, 0.04, 0.62), (cx, cy, belfry + 0.31), "pal_void", rot=(0, 0, rot))
            for z in range(4):
                p.box((0.22, 0.05, 0.03), (cx * 1.01, cy * 1.01, belfry + 0.1 + z * 0.13), "pal_umber", rot=(-25, 0, rot))
            p.cyl(0.11, 0.045, (cx, cy, belfry + 0.62), "pal_void", rot=(90, 0, rot), segs=12)
    p.box((S + 0.22, S + 0.22, 0.14), (0, 0, shaft + 0.07), DRESSED)
    for k in range(8):
        a = k * 45
        p.box((0.16, 0.16, 0.16), ((S / 2 + 0.06) * math.cos(math.radians(a)) * (1.41 if k % 2 else 1.0),
                                    (S / 2 + 0.06) * math.sin(math.radians(a)) * (1.41 if k % 2 else 1.0), shaft + 0.22), DRESSED)
    spire = 2.9
    p.lathe([(0.0, 0.0), (S * 0.62, 0.0), (S * 0.62, 0.12), (0.06, spire), (0.0, spire)], (0, 0, shaft + 0.14),
            "tex_village__roof_slate", segs=8, smooth=False)
    p.cyl(0.03, 0.55, (0, 0, shaft + 0.14 + spire - 0.05), "pal_ink", segs=6)
    p.box((0.26, 0.04, 0.04), (0, 0, shaft + 0.14 + spire + 0.32), "pal_ink")


# --- Roofs ------------------------------------------------------------------------------------------------------
# A roof module is one unit along the ridge (Blender x from -0.5 to 0.5), its cross-section across the span in y,
# with z = 0 at the eaves (the top of the walls). The house's walls stand at y = +-w/2.

def _slope_prism(p, y0, z0, y1, z1, thick, mat, x0=-0.5, x1=0.5, under=None):
    """One slope of roof as a slab from (y0, z0) to (y1, z1) on its underside, `thick` deep, from x0 to x1."""
    import bmesh
    from mathutils import Vector
    dy, dz = y1 - y0, z1 - z0
    ln = math.hypot(dy, dz)
    ny, nz = -dz / ln, dy / ln
    if nz < 0:
        ny, nz = -ny, -nz
    t = bmesh.new()
    pts = [(y0, z0), (y1, z1), (y1 + ny * thick, z1 + nz * thick), (y0 + ny * thick, z0 + nz * thick)]
    a = [t.verts.new((x0, y, z)) for y, z in pts]
    b = [t.verts.new((x1, y, z)) for y, z in pts]
    faces = []
    faces.append(t.faces.new(a))
    faces.append(t.faces.new(list(reversed(b))))
    for k in range(4):
        faces.append(t.faces.new([a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]]))
    bmesh.ops.recalc_face_normals(t, faces=t.faces)
    under_faces = {faces[2]}
    p._append_faces(t, lambda f: under if (under and f in under_faces) else mat)
    return Vector((0, ny, nz))


ROOFS = {"timber": ["thatch", "slate"], "clapboard": ["slate"], "stone": ["slate"], "church": ["slate"]}


def _roof(p, style, kind, w, end=False):
    """One unit of roof along its ridge (or, `end`, the VERGE past a gable): two slopes, `kind` thatch (thick, with a
    rounded eave and a rolled ridge) or slate (thin, ridge tiles, a fascia board and rafter feet under the eaves)."""
    half = w / 2.0
    rise = rise_of(style, w)
    slope = rise / half
    thick = 0.24 if kind == "thatch" else 0.09
    x0, x1 = (-0.5, 0.5) if not end else (0.0, VERGE)
    mat = "tex_village__roof_thatch" if kind == "thatch" else "tex_village__roof_slate"
    under = "pal_peat" if kind == "thatch" else "pal_umber"
    drop = EAVE * slope
    for s in (-1, 1):
        _slope_prism(p, s * (half + EAVE), -drop, 0.0, rise, thick, mat, x0, x1, under=under)
    if kind == "thatch":
        for s in (-1, 1):
            y = s * (half + EAVE)
            p.cyl(thick * 0.55, x1 - x0, (x0, y - s * 0.02, -drop + thick * 0.5), mat, rot=(0, 90, 0), segs=10)
            # the ridge's saddle: a second layer of thatch over the top of each slope
            _slope_prism(p, s * 0.42, rise - 0.42 * slope + thick, 0.0, rise + thick, 0.07, mat, x0, x1)
        p.cyl(0.17, x1 - x0, (x0, 0, rise + thick + 0.02), mat, rot=(0, 90, 0), segs=12)
    else:
        p.cyl(0.07, x1 - x0, (x0, 0, rise + thick + 0.02), "pal_stone_deep" if style == "stone" else "pal_slate",
              rot=(0, 90, 0), segs=8)
        fascia = TRIM if style == "clapboard" else "pal_umber"
        for s in (-1, 1):
            y = s * (half + EAVE)
            p.box((x1 - x0, 0.03, 0.12), ((x0 + x1) / 2, y + s * 0.012, -drop + 0.02), fascia)
            if not end:
                for xr in (-0.25, 0.25):
                    p.box((0.05, EAVE + 0.02, 0.07), (xr, s * (half + EAVE / 2), -drop / 2 - 0.02), "pal_umber",
                          rot=(-s * math.degrees(math.atan(slope)), 0, 0))
    if end:
        # Close the verge: a barge board under the roof's edge at the gable end (in a gable's plane: y across, z up).
        bw = 0.14 if kind == "slate" else 0.1
        board = TRIM if style == "clapboard" else OAK
        for s in (-1, 1):
            ya, za = s * (half + EAVE), -drop
            lift = thick * 0.3
            poly = [(ya, za - bw + lift), (0.0, rise - bw * 1.1 + lift), (0.0, rise + lift), (ya, za + lift)]
            if s > 0:
                poly = list(reversed(poly))
            p.prism(poly, 0.04, (VERGE - 0.03, 0, 0), board, rot=(0, 0, 90))
            if style == "clapboard":
                # Vallaki's carved bargeboards: a row of drops under the board.
                for k in range(1, 6):
                    t = k / 6.0
                    yy, zz = ya * (1 - t), za + (rise - za) * t
                    p.box((0.03, 0.05, 0.1), (VERGE - 0.03, yy, zz - bw - 0.03), TRIM)


for _style, _kinds in ROOFS.items():
    for _kind in _kinds:
        for _w in SPANS:
            _r = round(rise_of(_style, _w), 4)
            kit("kit_%s_%s_w%d" % (_style, _kind, _w), part="roof", span=_w, rise=_r)(
                lambda p, s=_style, k=_kind, w=_w: _roof(p, s, k, w))
            kit("kit_%s_%s_w%d_end" % (_style, _kind, _w), part="roof_end", span=_w, rise=_r)(
                lambda p, s=_style, k=_kind, w=_w: _roof(p, s, k, w, end=True))


def _gable(p, style, w):
    """The framing of a gable's triangle (front view on the gable face, x across the span, z up from the eaves):
    a tie beam, a king post, raking struts and the rafters along the roof's edge."""
    half = w / 2.0
    rise = rise_of(style, w)
    if style == "timber":
        beam(p, (-half, 0.05), (half, 0.05), 0.1, OAK, d=0.065)
        beam(p, (0.0, 0.0), (0.0, rise - 0.08), 0.1, OAK, d=0.06)
        for s in (-1, 1):
            beam(p, (s * half, 0.0), (0.0, rise), 0.11, OAK, d=0.07)
            if half > 1.0:
                brace(p, s * 0.06, 0.12, s * half * 0.5, rise * 0.5 - 0.03, 0.08, OAK)
            if half > 2.0:
                beam(p, (s * half * 0.5, 0.1), (s * half * 0.5, rise * 0.5), 0.08, OAK)
    elif style == "clapboard":
        # Boards running up the gable, and a round vent window.
        n = max(1, int(rise / 0.105))
        for k in range(n):
            z = k * rise / n
            span = half * (1 - (z + rise / n / 2) / rise)
            p.box((2 * span, 0.03, rise / n + 0.01), (0, -0.016, z + rise / n / 2), PAINT, rot=(-3, 0, 0))
        if rise > 0.9:
            p.cyl(0.16, 0.05, (0, -0.02, rise * 0.45), TRIM, rot=(90, 0, 0), segs=16)
            p.cyl(0.11, 0.06, (0, -0.02, rise * 0.45), "pal_night_deep", rot=(90, 0, 0), segs=16)
    elif style == "church":
        # A parapet gable: coping stones along both rakes standing over the roof, kneelers at the eaves, a cross on
        # the apex, and a lancet (a rose window on a wide gable) lighting the nave's roof space.
        for sx in (-1, 1):
            beam(p, (sx * (half + 0.12), -0.02), (0.0, rise + 0.16), 0.2, DRESSED, d=0.16)
            p.box((0.3, 0.24, 0.26), (sx * (half + 0.06), -0.06, 0.06), DRESSED, soft=0.01, segs=1)
        p.box((0.16, 0.12, 0.5), (0, -0.06, rise + 0.42), DRESSED_DARK)
        p.box((0.38, 0.12, 0.12), (0, -0.06, rise + 0.5), DRESSED_DARK)
        if half >= 2.5:
            p.cyl(0.42, 0.1, (0, -0.02, rise * 0.42), DRESSED, rot=(90, 0, 0), segs=24)
            p.cyl(0.33, 0.12, (0, -0.02, rise * 0.42), "pal_plum", rot=(90, 0, 0), segs=24)
            for k in range(6):
                a = k * 30
                p.box((0.66, 0.03, 0.03), (0, -0.09, rise * 0.42), DRESSED, rot=(0, a, 0))
        elif rise > 1.2:
            _church_lancet(p, 0.26, rise * 0.22, rise * 0.4, "pal_night_deep")
    else:
        p.box((2 * half, 0.07, 0.09), (0, -0.035, 0.045), DRESSED)
        if rise > 0.9:
            _stone_slit(p, rise * 0.4)


def _stone_slit(p, z):
    p.box((0.2, 0.08, 0.42), (0, -0.04, z), DRESSED, soft=0.01)
    p.box((0.08, 0.1, 0.32), (0, -0.04, z), "pal_void")


for _style in ("timber", "clapboard", "stone", "church"):
    for _w in SPANS:
        kit("kit_%s_gable_w%d" % (_style, _w), part="gable", span=_w, paint=PAINT if _style == "clapboard" else None)(
            lambda p, s=_style, w=_w: _gable(p, s, w))


# --- Yard walls, town walls and palisades -------------------------------------------------------------------------
# A yard wall square is a pier where the wall turns, ends or branches, and an arm from the square's middle to each
# neighbouring wall (x from 0 to 0.5, the wall 0.46 thick across y), made YARD_H high and stretched to the wall's
# height; a town wall (Krezk's) is its own taller arm with merlons. A palisade module is one square of sharpened logs.

YARD_H = 1.0
TOWN_H = 2.6
YARD_T = 0.46


def _yard_arm(p, h, mats, coping):
    T = YARD_T
    p.box((0.5, T - 0.08, h), (0.25, 0, h / 2), "pal_stone_deep")
    for out in (-1, 1):
        stones(p, 0.0, 0.5, 0.0, h - 0.08, mats, 0.05, course=0.17, mortar="", y0=out * (T / 2 - 0.05), out=out,
               soft=0.0, lengths=(0.2, 0.34), rough=3.0)
    if coping == "rubble":
        # Rounded capstones set on edge along the top.
        x = 0.0
        while x < 0.5:
            ln = min(p.rng.uniform(0.09, 0.14), 0.5 - x)
            p.box((ln - 0.012, T + 0.02, 0.12), (x + ln / 2, 0, h + 0.02), p.rng.choice(mats), soft=0.035, segs=1,
                  rot=(0, 0, p.rng.uniform(-2, 2)))
            x += ln
    elif coping == "dressed":
        p.box((0.5, T + 0.08, 0.08), (0.25, 0, h - 0.02), DRESSED)
        p.box((0.5, T - 0.04, 0.07), (0.25, 0, h + 0.05), DRESSED, rot=(0, 0, 0))
    elif coping == "merlons":
        p.box((0.5, T + 0.06, 0.08), (0.25, 0, h - 0.02), DRESSED_DARK)
        p.box((0.24, T, 0.36), (0.25, 0, h + 0.2), DRESSED, soft=0.01)


def _yard_pier(p, h, mats, coping):
    W = YARD_T + 0.12
    p.box((W - 0.06, W - 0.06, h + 0.12), (0, 0, (h + 0.12) / 2), "pal_stone_deep")
    n = max(1, int((h + 0.06) / 0.17))
    for k in range(n):
        z = (k + 0.5) * (h + 0.06) / n
        for (sx, sy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ln = W if sx else W - 0.1
            p.box((0.05 if sx else ln - 0.01, ln - 0.01 if sx else 0.05, (h + 0.06) / n - 0.016),
                  (sx * (W / 2 - 0.025), sy * (W / 2 - 0.025), z), p.rng.choice(mats),
                  rot=(p.rng.uniform(-2, 2), p.rng.uniform(-2, 2), 0))
    if coping == "merlons":
        p.box((W + 0.08, W + 0.08, 0.1), (0, 0, h + 0.17), DRESSED_DARK)
        p.box((W, W, 0.4), (0, 0, h + 0.42), DRESSED, soft=0.01)
    else:
        p.box((W + 0.08, W + 0.08, 0.08), (0, 0, h + 0.16), DRESSED if coping == "dressed" else "pal_slate", soft=0.015)
        p.box((W - 0.1, W - 0.1, 0.08), (0, 0, h + 0.24), DRESSED if coping == "dressed" else "pal_stone", soft=0.02)


YARD_STONE = ["pal_stone", "pal_slate"]
for _style, _mats, _cope in (("timber", YARD_STONE, "rubble"), ("clap", YARD_STONE, "rubble"),
                             ("stone", [DRESSED, DRESSED_DARK], "dressed")):
    kit("kit_%s_yard_arm" % _style, part="yard_arm", height=YARD_H)(lambda p, m=_mats, c=_cope: _yard_arm(p, YARD_H, m, c))
    kit("kit_%s_yard_pier" % _style, part="yard_pier", height=YARD_H)(lambda p, m=_mats, c=_cope: _yard_pier(p, YARD_H, m, c))
kit("kit_town_wall_arm", part="yard_arm", height=TOWN_H)(lambda p: _yard_arm(p, TOWN_H, [DRESSED, DRESSED_DARK], "merlons"))
kit("kit_town_wall_pier", part="yard_pier", height=TOWN_H)(lambda p: _yard_pier(p, TOWN_H, [DRESSED, DRESSED_DARK], "merlons"))


@kit("kit_palisade", part="palisade")
def kit_palisade(p):
    """One square of Vallaki's palisade: sharpened logs side by side along x, lashed to a rail behind (+y, inside)."""
    rng = p.rng
    n = 5
    for k in range(n):
        x = -0.5 + (k + 0.5) / n
        r = rng.uniform(0.088, 0.1)
        h = 2.2 + rng.uniform(-0.18, 0.12)
        lean = rng.uniform(-2.0, 2.0)
        p.cyl(r, h, (x, 0, -0.1), "pal_umber", segs=8, rot=(lean, 0, 0))
        top = (x, -math.sin(math.radians(lean)) * h, -0.1 + math.cos(math.radians(lean)) * h)
        p.cyl(r, 0.28, top, "pal_walnut", r2=0.012, segs=8, rot=(lean, 0, 0))
    for z in (0.55, 1.6):
        p.box((1.0, 0.07, 0.1), (0, 0.12, z), "pal_peat")
        p.box((1.0, 0.03, 0.03), (0, -0.1, z), "pal_ink")


# A footing alone, for a house cut away toward the camera (TownBuilder.cut_away): the low band keeps its stones.
kit("kit_timber_foot", part="foot")(lambda p: _footing(p, FIELD))
kit("kit_clap_foot", part="foot")(lambda p: _footing(p, ["pal_stone", "pal_slate", "pal_pewter"], proud=0.06, top="pal_slate"))
kit("kit_stone_foot", part="foot")(lambda p: _stone_lower(p, "a"))


@kit("kit_chimney_cap", part="chimney")
def kit_chimney_cap(p):
    """A chimney's top over TownBuilder's 0.38-wide stack: a corbelled course, a slab and a clay pot."""
    p.box((0.48, 0.48, 0.08), (0, 0, 0.04), "pal_slate", soft=0.012)
    p.box((0.42, 0.42, 0.1), (0, 0, 0.13), "pal_stone", soft=0.01)
    p.box((0.5, 0.5, 0.05), (0, 0, 0.205), "pal_stone_deep")
    p.lathe([(0.0, 0.23), (0.09, 0.23), (0.08, 0.36), (0.1, 0.4), (0.07, 0.4), (0.0, 0.38)], (0, 0, 0), "pal_rust", segs=10)
    p.socket("smoke", (0, 0, 0.42))


# --- Interior pillars --------------------------------------------------------------------------------------------
# A lone wall square inside a room is a pillar (BuildingKit.pillar): origin at the middle of its square on the floor,
# made per interior style. They stand taller than the cut-away walls and fade when they hide the party.

ASHLAR = "tex_castle__ashlar"


def _sconce(p, at, out, candles=3):
    """An iron sconce on a pillar's face at `at` (x, y, z), sticking out toward `out` (a unit (x, y)): a bracket, a
    drip pan and candles with their flames."""
    ox, oy = out
    x, y, z = at
    p.box((0.05 + abs(ox) * 0.14, 0.05 + abs(oy) * 0.14, 0.04), (x + ox * 0.07, y + oy * 0.07, z - 0.06), "pal_ink")
    p.cyl(0.11, 0.025, (x + ox * 0.16, y + oy * 0.16, z - 0.04), "pal_ink", segs=10)
    for k in range(candles):
        a = 2 * math.pi * k / candles
        cx, cy = x + ox * 0.16 + 0.06 * math.cos(a), y + oy * 0.16 + 0.06 * math.sin(a)
        hgt = 0.1 + 0.03 * k
        p.cyl(0.018, hgt, (cx, cy, z - 0.02), "pal_ivory", segs=6)
        p.cyl(0.012, 0.045, (cx, cy, z - 0.02 + hgt), "glow_flame", r2=0.002, segs=5)


@kit("kit_pillar_castle", part="pillar")
def kit_pillar_castle(p):
    """Castle Ravenloft's hall piers: a stepped plinth, a shaft of ashlar clustered with four colonnettes, a band,
    a carved upper block with a blind pointed arch on each face and gargoyle heads at its corners, a cornice, and an
    iron sconce of candles on two faces."""
    p.box((0.96, 0.96, 0.16), (0, 0, 0.08), DRESSED_DARK, soft=0.01, segs=1)
    p.box((0.86, 0.86, 0.16), (0, 0, 0.24), DRESSED_DARK, soft=0.01, segs=1)
    p.box((0.66, 0.66, 1.3), (0, 0, 0.32 + 0.65), ASHLAR)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.cyl(0.075, 1.3, (sx * 0.33, sy * 0.33, 0.32), DRESSED, segs=10)
            p.lathe([(0.0, 0.0), (0.11, 0.0), (0.11, 0.06), (0.08, 0.1), (0.0, 0.1)], (sx * 0.33, sy * 0.33, 0.32), DRESSED_DARK, segs=10)
    p.box((0.84, 0.84, 0.1), (0, 0, 1.67), DRESSED_DARK)
    p.box((0.76, 0.76, 0.58), (0, 0, 2.01), ASHLAR)
    for k in range(4):
        a = math.radians(k * 90)
        nx, ny = math.sin(a), -math.cos(a)
        outer = arch(-0.2, 0.2, 1.86, 0.2, n=10)
        inner = arch(-0.14, 0.14, 1.86, 0.15, n=10)
        # A blind arch: a dark recess with a stone ring round its head, on the face looking along (nx, ny).
        p.box((0.28, 0.04, 0.3), (nx * 0.385, ny * 0.385, 1.94), "pal_void", rot=(0, 0, k * 90))
        p.prism(outer + list(reversed(inner)) , 0.05, (nx * 0.39, ny * 0.39, 0), DRESSED, rot=(0, 0, k * 90))
        for sx in (-1, 1):   # jambs
            p.box((0.06, 0.05, 0.36), (nx * 0.39 + math.cos(a) * sx * 0.17, ny * 0.39 + math.sin(a) * sx * 0.17, 1.68 + 0.18 + 0.0),
                  DRESSED, rot=(0, 0, k * 90))
    for sx in (-1, 1):
        for sy in (-1, 1):
            # gargoyle heads: a snout and two horns pointing out from each upper corner
            hx, hy = sx * 0.42, sy * 0.42
            p.box((0.14, 0.14, 0.12), (hx, hy, 2.2), DRESSED_DARK, rot=(0, 0, 45), soft=0.02)
            p.box((0.1, 0.22, 0.07), (hx + sx * 0.06, hy + sy * 0.06, 2.17), DRESSED_DARK, rot=(0, 0, 45 * sx * sy))
            for h in (-1, 1):
                p.cyl(0.016, 0.1, (hx + h * 0.03, hy - h * 0.03, 2.26), "pal_bone", r2=0.003, segs=5, rot=(sx * 25, sy * 25, 0))
    p.box((0.9, 0.9, 0.1), (0, 0, 2.35), DRESSED)
    p.box((0.7, 0.7, 0.1), (0, 0, 2.45), DRESSED_DARK)
    for out in ((0, -1), (0, 1)):
        _sconce(p, (out[0] * 0.33, out[1] * 0.33, 1.35), out)


@kit("kit_pillar_church", part="pillar")
def kit_pillar_church(p):
    """A nave column: a square plinth, a moulded base, a round shaft, a cushion capital under a square abacus."""
    p.box((0.7, 0.7, 0.14), (0, 0, 0.07), DRESSED_DARK, soft=0.01, segs=1)
    p.lathe([(0.0, 0.14), (0.3, 0.14), (0.3, 0.2), (0.26, 0.26), (0.28, 0.3), (0.22, 0.36), (0.0, 0.36)], (0, 0, 0), DRESSED, segs=16)
    p.cyl(0.21, 1.62, (0, 0, 0.36), DRESSED, segs=16)
    p.lathe([(0.0, 1.98), (0.22, 1.98), (0.24, 2.02), (0.36, 2.2), (0.0, 2.2)], (0, 0, 0), DRESSED, segs=16)
    p.box((0.66, 0.66, 0.1), (0, 0, 2.25), DRESSED_DARK)


@kit("kit_pillar_dungeon", part="pillar")
def kit_pillar_dungeon(p):
    """A rough pillar of stacked stone blocks, worn and uneven, with a flat capstone."""
    rng = p.rng
    z = 0.0
    while z < 1.9:
        h = rng.uniform(0.26, 0.36)
        w = rng.uniform(0.62, 0.74)
        p.box((w, w * rng.uniform(0.92, 1.05), h - 0.02), (rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03), z + h / 2),
              rng.choice(["pal_stone", "pal_slate", "pal_stone_deep"]), rot=(rng.uniform(-2, 2), rng.uniform(-2, 2), rng.uniform(-8, 8)),
              soft=0.04, segs=1)
        z += h
    p.box((0.86, 0.86, 0.14), (0, 0, z + 0.07), "pal_slate", soft=0.03, segs=1)


@kit("kit_pillar_timber", part="pillar")
def kit_pillar_timber(p):
    """A wooden post on a stone pad, its top braced out four ways under a cross of beams."""
    p.box((0.42, 0.42, 0.14), (0, 0, 0.07), "pal_slate", soft=0.02, segs=1)
    p.box((0.24, 0.24, 2.0), (0, 0, 1.14), OAK, soft=0.02, segs=1)
    for k in range(4):
        a = math.radians(k * 90)
        ux, uy = math.cos(a), math.sin(a)
        p.box((0.46, 0.08, 0.08), (ux * 0.25, uy * 0.25, 1.96), OAK, rot=(0, -45, k * 90), soft=0.01, segs=1)
    p.box((1.0, 0.2, 0.2), (0, 0, 2.24), OAK)
    p.box((0.2, 1.0, 0.2), (0, 0, 2.26), OAK)


@kit("kit_pillar_amber", part="pillar")
def kit_pillar_amber(p):
    """The Amber Temple's pillars: an octagonal shaft of black stone with veins of amber light, a stepped base and a
    flaring capital."""
    p.box((0.86, 0.86, 0.18), (0, 0, 0.09), "pal_void", soft=0.01, segs=1)
    p.lathe([(0.0, 0.18), (0.38, 0.18), (0.36, 0.28), (0.3, 0.32), (0.0, 0.32)], (0, 0, 0), "pal_ink", segs=8, smooth=False)
    p.lathe([(0.0, 0.32), (0.27, 0.32), (0.25, 2.0), (0.0, 2.0)], (0, 0, 0), "tex_amber__black_stone", segs=8, smooth=False)
    for k in range(8):
        a = math.radians(k * 45 + 22.5)
        p.box((0.03, 0.03, 1.5), (0.255 * math.cos(a), 0.255 * math.sin(a), 1.15), "glow_candle" if k % 2 else "glow_ember")
    p.lathe([(0.0, 2.0), (0.26, 2.0), (0.42, 2.2), (0.42, 2.28), (0.0, 2.28)], (0, 0, 0), "pal_ink", segs=8, smooth=False)


# --- Interior wall faces -----------------------------------------------------------------------------------------
# On each face of a cut-away interior wall that looks into a room (ModelPiece.dress_wall): a face module in the
# place's style, and a coping along the cut top so the wall reads as a wall with a moulded top, not a box. Faces are
# one square wide, origin at the foot of the face, front -y like the house modules; CUT is the walls' cut height.

CUT = 1.15


@kit("kit_castle_face", part="face")
def kit_castle_face(p):
    """Castle Ravenloft's halls: a plinth course, a blind pointed arch on slender colonnettes, a moulded coping."""
    p.box((1.0, 0.05, 0.16), (0, -0.025, 0.08), DRESSED_DARK)
    for sx in (-1, 1):
        p.cyl(0.032, 0.62, (sx * 0.38, -0.04, 0.16), DRESSED, segs=8)
        p.box((0.1, 0.07, 0.05), (sx * 0.38, -0.035, 0.8), DRESSED_DARK)
    outer = arch(-0.44, 0.44, 0.83, 0.26, n=12)
    inner = arch(-0.34, 0.34, 0.83, 0.2, n=12)
    p.prism(outer + list(reversed(inner)), 0.05, (0, -0.025, 0), DRESSED)


@kit("kit_church_face", part="face")
def kit_church_face(p):
    """A nave's walls: a chamfered plinth and a string course at sill height."""
    p.box((1.0, 0.06, 0.2), (0, -0.03, 0.1), DRESSED_DARK)
    p.box((1.0, 0.05, 0.05), (0, -0.04, 0.2), DRESSED_DARK, rot=(45, 0, 0))
    p.box((1.0, 0.05, 0.06), (0, -0.025, 0.72), DRESSED)


def _coping(p, mat, edge, proud=0.06, h=0.08):
    """A moulded band along the cut top of an interior wall's face, with a bead under it."""
    p.box((1.0, proud + 0.02, h), (0, -(proud + 0.02) / 2 + 0.01, CUT - h / 2 + 0.01), mat)
    p.box((1.0, proud * 0.6, 0.025), (0, -proud * 0.3, CUT - h - 0.008), edge)


kit("kit_castle_coping", part="coping")(lambda p: _coping(p, DRESSED, DRESSED_DARK, proud=0.07, h=0.1))
kit("kit_church_coping", part="coping")(lambda p: _coping(p, DRESSED, DRESSED_DARK))
kit("kit_amber_coping", part="coping")(lambda p: _coping(p, "pal_ink", "glow_ember", proud=0.05))
kit("kit_manor_coping", part="coping")(lambda p: _coping(p, "pal_peat", "pal_umber", proud=0.05, h=0.07))
kit("kit_timber_coping", part="coping")(lambda p: beam(p, (-0.5, CUT - 0.06), (0.5, CUT - 0.06), 0.12, OAK, d=0.07))
kit("kit_dungeon_coping", part="coping")(lambda p: stones(p, -0.5, 0.5, CUT - 0.14, CUT + 0.01, ["pal_stone", "pal_slate"], 0.06,
                                                          course=0.15, mortar="", soft=0.0, lengths=(0.22, 0.4), rough=4.0))


# --- Build and export --------------------------------------------------------------------------------------------

def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", default=[])
    ap.add_argument("--preview", default="")
    a = ap.parse_args(argv)
    ids = a.only or list(KIT)
    unknown = [i for i in ids if i not in KIT]
    if unknown:
        raise SystemExit("unknown kit pieces: %s" % unknown)
    for i in ids:
        m3.MODELS[i] = KIT[i]
    built = m3.build(ids)
    (m3.OUT_DIR / OUT).mkdir(parents=True, exist_ok=True)
    m3.export(built, subdir=OUT, extra_keys=("part", "span", "rise", "paint", "height"))
    path = m3.OUT_DIR / OUT / "manifest.json"
    data = m3.json.loads(path.read_text())
    data["about"] = ("The building kit from blender/building_kit.py (docs/art/building_kit.md): modules TownBuilder "
                     "builds houses from. size is [width, height, depth] in world units; part says where a module goes; "
                     "span and rise are a roof's; paint is the colour each house repaints.")
    data["constants"] = {"H": H, "LOW_TOP": LOW_TOP, "FOOT": FOOT, "EAVE": EAVE, "VERGE": VERGE,
                         "pitch": {s: pitch(s) for s in ROOFS}, "spans": [min(SPANS), max(SPANS)]}
    path.write_text(m3.json.dumps(data, indent=2) + "\n")
    if a.preview:
        m3.preview(built, a.preview)


if __name__ == "__main__":
    main()
