"""Paints the leaf cards the 3D trees and plants are dressed with (Improvement Ideas W9, docs/art/plants.md): one atlas,
art/plants/cards.png, four cells wide and as many rows as it needs, each a spray of needles, a fern frond, a tuft of
grass, a cluster of leaves, reeds or bare twigs on a transparent ground; the last rows are the regions' own plants
(the vault's Region Variety Plan): birch, oak and Scots pine sprays, willow strands, vine leaves, heather, thistles and
cattails. blender/plants_3d.py maps its cards onto these cells (CELLS below is the
shared list). Drawn here rather than generated, so it costs nothing and comes out the same every time (fixed seeds).

  python3 tools/art/plant_cards.py [--out art/plants/cards.png] [--size 512]

Each cell is drawn at four times its size and scaled down, so edges are smooth; a dark band just inside every shape's
edge gives the inked silhouette of the target frames; the colour under transparent pixels is spread outward so the
cards' mipmaps never pick up a dark fringe. The green of a cell is its albedo before light: the game's light, the
shade between tiers and the grade do the rest.
"""
import argparse
import json
import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageMath

ROOT = Path(__file__).resolve().parents[2]

# Cell order in the atlas, four to a row (row by row from the top left). blender/plants_3d.py reads the same names.
# New cells go at the end, so the ones before keep their seeds and their paintings.
CELLS = [
    "fir_spray_a", "fir_spray_b", "fir_spray_c", "fir_top",
    "fern_a", "fern_b", "fern_brown", "bracken",
    "grass_a", "grass_b", "grass_dry", "sedge",
    "leaves_a", "leaves_b", "twigs", "reeds",
    "birch_leaves", "oak_leaves", "pine_tuft", "willow_strand",
    "vine_leaves", "heather", "thistle", "cattails",
]

SS = 4   # supersampling


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(4))


def jitter(c, rng, amount):
    k = 1.0 + rng.uniform(-amount, amount)
    return (min(255, int(c[0] * k)), min(255, int(c[1] * k)), min(255, int(c[2] * k)), c[3])


# --- Colours ------------------------------------------------------------------------------------------------------
# The target frames' forest: blue-green conifers near black in the shade, olive and rust ferns, grass going to straw.
FIR_DEEP = hexc("#16302c")
FIR_MID = hexc("#24473d")
FIR_LIGHT = hexc("#3d6a55")
FIR_TIP = hexc("#5f8a64")
FERN_DEEP = hexc("#2d3d1e")
FERN_MID = hexc("#4f6430")
FERN_LIGHT = hexc("#7a8c42")
RUST_DEEP = hexc("#4a2a16")
RUST = hexc("#8a4f22")
RUST_LIGHT = hexc("#b0763a")
GRASS_DEEP = hexc("#26331d")
GRASS_MID = hexc("#4b5d32")
GRASS_LIGHT = hexc("#7c8650")
STRAW = hexc("#a39258")
LEAF_DEEP = hexc("#1f2d1f")
LEAF_MID = hexc("#36502f")
LEAF_LIGHT = hexc("#5d7a45")
LEAF_RED = hexc("#6e2a24")
BARK = hexc("#4a4048")
BARK_LIGHT = hexc("#7a6e78")
REED = hexc("#6b6a3a")
REED_LIGHT = hexc("#a09a5c")
CATTAIL = hexc("#4e3020")
# The regions' own plants: birch's light yellow-green, oak's olive, the Scots pine's blue-green, the willow's grey-green,
# the vine's leaf and grapes, heather's dull purple, the thistle's grey leaf and purple head.
BIRCH_DEEP = hexc("#2e3d22")
BIRCH_MID = hexc("#5b7436")
BIRCH_LIGHT = hexc("#9aa857")
OAK_DEEP = hexc("#232e1e")
OAK_MID = hexc("#45572c")
OAK_LIGHT = hexc("#76803f")
PINE_DEEP = hexc("#183029")
PINE_MID = hexc("#2c5046")
PINE_LIGHT = hexc("#55786a")
PINE_TIP = hexc("#7d9a84")
WILLOW_DEEP = hexc("#283828")
WILLOW_MID = hexc("#4d6444")
WILLOW_LIGHT = hexc("#86996a")
VINE_DEEP = hexc("#25311c")
VINE_MID = hexc("#4b5e2b")
VINE_LIGHT = hexc("#7c8941")
GRAPE = hexc("#2a1832")
GRAPE_LIGHT = hexc("#4f3060")
HEATHER_DEEP = hexc("#33282f")
HEATHER = hexc("#6e4a6e")
HEATHER_LIGHT = hexc("#a07aa0")
THISTLE_LEAF = hexc("#46553f")
THISTLE_LIGHT = hexc("#7f8f78")
THISTLE_HEAD = hexc("#7a4a86")


