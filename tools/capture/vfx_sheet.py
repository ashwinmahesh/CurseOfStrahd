#!/usr/bin/env python3
"""Joins the spell-effect captures (tools/capture/vfx_capture.tscn) into before-and-after pictures: for each spell a
side-by-side GIF (effects off on the left, on on the right, frame for frame), a side-by-side still at the moment the
two differ most, and one overview sheet of every spell's still.

python3 tools/capture/vfx_sheet.py captures/vfx/vfx [out_dir]   (needs Pillow)"""
import glob
import json
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageStat

W, H = 1600, 900
HALF = 440          # width of each side in the GIFs
STILL_HALF = 800    # width of each side in the stills


def font(size):
    for path in ["/System/Library/Fonts/Supplemental/Georgia Bold.ttf", "/System/Library/Fonts/Supplemental/Georgia.ttf",
                 "/System/Library/Fonts/Helvetica.ttc"]:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def crop_box(meta_box, wide):
    """The stage's screen box grown to a 16:9 frame with room around it."""
    x, y, w, h = meta_box
    cx, cy = x + w / 2, y + h / 2
    bw = max(w + (520 if wide else 380), (h + 260) * 16 / 9, 760)
    bh = bw * 9 / 16
    left = min(max(cx - bw / 2, 0), W - bw)
    top = min(max(cy - bh / 2 - 30, 0), H - bh)
    return int(left), int(top), int(left + bw), int(top + bh)


def label(img, text, colour):
    d = ImageDraw.Draw(img)
    f = font(max(14, img.width // 22))
    d.rectangle([0, 0, img.width, f.size + 14], fill=(13, 10, 18))
    d.text((12, 6), text, font=f, fill=colour)
    return img


def pair(before, after, box, half, caption=None):
    b = before.crop(box).resize((half, half * 9 // 16), Image.LANCZOS)
    a = after.crop(box).resize((half, half * 9 // 16), Image.LANCZOS)
    label(b, "BEFORE  (effects off)", (199, 177, 138))
    label(a, "AFTER" + (f"  {caption}" if caption else ""), (251, 224, 138))
    out = Image.new("RGB", (half * 2 + 6, b.height), (13, 10, 18))
    out.paste(b, (0, 0))
    out.paste(a, (half + 6, 0))
    return out


def main():
    prefix = sys.argv[1]
    out_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.dirname(prefix)
    meta = json.load(open(prefix + "_meta.json"))
    stills = []
    for key, box in meta.items():
        before = sorted(glob.glob(f"{prefix}_{key}_before_*.jpg"))
        after = sorted(glob.glob(f"{prefix}_{key}_after_*.jpg"))
        n = min(len(before), len(after))
        if n == 0:
            continue
        cb = crop_box(box, key not in ("fire_bolt", "eldritch_blast", "cure_wounds", "divine_smite"))
        name = key.replace("_", " ").title()
        frames = []
        best, best_i = -1.0, 0
        for i in range(n):
            bi, ai = Image.open(before[i]).convert("RGB"), Image.open(after[i]).convert("RGB")
            diff = sum(ImageStat.Stat(ImageChops.difference(bi.crop(cb), ai.crop(cb))).mean)
            if diff > best:
                best, best_i = diff, i
            frames.append(pair(bi, ai, cb, HALF, name))
        gif = os.path.join(out_dir, f"vfx_{key}.gif")
        # Long clips (a lingering area) keep every other frame, so the GIF stays small.
        step = 2 if len(frames) > 80 else 1
        pal = [f.quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE) for f in frames[::step]]
        pal[0].save(gif, save_all=True, append_images=pal[1:], duration=33 * step, loop=0, optimize=True)
        still = pair(Image.open(before[best_i]).convert("RGB"), Image.open(after[best_i]).convert("RGB"), cb, STILL_HALF, name)
        still_path = os.path.join(out_dir, f"vfx_{key}_still.png")
        still.save(still_path)
        stills.append(still)
        print(f"{key}: {n} frames, peak at {best_i}, {gif}, {still_path}")
    if stills:
        sheet = Image.new("RGB", (stills[0].width, sum(s.height + 8 for s in stills)), (13, 10, 18))
        y = 0
        for s in stills:
            sheet.paste(s, (0, y))
            y += s.height + 8
        sheet.save(os.path.join(out_dir, "vfx_overview.png"))
        print("overview:", os.path.join(out_dir, "vfx_overview.png"))


if __name__ == "__main__":
    main()
