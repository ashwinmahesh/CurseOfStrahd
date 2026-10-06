#!/usr/bin/env python3
"""Builds the Strahd palette files from the single list below (plan §4.1).

Writes art/palette/strahd_palette.gpl (GIMP/Aseprite/Krita), palette.json (tools), and
strahd_palette.png (an N x 1 strip the palette post-process shader samples). Stdlib only.
"""
import json
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "palette"

# name, hex. Near-black instead of pure black; ramps run dark to light.
PALETTE = [
    ("void", "0d0a12"), ("ink", "1a1220"), ("grave", "271c2e"), ("ash_violet", "3a2a44"),
    ("blood_deep", "3d0a14"), ("blood", "6e1023"), ("crimson", "a3192d"), ("vampire_red", "d6283a"), ("rose", "e8606a"),
    ("bruise_deep", "2b1438"), ("bruise", "4a2160"), ("plum", "6d3486"), ("orchid", "9a5bb0"), ("lilac", "c495cf"),
    ("night_deep", "0f1a2e"), ("night", "1c2e4c"), ("moon_blue", "2f4e78"), ("mist_blue", "5379a3"), ("moonlight", "8fb2cf"), ("frost", "c9dfe8"),
    ("bone_dark", "5b4c3e"), ("bone", "8e7a62"), ("parchment", "c7b18a"), ("vellum", "e6d6b0"), ("ivory", "f4ecd6"),
    ("bog_deep", "14261c"), ("bog", "254232"), ("moss", "3e6a3a"), ("sickly", "6f9a3e"), ("bile", "a9c450"),
    ("ember_deep", "4a1e0c"), ("ember", "8a3a12"), ("candle", "d9731e"), ("flame", "f2a93b"), ("wick", "fbe08a"),
    ("stone_deep", "22222a"), ("stone", "3b3b45"), ("slate", "5c5c69"), ("pewter", "8a8a96"), ("silver", "bdbdc6"),
    ("peat", "2b1f1a"), ("umber", "4d382a"), ("walnut", "664a35"),
    ("rust", "6b3a26"), ("leather", "8c5a3a"), ("tan", "b88a5e"),
    ("skin_shadow", "7a4a3c"), ("skin", "c48a6a"), ("skin_light", "e6b896"),
]

# Menus and overlays only (owner feedback after Phase 3: crimson and black with aged gold trim). Written to
# ui_palette.json, never to the strip or the .gpl, so the world's palette pass and the sprite pipeline don't change.
UI_PALETTE = [
    ("ui_black", "120709"), ("ui_oxblood", "2a0c12"), ("ui_wine", "4f1420"),
    ("gilt_dark", "6b4f24"), ("gilt", "b08a3e"), ("gilt_light", "e2c475"),
]


def png_strip(colors, path):
    # one row: filter byte then RGB triples
    row = b"\x00" + b"".join(bytes.fromhex(c) for c in colors)
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    ihdr = struct.pack(">IIBBBBB", len(colors), 1, 8, 2, 0, 0, 0)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(row)) + chunk(b"IEND", b""))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    lines = ["GIMP Palette", "Name: Strahd", "Columns: 8", "#"]
    for name, h in PALETTE:
        r, g, b = bytes.fromhex(h)
        lines.append(f"{r:3d} {g:3d} {b:3d}\t{name}")
    (OUT / "strahd_palette.gpl").write_text("\n".join(lines) + "\n")
    (OUT / "palette.json").write_text(json.dumps({n: "#" + h for n, h in PALETTE}, indent=2) + "\n")
    png_strip([h for _, h in PALETTE], OUT / "strahd_palette.png")
    (OUT / "ui_palette.json").write_text(json.dumps({n: "#" + h for n, h in UI_PALETTE}, indent=2) + "\n")
    print(f"{len(PALETTE)} colours (+{len(UI_PALETTE)} for the UI) written to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