# --- Drawing helpers --------------------------------------------------------------------------------------------

def stroke(d, pts, w0, w1, col):
    """A tapering stroke along a polyline: width w0 at the start to w1 at the end."""
    n = len(pts)
    for i in range(n - 1):
        t = i / max(1, n - 2)
        w = w0 + (w1 - w0) * t
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        d.line([(x0, y0), (x1, y1)], fill=col, width=max(1, int(round(w))))
        r = w / 2.0
        d.ellipse([x1 - r, y1 - r, x1 + r, y1 + r], fill=col)


def curve(p0, p1, bend, n=12):
    """Points from p0 to p1 bowed sideways by `bend` (a fraction of the length)."""
    (x0, y0), (x1, y1) = p0, p1
    dx, dy = x1 - x0, y1 - y0
    nx, ny = -dy, dx
    out = []
    for i in range(n + 1):
        t = i / n
        b = bend * 4.0 * t * (1.0 - t)
        out.append((x0 + dx * t + nx * b, y0 + dy * t + ny * b))
    return out


def leaf_poly(base, tip, width, serrate=0, rng=None, n=14):
    """An ovate leaf (or pinna) from base to tip, `width` across at its widest, its edge toothed `serrate` times."""
    (x0, y0), (x1, y1) = base, tip
    dx, dy = x1 - x0, y1 - y0
    ln = math.hypot(dx, dy) or 1.0
    ux, uy = dx / ln, dy / ln
    nx, ny = -uy, ux
    left, right = [], []
    for i in range(n + 1):
        t = i / n
        w = width * 0.5 * math.sin(math.pi * min(1.0, t * 1.15)) ** 0.8 * (1.0 - t * 0.25)
        if serrate and 0.05 < t < 0.95:
            w *= 0.82 + 0.3 * (0.5 + 0.5 * math.cos(t * serrate * 2.0 * math.pi))
        if rng is not None:
            w *= rng.uniform(0.92, 1.08)
        px, py = x0 + dx * t, y0 + dy * t
        left.append((px + nx * w, py + ny * w))
        right.append((px - nx * w, py - ny * w))
    return left + right[::-1]


def ink_and_bleed(img, ink=0.42, band=3):
    """Darkens a band just inside each shape's edge (the inked silhouette), then spreads colour into the transparent
    pixels around the shapes so mipmaps don't fringe."""
    r, g, b, a = img.split()
    inner = a.filter(ImageFilter.MinFilter(band * 2 + 1))
    edge = ImageChops.subtract(a, inner)
    dark = Image.merge("RGB", (r, g, b)).point(lambda v: int(v * (1.0 - ink)))
    rgb = Image.composite(dark, Image.merge("RGB", (r, g, b)), edge)
    # Bleed: the colour of the shapes, blurred wider and wider (weighted by where there is colour, so it doesn't fade
    # toward black), fills the pixels that have none yet.
    filled = rgb
    mask = a.point(lambda v: 255 if v > 8 else 0)
    for radius in (2, 6, 16, 40):
        wm = mask.filter(ImageFilter.GaussianBlur(radius))
        chans = []
        for c in filled.split():
            num = ImageChops.multiply(c, mask).filter(ImageFilter.GaussianBlur(radius))
            chans.append(ImageMath.lambda_eval(
                lambda e: e["convert"](e["float"](e["n"]) * 255.0 / (e["float"](e["w"]) + 0.001), "L"), n=num, w=wm))
        spread = Image.merge("RGB", chans)
        filled = Image.composite(filled, spread, mask)
        mask = ImageChops.lighter(mask, wm.point(lambda v: 255 if v > 2 else 0))
    return Image.merge("RGBA", (*filled.split(), a))


# --- The cells ----------------------------------------------------------------------------------------------------

