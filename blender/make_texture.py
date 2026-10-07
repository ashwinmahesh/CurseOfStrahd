"""Generated texture swatch -> seamless, palette-snapped tile for the 3D sets (P4-09).

blender -b --python blender/make_texture.py -- --in <png> --theme <theme> --surface <surface>
        [--size 512] [--axis both|x] [--tile-units 2.0] [--max-colours 8] [--palette a,b,c] [--saturate K]
        [--note text] [--preview out.png]

Steps (all numpy, no PIL; runs in Blender's Python like the sprite tools):
1. Seamless by quilting: a square region of N px plus an overlap of m px is taken from the source. The m px
   that run past the tile's right edge are pasted over its left edge and joined to the original along a
   minimum-error cut (dynamic programming), then the same top/bottom. Line art is cut, never cross-faded, so
   there are no ghosted double lines. The cut starts and ends within a pixel of itself so the other axis
   still wraps. --axis x makes it wrap horizontally only (a wainscot wall mapped once over the wall height).
2. Downscale N -> size by exact area averaging on the tile's own grid (wrap-safe).
3. Flatten low-frequency lighting (a vignette or a light gradient in the source would show as a repeating
   blotch): luminance is divided by its wrap-around Gaussian blur, gently (gain clamped to 0.8..1.25).
4. Palette: snap to the full Strahd palette (cutout.quantize), keep the colours that cover the image (at most
   --max-colours, each at least 0.6 %) or the --palette names given, snap again to that subset so no stray hue
   flecks remain, then cutout.despeckle on the tile (wrap-around).
Writes art/textures/<theme>/<surface>.png and its entry in art/textures/manifest.json.
--hd instead writes only the Modern look's tile, <surface>_hd.png (hd_tile), and its entry's hd_file.
"""
import argparse
import json
import math
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import cutout  # noqa: E402

MANIFEST = cutout.ROOT / "art" / "textures" / "manifest.json"


def args():
    p = argparse.ArgumentParser()
    p.add_argument("--in", dest="src", required=True)
    p.add_argument("--theme", required=True)
    p.add_argument("--surface", required=True)
    p.add_argument("--size", type=int, default=512)
    p.add_argument("--axis", choices=["both", "x"], default="both")
    p.add_argument("--tile-units", type=float, default=2.0, help="world units (5 ft squares) one tile should span")
    p.add_argument("--max-colours", type=int, default=8)
    p.add_argument("--palette", default="", help="comma-separated palette names (overrides the automatic subset)")
    p.add_argument("--saturate", type=float, default=1.0, help="chroma boost before quantizing (cutout.saturate)")
    p.add_argument("--note", default="")
    p.add_argument("--preview", default="")
    p.add_argument("--hd", action="store_true", help="write only the Modern look's smooth tile (<surface>_hd.png)")
    return p.parse_args(sys.argv[sys.argv.index("--") + 1:])


# ---------- seamless ----------

