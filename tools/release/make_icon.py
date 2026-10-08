#!/usr/bin/env python3
"""The game's app icon from its title art (art/ui/title_backdrop.png): Castle Ravenloft under the moon in a rounded,
gilt-rimmed square, the same art as the site's icon (owner, 2026-10-08: the builds showed Godot's icon).

  python3 tools/release/make_icon.py      (needs Pillow; the outputs are committed, so builds don't)

Writes:
- art/ui/app_icon.png: 1024 px, edge to edge; the window and taskbar icon (project setting application/config/icon).
- art/ui/app_icon.ico: the Windows .exe's icon, 16 to 256 px (the Windows export preset's application/icon).
- tools/release/app_icon.icns: the Mac app's icon, on Apple's icon grid (an 824 px rounded square with a shadow in a
  1024 px canvas), which tools/release/mac_app.py puts in the bundle.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
GOLD = (176, 138, 62, 255)
WINE = (79, 20, 32, 200)


def castle(size: int) -> Image.Image:
	"""The square of the title art around the castle and the moon, at `size` px."""
	art = Image.open(ROOT / "art/ui/title_backdrop.png").convert("RGB")
	side, cx, top = 600, 845, 20
	return art.crop((cx - side // 2, top, cx + side // 2, top + side)).resize((size, size), Image.LANCZOS)


def tile(size: int) -> Image.Image:
	"""The castle in a rounded square with a gilt rim and a wine inner line, filling `size` px."""
	k = size / 1024
	mask = Image.new("L", (size, size), 0)
	# The art stops at the gilt rim's outer edge, so none shows outside it at the corners.
	e = round(10 * k)
	ImageDraw.Draw(mask).rounded_rectangle([e, e, size - 1 - e, size - 1 - e], radius=round(192 * k), fill=255)
	icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	icon.paste(castle(size), (0, 0), mask)
	rim = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	d = ImageDraw.Draw(rim)
	d.rounded_rectangle([e, e, size - 1 - e, size - 1 - e], radius=round(192 * k), outline=GOLD,
		width=max(1, round(22 * k)))
	d.rounded_rectangle([round(34 * k), round(34 * k), size - 1 - round(34 * k), size - 1 - round(34 * k)],
		radius=round(170 * k), outline=WINE, width=max(1, round(10 * k)))
	return Image.alpha_composite(icon, rim)


def mac_tile() -> Image.Image:
	"""The 824 px body for Apple's grid. macOS clips app icons to its own rounder shape, so the art fills the whole
	square and the rims sit far enough in, with round enough corners, to survive the clip."""
	size = 824
	icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	mask = Image.new("L", (size, size), 0)
	ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=185, fill=255)
	icon.paste(castle(size), (0, 0), mask)
	rim = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	d = ImageDraw.Draw(rim)
	d.rounded_rectangle([22, 22, size - 23, size - 23], radius=190, outline=GOLD, width=18)
	d.rounded_rectangle([40, 40, size - 41, size - 41], radius=172, outline=WINE, width=8)
	return Image.alpha_composite(icon, rim)


def mac_icon() -> Image.Image:
	"""Apple's grid: the body at 824 px centred in 1024, with a soft shadow below it."""
	shadow = Image.new("L", (1024, 1024), 0)
	ImageDraw.Draw(shadow).rounded_rectangle([100, 112, 923, 935], radius=185, fill=110)
	canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
	canvas.putalpha(shadow.filter(ImageFilter.GaussianBlur(14)))   # black, as dark as the blurred shape
	canvas.alpha_composite(mac_tile(), (100, 100))
	return canvas


def main() -> None:
	full = tile(1024)
	full.save(ROOT / "art/ui/app_icon.png")
	full.save(ROOT / "art/ui/app_icon.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
	mac_icon().save(ROOT / "tools/release/app_icon.icns")
	print("make_icon: art/ui/app_icon.png, art/ui/app_icon.ico, tools/release/app_icon.icns")


if __name__ == "__main__":
	main()
