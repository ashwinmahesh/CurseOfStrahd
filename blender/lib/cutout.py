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


def downsample(arr, k):
    """Area-average an RGBA frame by an integer factor `k` (premultiplied, so edges don't pick up the background):
    a frame rendered at k times the size comes out with smooth, correctly placed edges instead of nearest-pixel steps."""
    if k <= 1:
        return arr
    h, w = arr.shape[:2]
    h2, w2 = h // k, w // k
    a = arr[:h2 * k, :w2 * k]
    alpha = a[..., 3:4]
    pre = np.concatenate([a[..., :3] * alpha, alpha], axis=2)
    pre = pre.reshape(h2, k, w2, k, 4).mean(axis=(1, 3))
    out = pre.copy()
    al = pre[..., 3:4]
    out[..., :3] = np.where(al > 1e-6, pre[..., :3] / np.maximum(al, 1e-6), 0.0)
    return out


def binarize_alpha(arr, threshold=0.5):
    out = arr.copy()
    out[..., 3] = (out[..., 3] >= threshold).astype(np.float32)
    out[out[..., 3] == 0] = 0.0
    return out


def load_palette(names=None):
    """The Strahd palette as an (N, 3) float array; `names` picks a subset (palette.json keys)."""
    data = json.loads((ROOT / "art" / "palette" / "palette.json").read_text())
    keys = list(data) if names is None else list(names)
    return np.array([[int(data[k][i:i + 2], 16) / 255.0 for i in (1, 3, 5)] for k in keys], dtype=np.float32)


# Neutral greys: the palette's grey ramp is cool (stone, slate, pewter, silver), so by redmean alone a
# neutral mid grey lands on warm `bone` (the grey wolf came out beige, Build Log 04). A pixel with almost
# no chroma is only matched against low-chroma palette colours, unless it is near-white (eye glints).
NEUTRAL_PIXEL = 0.06
NEUTRAL_PALETTE = 0.075


def _box_sum(mask, r):
    """Count of True pixels in the (2r+1)^2 window around each pixel (integral image)."""
    h, w = mask.shape
    c = np.pad(mask.astype(np.int32), ((r + 1, r), (r + 1, r))).cumsum(0).cumsum(1)
    k = 2 * r + 1
    return c[k:k + h, k:k + w] - c[:h, k:k + w] - c[k:k + h, :w] + c[:h, :w]


def quantize(arr, palette=None, chunk=200_000, keep_neutrals=True, neutral_area=0.0):
    """Snaps every visible pixel to the nearest palette colour (redmean distance, same as the shader).
    keep_neutrals: grey pixels stay on the grey ramp instead of drifting to bone/tan.
    neutral_area > 0 applies that only where at least that share of the pixel's 7x7 neighbourhood is grey too (wolf
    fur, mail, a grey coat): a thin warm-grey line on skin or cloth (a jaw line, a fold) then snaps to the warm
    browns around it instead of turning into a cool grey blotch. Walk sheets use 0.5."""
    if palette is None:
        palette = load_palette()
    out = arr.copy()
    flat = out.reshape(-1, 4)
    idx = np.nonzero(flat[:, 3] > 0)[0]
    pal_chroma = palette.max(axis=1) - palette.min(axis=1)
    area = None
    if keep_neutrals and neutral_area > 0:
        rgb = arr[..., :3]
        opaque = arr[..., 3] > 0
        grey = ((rgb.max(axis=2) - rgb.min(axis=2)) < NEUTRAL_PIXEL) & (rgb.max(axis=2) < 0.86) & opaque
        area = (_box_sum(grey, 3) >= neutral_area * np.maximum(_box_sum(opaque, 3), 1)).ravel()
    for start in range(0, len(idx), chunk):
        sel = idx[start:start + chunk]
        c = flat[sel, :3][:, None, :]
        p = palette[None, :, :]
        r = (c[..., 0] + p[..., 0]) * 0.5
        d = c - p
        dist = (2 + r) * d[..., 0] ** 2 + 4 * d[..., 1] ** 2 + (3 - r) * d[..., 2] ** 2
        if keep_neutrals and (pal_chroma < NEUTRAL_PALETTE).any():
            px = flat[sel, :3]
            neutral = ((px.max(axis=1) - px.min(axis=1)) < NEUTRAL_PIXEL) & (px.max(axis=1) < 0.86)
            if area is not None:
                neutral &= area[sel]
            dist = dist + np.where(neutral[:, None] & (pal_chroma[None, :] >= NEUTRAL_PALETTE), 10.0, 0.0)
        flat[sel, :3] = palette[np.argmin(dist, axis=1)]
    return out


