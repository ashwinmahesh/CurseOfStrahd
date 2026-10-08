#!/usr/bin/env python3
"""Paints the swatch of the Vistani tent's canvas (tent/canvas, docs/art/interiors.md) in code, no image model: dusky
violet cloth sewn from panels, patched where it has worn through, the patches and seams sewn with coarse dark
stitches, as in Madam Eva's reading (art/cutscenes/madam_eva_reading.jpg). It tiles both ways.

    python3 tools/art/make_canvas_swatch.py      # -> art/generated/surfaces/tent_canvas.webp
    python3 tools/art/build_surfaces.py --only tent/canvas

build_surfaces.py then makes it the HD set (seamless tile, normal and ORM maps) like a painted swatch. A cosmetic
random seed keeps it the same every run.
"""
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "generated" / "surfaces" / "tent_canvas.webp"
S = 2048          # the swatch; about 768 px make one world unit once build_surfaces cuts its tile
UNIT = 768

# Cloth colours: the reading's dusky violets and indigos (bruise, ash violet, plum, night), dyed unevenly.
PANELS = [(74, 40, 98), (62, 44, 84), (84, 50, 112), (58, 36, 82), (70, 46, 96)]
PATCHES = [(46, 34, 72), (96, 60, 122), (40, 46, 82), (88, 44, 70), (66, 54, 92), (52, 28, 66)]
THREAD = (24, 16, 32)


def wrap_rect(draw, box, **kw):
    """A rectangle drawn at every wrapped offset, so it tiles."""
    x0, y0, x1, y1 = box
    for dx in (-S, 0, S):
        for dy in (-S, 0, S):
            draw.rectangle((x0 + dx, y0 + dy, x1 + dx, y1 + dy), **kw)


def wrap_line(draw, pts, **kw):
    for dx in (-S, 0, S):
        for dy in (-S, 0, S):
            draw.line([(x + dx, y + dy) for x, y in pts], **kw)


def wrap_ellipse(draw, box, **kw):
    x0, y0, x1, y1 = box
    for dx in (-S, 0, S):
        for dy in (-S, 0, S):
            draw.ellipse((x0 + dx, y0 + dy, x1 + dx, y1 + dy), **kw)


def wrap_poly(draw, pts, **kw):
    for dx in (-S, 0, S):
        for dy in (-S, 0, S):
            draw.polygon([(x + dx, y + dy) for x, y in pts], **kw)


def ragged(x, y, w, h, rng, step=36, jag=7):
    """A patch's outline: its box with the edges a little ragged, as cut cloth is."""
    pts = []
    for (ax, ay), (bx, by) in (((x, y), (x + w, y)), ((x + w, y), (x + w, y + h)), ((x + w, y + h), (x, y + h)),
                               ((x, y + h), (x, y))):
        n = max(1, int(max(abs(bx - ax), abs(by - ay)) / step))
        for i in range(n):
            t = i / n
            pts.append((ax + (bx - ax) * t + rng.uniform(-jag, jag), ay + (by - ay) * t + rng.uniform(-jag, jag)))
    return pts


def stitches(draw, a, b, rng, across=(0, 1), step=26, length=20):
    """Coarse stitches along the edge a -> b, each crossing it (`across` is the unit normal)."""
    (ax, ay), (bx, by) = a, b
    n = max(1, int(((bx - ax) ** 2 + (by - ay) ** 2) ** 0.5 / step))
    for i in range(n + 1):
        t = (i + rng.uniform(-0.15, 0.15)) / n
        x = ax + (bx - ax) * t
        y = ay + (by - ay) * t
        h = length * rng.uniform(0.8, 1.2) / 2
        skew = rng.uniform(-0.35, 0.35)
        nx, ny = across
        wrap_line(draw, [(x - nx * h + ny * h * skew, y - ny * h + nx * h * skew),
                         (x + nx * h - ny * h * skew, y + ny * h - nx * h * skew)], fill=THREAD, width=4)


def weave(rng):
    """The cloth's grain: fine noise and threads both ways, as a multiplier around 1."""
    noise = Image.effect_noise((S, S), 22).filter(ImageFilter.GaussianBlur(0.8))
    lines = Image.new("L", (S, S), 128)
    d = ImageDraw.Draw(lines)
    for k in range(0, S, 7):
        d.line([(0, k), (S, k)], fill=118 + rng.randint(-4, 4), width=2)
        d.line([(k, 0), (k, S)], fill=122 + rng.randint(-4, 4), width=2)
    lines = lines.filter(ImageFilter.GaussianBlur(0.7))
    return ImageChops.add(ImageChops.multiply(noise, Image.new("L", (S, S), 128)), lines, scale=1.0, offset=-64)


