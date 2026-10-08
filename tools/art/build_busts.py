#!/usr/bin/env python3
"""Builds the dialogue busts from tools/art/bust_recipes.json (docs/ui/busts.md).

Usage: tools/art/build_busts.py [--generate] [--only id ...] [--moods] [--jobs N] [--sheet out.png]

With --generate, asks Gemini (tools/art/generate_gemini.py with the pinned model and the cartoon style preamble, so the
spend ledger counts every call) for each person's neutral bust that has no take yet: half-body, 2:3, from their
turnaround. With --moods it draws each of their moods instead, from the neutral take the recipe uses, so the face and
clothes stay the same. Takes are art/generated/busts/<id>_<mood>_<a, b ...>.png; `use` in the recipes picks one by
"<id>_<mood>" (the first take otherwise). Then every take in use is cut out of its white background (a flood fill from
the edges, stopped by the ink outline) and saved as art/busts/<id>.webp (neutral) or <id>_<mood>.webp, with alpha
(Git LFS). After new busts: make import, then tools/art/set_import.py on them and `git add -f` their .import files.
At most --jobs calls run at once (default 3). --sheet draws a contact sheet of the newest takes for review (Pillow).
"""
import argparse
import json
import string
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gemini_budget  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
RECIPES = ROOT / "tools" / "art" / "bust_recipes.json"
TAKES = ROOT / "art" / "generated" / "busts"
OUT = ROOT / "art" / "busts"
## The game's copy is at most this tall (Gemini's 2:3 at 1K is 848 x 1264).
HEIGHT = 1264


def takes(key):
    return sorted(TAKES.glob(f"{key}_?.png"))


def chosen(rec, key):
    use = rec.get("use", {}).get(key, "")
    if use:
        p = TAKES / f"{key}_{use}.png"
        return p if p.exists() else None
    t = takes(key)
    return t[0] if t else None


def next_take(key):
    used = {p.stem[-1] for p in takes(key)}
    return next(c for c in string.ascii_lowercase if c not in used)


def job(rec, pid, mood):
    """(key, prompt, refs) for one bust."""
    p = rec["people"][pid]
    expr = rec["expressions"][mood]
    if mood == "neutral":
        side = p["side"]
        text = rec["prompt"].replace("{NAME}", p["name"]).replace("{SIDE}", side).replace("{EXPRESSION}", expr)
        return f"{pid}_neutral", text, [str(ROOT / p["ref"])]
    base = chosen(rec, f"{pid}_neutral")
    return f"{pid}_{mood}", rec["mood_prompt"].replace("{EXPRESSION}", expr), [str(base)]


def generate(key, prompt, refs, stop):
    name = f"{key}_{next_take(key)}"
    cmd = [sys.executable, str(ROOT / "tools" / "art" / "generate_gemini.py"), name, "busts", prompt, "--aspect", "2:3",
           "--model", gemini_budget.pinned_model()]
    for r in refs:
        cmd += ["--ref", r]
    delay = 8.0
    for attempt in range(6):
        if stop:
            return "stopped"
        out = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
        if out.returncode == 0:
            print(f"generated: {name}", flush=True)
            return ""
        err = (out.stderr or out.stdout).strip() or "failed"
        if "(402)" in err or "exceeded your current quota" in err or "Stopped before" in err or "No space left" in err:
            stop.append(True)
            return err
        if any(code in err for code in ("(429)", "(500)", "(502)", "(503)", "(504)", "No image returned", "timed out")):
            print(f"retrying {name} in {delay:.0f}s: {err.splitlines()[-1][:160]}", flush=True)
            time.sleep(delay)
            delay *= 2
            continue
        return err
    return "gave up after retries"


