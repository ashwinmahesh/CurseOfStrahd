#!/usr/bin/env python3
"""Builds the environment texture sets from tools/art/texture_recipes.json (P4-09, docs/art/textures.md).

Usage: tools/art/build_textures.py [--generate] [--only theme/surface ...] [--preview-dir DIR] [--hd]

For each recipe: (with --generate) asks Gemini for a swatch through tools/art/generate.sh, saved as
art/generated/textures/<theme>_<surface>.png; then runs blender/make_texture.py, which makes it seamless,
palette-snaps it and writes art/textures/<theme>/<surface>.png and its entry in art/textures/manifest.json.
Without --generate only the processing step runs, from the swatches already generated. --hd writes only the Modern
look's smooth tiles beside them (<surface>_hd.png, the entry's hd_file). Stdlib only.
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"
RECIPES = ROOT / "tools" / "art" / "texture_recipes.json"
MANIFEST = ROOT / "art" / "textures" / "manifest.json"

# How the lead applies the sets (kept in the manifest so the game side can read it).
APPLY = {
    "size_px": 512,
    "colour_space": "sRGB albedo, already snapped to art/palette/palette.json",
    "import": "VRAM compressed with mipmaps (the .import files are in the repo)",
    "filter": "linear with mipmaps (anisotropic for floors); nearest without mipmaps shimmers at the combat camera",
    "repeat": True,
    "tile_world_units": "world units (5 ft squares) one copy of the tile spans; UV = world position / tile_world_units",
    "wrap": "xy tiles both ways; x tiles horizontally only and is mapped once over the wall height",
}

# Suggested use per ArenaBoard theme (world/combat/arena_board.gd): which surface goes on which part.
# floor = '.' cells, floor_alt = the second floor material it mixes in, difficult = '~' cells, wall = '#' boxes,
# roof = the cap on village houses, outer = a perimeter wall.
ARENA_THEMES = {
    "village": {"floor": "village/grass", "floor_alt": "village/cobbles", "difficult": "village/mud_road",
                "wall": "village/house_wall", "roof": "village/roof_thatch", "roof_alt": "village/roof_slate"},
    "vallaki": {"floor": "vallaki/cobbled_square", "floor_alt": "village/cobbles", "difficult": "village/mud_road",
                "wall": "vallaki/house_wall", "outer": "vallaki/palisade_logs", "roof": "village/roof_slate"},
    "tavern": {"floor": "interior/wood_planks", "floor_alt": "interior/rug", "wall": "interior/plaster_wall"},
    "shop": {"floor": "interior/wood_planks", "floor_alt": "interior/rug", "wall": "interior/plaster_wall"},
    "townhouse": {"floor": "interior/wood_planks", "floor_alt": "interior/rug", "wall": "interior/wainscot_wall"},
    "manor": {"floor": "interior/wood_planks", "floor_alt": "interior/rug", "wall": "interior/wainscot_wall"},
    "attic": {"floor": "interior/wood_planks", "wall": "interior/plaster_wall"},
    "church": {"floor": "church/stone_flags", "wall": "church/stone_wall"},
    "dungeon": {"floor": "dungeon/stone_floor", "difficult": "village/mud_road", "wall": "dungeon/stone_wall",
                "wall_alt": "dungeon/damp_brick"},
}


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--generate", action="store_true", help="generate the source swatches with Gemini first")
    p.add_argument("--only", nargs="*", default=[], help="theme/surface keys to build (default: all)")
    p.add_argument("--preview-dir", default="", help="also write a 3x3 tiled preview per texture here")
    p.add_argument("--manifest-only", action="store_true", help="only rewrite the manifest's apply/arena_themes")
    p.add_argument("--hd", action="store_true", help="only the Modern look's smooth tiles (<surface>_hd.png)")
    a = p.parse_args()
    rec = json.loads(RECIPES.read_text())
    failed = []
    for theme, surfaces in rec["themes"].items():
        for surf, r in surfaces.items():
            if a.manifest_only:
                continue
            key = f"{theme}/{surf}"
            if a.only and key not in a.only:
                continue
            src = ROOT / "art" / "generated" / "textures" / f"{theme}_{surf}.png"
            if a.generate:
                prompt = rec["prompt_template"].format(subject=r["subject"], view=rec["views"][r["view"]])
                g = subprocess.run([str(ROOT / "tools" / "art" / "generate.sh"), f"{theme}_{surf}", "textures", prompt,
                                    "--aspect", "1:1"], cwd=ROOT)
                if g.returncode != 0:
                    failed.append(key)
                    continue
            if not src.exists():
                print(f"missing swatch for {key}: run with --generate", file=sys.stderr)
                failed.append(key)
                continue
            cmd = [BLENDER, "-b", "--python", str(ROOT / "blender" / "make_texture.py"), "--", "--in", str(src),
                   "--theme", theme, "--surface", surf, "--axis", r.get("axis", "both"),
                   "--tile-units", str(r.get("tile_world_units", 2.0)), "--saturate", str(r.get("saturate", 1.0))]
            if r.get("palette"):
                cmd += ["--palette", ",".join(r["palette"])]
            if r.get("note"):
                cmd += ["--note", r["note"]]
            if a.hd:
                cmd += ["--hd"]
            if a.preview_dir:
                cmd += ["--preview", str(Path(a.preview_dir).resolve() / f"{theme}_{surf}.png")]
            out = subprocess.run(cmd, capture_output=True, text=True)
            line = next((l for l in out.stdout.splitlines() if l.startswith("texture:")), None)
            if out.returncode != 0 or line is None:
                print(out.stdout[-800:] + out.stderr[-800:], file=sys.stderr)
                failed.append(key)
            else:
                print(line)
    if MANIFEST.exists():
        data = json.loads(MANIFEST.read_text())
        data = {"apply": APPLY, "arena_themes": ARENA_THEMES, "themes": data.get("themes", {})}
        MANIFEST.write_text(json.dumps(data, indent=2) + "\n")
    if failed:
        sys.exit(f"failed: {', '.join(failed)}")


if __name__ == "__main__":
    main()