def main():
    rng = random.Random(29)
    img = Image.new("RGB", (S, S))
    d = ImageDraw.Draw(img)
    # Panels sewn side by side down the wall, each its own dye lot.
    xs = [0]
    while xs[-1] < S - 300:
        xs.append(xs[-1] + rng.randint(int(UNIT * 0.42), int(UNIT * 0.66)))
    xs[-1] = S
    for i, (x0, x1) in enumerate(zip(xs, xs[1:])):
        c = PANELS[i % len(PANELS)]
        d.rectangle((x0, 0, x1, S), fill=tuple(max(0, min(255, v + rng.randint(-6, 6))) for v in c))
    # Faded and stained cloth: soft light and dark blotches.
    blot = Image.new("L", (S, S), 128)
    bd = ImageDraw.Draw(blot)
    for _ in range(46):
        r = rng.randint(80, 320)
        x, y = rng.randint(0, S), rng.randint(0, S)
        wrap_ellipse(bd, (x - r, y - r * rng.uniform(0.6, 1.4), x + r, y + r), fill=128 + rng.choice([-1, 1]) * rng.randint(10, 26))
    blot = blot.filter(ImageFilter.GaussianBlur(70))
    # Seams between the panels: a dark fold of cloth and a line of stitches.
    for x in xs[1:-1]:
        wrap_rect(d, (x - 5, 0, x + 5, S), fill=tuple(int(v * 0.55) for v in PANELS[0]))
        wrap_line(d, [(x + 9, 0), (x + 9, S)], fill=tuple(int(v * 1.12) for v in PANELS[2]), width=3)
        stitches(d, (x, 0), (x, S), rng, across=(1, 0), step=30, length=22)
    # Brushy streaks down the cloth (the dye and the weather), painted over the panels.
    streaks = Image.new("L", (S, S), 128)
    sd = ImageDraw.Draw(streaks)
    for _ in range(900):
        x, y = rng.randint(0, S), rng.randint(0, S)
        ln = rng.randint(60, 420)
        wrap_line(sd, [(x, y), (x + rng.randint(-14, 14), y + ln)], fill=128 + rng.randint(-22, 22), width=rng.randint(3, 14))
    streaks = streaks.filter(ImageFilter.GaussianBlur(5))
    img = Image.merge("RGB", [ImageChops.multiply(ch, streaks.point(lambda v: min(255, int(v * 1.98)))) for ch in img.split()])
    d = ImageDraw.Draw(img)
    # Patches over the worn places, each a darker or brighter scrap with ragged edges, sewn down all round; they
    # don't overlap (a wrapped distance between their boxes).
    sew = []
    tries = 0
    while len(sew) < 11 and tries < 400:
        tries += 1
        w = rng.randint(int(UNIT * 0.22), int(UNIT * 0.55))
        h = rng.randint(int(UNIT * 0.2), int(UNIT * 0.5))
        x, y = rng.randint(0, S), rng.randint(0, S)
        clash = False
        for ox, oy, ow, oh in sew:
            for dx in (-S, 0, S):
                for dy in (-S, 0, S):
                    if x < ox + dx + ow + 40 and ox + dx < x + w + 40 and y < oy + dy + oh + 40 and oy + dy < y + h + 40:
                        clash = True
        if clash:
            continue
        c = rng.choice(PATCHES)
        poly = ragged(x, y, w, h, rng)
        wrap_poly(d, [(px + 4, py + 6) for px, py in poly], fill=tuple(int(v * 0.6) for v in c))   # its shadow
        wrap_poly(d, poly, fill=c)
        sew.append((x, y, w, h))
    for x, y, w, h in sew:
        inset = 12
        stitches(d, (x + inset, y + inset), (x + w - inset, y + inset), rng, across=(0, 1))
        stitches(d, (x + inset, y + h - inset), (x + w - inset, y + h - inset), rng, across=(0, 1))
        stitches(d, (x + inset, y + inset), (x + inset, y + h - inset), rng, across=(1, 0))
        stitches(d, (x + w - inset, y + inset), (x + w - inset, y + h - inset), rng, across=(1, 0))
    # The grain and the blotches over everything.
    grain = weave(rng)
    shade = ImageChops.add(grain, blot, scale=1.0, offset=-128)
    lit = Image.merge("RGB", [ImageChops.multiply(ch, shade.point(lambda v: min(255, int(v * 1.9)))) for ch in img.split()])
    out = Image.blend(img, lit, 0.55).filter(ImageFilter.GaussianBlur(0.6))
    out = ImageEnhance.Color(out).enhance(0.82)   # dusty, as the cloth in the reading is
    OUT.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT, "WEBP", quality=94, method=6)
    print(f"wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