def needle_clump(base, tip, width, rng, teeth=11, lean=0.35):
    """A clump of needles round a twig from `base` to `tip`, as a polygon: pointed at the tip, its edge a fringe of
    needle points leaning toward the tip."""
    (x0, y0), (x1, y1) = base, tip
    dx, dy = x1 - x0, y1 - y0
    ln = math.hypot(dx, dy) or 1.0
    ux, uy = dx / ln, dy / ln
    nx, ny = -uy, ux
    n = teeth * 2
    left, right = [], []
    for i in range(n + 1):
        t = i / n
        w = width * 0.5 * math.sin(math.pi * min(1.0, 0.08 + t * 0.95)) ** 0.75
        out = 1.0 if i % 2 == 0 else rng.uniform(0.6, 0.78)
        fwd = (lean * width * 0.5) if i % 2 == 0 else 0.0
        px, py = x0 + dx * t + ux * fwd, y0 + dy * t + uy * fwd
        left.append((px + nx * w * out, py + ny * w * out))
        right.append((px - nx * w * out * rng.uniform(0.92, 1.05), py - ny * w * out * rng.uniform(0.92, 1.05)))
    return left + right[::-1]


def shrink(poly, k, toward):
    """`poly` scaled by k about a point `toward` (a clump's lit part, nearer its tip)."""
    cx, cy = toward
    return [(cx + (x - cx) * k, cy + (y - cy) * k) for x, y in poly]


def fir_spray(size, seed, density=1.0, top=False, colours=None, needles=1.0):
    """A spray of fir seen from above, filling its cell, painted rather than drawn needle by needle so it reads at the
    size a tree is on screen: the branch runs from the trunk (left) to its tip (right) and each side twig carries a
    clump of needles, dark at its root and lighter toward its fringed tip, the ones nearer the tip laid over the
    ones behind. The lighter tones lie toward the tips, the new growth; the inked edge comes from ink_and_bleed."""
    rng = random.Random(seed)
    deep_c, mid_c, light_c, tip_c = colours or (FIR_DEEP, FIR_MID, FIR_LIGHT, FIR_TIP)
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cy = S * 0.5
    reach = S * (0.47 if not top else 0.34)

    def width_at(t):
        return reach * (0.6 + 0.4 * math.sin(math.pi * min(1.0, 0.15 + t * 0.9))) * (1.0 - t ** 2.0 * 0.8)

    start = (S * 0.01, cy + rng.uniform(-0.02, 0.02) * S)
    end = (S * (0.985 if not top else 0.95), cy + rng.uniform(-0.04, 0.04) * S)
    main = curve(start, end, rng.uniform(-0.04, 0.04), 30)
    clumps = []
    k = 0
    pos = 0.05
    while pos < 0.9:
        i = int(pos * (len(main) - 1))
        x, y = main[i]
        side = 1 if k % 2 == 0 else -1
        ln = width_at(pos) * rng.uniform(0.9, 1.1) / math.sin(0.95)
        ang = rng.uniform(0.7, 1.0) * side
        tip = (x + math.cos(ang) * ln, y + math.sin(ang) * ln)
        clumps.append((pos, (x, y), tip, ln * rng.uniform(0.5, 0.62) * needles))
        k += 1
        pos += rng.uniform(0.055, 0.075) / density ** 0.3
    # The stem's own clump down the middle, on top of the twigs near the trunk.
    clumps.append((0.55, main[2], main[-1], reach * 0.55))
    clumps.sort(key=lambda c: c[0])
    for pos, base, tip, w in clumps:
        poly = needle_clump(base, tip, w, rng, teeth=max(6, int(9 + pos * 4)))
        lit = (base[0] + (tip[0] - base[0]) * 0.72, base[1] + (tip[1] - base[1]) * 0.72)
        deep = jitter(mix(deep_c, (0, 0, 0, 255), 0.18), rng, 0.05)
        midc = jitter(mix(deep_c, mid_c, min(1.0, 0.45 + pos * 0.6)), rng, 0.06)
        light = jitter(mix(mid_c, light_c, min(1.0, 0.25 + pos * 0.9)), rng, 0.06)
        d.polygon(poly, fill=deep)
        d.polygon(shrink(poly, 0.78, lit), fill=midc)
        d.polygon(shrink(poly, 0.48, lit), fill=light)
        if pos > 0.6 or rng.random() < 0.3:
            d.polygon(shrink(poly, 0.22, (base[0] + (tip[0] - base[0]) * 0.85, base[1] + (tip[1] - base[1]) * 0.85)),
                      fill=jitter(mix(light, tip_c, 0.6), rng, 0.05))
    stroke(d, main, S * 0.014, S * 0.004, mix(BARK, deep_c, 0.4))
    return img


