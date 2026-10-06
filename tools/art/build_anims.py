#!/usr/bin/env python3
"""Renders every character's walk and attack sheets from art/anim/animations.json (docs/art/animation.md).

Usage: tools/art/build_anims.py [--only id ...] [--jobs 3] [--walk-only | --attack-only]

For each character: blender/render_walk.py with the entry's body, saturation, view count and facing (the same
flags `make sprite` takes), then blender/render_attack.py from the attack strips (tools/art/anim_keyframes.py).
Blender runs in parallel, one process per character. Prints each script's warnings and lists what failed; then
`make import` and tools/art/set_import.py give new sheets their VRAM + mipmap import settings (make anims does both).
"""
import argparse
import json
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"
REGISTRY = ROOT / "art" / "anim" / "animations.json"


def blender(script, args):
    r = subprocess.run([BLENDER, "-b", "--python", str(ROOT / "blender" / script), "--", *args],
                       capture_output=True, text=True)
    lines = [ln for ln in r.stdout.splitlines() if ln.startswith(("WARNING", "walk sheet", "attack sheet"))]
    ok = r.returncode == 0 and any(ln.startswith(("walk sheet", "attack sheet")) for ln in lines)
    if not ok:
        tail = [ln for ln in (r.stdout + r.stderr).splitlines() if ln.strip()][-6:]
        lines += [f"FAILED {script}: " + " | ".join(tail)]
    return ok, lines


def build(asset_id, spec, walk, attack):
    out, ok = [], True
    if walk:
        args = ["--turnaround", str(ROOT / spec.get("turnaround", f"art/generated/characters/{asset_id}_turnaround.png")),
                "--id", asset_id]
        if spec.get("body", "humanoid") != "humanoid":
            args += ["--body", spec["body"]]
        if spec.get("saturate"):
            args += ["--saturate", str(spec["saturate"])]
        if spec.get("views"):
            args += ["--views", str(spec["views"])]
        if spec.get("side_faces"):
            args += ["--side-faces", spec["side_faces"]]
        good, lines = blender("render_walk.py", args)
        ok &= good
        out += lines
    if attack:
        good, lines = blender("render_attack.py", ["--id", asset_id])
        ok &= good
        out += lines
    print(f"== {asset_id}\n" + "\n".join(out), flush=True)
    return ok


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--only", nargs="*")
    p.add_argument("--jobs", type=int, default=3)
    g = p.add_mutually_exclusive_group()
    g.add_argument("--walk-only", action="store_true")
    g.add_argument("--attack-only", action="store_true")
    a = p.parse_args()
    reg = json.loads(REGISTRY.read_text())
    ids = a.only or sorted(reg)
    unknown = [i for i in ids if i not in reg]
    if unknown:
        sys.exit(f"not in {REGISTRY.relative_to(ROOT)}: {', '.join(unknown)}")
    with ThreadPoolExecutor(max_workers=a.jobs) as pool:
        results = list(pool.map(lambda i: build(i, reg[i], not a.attack_only, not a.walk_only), ids))
    failed = [i for i, ok in zip(ids, results) if not ok]
    if failed:
        sys.exit(f"failed: {' '.join(failed)}")
    print(f"built {len(ids)} characters")


if __name__ == "__main__":
    main()
