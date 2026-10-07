"""Generated 2K swatches -> one HD surface set for the Modern look (Improvement Ideas W4, docs/art/textures.md):
a seamless albedo tile per variant, every variant edge-matched to the first so any mix of them tiles, and for each a
normal map and an occlusion-roughness-metal map made from it. No palette snap (owner, 2026-10-07: HD surfaces may
leave the palette). Writes PNGs into --out; tools/art/build_surfaces.py turns them into the game's files and manifest.

blender -b --python blender/make_surface.py -- --in a.png [--in b.png ...] --out DIR --name theme_surface
        [--axis both|x] [--size 1536] [--roughness 0.8] [--spread 0.35] [--metallic 0] [--relief 1.0]

Steps (numpy in Blender's Python, as blender/make_texture.py):
1. The first swatch is made seamless by quilting along minimum-error cuts (make_texture.make_seamless).
2. Variants: each further swatch takes the same middle square, brought to the first's scale and colour balance, or
   (--quilt) a variant is quilted from the first tile's own content, a different layout of the same pieces. Then the
   first tile's own border band is cut into the variant's edges along minimum-error seams (through the dark joints
   where it can): every variant ends in the first tile's pixels, so variants sit side by side in any order.
   Low-frequency light is flattened first in each (a vignette would repeat as a blotch).
3. The tiles are resized to --size.
4. Normal map (OpenGL, green up) from the tile's brightness at two scales: dark joints and cracks read as grooves.
5. ORM: occlusion from how much darker a pixel is than its surroundings (joints, cracks, crevices), roughness from the
   surface's own numbers and its brightness (the dark of a tile rougher than its light, as lit_world.gdshader does
   without a map), metal from --metallic.
"""
import argparse
import json
import math
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import cutout  # noqa: E402
import make_texture as mt  # noqa: E402

LUM = np.array([0.299, 0.587, 0.114], dtype=np.float32)