def fern(size, seed, base=FERN_DEEP, mid=FERN_MID, light=FERN_LIGHT, droop=0.12, pinnae=17, brown=0.0):
    """A fern frond standing from the bottom middle to the top: a curved rachis with pinnae either side, each pinna a
    toothed leaflet, longest a third of the way up."""
    rng = random.Random(seed)
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rach = curve((S * 0.5, S * 0.99), (S * (0.5 + rng.uniform(-0.04, 0.04)), S * 0.03), droop, 40)
    n = len(rach)
    for k in range(pinnae):
        t = 0.08 + 0.9 * k / pinnae
        i = int(t * (n - 1))
        x, y = rach[i]
        dx, dy = rach[min(n - 1, i + 1)][0] - x, rach[min(n - 1, i + 1)][1] - y
        ang = math.atan2(dy, dx)
        L = S * 0.26 * math.sin(math.pi * (0.15 + 0.85 * (1.0 - t)) ** 1.1) * rng.uniform(0.85, 1.1)
        if t < 0.2:
            L *= 0.6 + 2.0 * t
        for side in (-1, 1):
            a = ang + side * (1.15 - 0.25 * t) + rng.uniform(-0.08, 0.08)
            tip = (x + math.cos(a) * L, y + math.sin(a) * L)
            col_t = t + rng.uniform(-0.15, 0.15)
            col = mix(base, mid, min(1.0, col_t * 1.6))
            col = mix(col, light, max(0.0, col_t - 0.45) * 1.5)
            if brown > 0 and rng.random() < brown * (1.2 - t):
                col = mix(RUST, RUST_LIGHT, rng.random())
            d.polygon(leaf_poly((x, y), tip, L * 0.32, serrate=7, rng=rng), fill=jitter(col, rng, 0.06))
            # The pinna's own midrib.
            stroke(d, [(x, y), ((x + tip[0]) / 2, (y + tip[1]) / 2)], S * 0.004, S * 0.002, mix(col, base, 0.6))
    stroke(d, rach, S * 0.014, S * 0.004, mix(base, RUST_DEEP, 0.5))
    return img


def bracken(size, seed):
    """Bracken: a stiffer, triangular frond, going rust-coloured as the season turns."""
    return fern(size, seed, base=RUST_DEEP, mid=RUST, light=RUST_LIGHT, droop=0.05, pinnae=13, brown=0.2)


def grass(size, seed, blades=34, colours=(GRASS_DEEP, GRASS_MID, GRASS_LIGHT), dry=0.15, tall=0.95, spread=0.42):
    """A tuft of grass rising from the bottom middle: tapering blades fanning out and arching over."""
    rng = random.Random(seed)
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    order = sorted(range(blades), key=lambda _: rng.random())
    for b in order:
        x0 = S * (0.5 + rng.uniform(-0.12, 0.12))
        lean = rng.uniform(-spread, spread)
        h = S * tall * rng.uniform(0.5, 1.0)
        tip = (x0 + lean * h, S - h)
        bend = rng.uniform(-0.25, 0.25)
        pts = curve((x0, S * 0.995), tip, bend, 14)
        w = S * rng.uniform(0.016, 0.03)
        col = mix(colours[0], colours[1], rng.uniform(0.2, 1.0))
        if rng.random() < dry:
            col = mix(col, STRAW, rng.uniform(0.5, 0.9))
        # Light toward the tip: draw the blade in two halves.
        half = len(pts) // 2
        stroke(d, pts[:half + 1], w, w * 0.65, col)
        tipc = mix(col, colours[2] if rng.random() > dry else STRAW, 0.55)
        stroke(d, pts[half:], w * 0.65, 1.0, tipc)
    return img


def sedge(size, seed):
    return grass(size, seed, blades=26, colours=(hexc("#1f2d26"), hexc("#3f5a48"), hexc("#6f8a6a")), dry=0.05,
                 tall=0.85, spread=0.3)


