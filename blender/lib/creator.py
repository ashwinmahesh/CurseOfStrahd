"""The character creator's paper doll (docs/art/creator.md): finding the keyed skin, hair and head in Gemini art.

The creator's art is drawn with chroma keys: skin is flat lime green (#7CFC00) and hair and beards are flat magenta
(#FF00FF), each with darker cel shading of its own colour and black ink outlines. Here those keys become shade
indices (0 deep, 1 shadow, 2 base, 3 light) that the game tints with the player's skin tone and hair colour
(world/look/hero_look.gd), and the head (skull and face above the neck) is found so heads, hair and beards drawn
apart can be fitted onto any body.

Images are numpy float arrays shaped (height, width, 4), top row first, RGBA 0..1, as in cutout.py.
"""
import numpy as np

import cutout

# Shades of a keyed region, by value relative to the region's most common value (its flat base tone).
SHADE_CUTS = (0.55, 0.84, 1.1)
# Skin is lime: hue 65-165 degrees, clearly saturated. Hair is magenta: hue 275-345.
SKIN_HUE = (65.0, 165.0)
HAIR_HUE = (275.0, 345.0)
MIN_SAT = 0.28
MIN_VAL = 0.18
# In the stored pieces (PNG, read by the game): alpha 254 marks skin and 253 hair; red holds the shade (0-3).
ALPHA_SKIN = 254
ALPHA_HAIR = 253
# Key colours the Blender renders carry (Closest sampling, no anti-aliasing, so they come back exactly).
KEY_SKIN = [(0.0, 1.0, k / 4.0) for k in range(4)]


def hsv(arr):
    """Hue in degrees, saturation and value, each (h, w)."""
    rgb = arr[..., :3]
    mx = rgb.max(axis=2)
    mn = rgb.min(axis=2)
    d = mx - mn
    sat = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0.0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    safe = np.maximum(d, 1e-6)
    hue = np.where(mx == r, ((g - b) / safe) % 6.0, np.where(mx == g, (b - r) / safe + 2.0, (r - g) / safe + 4.0))
    hue = np.where(d > 1e-6, hue * 60.0, 0.0)
    return hue, sat, mx


def key_mask(arr, hue_range):
    hue, sat, val = hsv(arr)
    return (arr[..., 3] > 0.5) & (hue >= hue_range[0]) & (hue <= hue_range[1]) & (sat >= MIN_SAT) & (val >= MIN_VAL)


def skin_mask(arr):
    return key_mask(arr, SKIN_HUE)


def hair_mask(arr):
    return key_mask(arr, HAIR_HUE)


def shades(arr, mask):
    """Shade index (0-3) for every pixel of `mask` (-1 elsewhere), by value against the region's most common
    value."""
    out = np.full(mask.shape, -1, dtype=np.int8)
    if not mask.any():
        return out
    _, _, val = hsv(arr)
    v = val[mask]
    hist, edges = np.histogram(v, bins=40, range=(0.0, 1.0))
    mode = 0.5 * (edges[int(np.argmax(hist))] + edges[int(np.argmax(hist)) + 1])
    rel = val / max(mode, 1e-3)
    idx = np.full(mask.shape, 3, dtype=np.int8)
    idx[rel <= SHADE_CUTS[2]] = 2
    idx[rel < SHADE_CUTS[1]] = 1
    idx[rel < SHADE_CUTS[0]] = 0
    out[mask] = idx[mask]
    return out


def dilate(mask, r=1):
    out = mask.copy()
    for _ in range(r):
        grown = out.copy()
        grown[1:] |= out[:-1]
        grown[:-1] |= out[1:]
        grown[:, 1:] |= out[:, :-1]
        grown[:, :-1] |= out[:, 1:]
        out = grown
    return out


def fill_holes(mask):
    """`mask` plus everything it encloses (not reachable from the border without crossing it)."""
    outside = np.zeros_like(mask)
    free = ~mask
    outside[0, :] = free[0, :]
    outside[-1, :] = free[-1, :]
    outside[:, 0] = free[:, 0]
    outside[:, -1] = free[:, -1]
    while True:
        grown = dilate(outside, 1) & free
        if (grown == outside).all():
            break
        outside = grown
    return ~outside


def components(mask):
    """Each 4-connected component of `mask` as a boolean mask, largest first."""
    out = []
    for comp in cutout.label_components(mask):
        m = np.zeros(mask.shape, dtype=bool)
        for y, x0, x1 in comp:
            m[y, x0:x1] = True
        out.append(m)
    out.sort(key=lambda m: -int(m.sum()))
    return out