def args():
    p = argparse.ArgumentParser()
    p.add_argument("--in", dest="srcs", action="append", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--name", required=True)
    p.add_argument("--axis", choices=["both", "x"], default="both")
    p.add_argument("--size", type=int, default=1536)
    p.add_argument("--roughness", type=float, default=0.8)
    p.add_argument("--spread", type=float, default=0.35)
    p.add_argument("--metallic", type=float, default=0.0)
    p.add_argument("--relief", type=float, default=1.0)
    p.add_argument("--quilt", type=int, default=0, help="further variants made from the first tile's own content")
    p.add_argument("--pieces", type=float, default=0.0, help="how many pieces (stones, boards) across one tile: the "
                   "tile is cut from as much of the swatch as holds that many (0: the most the swatch allows)")
    p.add_argument("--band", type=int, default=0, help="the border band variants take from the first (px; default n/8)")
    return p.parse_args(sys.argv[sys.argv.index("--") + 1:])


def middle(rgb, n):
    """The same middle square make_seamless takes its tile from."""
    s = min(rgb.shape[:2])
    margin = s // 32
    avail = s - 2 * margin
    y0 = (rgb.shape[0] - avail) // 2
    x0 = (rgb.shape[1] - avail) // 2
    return rgb[y0:y0 + n, x0:x0 + n].copy()


def pieces_across(rgb):
    """How many pieces (stones, boards, tiles) lie across the image: the strongest repeat in its brightness, from the
    radially averaged power spectrum (windowed, weighted toward the pieces' own scale rather than the fine grain)."""
    lum = rgb @ LUM
    s = min(lum.shape)
    lum = lum[:s, :s]
    win = np.outer(np.hanning(s), np.hanning(s))
    P = np.abs(np.fft.fft2((lum - lum.mean()) * win)) ** 2
    fy = np.fft.fftfreq(s)[:, None] * s
    fx = np.fft.fftfreq(s)[None, :] * s
    r = np.sqrt(fx ** 2 + fy ** 2).astype(np.int64)
    radial = np.bincount(r.ravel(), P.ravel()) / np.maximum(np.bincount(r.ravel()), 1)
    k = np.arange(len(radial), dtype=np.float64)
    lo, hi = 2, s // 6
    w = np.convolve(radial[lo:hi] * k[lo:hi] ** 2, np.ones(3) / 3, mode="same")
    return float(lo + int(np.argmax(w)))


def seamless_n(rgb, axis, n):
    """make_texture.make_seamless with the tile's size chosen: an n px tile from the middle of the image, joined
    across a quarter-tile overlap."""
    m = n // 4
    s = min(rgb.shape[:2])
    if n + m > s:
        n = int(s * 0.94) * 4 // 5
        m = n // 4
    y0 = (rgb.shape[0] - n - m) // 2
    x0 = (rgb.shape[1] - n - m) // 2
    return mt.make_seamless(rgb[y0:y0 + n + m + 2 * (s // 32), x0:x0 + n + m + 2 * (s // 32)], axis)


def feature_size(rgb):
    """The size of the surface's pieces in px (stones, boards, tufts): how far the brightness's high-pass
    autocorrelation reaches before it drops away."""
    lum = rgb @ LUM
    s = lum.shape[0]
    h = lum - mt.gaussian_wrap(lum, s / 24.0)
    F = np.fft.fft2(h)
    ac = np.real(np.fft.ifft2(np.abs(F) ** 2))
    ac /= max(ac[0, 0], 1e-9)
    fy = np.fft.fftfreq(lum.shape[0])[:, None] * lum.shape[0]
    fx = np.fft.fftfreq(lum.shape[1])[None, :] * lum.shape[1]
    r = np.sqrt(fx ** 2 + fy ** 2).astype(np.int64)
    radial = np.bincount(r.ravel(), ac.ravel()) / np.maximum(np.bincount(r.ravel()), 1)
    below = np.nonzero(radial[1:s // 4] < 0.2)[0]
    return float(below[0] + 1) if below.size else float(s // 4)


def rescale(rgb, f):
    """Bilinear resize by f about the middle (wrap-free; edges are reflected where the result is too small)."""
    h, w = rgb.shape[:2]
    nh, nw = int(round(h * f)), int(round(w * f))
    ys = (np.arange(nh) + 0.5) / f - 0.5
    xs = (np.arange(nw) + 0.5) / f - 0.5
    y0 = np.clip(np.floor(ys).astype(np.int64), 0, h - 1)
    x0 = np.clip(np.floor(xs).astype(np.int64), 0, w - 1)
    y1 = np.clip(y0 + 1, 0, h - 1)
    x1 = np.clip(x0 + 1, 0, w - 1)
    ty = np.clip(ys - y0, 0, 1)[:, None, None]
    tx = np.clip(xs - x0, 0, 1)[None, :, None]
    top = rgb[y0][:, x0] * (1 - tx) + rgb[y0][:, x1] * tx
    bot = rgb[y1][:, x0] * (1 - tx) + rgb[y1][:, x1] * tx
    return (top * (1 - ty) + bot * ty).astype(np.float32)


def centre(rgb, n):
    """The middle n x n, reflected out at the edges where the image is smaller than that."""
    h, w = rgb.shape[:2]
    if h < n or w < n:
        py, px = max(0, n - h), max(0, n - w)
        rgb = np.pad(rgb, ((py // 2 + 1, py - py // 2 + 1), (px // 2 + 1, px - px // 2 + 1), (0, 0)), mode="reflect")
        h, w = rgb.shape[:2]
    y0, x0 = (h - n) // 2, (w - n) // 2
    return rgb[y0:y0 + n, x0:x0 + n].copy()


def balance(rgb, ref):
    """Scales each channel so its mean matches the reference tile's (variants of one surface read as one)."""
    m = rgb.reshape(-1, 3).mean(axis=0)
    r = ref.reshape(-1, 3).mean(axis=0)
    return np.clip(rgb * (r / np.maximum(m, 1e-3))[None, None, :], 0.0, 1.0)


def _seam_cost(A, B):
    """Where a seam between two patches shows least: where they agree, and in the dark (joints, mortar, cracks), so
    cuts run along the gaps between stones rather than through them."""
    dark = ((A + B) * 0.5) @ LUM
    return (mt.blur3(A - B) ** 2).sum(axis=2) + 0.08 * mt.blur3(dark[..., None])[..., 0]


def _cut_side(out, a, band, side):
    """Cuts the first tile's band into `out` on one side ('left', 'right', 'top', 'bottom') along a minimum-error
    seam, the first tile's pixels on the edge side of the seam."""
    if side in ("left", "right"):
        sl = slice(0, band) if side == "left" else slice(out.shape[1] - band, out.shape[1])
        A, B = a[:, sl], out[:, sl]
        if side == "right":
            A, B = A[:, ::-1], B[:, ::-1]
        err = _seam_cost(A, B)
        cut = mt.seam_cut(err, lo=4)
        take_a = np.arange(band)[None, :] < cut[:, None]
        strip = np.where(take_a[..., None], A, B)
        out[:, sl] = strip if side == "left" else strip[:, ::-1]
    else:
        sl = slice(0, band) if side == "top" else slice(out.shape[0] - band, out.shape[0])
        A, B = a[sl], out[sl]
        if side == "bottom":
            A, B = A[::-1], B[::-1]
        err = _seam_cost(A, B).T
        cut = mt.seam_cut(err, lo=4)
        take_a = np.arange(band)[:, None] < cut[None, :]
        strip = np.where(take_a[..., None], A, B)
        out[sl] = strip if side == "top" else strip[::-1]


def edge_match(tile_a, src_b, n, axis, band):
    """Variant b with tile a's border band cut into its edges; first brought to a's scale (Gemini draws the same
    surface at different sizes from one call to the next). None when the scales are too far apart to trust."""
    f = feature_size(tile_a) / max(feature_size(middle(src_b, n)), 1.0)
    print(f"variant scale: {f:.2f}")
    if not 0.55 <= f <= 2.2:
        return None
    if abs(f - 1.0) > 0.08:
        src_b = rescale(src_b, f)
    out = mt.flatten_light(balance(centre(src_b, n), tile_a), axis).astype(np.float32)
    for side in ("left", "right") + (("top", "bottom") if axis == "both" else ()):
        _cut_side(out, tile_a, band, side)
    return out


def quilt(tile, seed, patch_frac=0.25, candidates=48):
    """A new arrangement of a seamless tile's own content (image quilting): patches taken from anywhere in it (it
    wraps), each the candidate that best continues what's already laid, joined to it along minimum-error cuts. Same
    pieces, same size, same colours, a different layout; its edges are then the first tile's (edge_match)."""
    rng = np.random.default_rng(seed)
    n = tile.shape[0]
    P = int(n * patch_frac)
    O = P // 4
    step = P - O
    count = int(math.ceil((n - O) / step))
    size = step * count + O
    out = np.zeros((size, size, 3), np.float32)
    idx = np.arange(P)
    for gy in range(count):
        for gx in range(count):
            y, x = gy * step, gx * step
            best, best_err = None, None
            for _ in range(candidates):
                oy, ox = rng.integers(0, n, 2)
                cand = tile[np.ix_((idx + oy) % n, (idx + ox) % n)]
                err = 0.0
                if gx > 0:
                    err += ((cand[:, :O] - out[y:y + P, x:x + O]) ** 2).sum()
                if gy > 0:
                    err += ((cand[:O, :] - out[y:y + O, x:x + P]) ** 2).sum()
                err *= rng.uniform(1.0, 1.15)   # a little chance, so the same best patch isn't always taken
                if best_err is None or err < best_err:
                    best, best_err = cand, err
            region = out[y:y + P, x:x + P].copy()
            mask = np.ones((P, P), bool)
            if gx > 0:
                cut = mt.seam_cut(_seam_cost(best[:, :O], region[:, :O]), lo=2)
                mask[:, :O] &= np.arange(O)[None, :] >= cut[:, None]
            if gy > 0:
                cut = mt.seam_cut(_seam_cost(best[:O, :], region[:O, :]).T, lo=2)
                mask[:O, :] &= np.arange(O)[:, None] >= cut[None, :]
            out[y:y + P, x:x + P] = np.where(mask[..., None], best, region)
    return out[(size - n) // 2:(size - n) // 2 + n, (size - n) // 2:(size - n) // 2 + n]


def resize(tile, size):
    """A seamless tile to size x size, still seamless: exact area averaging when the sizes divide nicely, else
    bilinear with the samples wrapping round the tile."""
    n = tile.shape[0]
    if n == size:
        return tile
    if n % size == 0 or size % n == 0 or math.gcd(n, size) >= 64:
        return mt.area_resize(tile, size)
    c = (np.arange(size) + 0.5) * n / size - 0.5
    i0 = np.floor(c).astype(np.int64)
    t = (c - i0).astype(np.float32)
    i0 %= n
    i1 = (i0 + 1) % n
    rows = tile[i0] * (1 - t)[:, None, None] + tile[i1] * t[:, None, None]
    return rows[:, i0] * (1 - t)[None, :, None] + rows[:, i1] * t[None, :, None]


def normal_map(rgb, relief):
    lum = rgb @ LUM
    n = rgb.shape[0]
    h = 0.55 * mt.gaussian_wrap(lum, n / 1024.0) + 0.45 * mt.gaussian_wrap(lum, n / 220.0)
    k = 2.6 * relief * n / 512.0
    gx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5 * k
    gy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5 * k
    nrm = np.stack([-gx, gy, np.ones_like(h)], axis=2)
    nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)
    return nrm * 0.5 + 0.5


def orm_map(rgb, roughness, spread, metallic):
    lum = rgb @ LUM
    n = rgb.shape[0]
    cavity = np.maximum(mt.gaussian_wrap(lum, n / 90.0) - lum, 0.0)
    ao = np.clip(1.0 - 2.4 * cavity, 0.35, 1.0)
    r = np.clip(roughness + (0.45 - mt.gaussian_wrap(lum, n / 700.0)) * spread, 0.1, 1.0)
    m = np.full_like(lum, metallic)
    return np.stack([ao, r, m], axis=2)


def rgba(a):
    return np.concatenate([a.astype(np.float32), np.ones(a.shape[:2] + (1,), np.float32)], axis=2)


def main():
    a = args()
    out = Path(a.out)
    first = cutout.load_rgba(a.srcs[0])[..., :3]
    if a.pieces > 0:
        # Gemini paints a surface at whatever size it likes: cut the tile from the part of the swatch that holds the
        # pieces the tile should have, within what the swatch can give (at most a 1.7x enlargement).
        k = pieces_across(first)
        s = min(first.shape[:2])
        want = int(round(a.pieces * s / k))
        most = int(s * 0.94) * 4 // 5
        n_src = max(min(want, most), int(a.size / 1.7))
        print(f"pieces: {k:.0f} across the swatch; the tile takes {n_src} px (wanted {want}, "
              f"{a.pieces * n_src / max(want, 1):.1f} pieces across)")
        tile_a, n = seamless_n(first, a.axis, n_src)
    else:
        tile_a, n = mt.make_seamless(first, a.axis)
    tile_a = mt.flatten_light(tile_a, a.axis).astype(np.float32)
    band = a.band or max(32, n // 8)
    tiles = [tile_a]
    for src in a.srcs[1:]:
        t = edge_match(tile_a, cutout.load_rgba(src)[..., :3], n, a.axis, band)
        if t is None:
            print(f"variant left out (its scale is too far from the first's): {src}")
            continue
        tiles.append(t)
    for k in range(a.quilt):
        q = quilt(tile_a, seed=17 + k)
        for side in ("left", "right") + (("top", "bottom") if a.axis == "both" else ()):
            _cut_side(q, tile_a, band, side)
        tiles.append(q)
    written = []
    for i, t in enumerate(tiles):
        t = resize(t, a.size).astype(np.float32)
        letter = "abcdefgh"[i]
        files = {"albedo": out / f"{a.name}_{letter}.png", "normal": out / f"{a.name}_{letter}_n.png",
                 "orm": out / f"{a.name}_{letter}_orm.png"}
        cutout.save_rgba(rgba(t), files["albedo"])
        cutout.save_rgba(rgba(normal_map(t, a.relief)), files["normal"])
        cutout.save_rgba(rgba(orm_map(t, a.roughness, a.spread, a.metallic)), files["orm"])
        written.append({k: str(v) for k, v in files.items()})
    print("surface: " + json.dumps({"name": a.name, "tile_px": n, "size": a.size, "band": band, "variants": written}))


if __name__ == "__main__":
    main()