def saturate(arr, k):
    """Scales colourfulness around each pixel's luma by `k` before quantizing. Gemini's colours are muted and a
    muted red or pink lands on brown (leather, rust) in the saturated Strahd palette; k of about 1.3 keeps it
    red. Greys barely move (they have no chroma to scale). k = 1 is a no-op."""
    if k == 1.0:
        return arr
    out = arr.copy()
    rgb = out[..., :3]
    luma = (rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32))[..., None]
    out[..., :3] = np.clip(luma + (rgb - luma) * k, 0.0, 1.0)
    return out


def _key_rgb(key):
    """Packed 0xRRGGBB keys -> float RGB 0..1 (last axis)."""
    return np.stack([(key >> 16) & 255, (key >> 8) & 255, key & 255], axis=-1).astype(np.float32) / 255.0


def _redmean(a, b):
    """Redmean colour distance between float RGB arrays (the quantizer's metric, square-rooted)."""
    r = (a[..., 0] + b[..., 0]) * 0.5
    d = a - b
    return np.sqrt((2 + r) * d[..., 0] ** 2 + 4 * d[..., 1] ** 2 + (3 - r) * d[..., 2] ** 2)


def despeckle(arr, max_same=1, wrap=False, near=0.0, ring=False):
    """Cleans the salt-and-pepper left when a noisy (JPEG) source is snapped to the palette: an opaque pixel
    with at most `max_same` of its 8 neighbours in its own colour takes its neighbours' most common colour.
    wrap=True treats the image as a tile (textures). Run after quantize; colours stay in the palette.
    near > 0 counts a neighbour within that redmean distance as the pixel's own colour, so a line drawn in two or
    three dark shades (void, ink, grave) is not mistaken for specks. ring=True also requires nothing alike in the
    5x5 ring around the pixel: a thin line sampled down to a dotted line (a jaw line, an eyelid) keeps its dots, and
    only truly lone specks go. Walk sheets use near=0.3, ring=True."""
    out = arr.copy()
    h, w = arr.shape[:2]
    rgb8 = np.round(arr[..., :3] * 255).astype(np.int64)
    key = (rgb8[..., 0] << 16) | (rgb8[..., 1] << 8) | rgb8[..., 2]
    key = np.where(arr[..., 3] > 0, key, -1)
    if wrap:
        nb = np.stack([np.roll(np.roll(key, dy, 0), dx, 1)
                       for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx])
    else:
        pad = np.pad(key, 1, constant_values=-1)
        nb = np.stack([pad[1 + dy:1 + dy + h, 1 + dx:1 + dx + w]
                       for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx])
    if near > 0:
        own = _key_rgb(np.maximum(key, 0))
        same = np.zeros(key.shape, dtype=np.int32)
        for n in nb:
            same += ((n >= 0) & ((n == key) | (_redmean(_key_rgb(np.maximum(n, 0)), own) <= near))).astype(np.int32)
    else:
        same = (nb == key[None]).sum(axis=0)
    fix = (key >= 0) & (same <= max_same)
    if ring and not wrap and fix.any():
        ys, xs = np.nonzero(fix)
        k = key[ys, xs]
        own = _key_rgb(k)
        pad2 = np.pad(key, 2, constant_values=-1)
        extra = np.zeros(len(ys), dtype=np.int32)
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                if max(abs(dy), abs(dx)) < 2:
                    continue
                n = pad2[ys + 2 + dy, xs + 2 + dx]
                alike = (n == k) if near <= 0 else ((n == k) | (_redmean(_key_rgb(np.maximum(n, 0)), own) <= near))
                extra += ((n >= 0) & alike).astype(np.int32)
        fix[ys, xs] = same[ys, xs] + extra <= max_same
    if not fix.any():
        return out
    ys, xs = np.nonzero(fix)
    cand = nb[:, ys, xs]                                   # (8, n)
    votes = (cand[:, None, :] == cand[None, :, :]).sum(axis=1)
    votes = np.where(cand >= 0, votes, -1)
    best = cand[np.argmax(votes, axis=0), np.arange(len(ys))]
    ok = best >= 0
    ys, xs, best = ys[ok], xs[ok], best[ok]
    out[ys, xs, 0] = ((best >> 16) & 255) / 255.0
    out[ys, xs, 1] = ((best >> 8) & 255) / 255.0
    out[ys, xs, 2] = (best & 255) / 255.0
    return out


