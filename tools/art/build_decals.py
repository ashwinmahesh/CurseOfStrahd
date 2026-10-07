#!/usr/bin/env python3
"""Builds the decals (Improvement Ideas W10, docs/art/decals.md) from tools/art/decal_recipes.json.

Usage: tools/art/build_decals.py [--generate] [--only sheet ...] [--jobs 3] [--force]

--generate paints each sheet (four marks on white) with Gemini at 2K through tools/art/generate.sh, with
art/prompts/decal_preamble.txt and a look target frame as the style reference, into art/generated/decals/<sheet>.webp
(sheets already there are kept unless --force; the art spend ledger checks the batch first). Then
blender/make_decals.py cuts each sheet into four decals with soft alpha and a normal map, saved as WebP in
art/textures/decals/<sheet>_<n>.webp (and _n.webp), listed in art/textures/decals/manifest.json with each one's
view (floor or wall) and aspect. Then: make import && tools/art/set_import.py art/textures/decals/*.webp && make import
"""
import argparse
import json
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gemini_budget  # noqa: E402
import build_surfaces  # noqa: E402  (its small style references)

ROOT = Path(__file__).resolve().parents[2]
BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"
RECIPES = ROOT / "tools" / "art" / "decal_recipes.json"
OUT = ROOT / "art" / "textures" / "decals"
SHEETS = ROOT / "art" / "generated" / "decals"


def sheet(name):
    """A decal sheet: kept as WebP (Gemini's PNG turned into WebP once it's painted)."""
    png = SHEETS / f"{name}.png"
    if png.exists():
        Image.open(png).convert("RGB").save(SHEETS / f"{name}.webp", "WEBP", quality=94, method=6)
        png.unlink()
    return SHEETS / f"{name}.webp"


def generate(rec, name):
    r = rec["sheets"][name]
    a, b, c, d = r["subjects"]
    prompt = rec["prompt"].format(what=name.split("_", 1)[1], a=a, b=b, c=c, d=d, view=rec["views"][r["view"]])
    cmd = [str(ROOT / "tools" / "art" / "generate.sh"), name, "decals", prompt, "--aspect", "1:1", "--size", "2K",
           "--preamble", "art/prompts/decal_preamble.txt", "--ref", build_surfaces.small_ref(r["ref"])]
    g = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    ok = g.returncode == 0 and sheet(name).exists()
    print(f"{'ok' if ok else 'FAILED'} {name}" + ("" if ok else ": " + (g.stdout + g.stderr)[-400:]), flush=True)
    return ok


def process(rec, name):
    with tempfile.TemporaryDirectory() as tmp:
        out = subprocess.run([BLENDER, "-b", "--python", str(ROOT / "blender" / "make_decals.py"), "--",
                              "--in", str(sheet(name)), "--out", tmp, "--name", name]
                             + (["--along"] if rec["sheets"][name].get("along") else []),
                             capture_output=True, text=True)
        made = [json.loads(l[len("decal: "):]) for l in out.stdout.splitlines() if l.startswith("decal: ")]
        if out.returncode != 0 or not made:
            print(out.stdout[-800:] + out.stderr[-400:], file=sys.stderr)
            return None
        entries = {}
        OUT.mkdir(parents=True, exist_ok=True)
        for m in made:
            if m.get("empty"):
                continue
            id_ = f"{name}_{m['n']}"
            f, fn = OUT / f"{id_}.webp", OUT / f"{id_}_n.webp"
            Image.open(m["file"]).convert("RGBA").save(f, "WEBP", quality=92, method=6)
            Image.open(m["normal"]).convert("RGBA").save(fn, "WEBP", quality=95, method=6)
            entries[id_] = {"file": str(f.relative_to(ROOT)), "normal_file": str(fn.relative_to(ROOT)),
                            "view": rec["sheets"][name]["view"], "aspect": m["aspect"], "sheet": name,
                            "subject": rec["sheets"][name]["subjects"][m["n"] - 1]}
        print(f"decals: {name} ({len(entries)})")
        return entries


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--generate", action="store_true")
    p.add_argument("--only", nargs="*", default=[])
    p.add_argument("--jobs", type=int, default=3)
    p.add_argument("--force", action="store_true")
    a = p.parse_args()
    rec = json.loads(RECIPES.read_text())
    names = [n for n in rec["sheets"] if not a.only or n in a.only]
    failed = []
    if a.generate:
        todo = [n for n in names if a.force or not sheet(n).exists()]
        if todo:
            gemini_budget.preflight(len(todo), "2K", "decal sheets")
            SHEETS.mkdir(parents=True, exist_ok=True)
            with ThreadPoolExecutor(max_workers=max(1, a.jobs)) as pool:
                for n, ok in zip(todo, pool.map(lambda n: generate(rec, n), todo)):
                    if not ok:
                        failed.append(n)
    man = OUT / "manifest.json"
    data = json.loads(man.read_text()) if man.exists() else {}
    data["about"] = ("Decals (docs/art/decals.md, tools/art/build_decals.py): each one's albedo with soft alpha, its "
                     "normal map, whether it lies on a floor or a wall, and its aspect (width / height).")
    decals = data.setdefault("decals", {})
    with ThreadPoolExecutor(max_workers=max(1, a.jobs)) as pool:
        for n, res in zip(names, pool.map(lambda n: process(rec, n) if sheet(n).exists() else None, names)):
            if res is None:
                failed.append(n)
                continue
            for k in [k for k, v in decals.items() if v.get("sheet") == n]:
                del decals[k]
            decals.update(res)
    man.write_text(json.dumps(data, indent=2) + "\n")
    if failed:
        sys.exit(f"failed: {', '.join(sorted(set(failed)))}")


if __name__ == "__main__":
    main()
