#!/usr/bin/env python3
"""Puts monster art where it belongs (docs/plans/engine_split.md): the sprites and portraits of every creature that is in the
engine core's data (its monsters and the generic summons) live in addons/dnd_core/art; the pipelines (make sprite, anims,
portrait, tools/art/new_creatures.py) still write into the game's art/. Run this after them:

    python3 tools/art/route_to_core.py            every such creature found in the game's art/
    python3 tools/art/route_to_core.py wolf ape   only these

It moves art/sprites/<id>/ and art/portraits/<id>.png(+.import) into the core (replacing what is there), points the .tres sheets at
the new place, and moves the creature's height and alias from the game's art/creature_looks.json to the core's. Creatures of the
game's own (its monsters, heroes, NPCs) are never moved. Nothing is committed: the core's new files are committed in the core.
"""
import glob
import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CORE = ROOT / "addons" / "dnd_core"
SUMMONS = {"aberrant_spirit", "animated_object", "bestial_spirit", "bigbys_hand", "celestial_spirit", "construct_spirit", "dinosaur_spirit",
           "elemental_spirit", "fey_spirit", "giant_insect", "guardian_of_faith", "illusion", "imp_familiar", "otherworldly_steed",
           "plant_spirit", "primal_beast", "pseudodragon_familiar", "quasit_familiar", "slaad_tadpole_familiar", "sphinx_familiar",
           "sprite_familiar", "undead_spirit", "venomous_snake_familiar", "severed_arm", "severed_head", "werewolf_human"}


def core_ids():
    ids = set(SUMMONS)
    for f in glob.glob(str(CORE / "data" / "monsters" / "*.json")):
        j = json.loads(Path(f).read_text())
        ids |= {j["id"], j.get("art", j["id"])}
    return ids


def route(only=None):
    ids = core_ids()
    moved = []
    for d in sorted(p for p in (ROOT / "art" / "sprites").iterdir() if p.is_dir()):
        if d.name in ids and (not only or d.name in only):
            dest = CORE / "art" / "sprites" / d.name
            if dest.exists():
                shutil.rmtree(dest)
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(d), str(dest))
            for tres in dest.glob("*.tres"):
                tres.write_text(tres.read_text().replace(f"res://art/sprites/{d.name}/", f"res://addons/dnd_core/art/sprites/{d.name}/"))
            moved.append(d.name)
    for p in sorted((ROOT / "art" / "portraits").glob("*.png")):
        if p.stem in ids and (not only or p.stem in only):
            dest = CORE / "art" / "portraits"
            dest.mkdir(parents=True, exist_ok=True)
            for ext in (".png", ".png.import"):
                src = ROOT / "art" / "portraits" / (p.stem + ext)
                if src.exists():
                    shutil.move(str(src), str(dest / src.name))
            if p.stem not in moved:
                moved.append(p.stem)
    looks_game = ROOT / "art" / "creature_looks.json"
    looks_core = CORE / "art" / "creature_looks.json"
    if looks_game.exists() and looks_core.exists() and moved:
        g, c = json.loads(looks_game.read_text()), json.loads(looks_core.read_text())
        for sect in ("heights", "art_aliases"):
            for k in [k for k in g.get(sect, {}) if k in moved]:
                c.setdefault(sect, {})[k] = g[sect].pop(k)
        looks_game.write_text(json.dumps(g, indent=1) + "\n")
        looks_core.write_text(json.dumps(c, indent=1) + "\n")
    return moved


if __name__ == "__main__":
    done = route(set(sys.argv[1:]) or None)
    print(f"route_to_core: {len(done)} creature(s) now in addons/dnd_core/art: {' '.join(done) if done else '-'}")
