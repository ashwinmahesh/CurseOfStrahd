#!/usr/bin/env python3
"""Where wall pieces hang: for each location, every wall-mounted prop or container (portrait, fireplace, window,
tapestry ...), the wall face it hangs on and the area it looks into, using the same rule as SetDressing._hang (the
first open side of its wall square in the order south, west, east, north; doors count as open).

Reports what an author can't see in the data:
  - problems: two pieces on the same wall face (drawn on top of each other), two things (props, containers,
    doors, NPCs, exits) on the same square, a wall piece with no wall to hang on;
  - to check by eye: a piece on a wall square between two areas, with the one it actually hangs into (the old Death
    House portraits hung in the den and inside the secret study this way).

Usage: tools/data/check_wall_pieces.py [location id prefix ...]   (default: death_house)
Exit code 1 if there are problems.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FACES = [(0, 1), (-1, 0), (1, 0), (0, -1)]


def main():
    prefixes = sys.argv[1:] or ["death_house"]
    cat = json.loads((ROOT / "art/sprites/props/catalog.json").read_text())
    man = json.loads((ROOT / "art/sprites/props/manifest.json").read_text())["props"]

    def art_for(spec, container):
        model = spec.get("model", "")
        if spec["id"] in cat["ids"]:
            v = cat["ids"][spec["id"]]
        elif model in cat["models"]:
            v = cat["models"][model]
        elif model in man:
            v = model
        else:
            v = cat["container_default"] if container else None
        return v.get("art") if isinstance(v, dict) else v

    problems = 0
    for f in sorted((ROOT / "data/locations").glob("*.json")):
        loc = json.loads(f.read_text())
        if not any(loc["id"].startswith(p) for p in prefixes):
            continue
        rows = loc["map"]["rows"]
        doors = {tuple(d["cell"]) for d in loc.get("doors") or []}

        def inside(c):
            return 0 <= c[1] < len(rows) and 0 <= c[0] < len(rows[c[1]])

        def wall(c):
            return inside(c) and rows[c[1]][c[0]] == "#" and c not in doors

        def open_(c):
            return inside(c) and rows[c[1]][c[0]] != " " and (rows[c[1]][c[0]] != "#" or c in doors)

        def areas_at(c):
            out = []
            for a in loc.get("areas") or []:
                (x0, z0), (x1, z1) = a["cells"]
                if min(x0, x1) <= c[0] <= max(x0, x1) and min(z0, z1) <= c[1] <= max(z0, z1):
                    out.append(a["id"])
            return out

        lines = []
        notes = []
        faces = {}
        squares = {}
        for kind in ("props", "containers"):
            for p in loc.get(kind) or []:
                c = tuple(p["cell"])
                squares.setdefault(c, []).append(p["id"])
                art = art_for(p, kind == "containers")
                if not art or (man.get(art) or {}).get("mount") != "wall":
                    continue
                if wall(c):
                    n = next((d for d in FACES if open_((c[0] + d[0], c[1] + d[1]))), None)
                    w = c
                else:
                    n = next((d for d in FACES if wall((c[0] - d[0], c[1] - d[1]))), None)
                    w = (c[0] - n[0], c[1] - n[1]) if n else c
                if n is None:
                    lines.append(f"  {p['id']} at {list(c)}: a wall piece with no wall face to hang on")
                    continue
                faces.setdefault((w, n), []).append(p["id"])
                into = areas_at((w[0] + n[0], w[1] + n[1]))
                sides = set()
                for d in FACES:
                    nb = (w[0] + d[0], w[1] + d[1])
                    if open_(nb):
                        sides.update(areas_at(nb))
                if len(sides) > 1:
                    notes.append(f"  check: {p['id']} at {list(c)} hangs into {into or ['no area']} "
                                 f"(its wall also faces {sorted(sides - set(into))})")
        for kind, key in (("doors", "id"), ("exits", "id"), ("npcs", "npc")):
            for e in loc.get(kind) or []:
                squares.setdefault(tuple(e["cell"]), []).append(e[key])
        for (w, n), ids in faces.items():
            if len(ids) > 1:
                lines.append(f"  {ids} hang on the same wall face {list(w)} -> {list(n)}")
        for c, ids in squares.items():
            if len(ids) > 1:
                lines.append(f"  {ids} share the square {list(c)}")
        if lines or notes:
            print(loc["id"])
            print("\n".join(lines + notes))
            problems += len(lines)
    print(f"{problems} placement problems")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