def smooth_colours(arr, radius=3, sigma=0.06, passes=2):
    """Edge-preserving (bilateral) smoothing of the opaque pixels of a source image, before it is cut and snapped.
    Gemini's JPEG noise and faint painted texture leave a flat area sitting between two palette shades, and the
    snap then turns it into salt-and-pepper (owner feedback 2026-10-06: sprites read noisy). Each pixel is averaged
    with neighbours within `radius` whose colour is within about `sigma` of its own, so flat areas even out while
    ink lines and colour edges (far more than `sigma` apart) stay where they are. Transparent pixels are ignored."""
    out = arr.copy()
    h, w = arr.shape[:2]
    sig_s2 = 2.0 * max(radius / 1.5, 0.5) ** 2
    sig_r2 = 2.0 * sigma ** 2
    offsets = [(dy, dx) for dy in range(-radius, radius + 1) for dx in range(-radius, radius + 1)
               if dy * dy + dx * dx <= radius * radius]
    for _ in range(passes):
        rgb = out[..., :3]
        opaque = out[..., 3] > 0.5
        pr = np.pad(rgb, ((radius, radius), (radius, radius), (0, 0)), mode="edge")
        pa = np.pad(opaque, radius, constant_values=False)
        acc = np.zeros_like(rgb)
        wsum = np.zeros((h, w), dtype=np.float32)
        for dy, dx in offsets:
            n = pr[radius + dy:radius + dy + h, radius + dx:radius + dx + w]
            na = pa[radius + dy:radius + dy + h, radius + dx:radius + dx + w]
            wgt = np.exp(-(dy * dy + dx * dx) / sig_s2 - ((n - rgb) ** 2).sum(axis=2) / sig_r2) * na
            acc += n * wgt[..., None]
            wsum += wgt
        out[..., :3] = np.where(opaque[..., None], acc / np.maximum(wsum, 1e-6)[..., None], rgb)
    return out


def merge_islands(arr, max_size=6, max_contrast=0.45):
    """The majority step after despeckle: a same-coloured patch of at most `max_size` pixels (8-connected) takes the
    most common near shade around it (redmean distance <= `max_contrast`, e.g. two greys, blood and rust, two skin
    tones next to each other on the ramp, void and ink in an outline). Clears the 2-to-6-pixel clumps despeckle leaves
    in flat areas, and evens a line drawn in two dark shades into one, without blurring: lines longer than `max_size`
    are never touched, and a patch with no near shade around it (ink pupils on skin, a highlight, an earring) keeps
    its pixels. Colours stay in the palette; alpha is unchanged."""
    out = arr.copy()
    h, w = arr.shape[:2]
    n = h * w
    rgb8 = np.round(arr[..., :3] * 255).astype(np.int64)
    key = (rgb8[..., 0] << 16) | (rgb8[..., 1] << 8) | rgb8[..., 2]
    key = np.where(arr[..., 3] > 0, key, -1)
    opaque = key >= 0
    offsets = [(dy, dx) for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx]

    def shifted(a, dy, dx, fill):
        p = np.pad(a, 1, constant_values=fill)
        return p[1 + dy:1 + dy + h, 1 + dx:1 + dx + w]

    same = [(shifted(key, dy, dx, -2) == key) & opaque for dy, dx in offsets]
    # Label propagation: after max_size - 1 rounds every patch of max_size pixels or fewer carries one label (its
    # smallest pixel index); a bigger patch still has a seam between labels, which marks all its labels "open".
    big = np.int64(n)
    lab = np.where(opaque, np.arange(n, dtype=np.int64).reshape(h, w), big)
    for _ in range(max_size - 1):
        new = lab.copy()
        for (dy, dx), s in zip(offsets, same):
            np.minimum(new, np.where(s, shifted(lab, dy, dx, big), big), out=new)
        if (new == lab).all():
            break
        lab = new
    is_open = np.zeros(n + 1, dtype=bool)
    for (dy, dx), s in zip(offsets, same):
        is_open[lab[s & (shifted(lab, dy, dx, big) != lab)]] = True
    sizes = np.bincount(lab[opaque], minlength=n + 1)
    small = opaque & (sizes[lab] <= max_size) & ~is_open[lab]
    if not small.any():
        return out
    # The colour around each patch: its pixels' opaque neighbours of another colour, counted per patch.
    pairs = []
    for dy, dx in offsets:
        nk = shifted(key, dy, dx, -1)
        sel = small & (nk >= 0) & (nk != key)
        pairs.append(lab[sel] * (1 << 24) + nk[sel])
    pairs = np.concatenate(pairs)
    if len(pairs) == 0:
        return out
    uniq, counts = np.unique(pairs, return_counts=True)
    plab, pcol = uniq >> 24, uniq & ((1 << 24) - 1)
    # Only near shades are candidates; the most common of them wins.
    near = _redmean(_key_rgb(key.ravel()[plab]), _key_rgb(pcol)) <= max_contrast
    plab, pcol, counts = plab[near], pcol[near], counts[near]
    if len(plab) == 0:
        return out
    order = np.lexsort((counts, plab))
    last = np.append(plab[order][1:] != plab[order][:-1], True)
    best_lab, best_col = plab[order][last], pcol[order][last]
    target = np.full(n + 1, -1, dtype=np.int64)
    target[best_lab] = best_col
    t = np.where(small, target[lab], -1)
    ys, xs = np.nonzero(t >= 0)
    col = t[ys, xs]
    out[ys, xs, 0] = ((col >> 16) & 255) / 255.0
    out[ys, xs, 1] = ((col >> 8) & 255) / 255.0
    out[ys, xs, 2] = (col & 255) / 255.0
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
