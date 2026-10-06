#!/usr/bin/env python3
"""Generates the keyframe strips the animation renderers read (docs/art/animation.md), through the pinned Gemini model.

Usage: tools/art/anim_keyframes.py [--only id ...] [--kind attack|walk] [--views side front ...] [--force] [--jobs 2]
                                   [--retry 2] [--recheck]

For each character in art/anim/animations.json: cuts its turnaround into one reference image per view (Blender,
blender/anim_refs.py, into a temp folder), then asks for one strip per view: art/generated/anim/<id>/<kind>_<view>.png,
three figures drawn from that view's angle (the reference pose, then the two new poses). The prompt comes from
art/prompts/<kind>_keyframes.txt plus the character's entry. Strips that already exist are kept unless --force or
--views names them. Every call is logged by tools/art/generate_gemini.py (art/generation_log.jsonl).

--retry N (attack): after generating, blender/render_attack.py --check reads every strip of the characters touched and
the views it flags (figures merged or clipped, frame 1 not the standing view) are drawn again, up to N more times.
--recheck checks every existing strip of the chosen characters first, too.

kind attack: every character (wind-up, strike). kind walk: four-legged bodies only (two strides, profile and
three-quarter views; head-on views walk with the rig).
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
REGISTRY = ROOT / "art" / "anim" / "animations.json"
VIEW_TEXT = {
    "front": "the front, facing the viewer",
    "front34": "a front three-quarter angle, turned toward the right of the picture",
    "side": "the side, in profile facing right",
    "back34": "a back three-quarter angle, facing away from the viewer toward the upper right",
    "back": "behind, facing straight away from the viewer",
}
WALK_VIEWS = ("front34", "side", "back34")
QUADRUPED_STRIDES = (
    "trotting, legs at full stretch: the front legs reaching forward and the hind legs pushing back",
    "trotting, legs gathered: all four legs drawn in under the body, one front paw lifted",
)


def model():
    return json.loads((ROOT / "art" / "manifest.json").read_text())["image_model"]


def cut_refs(asset_id, out):
    r = subprocess.run([BLENDER, "-b", "--python", str(ROOT / "blender" / "anim_refs.py"), "--",
                        "--id", asset_id, "--out", str(out)], capture_output=True, text=True)
    meta = out / "views.json"
    if r.returncode != 0 or not meta.exists():
        sys.exit(f"{asset_id}: could not cut the turnaround into views\n{r.stdout[-800:]}{r.stderr[-800:]}")
    return list(json.loads(meta.read_text()))


def prompt(kind, spec, view):
    text = (ROOT / "art" / "prompts" / f"{kind}_keyframes.txt").read_text().strip()
    fields = {"WHO": spec["who"], "VIEW": VIEW_TEXT[view]}
    if kind == "attack":
        fields.update(ACTION=spec["attack"], WINDUP=spec["windup"], STRIKE=spec["strike"])
    else:
        a, b = spec.get("strides", QUADRUPED_STRIDES)
        fields.update(STRIDE_A=a, STRIDE_B=b)
    for k, v in fields.items():
        text = text.replace("{" + k + "}", v)
    return text


# Gemini caps the spending rate per billing tier (and other threads share the key): on a rate-limit error,
# wait and try again rather than failing the strip.
BACKOFF = (60, 120, 240, 480)


def generate(job):
    asset_id, kind, view, text, ref = job
    for wait in (*BACKOFF, None):
        r = subprocess.run([sys.executable, str(ROOT / "tools" / "art" / "generate_gemini.py"), f"{kind}_{view}",
                            f"anim/{asset_id}", text, "--model", model(), "--aspect", "21:9", "--ref", str(ref)],
                           capture_output=True, text=True)
        limited = "rate limit" in (r.stderr + r.stdout) or "(429)" in (r.stderr + r.stdout)
        if r.returncode == 0 or not limited or wait is None:
            break
        print(f"rate limited ({asset_id} {kind}_{view}); waiting {wait} s", flush=True)
        time.sleep(wait)
    ok = r.returncode == 0
    print(f"{'ok ' if ok else 'FAILED'} {asset_id} {kind}_{view}" + ("" if ok else f": {(r.stderr or r.stdout).strip()[-300:]}"),
          flush=True)
    return ok


def check(asset_id):
    """Views of `asset_id` whose attack strip should be drawn again, with the reasons."""
    r = subprocess.run([BLENDER, "-b", "--python", str(ROOT / "blender" / "render_attack.py"), "--",
                        "--id", asset_id, "--check"], capture_output=True, text=True)
    for line in r.stdout.splitlines():
        if line.startswith("CHECK "):
            return json.loads(line[6:])
    sys.exit(f"{asset_id}: check failed\n{r.stdout[-800:]}{r.stderr[-800:]}")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--only", nargs="*")
    p.add_argument("--kind", choices=["attack", "walk"], default="attack")
    p.add_argument("--views", nargs="*", help="regenerate just these views (implies --force for them)")
    p.add_argument("--force", action="store_true")
    p.add_argument("--jobs", type=int, default=2)
    p.add_argument("--retry", type=int, default=0)
    p.add_argument("--recheck", action="store_true", help="check every strip first and redraw the flagged ones")
    a = p.parse_args()
    reg = json.loads(REGISTRY.read_text())
    ids = a.only or sorted(reg)
    missing = [i for i in ids if i not in reg]
    if missing:
        sys.exit(f"not in {REGISTRY.relative_to(ROOT)}: {', '.join(missing)}")
    if a.kind == "walk":
        ids = [i for i in ids if reg[i].get("body") == "quadruped"]
    ready = [i for i in ids if (ROOT / reg[i].get("turnaround", f"art/generated/characters/{i}_turnaround.png")).exists()]
    for i in sorted(set(ids) - set(ready)):
        print(f"skip {i}: no turnaround yet", flush=True)
    ids = ready
    with tempfile.TemporaryDirectory(prefix="anim_refs_") as tmp:
        refs_cache = {}

        def refs_for(asset_id):
            if asset_id not in refs_cache:
                refs_cache[asset_id] = cut_refs(asset_id, Path(tmp) / asset_id)
            return refs_cache[asset_id]

        def job(asset_id, view):
            return (asset_id, a.kind, view, prompt(a.kind, reg[asset_id], view), Path(tmp) / asset_id / f"{view}.png")

        jobs = []
        for asset_id in ids:
            for view in VIEW_TEXT:
                if a.kind == "walk" and view not in WALK_VIEWS:
                    continue
                out = ROOT / "art" / "generated" / "anim" / asset_id / f"{a.kind}_{view}.png"
                wanted = (a.views and view in a.views) or (not a.views and (a.force or not out.exists()))
                if wanted and view in refs_for(asset_id):
                    jobs.append(job(asset_id, view))
        if a.recheck and a.kind == "attack":
            with ThreadPoolExecutor(max_workers=4) as pool:
                verdicts = dict(zip(ids, pool.map(check, ids)))
            queued = {(j[0], j[2]) for j in jobs}
            for asset_id, bad in verdicts.items():
                for view, why in bad.items():
                    if (asset_id, view) not in queued:
                        print(f"redo {asset_id} {view}: {'; '.join(why)}", flush=True)
                        jobs.append(job(asset_id, view))
        failed = 0
        for attempt in range(a.retry + 1):
            if not jobs:
                break
            print(f"{len(jobs)} strips to generate" + (f" (retry {attempt})" if attempt else ""), flush=True)
            with ThreadPoolExecutor(max_workers=a.jobs) as pool:
                results = list(pool.map(generate, jobs))
            failed = results.count(False)
            if a.kind != "attack" or attempt == a.retry:
                break
            touched = sorted({j[0] for j in jobs})
            with ThreadPoolExecutor(max_workers=4) as pool:
                verdicts = dict(zip(touched, pool.map(check, touched)))
            jobs = []
            for asset_id, bad in verdicts.items():
                for view, why in bad.items():
                    print(f"redo {asset_id} {view}: {'; '.join(why)}", flush=True)
                    jobs.append(job(asset_id, view))
    if failed:
        sys.exit(f"{failed} strips failed")


if __name__ == "__main__":
    main()
