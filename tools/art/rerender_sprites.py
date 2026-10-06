#!/usr/bin/env python3
"""Re-renders every character walk sheet from its turnaround with the current cutter, so a pipeline change
(blender/render_walk.py, blender/lib/cutout.py) reaches all sheets alike.

Usage: tools/art/rerender_sprites.py [--only id ...] [--dry-run]     (make sprites [ONLY="id ..."])

Reads art/manifest.json: every asset whose "sprites" is art/sprites/<dir>/walk.tres and whose "source" turnaround
exists is rendered with `make sprite TURNAROUND=<source> ID=<dir>` plus the asset's "sprite_flags" (e.g. ["SAT=1.3"]
or ["STATIC=1"]), the same flags it was first made with. Ids match the asset id or the sprite folder.
"""
import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def sheets():
    for a in json.loads((ROOT / "art" / "manifest.json").read_text())["assets"]:
        sp, src = a.get("sprites"), a.get("source")
        if not (isinstance(sp, str) and sp.endswith("/walk.tres") and isinstance(src, str)):
            continue
        yield a["id"], Path(sp).parent.name, src, list(a.get("sprite_flags", []))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--only", nargs="*", default=[])
    p.add_argument("--dry-run", action="store_true")
    a = p.parse_args()
    failed, done = [], 0
    for aid, folder, src, flags in sheets():
        if a.only and aid not in a.only and folder not in a.only:
            continue
        if not (ROOT / src).exists():
            print(f"skip {aid}: no turnaround at {src}")
            continue
        cmd = ["make", "--no-print-directory", "sprite", f"TURNAROUND={src}", f"ID={folder}", *flags]
        print(" ".join(cmd), flush=True)
        if a.dry_run:
            continue
        t = time.time()
        r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
        line = next((l for l in r.stdout.splitlines() if l.startswith("walk sheet:")), "")
        if r.returncode != 0 or not line:
            failed.append(aid)
            print(f"  FAILED ({r.returncode}): {(r.stderr or r.stdout)[-400:]}")
        else:
            done += 1
            print(f"  {line.split('(', 1)[-1].rstrip(')')} in {time.time() - t:.0f}s")
    print(f"{done} sheets rendered" + (f", failed: {' '.join(failed)}" if failed else ""))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
