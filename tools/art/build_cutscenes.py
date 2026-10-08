#!/usr/bin/env python3
"""Builds the story cutscenes' pictures from tools/art/cutscene_recipes.json (docs/ui/cutscenes.md).

Usage: tools/art/build_cutscenes.py [--generate] [--only id ...] [--jobs N] [--sheet out.png]

With --generate, asks Gemini (tools/art/generate_gemini.py with the pinned model, so every call is logged and counted
in the art spend ledger) for each picture without a take yet, or a new take of each one named in --only: 16:9 at 2K
with art/prompts/cutscene_preamble.txt, the recipe's characters' turnarounds as references. Takes are kept as
art/generated/cutscenes/<id>_<a, b, ...>.png. Then every recipe with a `use` take has it saved as
art/cutscenes/<id>.jpg (Git LFS), a quality-92 JPEG: Gemini returns JPEG, so the PNG take holds nothing more, and the
game's copy stays a tenth of the size. After new pictures: make import, then tools/art/set_import.py on them, and
`git add -f` their .import files. At most --jobs calls run at once (default 3); a rate-limit or server error is
retried with backoff, and out of credits (402) stops the run. --sheet writes a contact sheet of the newest takes of
--only (or all) for review (Pillow).
"""
import argparse
import io
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
RECIPES = ROOT / "tools" / "art" / "cutscene_recipes.json"
TAKES = ROOT / "art" / "generated" / "cutscenes"
OUT = ROOT / "art" / "cutscenes"
PREAMBLE = "art/prompts/cutscene_preamble.txt"


def takes(cid):
    return sorted(p for p in TAKES.glob(f"{cid}_?.png"))


def next_take(cid):
    used = {p.stem[-1] for p in takes(cid)}
    return next(c for c in string.ascii_lowercase if c not in used)


def ref_name(rid):
    for folder in ("npcs", "monsters"):
        f = ROOT / "data" / folder / f"{rid}.json"
        if f.exists():
            return json.loads(f.read_text()).get("name", rid)
    return rid.replace("_", " ").title()


def prompt(rec, r):
    text = r["prompt"].replace("{party}", rec["party"])
    if r.get("refs"):
        named = ", ".join(f"{i + 1} {ref_name(x)}" for i, x in enumerate(r["refs"]))
        text += (f" The reference images are character turnaround sheets on white, in this order: {named}. Draw each of"
                 " them exactly as their sheet shows them (face, hair, clothes, colours), posed and lit for this scene;"
                 " the sheets themselves are not part of the picture.")
    return text


def generate(rec, cid, stop):
    """One Gemini call, retried on rate limits and server errors. Returns an error string or ''."""
    r = rec["images"][cid]
    name = f"{cid}_{next_take(cid)}"
    cmd = [sys.executable, str(ROOT / "tools" / "art" / "generate_gemini.py"), name, "cutscenes", prompt(rec, r),
           "--aspect", "16:9", "--size", "2K", "--preamble", PREAMBLE, "--model", gemini_budget.pinned_model()]
    for x in r.get("refs", []):
        cmd += ["--ref", str(ROOT / "art" / "generated" / "characters" / f"{x}_turnaround.png")]
    delay = 8.0
    for attempt in range(6):
        if stop:
            return "stopped (out of credits)"
        out = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
        if out.returncode == 0:
            print(f"generated: {name}", flush=True)
            return ""
        err = (out.stderr or out.stdout).strip() or "failed"
        if "(402)" in err or "exceeded your current quota" in err or "Stopped before" in err:
            stop.append(True)
            return err
        if any(code in err for code in ("(429)", "(500)", "(502)", "(503)", "(504)", "No image returned", "timed out")):
            print(f"retrying {name} in {delay:.0f}s: {err.splitlines()[-1][:160]}", flush=True)
            time.sleep(delay)
            delay *= 2
            continue
        return err
    return "gave up after retries"


def jpeg(src):
    from PIL import Image
    buf = io.BytesIO()
    Image.open(src).convert("RGB").save(buf, "JPEG", quality=92, optimize=True, progressive=False)
    return buf.getvalue()


def contact_sheet(ids, out):
    from PIL import Image, ImageDraw
    cells = [(cid, takes(cid)[-1]) for cid in ids if takes(cid)]
    w, h, cols = 640, 357, 3
    rows = (len(cells) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * w, rows * (h + 22)), "black")
    draw = ImageDraw.Draw(sheet)
    for i, (cid, path) in enumerate(cells):
        x, y = (i % cols) * w, (i // cols) * (h + 22)
        sheet.paste(Image.open(path).convert("RGB").resize((w, h)), (x, y + 22))
        draw.text((x + 6, y + 4), path.stem, fill="white")
    sheet.save(out)
    print(f"contact sheet: {out} ({len(cells)} pictures)")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--generate", action="store_true")
    p.add_argument("--only", nargs="*", default=[])
    p.add_argument("--jobs", type=int, default=3)
    p.add_argument("--sheet", default="")
    a = p.parse_args()
    rec = json.loads(RECIPES.read_text())
    unknown = [c for c in a.only if c not in rec["images"]]
    if unknown:
        sys.exit(f"not in {RECIPES.name}: {', '.join(unknown)}")
    ids = a.only or list(rec["images"])
    failed = {}
    if a.generate:
        todo = [c for c in ids if a.only or not takes(c)]
        gemini_budget.preflight(len(todo), "2K", "cutscene pictures")
        stop = []
        TAKES.mkdir(parents=True, exist_ok=True)
        with ThreadPoolExecutor(max_workers=a.jobs) as pool:
            for c, err in zip(todo, pool.map(lambda c: generate(rec, c, stop), todo)):
                if err:
                    failed[c] = err
    copied = 0
    OUT.mkdir(parents=True, exist_ok=True)
    for cid, r in rec["images"].items():
        if not r.get("use"):
            continue
        src = TAKES / f"{cid}_{r['use']}.png"
        dst = OUT / f"{cid}.jpg"
        if not src.exists():
            failed[cid] = f"no take {src.name}"
            continue
        if dst.exists() and dst.stat().st_mtime >= src.stat().st_mtime:
            continue   # already saved from this take (re-encoding all of them takes minutes)
        dst.write_bytes(jpeg(src))
        copied += 1
    print(f"{copied} pictures saved to art/cutscenes")
    if a.sheet:
        contact_sheet(ids, Path(a.sheet))
    for c, err in failed.items():
        print(f"FAILED {c}: {err.splitlines()[-1][:300]}", file=sys.stderr)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
