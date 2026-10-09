#!/usr/bin/env python3
"""Joins a look capture's clip (LOOK_CLIP, tools/capture/look_capture.gd) into a GIF, at the pace it ran in the game.

    python3 tools/capture/clip_gif.py <out.gif> <prefix> [<prefix> ...] [--width=800] [--labels=Before,After]

Each prefix is a clip's <out>_<shot> (its frames are <prefix>_clip_000.png on, its times <prefix>_clip.txt). Several
clips play side by side, frame by frame, each scaled to the width and labelled. Needs Pillow (macOS's /usr/bin/python3
has it).
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw


def clip(prefix: str) -> tuple[list[Path], list[float]]:
    times = [float(t) for t in Path(prefix + "_clip.txt").read_text().split()]
    frames = [Path("%s_clip_%03d.png" % (prefix, i)) for i in range(len(times))]
    return [f for f in frames if f.exists()], times


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    if len(args) < 2:
        sys.exit(__doc__)
    out, prefixes = args[0], args[1:]
    width = int(opts.get("width", "800"))
    labels = opts.get("labels", "").split(",") if opts.get("labels") else []
    clips = [clip(p) for p in prefixes]
    count = min(len(frames) for frames, _ in clips)
    times = clips[0][1]
    shown = []
    for i in range(count):
        tiles = []
        for k, (frames, _) in enumerate(clips):
            im = Image.open(frames[i]).convert("RGB")
            im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
            if k < len(labels):
                ImageDraw.Draw(im).text((12, 10), labels[k], fill=(255, 255, 255))
            tiles.append(im)
        sheet = Image.new("RGB", (sum(t.width for t in tiles), max(t.height for t in tiles)))
        x = 0
        for t in tiles:
            sheet.paste(t, (x, 0))
            x += t.width
        shown.append(sheet.quantize(colors=255, method=Image.Quantize.MEDIANCUT))
    # Each frame stays up as long as it lasted in the game (the last one as long as the one before it).
    lengths = [max(20, round((times[i + 1] - times[i]) * 1000)) for i in range(count - 1)]
    lengths.append(lengths[-1] if lengths else 50)
    shown[0].save(out, save_all=True, append_images=shown[1:], duration=lengths, loop=0, optimize=True)
    print("clip_gif: %s, %d frames, %.1f s" % (out, count, sum(lengths) / 1000.0))


if __name__ == "__main__":
    main()
