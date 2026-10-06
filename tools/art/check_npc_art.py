#!/usr/bin/env python3
"""Lists NPCs (data/npcs/*.json) whose portrait or walk sheet is missing: art/portraits/<portrait>.png and
art/sprites/<sprite>/walk.png (each defaults to the NPC id). Also lists the mood portraits each one has.

An NPC needs a walk sheet only if something can put it on a map: it names a `sprite`, a location places it
(data/locations/*.json `npcs`), or it can join as a guest. The rest are voices with a portrait only (the Amber
Temple's vestiges speak from their sarcophagi), shown as "portrait only".

Usage: tools/art/check_npc_art.py [--all]      (--all prints every NPC, not just the ones missing art)
Exit code 0 either way: missing art is a to-do list, not a failure.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MOODS = ("neutral", "smile", "angry", "afraid", "sad", "sly", "weary")


def placed_npcs():
    out = set()
    for f in (ROOT / "data" / "locations").glob("*.json"):
        for n in json.loads(f.read_text()).get("npcs", []):
            out.add(str(n.get("npc", "")))
    return out


def main():
    show_all = "--all" in sys.argv
    placed = placed_npcs()
    missing = []
    for f in sorted((ROOT / "data" / "npcs").glob("*.json")):
        npc = json.loads(f.read_text())
        nid = npc.get("id", f.stem)
        walks = "sprite" in npc or nid in placed or bool(npc.get("guest", False))
        portrait, sprite = str(npc.get("portrait", nid)), str(npc.get("sprite", nid))
        has_p = (ROOT / "art" / "portraits" / f"{portrait}.png").exists()
        has_s = not walks or (ROOT / "art" / "sprites" / sprite / "walk.png").exists()
        moods = [m for m in MOODS if (ROOT / "art" / "portraits" / f"{portrait}_{m}.png").exists()]
        gaps = ([] if has_p else [f"portrait {portrait}"]) + ([] if has_s else [f"sprite {sprite}"])
        if gaps:
            missing.append(nid)
        if gaps or show_all:
            if not walks:
                shared = " (portrait only" + ("" if portrait == nid else f", uses {portrait}") + ")"
            else:
                shared = "" if (portrait == nid and sprite == nid) else f" (uses {portrait}/{sprite})"
            print(f"{nid:22s} {'MISSING ' + ', '.join(gaps) if gaps else 'ok'}{shared}"
                  + (f"  moods: {' '.join(moods)}" if moods else ""))
    print(f"{len(missing)} NPCs without full art" + (f": {' '.join(missing)}" if missing else ""))


if __name__ == "__main__":
    main()