def leaves(size, seed, red=0.0):
    """A clump of broad leaves (bilberry, blackberry, nettle), seen from above and a little to the side: overlapping
    ovate leaves with a lighter top and a midrib, filling a rough disc."""
    rng = random.Random(seed)
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    items = []
    for k in range(70):
        r = S * 0.42 * math.sqrt(rng.random())
        a = rng.uniform(0, math.tau)
        cx, cy = S * 0.5 + math.cos(a) * r, S * 0.5 + math.sin(a) * r * 0.9
        items.append((cy, cx, a))
    items.sort()
    for cy, cx, a in items:
        ln = S * rng.uniform(0.09, 0.15)
        ang = a + rng.uniform(-0.7, 0.7)
        base = (cx - math.cos(ang) * ln * 0.4, cy - math.sin(ang) * ln * 0.4)
        tip = (cx + math.cos(ang) * ln * 0.6, cy + math.sin(ang) * ln * 0.6)
        depth = (cy / S)
        col = mix(LEAF_DEEP, LEAF_MID, min(1.0, 0.3 + depth * 0.9 + rng.uniform(-0.2, 0.2)))
        if rng.random() < 0.3:
            col = mix(col, LEAF_LIGHT, rng.uniform(0.3, 0.7))
        if red > 0 and rng.random() < red:
            col = mix(col, LEAF_RED, rng.uniform(0.4, 0.8))
        d.polygon(leaf_poly(base, tip, ln * 0.55, serrate=5, rng=rng), fill=jitter(col, rng, 0.06))
        stroke(d, [base, tip], S * 0.004, S * 0.002, mix(col, LEAF_DEEP, 0.5))
    return img


def twigs(size, seed):
    """Bare twigs for the dead trees' outer branches: a forked spray from the left edge to the right, thinning."""
    rng = random.Random(seed)
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def branch(p, ang, ln, w, depth):
        tip = (p[0] + math.cos(ang) * ln, p[1] + math.sin(ang) * ln)
        pts = curve(p, tip, rng.uniform(-0.12, 0.12), 8)
        col = mix(BARK, BARK_LIGHT, rng.uniform(0.0, 0.5) + depth * 0.1)
        stroke(d, pts, w, w * 0.55, col)
        if depth < 5:
            for k in range(3 if depth < 2 else rng.choice((1, 2, 2))):
                q = rng.uniform(0.45, 0.9)
                j = int(q * (len(pts) - 1))
                branch(pts[j], ang + rng.choice((-1, 1)) * rng.uniform(0.35, 0.8), ln * rng.uniform(0.45, 0.65),
                       w * 0.55, depth + 1)

    branch((S * 0.02, S * 0.5), rng.uniform(-0.08, 0.08), S * 0.62, S * 0.034, 0)
    branch((S * 0.02, S * 0.5), rng.uniform(0.35, 0.5), S * 0.45, S * 0.022, 1)
    branch((S * 0.02, S * 0.5), -rng.uniform(0.35, 0.5), S * 0.45, S * 0.022, 1)
    return img


def reeds(size, seed):
    """Reeds and a few cattails: tall straight blades from the bottom, some with a brown head."""
    rng = random.Random(seed)
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for k in range(22):
        x0 = S * (0.5 + rng.uniform(-0.25, 0.25))
        h = S * rng.uniform(0.55, 0.98)
        lean = rng.uniform(-0.12, 0.12)
        pts = curve((x0, S * 0.995), (x0 + lean * h, S - h), rng.uniform(-0.06, 0.06), 12)
        col = mix(REED, REED_LIGHT, rng.uniform(0.0, 0.7))
        stroke(d, pts, S * rng.uniform(0.012, 0.02), 1.0, jitter(col, rng, 0.08))
        if rng.random() < 0.3:
            j = int(len(pts) * 0.72)
            (x1, y1), (x2, y2) = pts[j], pts[min(len(pts) - 1, j + 2)]
            stroke(d, [(x1, y1), (x2, y2)], S * 0.032, S * 0.03, CATTAIL)
    return img


