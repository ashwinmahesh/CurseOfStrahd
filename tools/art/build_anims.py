#!/usr/bin/env python3
"""Renders every character's walk and attack sheets from art/anim/animations.json (docs/art/animation.md).

Usage: tools/art/build_anims.py [--only id ...] [--jobs 3] [--walk-only | --attack-only]

For each character: its walk sheet through tools/art/rerender_sprites.py (the flags art/manifest.json records for it,
e.g. BODY=quadruped or SAT=1.3: the same as make sprites), then blender/render_attack.py from the attack strips
(tools/art/anim_keyframes.py).
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
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_keys import HEROES  # noqa: E402


def blender(script, args):
    r = subprocess.run([BLENDER, "-b", "--python", str(ROOT / "blender" / script), "--", *args],
                       capture_output=True, text=True)
    lines = [ln for ln in r.stdout.splitlines() if ln.startswith(("WARNING", "walk sheet", "attack sheet"))]
    ok = r.returncode == 0 and any(ln.startswith(("walk sheet", "attack sheet")) for ln in lines)
    if not ok:
        tail = [ln for ln in (r.stdout + r.stderr).splitlines() if ln.strip()][-6:]
        lines += [f"FAILED {script}: " + " | ".join(tail)]
    return ok, lines


def build(asset_id, walk, attack):
    out, ok = [], True
    if walk:
        # The walk sheet with the flags the manifest records for it (make sprites), so both tools agree.
        r = subprocess.run([sys.executable, str(ROOT / "tools" / "art" / "rerender_sprites.py"), "--only", asset_id],
                           capture_output=True, text=True)
        good = r.returncode == 0 and "1 sheets rendered" in r.stdout
        ok &= good
        out += [ln.strip() for ln in r.stdout.splitlines() if ln.strip().startswith(("WARNING", "FAILED"))]
        out += ["walk sheet rendered" if good else f"FAILED walk: {(r.stdout + r.stderr).strip()[-400:]}"]
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
    for i in [i for i in ids if i not in reg]:
        print(f"skip {i}: not in {REGISTRY.relative_to(ROOT)} yet", flush=True)
    ids = [i for i in ids if i in reg]
    # The six heroes have the fuller HD set (make keys); their walk and attack aren't cut from the turnaround.
    for i in [i for i in ids if i in HEROES]:
        print(f"skip {i}: an HD hero (make keys ONLY={i})", flush=True)
    ids = [i for i in ids if i not in HEROES]
    manifest = json.loads((ROOT / "art" / "manifest.json").read_text())["assets"]
    sources = {Path(m["sprites"]).parent.name: m.get("source", "") for m in manifest
               if isinstance(m.get("sprites"), str) and m["sprites"].endswith("/walk.tres")}
    ready = [i for i in ids if (ROOT / sources.get(i, "missing")).is_file()]
    for i in sorted(set(ids) - set(ready)):
        print(f"skip {i}: no walk sheet or turnaround yet", flush=True)
    ids = ready
    with ThreadPoolExecutor(max_workers=a.jobs) as pool:
        results = list(pool.map(lambda i: build(i, not a.attack_only, not a.walk_only), ids))
    failed = [i for i, ok in zip(ids, results) if not ok]
    if failed:
        sys.exit(f"failed: {' '.join(failed)}")
    print(f"built {len(ids)} characters")


if __name__ == "__main__":
    main()
