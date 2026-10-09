#!/usr/bin/env python3
"""Renders the six heroes' HD animation sheets (animation set v2, docs/art/animation.md) from their keyframe strips, and
Strahd's (the main villain gets the fuller set too, owner 2026-10-09: idle, walk, attack, hit and cast).

Usage: tools/art/build_keys.py [--only id ...] [--kinds walk8 attack10 ...] [--jobs 2]

Each (hero, kind) is one blender/render_keys.py run (768 px cells from the HD turnaround, rendered at twice the size,
trimmed frames packed into one atlas, mirror-image directions left out). Prints each run's warnings and lists what
failed; `make keys` then imports the sheets and gives them their import settings (tools/art/set_import.py --sheets).
"""
import argparse
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"
HEROES = ["godrick_pendlebrook", "kip_smudgewick", "liriel_dawnsong", "ratatoille", "thistle", "wren_featherfoot"]
KINDS = ["walk8", "attack10", "hurt", "ride", "sneak", "cast"]
## Everyone with the fuller set and the kinds each has: the heroes all six, Strahd a drawn idle with his walk (walk8i)
## and no riding or sneaking.
KEYED = {**{h: KINDS for h in HEROES}, "strahd": ["walk8i", "attack10", "hurt", "cast"]}


def render(asset_id, kind):
    r = subprocess.run([BLENDER, "-b", "--python-exit-code", "1", "--python", str(ROOT / "blender" / "render_keys.py"),
                        "--", "--id", asset_id, "--kind", kind], capture_output=True, text=True)
    lines = [ln for ln in r.stdout.splitlines() if ln.startswith("WARNING") or " sheet: " in ln]
    ok = r.returncode == 0 and any(" sheet: " in ln for ln in lines)
    if not ok:
        tail = [ln for ln in (r.stdout + r.stderr).splitlines() if ln.strip()][-6:]
        lines.append(f"FAILED {asset_id} {kind}: " + " | ".join(tail))
    print(f"== {asset_id} {kind}\n" + "\n".join(lines), flush=True)
    return ok


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--only", nargs="*")
    p.add_argument("--kinds", nargs="*")
    p.add_argument("--jobs", type=int, default=2)
    a = p.parse_args()
    jobs = [(i, k) for i in (a.only or HEROES) for k in (a.kinds or KEYED.get(i, KINDS))]
    with ThreadPoolExecutor(max_workers=a.jobs) as pool:
        results = list(pool.map(lambda j: render(*j), jobs))
    failed = [f"{i} {k}" for (i, k), ok in zip(jobs, results) if not ok]
    if failed:
        sys.exit("failed: " + ", ".join(failed))
    print(f"rendered {len(jobs)} sheets")


if __name__ == "__main__":
    main()
