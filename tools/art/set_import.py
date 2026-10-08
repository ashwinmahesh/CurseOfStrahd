#!/usr/bin/env python3
"""Sets 3D-friendly import settings on images Godot has already imported: VRAM compression (BPTC/S3TC) with mipmaps
for art/textures and art/sprites/props (drawn with mipmapped filtering), or, with --sheets, without mipmaps for the
character walk, attack and hero sheets.

Usage: tools/art/set_import.py [--sheets | --normal] [--fast] <image> [<image> ...]      then: make import

--sheets: character sheets drawn through the crisp sprite shader (shaders/world/sprite_crisp.gdshader), which samples
the full-size sheet and never its mipmaps (nor does the title screen's sprite_small.gdshader): VRAM compression without
mipmaps (a quarter less memory). Every committed character sheet's .import says so; make anims and make keys set it
only on the sheets they build (ONLY=), so they never touch the rest.

Edits each <png>.import [params] and removes the cached .md5 under .godot/imported so the next import redoes it
(Godot does not notice a params change by itself). Stdlib only.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SETTINGS = {"compress/mode": "2", "compress/high_quality": "true", "mipmaps/generate": "true"}


def main():
    changed = 0
    args = sys.argv[1:]
    settings = dict(SETTINGS)
    if "--sheets" in args:
        args.remove("--sheets")
        settings["mipmaps/generate"] = "false"
    if "--fast" in args:
        # Big painted tiles (the HD surface sets, W4): S3TC, which imports in seconds, instead of BPTC.
        args.remove("--fast")
        settings["compress/high_quality"] = "false"
    if "--normal" in args:
        # Normal maps (the HD surfaces' _n files, W4): compressed as normal maps (RGTC), which keep their detail.
        args.remove("--normal")
        settings["compress/normal_map"] = "1"
    for arg in args:
        imp = Path(arg + ".import") if not arg.endswith(".import") else Path(arg)
        if not imp.exists():
            print(f"no import file yet (run make import first): {imp}", file=sys.stderr)
            continue
        text = imp.read_text()
        new = text
        for key, val in settings.items():
            new = re.sub(rf"^{re.escape(key)}=.*$", f"{key}={val}", new, flags=re.M)
        if new == text:
            continue
        imp.write_text(new)
        for m in re.finditer(r'res://(\.godot/imported/[^"]+?)\.ctex"', text):
            stem = re.sub(r"\.(s3tc_bptc|bptc|s3tc|etc2|astc)$", "", m.group(1))
            for f in (ROOT / stem).parent.glob(Path(stem).name + "*.md5"):
                f.unlink()
        changed += 1
    print(f"{changed} import files set to VRAM" + ("" if settings["mipmaps/generate"] == "false" else " + mipmaps"))


if __name__ == "__main__":
    main()
