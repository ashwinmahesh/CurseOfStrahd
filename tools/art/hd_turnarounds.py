#!/usr/bin/env python3
"""HD turnarounds (docs/art/animation.md, HD sheets): asks Gemini to redraw each character's turnaround at twice the
size, line for line with sharper ink, then gives the redraw the original's colours and checks it is the same sheet
(blender/hd_colour.py). A redraw that isn't (another layout, a figure of another size) is asked for again.

Usage: tools/art/hd_turnarounds.py [--only id ...] [--force] [--jobs 3] [--retry 2] [--heroes]

Writes art/generated/characters/<id>_turnaround_hd.png next to <id>_turnaround.png; render_walk.py and
render_attack.py use it when it exists. Characters that already have one are skipped unless --force. The six heroes
are left out unless --heroes (theirs came with the fuller set, tools/art/build_keys.py). Every call goes through
tools/art/generate_gemini.py (logged) and takes one from GEMINI_BUDGET when set; a spent daily quota or credits
stop the run.
"""
import argparse
import json
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gemini_budget  # noqa: E402
from build_keys import HEROES  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"
ASPECTS = {"16:9": 16 / 9, "21:9": 21 / 9, "3:2": 3 / 2, "4:3": 4 / 3, "1:1": 1.0}
PROMPT = ("Character turnaround sheet of {who}, the same character as in the reference turnaround sheet: redraw the "
          "identical sheet at high resolution, with every view, pose, proportion, colour, piece of clothing, gear and "
          "detail exactly as in the reference, the same views in one row in the same order, positions and spacing, but "
          "drawn with crisp, clean, bold black ink outlines, sharp detailed features and clean flat cel shading. Plain "
          "flat white background, no ground shadow, no text.")
BACKOFF = (60, 120, 240, 480)
_stop = False


def characters():
    """(id, turnaround path) for every character with a walk sheet in art/manifest.json."""
    for a in json.loads((ROOT / "art" / "manifest.json").read_text())["assets"]:
        sp, src = a.get("sprites"), a.get("source")
        if isinstance(sp, str) and sp.endswith("/walk.tres") and isinstance(src, str) and (ROOT / src).exists():
            yield Path(sp).parent.name, ROOT / src


def aspect(path):
    out = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(path)], capture_output=True, text=True)
    nums = [int(line.split()[-1]) for line in out.stdout.splitlines() if "pixel" in line]
    ratio = nums[0] / nums[1]
    return min(ASPECTS, key=lambda k: abs(ASPECTS[k] - ratio))


def generate(asset_id, src, who):
    """One redraw; False when it failed or the run must stop."""
    global _stop
    for wait in (*BACKOFF, None):
        if _stop:
            return False
        if not gemini_budget.take():
            print(f"STOP {asset_id}: the Gemini call budget is spent ({gemini_budget.used()})", flush=True)
            _stop = True
            return False
        r = subprocess.run([sys.executable, str(ROOT / "tools" / "art" / "generate_gemini.py"), f"{asset_id}_turnaround_hd",
                            "characters", PROMPT.format(who=who), "--aspect", aspect(src), "--size", "2K",
                            "--ref", str(src)], capture_output=True, text=True)
        out = r.stderr + r.stdout
        if "per_day" in out or "credits are depleted" in out or "(402)" in out:
            print(f"STOP {asset_id}: Gemini's daily quota or credits are used up", flush=True)
            _stop = True
            return False
        limited = "rate limit" in out or "(429)" in out
        if r.returncode == 0 or not limited or wait is None:
            break
        print(f"rate limited ({asset_id}); waiting {wait} s", flush=True)
        time.sleep(wait)
    if r.returncode != 0:
        print(f"FAILED {asset_id}: {(r.stderr or r.stdout).strip()[-300:]}", flush=True)
    return r.returncode == 0


def colour(asset_id):
    """hd_colour.py on the new redraw: (ok, message)."""
    r = subprocess.run([BLENDER, "-b", "--python-exit-code", "1", "--python", str(ROOT / "blender" / "hd_colour.py"),
                        "--", "--id", asset_id], capture_output=True, text=True)
    lines = [ln for ln in r.stdout.splitlines() if ln.startswith("HD ")]
    return r.returncode == 0, (lines[-1] if lines else (r.stdout + r.stderr).strip()[-300:])


def redraw(job):
    asset_id, src, who, tries = job
    out = src.with_name(src.stem + "_hd.png")
    for attempt in range(1 + tries):
        if not generate(asset_id, src, who):
            out.unlink(missing_ok=True)
            return False
        ok, msg = colour(asset_id)
        print(("ok  " if ok else "redo ") + msg, flush=True)
        if ok:
            return True
        out.unlink(missing_ok=True)
    print(f"GAVE UP {asset_id}: no faithful redraw in {1 + tries} tries", flush=True)
    return False


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--only", nargs="*")
    p.add_argument("--force", action="store_true")
    p.add_argument("--jobs", type=int, default=3)
    p.add_argument("--retry", type=int, default=2)
    p.add_argument("--heroes", action="store_true")
    a = p.parse_args()
    reg = json.loads((ROOT / "art" / "anim" / "animations.json").read_text())
    jobs = []
    for asset_id, src in characters():
        if a.only and asset_id not in a.only:
            continue
        if asset_id in HEROES and not a.heroes and not a.only:
            continue
        if src.with_name(src.stem + "_hd.png").exists() and not a.force:
            continue
        who = reg.get(asset_id, {}).get("who") or asset_id.replace("_", " ")
        jobs.append((asset_id, src, who, a.retry))
    print(f"{len(jobs)} turnarounds to redraw", flush=True)
    with ThreadPoolExecutor(max_workers=a.jobs) as pool:
        results = list(pool.map(redraw, jobs))
    failed = [j[0] for j, ok in zip(jobs, results) if not ok]
    print(f"redrew {len(jobs) - len(failed)} of {len(jobs)}" + (f"; failed: {' '.join(failed)}" if failed else ""))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