def cut_out(src, dst, flip=False):
    """The figure on its white background, cut out: a flood fill from near-white edge pixels (the ink outline stops it),
    eroded a pixel and feathered so no white fringe is left."""
    from PIL import Image, ImageChops, ImageDraw, ImageFilter
    img = Image.open(src).convert("RGB")
    if img.height > HEIGHT:
        img = img.resize((round(img.width * HEIGHT / img.height), HEIGHT), Image.LANCZOS)
    key = (255, 0, 255)
    work = img.copy()
    w, h = work.size
    seeds = [(x, 0) for x in range(0, w, 16)] + [(x, h - 1) for x in range(0, w, 16)] + \
            [(0, y) for y in range(0, h, 16)] + [(w - 1, y) for y in range(0, h, 16)]
    for xy in seeds:
        px = work.getpixel(xy)
        if px != key and min(px) > 225:
            ImageDraw.floodfill(work, xy, key, thresh=40)
    diff = ImageChops.difference(work, Image.new("RGB", work.size, key)).convert("L")
    alpha = diff.point(lambda v: 255 if v > 8 else 0).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    out = img.convert("RGBA")
    out.putalpha(alpha)
    out = out.crop(out.getbbox() or (0, 0, w, h))
    if flip:
        out = out.transpose(Image.FLIP_LEFT_RIGHT)   # drawn facing the wrong way for its side
    out.save(dst, "WEBP", quality=90, method=6)


def contact_sheet(keys, out):
    from PIL import Image, ImageDraw
    cells = [(k, takes(k)[-1]) for k in keys if takes(k)]
    w, h, cols = 280, 420, 8
    rows = (len(cells) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * w, rows * (h + 18)), (60, 50, 70))
    draw = ImageDraw.Draw(sheet)
    for i, (k, path) in enumerate(cells):
        x, y = (i % cols) * w, (i // cols) * (h + 18)
        sheet.paste(Image.open(path).convert("RGB").resize((w - 4, h)), (x + 2, y + 18))
        draw.text((x + 4, y + 3), path.stem, fill="white")
    sheet.save(out, quality=85)
    print(f"contact sheet: {out} ({len(cells)} busts)")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--generate", action="store_true")
    p.add_argument("--moods", action="store_true")
    p.add_argument("--only", nargs="*", default=[])
    p.add_argument("--jobs", type=int, default=3)
    p.add_argument("--sheet", default="")
    a = p.parse_args()
    rec = json.loads(RECIPES.read_text())
    people = a.only or list(rec["people"])
    failed = {}
    if a.generate:
        jobs = []
        for pid in people:
            moods = rec["people"][pid]["moods"] if a.moods else ["neutral"]
            for mood in moods:
                key = f"{pid}_{mood}"
                if a.moods and chosen(rec, f"{pid}_neutral") is None:
                    failed[key] = "no neutral take yet"
                    continue
                if a.only or not takes(key):
                    jobs.append(job(rec, pid, mood))
        gemini_budget.preflight(len(jobs), "", "dialogue busts")
        stop = []
        TAKES.mkdir(parents=True, exist_ok=True)
        with ThreadPoolExecutor(max_workers=a.jobs) as pool:
            for (key, _, _), err in zip(jobs, pool.map(lambda j: generate(*j, stop), jobs)):
                if err:
                    failed[key] = err
    OUT.mkdir(parents=True, exist_ok=True)
    saved = 0
    for pid, person in rec["people"].items():
        for mood in ["neutral"] + person["moods"]:
            src = chosen(rec, f"{pid}_{mood}")
            if src is None:
                continue
            dst = OUT / (f"{pid}.webp" if mood == "neutral" else f"{pid}_{mood}.webp")
            if dst.exists() and dst.stat().st_mtime >= src.stat().st_mtime:
                continue
            cut_out(src, dst, bool(person.get("flip", False)))
            saved += 1
    print(f"{saved} busts saved to art/busts")
    if a.sheet:
        keys = [f"{pid}_{m}" for pid in people for m in ["neutral"] + rec["people"][pid]["moods"]]
        contact_sheet(keys, Path(a.sheet))
    for k, err in failed.items():
        print(f"FAILED {k}: {err.splitlines()[-1][:300]}", file=sys.stderr)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