def leaf_spray(size, seed, colours, leaf=(0.06, 0.09), width=0.55, serrate=5, count=70, droop=0.0, fruit=0.0):
    """A leafy spray seen from above for a broadleaf tree's crown (birch, oak) or a vine, its twig running from the
    trunk (left) to its tip (right): side twigs either way, leaves crowded along their outer parts, the lighter ones
    nearer the tips; `fruit` hangs that many bunches of grapes."""
    rng = random.Random(seed)
    deep, mid, light = colours
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cy = S * 0.5
    main = curve((S * 0.01, cy), (S * 0.96, cy + droop * S), rng.uniform(-0.05, 0.05), 30)
    twigs = [main]
    pos, k = 0.1, 0
    while pos < 0.86:
        x, y = main[int(pos * (len(main) - 1))]
        side = 1 if k % 2 == 0 else -1
        ln = S * 0.34 * (1.0 - pos * 0.45) * rng.uniform(0.8, 1.1)
        ang = rng.uniform(0.45, 0.9) * side + droop * 0.8
        twigs.append(curve((x, y), (x + math.cos(ang) * ln, y + math.sin(ang) * ln), rng.uniform(-0.12, 0.12), 10))
        k += 1
        pos += rng.uniform(0.08, 0.13)
    for t in twigs:
        stroke(d, t, S * 0.009, S * 0.003, mix(BARK, deep, 0.35))
    items = []
    for n in range(count):
        t = twigs[rng.randrange(len(twigs))]
        q = rng.uniform(0.2, 1.0)
        x, y = t[int(q * (len(t) - 1))]
        items.append((y + rng.uniform(-S * 0.05, S * 0.05), x, y, q))
    items.sort()
    for _, x, y, q in items:
        ln = S * rng.uniform(*leaf)
        ang = rng.uniform(0, math.tau)
        tip = (x + math.cos(ang) * ln, y + math.sin(ang) * ln)
        col = mix(deep, mid, min(1.0, rng.uniform(0.25, 0.9) + q * 0.2))
        if rng.random() < 0.3 + q * 0.2:
            col = mix(col, light, rng.uniform(0.3, 0.8))
        d.polygon(leaf_poly((x, y), tip, ln * width, serrate=serrate, rng=rng), fill=jitter(col, rng, 0.06))
        stroke(d, [(x, y), ((x + tip[0]) / 2, (y + tip[1]) / 2)], S * 0.003, S * 0.0015, mix(col, deep, 0.5))
    for n in range(int(fruit)):
        t = twigs[1 + rng.randrange(max(1, len(twigs) - 1))] if len(twigs) > 1 else main
        x, y = t[int(rng.uniform(0.3, 0.7) * (len(t) - 1))]
        for g in range(14):
            gx = x + rng.uniform(-0.035, 0.035) * S
            gy = y + rng.uniform(0.0, 0.09) * S * (1.0 - g / 20)
            r = S * rng.uniform(0.011, 0.016)
            d.ellipse([gx - r, gy - r, gx + r, gy + r], fill=jitter(mix(GRAPE, GRAPE_LIGHT, rng.random()), rng, 0.05))
    return img


def strands(size, seed):
    """Willow: long thin strands of narrow leaves rising from the bottom middle (they hang from the branch in the
    tree, which turns the card over)."""
    rng = random.Random(seed)
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for k in range(9):
        x0 = S * (0.5 + rng.uniform(-0.18, 0.18))
        h = S * rng.uniform(0.75, 0.98)
        pts = curve((x0, S * 0.995), (x0 + rng.uniform(-0.1, 0.1) * S, S - h), rng.uniform(-0.08, 0.08), 24)
        stroke(d, pts, S * 0.006, S * 0.002, mix(BARK, WILLOW_DEEP, 0.5))
        for i in range(2, len(pts), 1):
            x, y = pts[i]
            for side in (-1, 1):
                if rng.random() < 0.25:
                    continue
                ln = S * rng.uniform(0.045, 0.07)
                ang = -math.pi / 2 + side * rng.uniform(0.25, 0.6)
                tip = (x + math.cos(ang) * ln, y + math.sin(ang) * ln)
                t = i / len(pts)
                col = mix(WILLOW_DEEP, WILLOW_MID, min(1.0, 0.3 + t))
                if rng.random() < 0.35:
                    col = mix(col, WILLOW_LIGHT, rng.uniform(0.3, 0.7))
                d.polygon(leaf_poly((x, y), tip, ln * 0.28, rng=rng), fill=jitter(col, rng, 0.06))
    return img