def skin_shadow(arr, skin, region):
    """Greyish mid-tone pixels next to the skin inside `region`: the cool shading Gemini sometimes paints on lime
    skin. Returned so callers can count them as skin shadow (shade 1)."""
    hue, sat, val = hsv(arr)
    greyish = (arr[..., 3] > 0.5) & (val > 0.28) & (val < 0.8) & ~skin & ~hair_mask(arr)
    greyish &= (sat < 0.35) | ((hue > 180.0) & (hue < 300.0))
    near = dilate(skin, 3)
    found = greyish & near & region
    # Grow into the rest of a shadow patch that touches the skin.
    for _ in range(6):
        found |= dilate(found, 1) & greyish & region
    return found


## Where the neck is, as shares of a standing figure's height below the top of the skull (a figure is about 7.3
## heads tall): the narrowest row through the head's centre between these is the cut.
NECK_ROWS = (0.115, 0.19)
## How far either side of the head's centre line the neck's width is measured, as a share of the figure's height.
NECK_REACH = 0.09
## The skull is measured this share of the figure's height below its top (about a third of the way down the head).
SKULL_ROW = 0.045


def _run_width(row, cx):
    """Width of the run of True in `row` that holds column `cx` (or the nearest run to it)."""
    xs = np.nonzero(row)[0]
    if len(xs) == 0:
        return 0
    if not row[cx]:
        cx = int(xs[np.argmin(np.abs(xs - cx))])
    left = cx
    while left > 0 and row[left - 1]:
        left -= 1
    right = cx
    while right + 1 < len(row) and row[right + 1]:
        right += 1
    return right - left + 1


