"""A decal sheet (four marks on white, Improvement Ideas W10) -> four decals with soft alpha and a normal map.

blender -b --python blender/make_decals.py -- --in sheet.png --out DIR --name <sheet> [--size 512]

Each quarter of the sheet is one mark. Its alpha is how far each pixel is from the sheet's white (the white measured
round the quarter's border, so an off-white sheet still clears), eased in so faint paper texture drops out; its colour
is unmixed from the white (the mark as it would look on its own). The mark is cropped to what it covers, its alpha
faded to nothing at the crop's edge, and scaled to --size on its longer side. The normal map reads the mark's dark
parts as grooves (cracks, ruts) and its body as a slight rise (moss, mud). Writes <name>_<1..4>.png and _n.png into
--out and prints a JSON line per mark with its aspect (width / height).
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import cutout  # noqa: E402

LUM = np.array([0.299, 0.587, 0.114], dtype=np.float32)


def args():
    p = argparse.ArgumentParser()
    p.add_argument("--in", dest="src", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--name", required=True)
    p.add_argument("--size", type=int, default=512)
    p.add_argument("--along", action="store_true", help="marks that run on (wheel ruts): keep the middle of each "
                   "lengthwise, fading out softly toward both ends so copies laid end to end overlap without seams")
    return p.parse_args(sys.argv[sys.argv.index("--") + 1:])


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def box_blur(a, r):
    out = a.copy()
    for ax in (0, 1):
        acc = np.zeros_like(out)
        for d in range(-r, r + 1):
            acc += np.roll(out, d, axis=ax)
        out = acc / (2 * r + 1)
    return out


def area_down(img, k):
    h, w = img.shape[:2]
    h2, w2 = h // k, w // k
    return img[:h2 * k, :w2 * k].reshape(h2, k, w2, k, -1).mean(axis=(1, 3))


def one(q, size, along=False):
    rgb = q[..., :3].copy()
    border = np.concatenate([rgb[:8].reshape(-1, 3), rgb[-8:].reshape(-1, 3), rgb[:, :8].reshape(-1, 3),
                             rgb[:, -8:].reshape(-1, 3)])
    bg = np.clip(np.median(border, axis=0), 0.6, 1.0)
    # Ruled lines Gemini sometimes draws between the quarters: the quarter's own edge band is background.
    e = max(6, q.shape[0] // 64)
    for sl in (np.s_[:e], np.s_[-e:], np.s_[:, :e], np.s_[:, -e:]):
        rgb[sl] = bg
    d = ((bg[None, None, :] - rgb) / bg[None, None, :]).max(axis=2)
    a = smoothstep(0.05, 0.42, d)
    a = np.minimum(a, box_blur(a, 1) * 1.6)        # loose specks of paper texture fade
    colour = np.clip((rgb - (1.0 - a[..., None]) * bg[None, None, :]) / np.maximum(a[..., None], 0.05), 0.0, 1.0)
    ys, xs = np.nonzero(a > 0.03)
    if ys.size == 0:
        return None
    pad = 12
    y0, y1 = max(0, ys.min() - pad), min(a.shape[0], ys.max() + pad)
    x0, x1 = max(0, xs.min() - pad), min(a.shape[1], xs.max() + pad)
    a, colour = a[y0:y1, x0:x1], colour[y0:y1, x0:x1]
    h, w = a.shape
    if along:
        # The middle lengthwise (the tracks run top to bottom, their ends tapered), faded over a third at each end.
        m0, m1 = int(h * 0.1), int(h * 0.9)
        a, colour = a[m0:m1].copy(), colour[m0:m1]
        h = a.shape[0]
        t = np.minimum(np.arange(h), np.arange(h)[::-1]) / (h / 3.0)
        a *= np.clip(t, 0.0, 1.0)[:, None] ** 1.5
    # Fade to nothing at the edges, so a projected decal never shows its box.
    ramp = 16
    fy = np.minimum(np.arange(h), np.arange(h)[::-1])[:, None]
    fx = np.minimum(np.arange(w), np.arange(w)[::-1])[None, :]
    a = a * np.clip(np.minimum(fy, fx) / ramp, 0.0, 1.0)
    k = max(1, int(max(h, w) / size))
    rgba = np.concatenate([colour, a[..., None]], axis=2).astype(np.float32)
    if k > 1:
        rgba = area_down(rgba, k)
    lum = rgba[..., :3] @ LUM
    height = rgba[..., 3] * (0.35 - 0.9 * (1.0 - lum))
    height = box_blur(height, 1)
    gx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5 * 6.0
    gy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5 * 6.0
    nrm = np.stack([-gx, gy, np.ones_like(height)], axis=2)
    nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)
    nrm = nrm * 0.5 + 0.5
    nrm = np.concatenate([nrm, rgba[..., 3:4]], axis=2).astype(np.float32)
    return rgba, nrm, w / float(h)


def main():
    a = args()
    sheet = cutout.load_rgba(a.src)
    H, W = sheet.shape[:2]
    out = Path(a.out)
    for i, (r, c) in enumerate(((0, 0), (0, 1), (1, 0), (1, 1))):
        q = sheet[r * H // 2:(r + 1) * H // 2, c * W // 2:(c + 1) * W // 2]
        res = one(q, a.size, a.along)
        if res is None:
            print("decal: " + json.dumps({"n": i + 1, "empty": True}))
            continue
        rgba, nrm, aspect = res
        f = out / f"{a.name}_{i + 1}.png"
        fn = out / f"{a.name}_{i + 1}_n.png"
        cutout.save_rgba(rgba, f)
        cutout.save_rgba(nrm, fn)
        print("decal: " + json.dumps({"n": i + 1, "file": str(f), "normal": str(fn), "aspect": round(aspect, 3)}))


if __name__ == "__main__":
    main()