def heather(size, seed):
    """Heather: a low tuft of wiry stems from the bottom, their upper parts crowded with tiny dull-purple bells."""
    rng = random.Random(seed)
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for k in range(30):
        x0 = S * (0.5 + rng.uniform(-0.2, 0.2))
        h = S * rng.uniform(0.45, 0.9)
        lean = rng.uniform(-0.45, 0.45)
        pts = curve((x0, S * 0.995), (x0 + lean * h, S - h), rng.uniform(-0.15, 0.15), 14)
        stroke(d, pts, S * 0.007, S * 0.003, mix(HEATHER_DEEP, BARK, 0.4))
        for i in range(len(pts) // 3, len(pts)):
            x, y = pts[i]
            r = S * rng.uniform(0.008, 0.014)
            col = mix(HEATHER_DEEP, HEATHER, min(1.0, 0.3 + i / len(pts)))
            if rng.random() < 0.35:
                col = mix(col, HEATHER_LIGHT, rng.uniform(0.3, 0.7))
            d.ellipse([x - r + rng.uniform(-r, r), y - r, x + r + rng.uniform(-r, r), y + r], fill=jitter(col, rng, 0.06))
    return img


def thistle(size, seed):
    """A thistle: spiny grey-green leaves round its foot and a stalk with a purple head."""
    rng = random.Random(seed)
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for k in range(11):
        ang = -math.pi / 2 + rng.uniform(-1.3, 1.3)
        ln = S * rng.uniform(0.3, 0.45)
        base = (S * 0.5, S * 0.97)
        tip = (base[0] + math.cos(ang) * ln, base[1] + math.sin(ang) * ln * 0.8)
        col = mix(THISTLE_LEAF, THISTLE_LIGHT, rng.uniform(0.0, 0.6))
        d.polygon(leaf_poly(base, tip, ln * 0.4, serrate=9, rng=rng), fill=jitter(col, rng, 0.06))
    for k in range(rng.choice((2, 3))):
        top = (S * (0.5 + rng.uniform(-0.18, 0.18)), S * rng.uniform(0.08, 0.2))
        stalk = curve((S * 0.5, S * 0.97), top, rng.uniform(-0.06, 0.06), 12)
        stroke(d, stalk, S * 0.012, S * 0.007, mix(THISTLE_LEAF, BARK, 0.3))
        x, y = top
        r = S * 0.07
        for sp in range(18):
            a = -math.pi + math.pi * sp / 17
            stroke(d, [(x, y + r * 0.6), (x + math.cos(a) * r * 1.3, y + r * 0.6 + math.sin(a) * r * 1.5)],
                   S * 0.008, S * 0.003, jitter(THISTLE_HEAD, rng, 0.08))
        d.ellipse([x - r * 0.75, y + r * 0.3, x + r * 0.75, y + r * 1.6], fill=mix(THISTLE_LEAF, THISTLE_LIGHT, 0.3))
    return img


def cattails(size, seed):
    """A stand of cattails: tall blades, most with a dark brown head."""
    rng = random.Random(seed)
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for k in range(18):
        x0 = S * (0.5 + rng.uniform(-0.22, 0.22))
        h = S * rng.uniform(0.6, 0.98)
        pts = curve((x0, S * 0.995), (x0 + rng.uniform(-0.1, 0.1) * h, S - h), rng.uniform(-0.05, 0.05), 12)
        col = mix(hexc("#3e4a2c"), REED_LIGHT, rng.uniform(0.0, 0.6))
        stroke(d, pts, S * rng.uniform(0.014, 0.022), 1.0, jitter(col, rng, 0.08))
        if rng.random() < 0.55:
            j = int(len(pts) * 0.7)
            (x1, y1), (x2, y2) = pts[j], pts[min(len(pts) - 1, j + 2)]
            stroke(d, [(x1, y1), (x2, y2)], S * 0.026, S * 0.024, jitter(CATTAIL, rng, 0.08))
    return img


def paint(name, size):
    seeds = {n: 1000 + i * 37 for i, n in enumerate(CELLS)}
    s = seeds[name]
    if name == "fir_spray_a":
        img = fir_spray(size, s)
    elif name == "fir_spray_b":
        img = fir_spray(size, s, density=1.25)
    elif name == "fir_spray_c":
        img = fir_spray(size, s, density=0.8)
    elif name == "fir_top":
        img = fir_spray(size, s, density=1.1, top=True)
    elif name == "fern_a":
        img = fern(size, s)
    elif name == "fern_b":
        img = fern(size, s, droop=-0.1, pinnae=15)
    elif name == "fern_brown":
        img = fern(size, s, droop=0.18, brown=0.7)
    elif name == "bracken":
        img = bracken(size, s)
    elif name == "grass_a":
        img = grass(size, s)
    elif name == "grass_b":
        img = grass(size, s, blades=24, tall=0.7, spread=0.55)
    elif name == "grass_dry":
        img = grass(size, s, dry=0.75)
    elif name == "sedge":
        img = sedge(size, s)
    elif name == "leaves_a":
        img = leaves(size, s)
    elif name == "leaves_b":
        img = leaves(size, s, red=0.25)
    elif name == "twigs":
        img = twigs(size, s)
    elif name == "reeds":
        img = reeds(size, s)
    elif name == "birch_leaves":
        img = leaf_spray(size, s, (BIRCH_DEEP, BIRCH_MID, BIRCH_LIGHT), leaf=(0.05, 0.08), width=0.7, count=190,
                         droop=0.25)
    elif name == "oak_leaves":
        img = leaf_spray(size, s, (OAK_DEEP, OAK_MID, OAK_LIGHT), leaf=(0.09, 0.13), width=0.6, serrate=4, count=120)
    elif name == "pine_tuft":
        img = fir_spray(size, s, density=0.9, colours=(PINE_DEEP, PINE_MID, PINE_LIGHT, PINE_TIP))
    elif name == "willow_strand":
        img = strands(size, s)
    elif name == "vine_leaves":
        img = leaf_spray(size, s, (VINE_DEEP, VINE_MID, VINE_LIGHT), leaf=(0.1, 0.15), width=0.95, serrate=3, count=34,
                         fruit=3)
    elif name == "heather":
        img = heather(size, s)
    elif name == "thistle":
        img = thistle(size, s)
    elif name == "cattails":
        img = cattails(size, s)
    else:
        raise ValueError(name)
    img = img.resize((size, size), Image.LANCZOS)
    return ink_and_bleed(img, band=max(1, size // 256))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(ROOT / "art" / "plants" / "cards.png"))
    ap.add_argument("--size", type=int, default=512)
    ap.add_argument("--only", nargs="*", default=[])
    a = ap.parse_args()
    out = Path(a.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    rows = (len(CELLS) + 3) // 4
    atlas = Image.open(out).convert("RGBA") if a.only and out.exists() else Image.new("RGBA", (a.size * 4, a.size * rows))
    for i, name in enumerate(CELLS):
        if a.only and name not in a.only:
            continue
        cell = paint(name, a.size)
        atlas.paste(cell, ((i % 4) * a.size, (i // 4) * a.size))
        print("card", name)
    atlas.save(out)
    # Where each cell's drawing lies, as a fraction of the atlas (u0, v0, u1, v1 from the top left), so a card can be
    # cut to it and waste no pixels or overdraw on empty ground.
    cells = {}
    full = atlas.getchannel("A")
    for i, name in enumerate(CELLS):
        x0, y0 = (i % 4) * a.size, (i // 4) * a.size
        box = full.crop((x0, y0, x0 + a.size, y0 + a.size)).point(lambda v: 255 if v > 24 else 0).getbbox()
        box = box or (0, 0, a.size, a.size)
        W = float(a.size * 4)
        H = float(a.size * rows)
        cells[name] = [round((x0 + box[0]) / W, 5), round((y0 + box[1]) / H, 5), round((x0 + box[2]) / W, 5),
                       round((y0 + box[3]) / H, 5)]
    meta = {"about": "Leaf cards painted by tools/art/plant_cards.py: each cell's drawn box in the atlas, as fractions "
                     "(u0, v0, u1, v1) from its top left, in an atlas four cells wide and `rows` tall. "
                     "blender/plants_3d.py maps the plants' cards onto them.",
            "atlas": out.name, "rows": rows, "cells": cells}
    out.with_suffix(".json").write_text(json.dumps(meta, indent=2) + "\n")
    print("wrote", out, "and", out.with_suffix(".json").name)


if __name__ == "__main__":
    main()
