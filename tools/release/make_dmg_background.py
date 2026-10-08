#!/usr/bin/env python3
"""The Mac disk image's window background: plain off-white, with an arrow from where the game's icon sits to where the
Applications folder sits, and "Drag to Applications" below it: the standard Mac installer look, clean and light
(owner, 2026-10-08). With a background picture Finder always draws the window in light mode, black names included,
so one light background reads the same on Macs in dark mode.

  python3 tools/release/make_dmg_background.py      (needs Pillow and macOS's tiffutil; the output is committed)

Writes tools/release/dmg_background.tiff at 660x400 and, inside the same file, 1320x800 for Retina screens. The icon
positions here must match tools/release/dmg_settings.py.
"""
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
W, H = 660, 400
APP_AT, APPS_AT = (170, 170), (490, 170)   # icon centres, in points
PAPER = (245, 245, 247)    # Apple's light grey; Finder always shows a picture-backed window in light mode
ARROW = (174, 174, 178)
INK = (110, 110, 115)      # Apple's secondary-label grey
FONT = "/System/Library/Fonts/SFNS.ttf"   # San Francisco, macOS's own font


def draw(scale: int) -> Image.Image:
	"""The standard installer look: a quiet light window, a thin arrow between the icons, one line of instruction.
	Drawn four times larger and shrunk, so the arrow's lines are smooth."""
	s = scale * 4
	img = Image.new("RGB", (W * s, H * s), PAPER)
	d = ImageDraw.Draw(img)
	y = APP_AT[1] * s
	x0, x1 = (APP_AT[0] + 84) * s, (APPS_AT[0] - 84) * s
	stroke = 3 * s
	d.line([(x0, y), (x1, y)], fill=ARROW, width=stroke)
	for dy in (-1, 1):   # an open chevron for the head, with rounded ends
		d.line([(x1 - 13 * s, y + dy * 13 * s), (x1, y)], fill=ARROW, width=stroke)
	for cx, cy in [(x0, y), (x1, y), (x1 - 13 * s, y - 13 * s), (x1 - 13 * s, y + 13 * s)]:
		r = stroke / 2
		d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=ARROW)
	font = ImageFont.truetype(FONT, 15 * s)
	font.set_variation_by_name("Medium")
	text = "Drag to Applications"
	# Finder's title bar takes about 28 points off the bottom of the window, so the text sits well above it.
	d.text(((W * s - d.textlength(text, font=font)) / 2, 284 * s), text, font=font, fill=INK)
	return img.resize((W * scale, H * scale), Image.LANCZOS)


def main() -> None:
	out = ROOT / "tools/release/dmg_background.tiff"
	with tempfile.TemporaryDirectory() as tmp:
		one, two = Path(tmp) / "bg.png", Path(tmp) / "bg@2x.png"
		draw(1).save(one)
		draw(2).save(two, dpi=(144, 144))
		subprocess.run(["tiffutil", "-cathidpicheck", str(one), str(two), "-out", str(out)], check=True)
	print("make_dmg_background: %s" % out.relative_to(ROOT))


if __name__ == "__main__":
	main()