def head(arr, skin=None, fig_h=None, expect=None, top_frac=0.45):
    """Finds the head in a figure: the skin of skull and face above the neck.

    `fig_h` is the standing figure's height (default: this image's); the neck is looked for NECK_ROWS of it below
    the top of the skull, so shoulders and bare arms joined to the neck never count. For a standing figure the head
    is the blob holding the topmost skin; in an attack pose (`expect`: the standing head's area in pixels) it is the
    blob most like that head in size and shape, so raised hands don't win.

    Returns a dict: `blob` (head and neck skin down to the search's end, holes filled), `cut` (the neck row),
    `box` (x0, y0, x1, y1) of the blob above the cut, `cx` (the head's centre column), or None."""
    if skin is None:
        skin = skin_mask(arr)
    h = arr.shape[0]
    fig_h = fig_h or h
    lo_off, hi_off = int(NECK_ROWS[0] * fig_h), int(NECK_ROWS[1] * fig_h)
    cands = []
    for comp in components(skin)[:12]:
        ys = np.nonzero(comp.any(axis=1))[0]
        top = int(ys.min())
        if top > top_frac * h:
            continue
        sub = comp.copy()
        sub[top + hi_off + 1:] = False
        sy, sx = np.nonzero(sub)
        if len(sy) < 40:
            continue
        cands.append((top, sub, float(len(sy)), (sy.max() - sy.min() + 1) * (sx.max() - sx.min() + 1)))
    if not cands:
        return None
    if expect is None:
        top, best, _, _ = min(cands, key=lambda c: c[0])
    else:
        def score(c):
            solidity = c[2] / float(c[3])
            return solidity / (1.0 + 2.0 * abs(np.log(max(c[2], 1.0) / expect)))
        top, best, _, _ = max(cands, key=score)
    blob = fill_holes(best)
    ys, xs = np.nonzero(blob)
    y0 = int(ys.min())
    top_rows = ys < y0 + max(4, lo_off // 3)
    cx = int(np.median(xs[top_rows]))
    lo, hi = y0 + lo_off, min(y0 + hi_off, int(ys.max()))
    # The neck ends where clothing crosses the head's centre line (a collar seen from behind): past it the run
    # through the centre is a sliver of shoulder, not neck.
    for y in range(lo, hi + 1):
        if not blob[y, cx]:
            hi = y - 1
            break
    if hi <= lo:
        cut = int(ys.max()) + 1
    else:
        # Width as the blob's pixels near the head's centre line (ink lines inside an ear would split a single run).
        reach = max(4, int(NECK_REACH * fig_h))
        x0, x1 = max(0, cx - reach), min(blob.shape[1], cx + reach + 1)
        widths = [int(blob[y, x0:x1].sum()) for y in range(lo, hi + 1)]
        # Walking down from the jaw: the narrowest row before the outline flares out into the shoulders (a quarter
        # wider than the narrowest so far). Past the flare a low neckline can pinch the skin narrower again, and that
        # isn't the neck.
        cut, narrowest = lo, widths[0]
        for i, w in enumerate(widths):
            if w < narrowest:
                cut, narrowest = lo + i, w
            elif w > narrowest * 1.25 + 2:
                break
    above = blob.copy()
    above[cut:] = False
    ys2, xs2 = np.nonzero(above)
    if len(ys2) == 0:
        return None
    box = (int(xs2.min()), int(ys2.min()), int(xs2.max()) + 1, int(cut))
    # The skull's width a little below its top, above where ears or a jaw can widen it: what pieces are scaled by.
    top = int(ys2.min())
    row = top + max(2, int(SKULL_ROW * fig_h))
    skull_w = _run_width(blob[min(row, cut - 1)], cx)
    return {"blob": blob, "cut": int(cut), "box": box, "area": float(above.sum()), "cx": cx, "top": top,
            "skull_w": int(skull_w), "skull_row": int(row)}


def head_template(hd, scale=1.0):
    """The standing head (its skin above the neck) as a boolean template at `scale`, with its skull's anchors in the
    template's pixels."""
    blob = hd["blob"].copy()
    blob[hd["cut"]:] = False
    ys, xs = np.nonzero(blob)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    t = blob[y0:y1, x0:x1]
    if abs(scale - 1.0) > 1e-3:
        h, w = t.shape
        nh, nw = max(1, int(round(h * scale))), max(1, int(round(w * scale)))
        t = t[np.minimum((np.arange(nh) / scale).astype(int), h - 1)][:, np.minimum((np.arange(nw) / scale).astype(int), w - 1)]
    return {"mask": t, "cx": (hd["cx"] - x0) * scale, "top": (hd["top"] - y0) * scale,
            "skull_w": hd["skull_w"] * scale, "cut": (hd["cut"] - y0) * scale, "area": float(t.sum())}


def find_head_like(skin, tmpl, top_frac=0.6):
    """Where the standing head sits in a pose: the placement of its template that best matches the pose's skin (skin
    under the template counts for, bare background or cloth against), searched in the upper part of the pose. Raised
    arms touching the head can't pull it off centre the way a blob's outline can. Returns a head dict like head()'s,
    or None."""
    h, w = skin.shape
    t = tmpl["mask"].astype(np.float32)
    th, tw = t.shape
    if th >= h or tw >= w:
        return None
    region = skin[: max(th + 1, int(top_frac * h))].astype(np.float32)
    rh, rw = region.shape
    size = (rh + th, rw + tw)
    f = np.fft.rfft2(region, size)
    g = np.fft.rfft2(t[::-1, ::-1], size)
    overlap = np.fft.irfft2(f * g, size)[th - 1:rh, tw - 1:rw]
    score = 2.0 * overlap - tmpl["area"]
    y, x = np.unravel_index(int(np.argmax(score)), score.shape)
    if score[y, x] < 0.35 * tmpl["area"]:
        return None
    return {"cx": float(x + tmpl["cx"]), "top": float(y + tmpl["top"]), "skull_w": float(tmpl["skull_w"]),
            "cut": int(round(y + tmpl["cut"])), "area": tmpl["area"]}


def encode_keys(arr, skin_shade=None, hair_shade=None):
    """The stored form of a piece: keyed pixels get alpha 254 (skin) or 253 (hair) and their shade in red."""
    out = arr.copy()
    for shade, alpha in ((skin_shade, ALPHA_SKIN), (hair_shade, ALPHA_HAIR)):
        if shade is None:
            continue
        m = shade >= 0
        out[m, 0] = shade[m] / 255.0
        out[m, 1] = 0.0
        out[m, 2] = 0.0
        out[m, 3] = alpha / 255.0
    return out


def to_key_colours(arr, skin, shade):
    """Replaces skin pixels with the render key colour of their shade (for Blender renders of the rig)."""
    out = arr.copy()
    for k, rgb in enumerate(KEY_SKIN):
        m = skin & (shade == k)
        out[m, :3] = rgb
        out[m, 3] = 1.0
    return out


def from_key_colours(arr, tol=3.0 / 255.0):
    """Reads the key colours back from a render: (shade index per pixel or -1, mask of keyed pixels)."""
    shade = np.full(arr.shape[:2], -1, dtype=np.int8)
    vis = arr[..., 3] > 0.5
    for k, rgb in enumerate(KEY_SKIN):
        d = np.abs(arr[..., :3] - np.array(rgb, dtype=np.float32)).max(axis=2)
        shade[vis & (d < tol)] = k
    return shade, shade >= 0
