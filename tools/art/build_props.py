#!/usr/bin/env python3
"""Builds the set-dressing props from tools/art/prop_recipes.json (docs/art/set_dressing.md).

Usage: tools/art/build_props.py [--generate] [--only sheet ...] [--jobs N]

With --generate, asks Gemini (through tools/art/generate.sh, so the model is pinned and every call is logged) for
each sheet's source: four objects in a 2 x 2 grid, or one object, saved as art/generated/props/sheet_<name>.png.
Sheets that already have a source are skipped unless named in --only. At most --jobs calls run at once (default 2:
the Gemini account is shared), and a rate-limit or server error is retried with backoff; out of credits (402)
stops the run. Then blender/prop_sheets.py cuts every source into art/sprites/props/<id>.png and records each in
art/sprites/props/manifest.json. After a first build of new props: make import, then tools/art/set_import.py on them.
Stdlib only.
"""
import argparse
import json
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"
RECIPES = ROOT / "tools" / "art" / "prop_recipes.json"
SLOTS = 4


def source(name):
    return ROOT / "art" / "generated" / "props" / f"sheet_{name}.png"


def prompt(rec, sheet):
    subjects = sheet.get("subjects") or [rec["props"][i]["subject"] for i in sheet["items"]]
    view = rec["views"][sheet["view"]]
    if len(subjects) == 1:
        return rec["single_prompt"].format(subjects[0], view=view)
    assert len(subjects) == SLOTS, f"a sheet holds {SLOTS} props"
    return rec["sheet_prompt"].format(*subjects, view=view)


def generate(rec, name, sheet, stop):
    """One Gemini call, retried on rate limits and server errors. Returns an error string or ''."""
    delay = 8.0
    for attempt in range(6):
        if stop:
            return "stopped (out of credits)"
        r = subprocess.run([str(ROOT / "tools" / "art" / "generate.sh"), f"sheet_{name}", "props", prompt(rec, sheet),
                            "--aspect", sheet.get("aspect", "1:1")], cwd=ROOT, capture_output=True, text=True)
        if r.returncode == 0:
            print(f"generated: sheet_{name}", flush=True)
            return ""
        err = (r.stderr or r.stdout).strip().splitlines()[-1] if (r.stderr or r.stdout).strip() else "failed"
        if "(402)" in err:
            stop.append(True)
            return err
        if any(code in err for code in ("(429)", "(500)", "(502)", "(503)", "(504)", "No image returned", "timed out")):
            print(f"retrying sheet_{name} in {delay:.0f}s: {err[:160]}", flush=True)
            time.sleep(delay)
            delay *= 2
            continue
        return err
    return "gave up after retries"


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--generate", action="store_true")
    p.add_argument("--only", nargs="*", default=[])
    p.add_argument("--jobs", type=int, default=2)
    a = p.parse_args()
    rec = json.loads(RECIPES.read_text())
    sheets = {n: s for n, s in rec["sheets"].items() if not a.only or n in a.only}
    failed = {}
    if a.generate:
        todo = [n for n in sheets if a.only or not source(n).exists()]
        stop = []
        with ThreadPoolExecutor(max_workers=a.jobs) as pool:
            for n, err in zip(todo, pool.map(lambda n: generate(rec, n, sheets[n], stop), todo)):
                if err:
                    failed[n] = err
    jobs = []
    for n, s in sheets.items():
        if n in failed:
            continue
        if not source(n).exists():
            failed[n] = "no source yet: run with --generate"
            continue
        layout = "1x1" if len(s["items"]) == 1 else "2x2"
        items = []
        for slot, pid in enumerate(s["items"]):
            r = rec["props"][pid]
            item = {"id": pid, "slot": slot, "mount": r.get("mount", s["view"])}
            for k in ("height", "width", "saturate", "max"):
                if k in r:
                    item[k] = r[k]
            items.append(item)
        jobs.append({"src": str(source(n).relative_to(ROOT)), "layout": layout, "items": items})
    if jobs:
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
            json.dump(jobs, f)
        out = subprocess.run([BLENDER, "-b", "--python", str(ROOT / "blender" / "prop_sheets.py"), "--", "--jobs", f.name],
                             capture_output=True, text=True)
        Path(f.name).unlink()
        lines = [l for l in out.stdout.splitlines() if l.startswith("prop")]
        print("\n".join(lines))
        if out.returncode != 0 or any(l.startswith("props failed") for l in lines):
            print(out.stdout[-1500:] + out.stderr[-1500:], file=sys.stderr)
            failed["cutting"] = "see output"
    if failed:
        for n, err in failed.items():
            print(f"FAILED {n}: {err}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