def seam_cut(err, lo=1):
    """Minimum-error path through an overlap strip. err: (L, m) cost per step along the seam (rows) and
    position across the strip (cols). Returns cut[L] in [lo, m-1] with |cut[i+1]-cut[i]| <= 1 and
    |cut[-1]-cut[0]| <= 1, so the seam closes on itself when the other axis wraps."""
    L, m = err.shape
    hi = m - 1
    starts = np.arange(lo + 2, hi - 1, max(1, (hi - lo) // 12))
    best = None
    inf = np.float64(1e18)
    for s in starts:
        cost = np.full(m, inf)
        cost[s] = err[0, s]
        back = np.zeros((L, m), dtype=np.int16)
        for i in range(1, L):
            left = np.concatenate(([inf], cost[:-1]))
            right = np.concatenate((cost[1:], [inf]))
            stack = np.stack([left, cost, right])
            k = np.argmin(stack, axis=0)
            back[i] = k - 1
            cost = stack[k, np.arange(m)] + err[i]
            cost[:lo] = inf
            cost[hi + 1:] = inf
        ends = np.arange(max(lo, s - 1), min(hi, s + 1) + 1)
        e = ends[np.argmin(cost[ends])]
        if best is None or cost[e] < best[0]:
            path = np.empty(L, dtype=np.int64)
            path[-1] = e
            for i in range(L - 1, 0, -1):
                path[i - 1] = path[i] + back[i, path[i]]
            best = (cost[e], path)
    return best[1]


def blur3(a):
    """Small box blur along both axes (for the seam error only)."""
    out = a.copy()
    for ax in (0, 1):
        out = (np.roll(out, 1, ax) + out + np.roll(out, -1, ax)) / 3.0
    return out


def make_seamless(rgb, axis):
    s = min(rgb.shape[:2])
    margin = s // 32
    avail = s - 2 * margin
    n = avail * 4 // 5
    m = avail - n
    y0 = (rgb.shape[0] - avail) // 2
    x0 = (rgb.shape[1] - avail) // 2
    r = rgb[y0:y0 + n + m, x0:x0 + n + m].copy()
    # Pass 1: wrap in x. A continues past the right edge, B is the tile's own left strip.
    a, b = r[:, n:n + m], r[:, 0:m]
    err = (blur3(a - b) ** 2).sum(axis=2)
    cut = seam_cut(err)
    cols = np.arange(m)[None, :]
    take_a = cols < cut[:, None]
    strip = np.where(take_a[..., None], a, b)
    r1 = r[:, 0:n].copy()
    r1[:, 0:m] = strip
    if axis == "x":
        return r1[(m // 2):(m // 2) + n], n
    # Pass 2: wrap in y, on the x-wrapped image.
    a, b = r1[n:n + m, :], r1[0:m, :]
    err = (blur3(a - b) ** 2).sum(axis=2).T          # (n cols along the seam, m rows across)
    cut = seam_cut(err)
    rows = np.arange(m)[:, None]
    take_a = rows < cut[None, :]
    strip = np.where(take_a[..., None], a, b)
    tile = r1[0:n].copy()
    tile[0:m] = strip
    return tile, n


def area_resize(tile, size):
    """Exact area averaging from n to size px: repeat by up, box-average by down (n*up == size*down)."""
    n = tile.shape[0]
    g = math.gcd(n, size)
    up, down = size // g, n // g
    if up > 1:
        tile = np.repeat(np.repeat(tile, up, axis=0), up, axis=1)
    h, w = tile.shape[:2]
    return tile.reshape(h // down, down, w // down, down, tile.shape[2]).mean(axis=(1, 3))


# ---------- tone ----------

def gaussian_wrap(a, sigma):
    h, w = a.shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    k = np.exp(-2.0 * (math.pi * sigma) ** 2 * (fx ** 2 + fy ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * k))


def flatten_light(rgb, axis):
    lum = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    low = gaussian_wrap(lum, rgb.shape[0] / 5.0)
    if axis == "x":
        # Only flatten along x: keep the deliberate vertical structure (wainscot below, paper above).
        low = np.broadcast_to(low.mean(axis=0, keepdims=True), low.shape)
    gain = np.clip(lum.mean() / np.maximum(low, 1e-3), 0.8, 1.25)
    return np.clip(rgb * gain[..., None], 0.0, 1.0)


def pick_palette(rgba, max_colours, min_share=0.006):
    names = list(json.loads((cutout.ROOT / "art" / "palette" / "palette.json").read_text()))
    full = cutout.load_palette()
    q = cutout.quantize(rgba, full)[..., :3].reshape(-1, 3)
    idx = np.argmin(((q[:, None, :] - full[None, :, :]) ** 2).sum(axis=2), axis=1)
    counts = np.bincount(idx, minlength=len(full)) / float(len(idx))
    order = [i for i in np.argsort(counts)[::-1] if counts[i] >= min_share][:max_colours]
    return [names[i] for i in order]


def hd_tile(src_tile, snapped):
    """The Modern look's tile (docs/plans/ui_polish.md): the palette-snapped tile's colours, softened so its flat
    bands blend, with the source's own fine shading laid back over them, so a stone keeps the set's hues but reads
    as carved rather than posterised. Wrap-safe (every blur wraps)."""
    w = np.array([0.299, 0.587, 0.114], dtype=np.float32)
    base = np.stack([gaussian_wrap(snapped[..., c], 1.6) for c in range(3)], axis=2)
    lum = src_tile @ w
    detail = lum - gaussian_wrap(lum, 4.0)
    out = base + detail[..., None] * 0.9
    # Keep the snapped tile's overall brightness so the sets match their Classic look in a scene.
    out *= (snapped @ w).mean() / max(float((out @ w).mean()), 1e-3)
    return np.clip(out, 0.0, 1.0).astype(np.float32)


def main():
    a = args()
    src = cutout.load_rgba(a.src)[..., :3]
    tile, n = make_seamless(src, a.axis)
    full_tile = tile
    tile = area_resize(tile, a.size)
    tile = flatten_light(tile, a.axis).astype(np.float32)
    rgba = np.concatenate([tile, np.ones(tile.shape[:2] + (1,), np.float32)], axis=2)
    rgba = cutout.saturate(rgba, a.saturate)
    names = [s.strip() for s in a.palette.split(",") if s.strip()] or pick_palette(rgba, a.max_colours)
    out = cutout.quantize(rgba, cutout.load_palette(names))
    out = cutout.despeckle(cutout.despeckle(out, wrap=True), wrap=True)
    if a.hd:
        # At the seamless tile's own resolution (768 px for a 1024 swatch): the snapped tile is brought up to it.
        hd_size = full_tile.shape[0]
        big = flatten_light(full_tile, a.axis).astype(np.float32)
        snapped_big = area_resize(out[..., :3].astype(np.float32), hd_size)
        hd = hd_tile(big, snapped_big)
        hd_rgba = np.concatenate([hd, np.ones(hd.shape[:2] + (1,), np.float32)], axis=2)
        rel_hd = Path("art") / "textures" / a.theme / f"{a.surface}_hd.png"
        cutout.save_rgba(hd_rgba, cutout.ROOT / rel_hd)
        data = json.loads(MANIFEST.read_text())
        data["themes"][a.theme][a.surface]["hd_file"] = str(rel_hd)
        MANIFEST.write_text(json.dumps(data, indent=2) + "\n")
        print(f"texture: {rel_hd} ({hd_size} px, Modern)")
        return
    rel = Path("art") / "textures" / a.theme / f"{a.surface}.png"
    cutout.save_rgba(out, cutout.ROOT / rel)
    if a.preview:
        cutout.save_rgba(np.tile(out, (3, 3, 1))[::2, ::2], a.preview)
    data = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}
    entry = {
        "file": str(rel),
        "size": a.size,
        "wrap": "xy" if a.axis == "both" else "x",
        "tile_world_units": a.tile_units,
        "palette": names,
        "source": str(Path(a.src).resolve().relative_to(cutout.ROOT)),
    }
    if a.saturate != 1.0:
        entry["saturate"] = a.saturate
    if a.note:
        entry["note"] = a.note
    old = data.setdefault("themes", {}).setdefault(a.theme, {}).get(a.surface, {})
    for k in ("hd_file", "normal_file", "orm_file", "variants", "material", "hd_source"):   # the HD set (W4) stays
        if k in old:
            entry[k] = old[k]
    data["themes"][a.theme][a.surface] = entry
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(data, indent=2) + "\n")
    print(f"texture: {rel} ({a.size} px from a {n} px seamless tile, wrap {entry['wrap']}, colours {', '.join(names)})")


if __name__ == "__main__":   # blender/make_surface.py imports the seamless tools
    main()
