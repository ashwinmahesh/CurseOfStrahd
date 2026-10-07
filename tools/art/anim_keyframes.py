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
GEMINI_BUDGET=<counter file>:<max> caps the calls (tools/art/gemini_budget.py).

kind attack: every character (wind-up, strike). kind walk: four-legged bodies only (BODY=quadruped in their
art/manifest.json sprite_flags: two strides, profile and three-quarter views; head-on views walk with the rig).
"""
import argparse
import json
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gemini_budget  # noqa: E402

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


def walk_flags():
    """Sprite folder -> its art/manifest.json sprite_flags as a dict, plus its turnaround ("source")."""
    out = {}
    for a in json.loads((ROOT / "art" / "manifest.json").read_text())["assets"]:
        sp = a.get("sprites")
        if isinstance(sp, str) and sp.endswith("/walk.tres"):
            flags = dict(f.split("=", 1) for f in a.get("sprite_flags", []) if "=" in f)
            flags["source"] = a.get("source", "")
            out[Path(sp).parent.name] = flags
    return out


def cut_refs(asset_id, out):
    r = subprocess.run([BLENDER, "-b", "--python", str(ROOT / "blender" / "anim_refs.py"), "--",
                        "--id", asset_id, "--out", str(out)], capture_output=True, text=True)
    meta = out / "views.json"
    if r.returncode != 0 or not meta.exists():
        sys.exit(f"{asset_id}: could not cut the turnaround into views\n{r.stdout[-800:]}{r.stderr[-800:]}")
    return list(json.loads(meta.read_text()))


# The fuller animation set (docs/art/animation.md, "Animation set v2"): one strip per view and kind, drawn at 2K. Each
# entry: the action named in the prompt, and frames 2.. (frame 1 is always the reference pose redrawn). {WINDUP},
# {STRIKE}, {CAST_GATHER} and {CAST_RELEASE} come from the character's animations.json entry.
V2_KINDS = {
    "walk4": ("walk cycle", [
        "walking, contact: the right leg forward with its heel just touching the ground, the left leg back on its toes, "
        "the left arm swinging forward and the right arm back",
        "walking, passing: the weight on the straight right leg, the left leg bent and lifted as it passes under the body, "
        "the body at its highest, arms passing the hips",
        "walking, contact: the left leg forward with its heel just touching the ground, the right leg back on its toes, "
        "the right arm swinging forward and the left arm back",
        "walking, passing: the weight on the straight left leg, the right leg bent and lifted as it passes under the body, "
        "the body at its highest, arms passing the hips"]),
    "attack5": ("{ATTACK}", [
        "ready: a fighting stance, knees bent, weight balanced, weapon or hands up and ready",
        "anticipation: crouching lower and pulling back, coiling the body, halfway to the wind-up",
        "wind-up at its peak: {WINDUP}",
        "strike: {STRIKE}, with a short curved pale motion smear trailing the weapon or hand and touching it",
        "follow-through: just after the blow, the weapon or hands carried on past the target, the body twisted, the "
        "weight on the front foot"]),
    # Doubled keys (owner 2026-10-07: "double the frames for even smoother animation"): eight walk poses and ten attack
    # poses, two strips per view so each pose keeps its detail.
    "walk8a": ("walk cycle, first step", [
        "contact: the right leg forward with its heel just touching the ground, the left leg back on its toes, the left "
        "arm swinging forward and the right arm back",
        "down: the weight dropping onto the bent right leg, the body at its lowest, the left foot lifting off behind",
        "passing: the weight on the straightening right leg, the left leg bent and swinging forward under the body, arms "
        "passing the hips",
        "up: pushing off the right toes, the body at its highest, the left leg reaching forward, the right arm swinging "
        "forward"]),
    "walk8b": ("walk cycle, second step", [
        "contact: the left leg forward with its heel just touching the ground, the right leg back on its toes, the right "
        "arm swinging forward and the left arm back",
        "down: the weight dropping onto the bent left leg, the body at its lowest, the right foot lifting off behind",
        "passing: the weight on the straightening left leg, the right leg bent and swinging forward under the body, arms "
        "passing the hips",
        "up: pushing off the left toes, the body at its highest, the right leg reaching forward, the left arm swinging "
        "forward"]),
    "attack10a": ("{ATTACK}, first half: getting ready and winding up", [
        "ready: a fighting stance, knees bent, weight balanced, weapon or hands up and ready",
        "settling: the weight shifting onto the back foot, eyes on the enemy",
        "anticipation: crouching lower and pulling back, coiling the body, a third of the way to the wind-up",
        "coiling: pulled back further, two thirds of the way to the wind-up, the body twisting",
        "wind-up at its peak: {WINDUP}"]),
    "attack10b": ("{ATTACK}, second half: the blow and the recovery", [
        "the strike beginning: whipping forward out of the wind-up, the weapon or hand halfway to the target, a long "
        "curved pale motion smear behind it",
        "the strike landing: {STRIKE}, with a short curved pale motion smear trailing the weapon or hand and touching it",
        "follow-through: just after the blow, the weapon or hands carried on past the target, the body twisted, the "
        "weight on the front foot",
        "recovering: pulling the weapon or hands back, the body straightening",
        "back on guard: a fighting stance, knees bent, weapon or hands up and ready"]),
    "hurt": ("hit, fall and collapse", [
        "hit and flinching: recoiling backward from a blow, head snapped back, grimacing, one arm raised to guard, knees "
        "bent",
        "staggering: knees buckling, the arms dropping, swaying",
        "collapsing: fallen to the knees, slumping forward, head bowed, one hand on the ground",
        "lying flat on the ground on the back, eyes closed, unconscious, drawn well apart from the kneeling figure with a "
        "wide gap between them"]),
    "ride": ("ride on a horse", [
        "riding: seated astride a horse, holding the reins, back straight",
        "riding and raising the weapon high to strike, still seated astride the horse",
        "riding and striking down at an enemy beside the horse, still seated astride"]),
    "sneak": ("sneaking walk", [
        "sneaking: crouched low with the knees deeply bent, the body hunched forward, looking ahead warily, weapon held "
        "close",
        "sneaking step: crouched low, the right foot stepping forward softly onto its toes",
        "sneaking step: crouched low, the left foot stepping forward softly onto its toes; no ground, stones or scenery "
        "anywhere"]),
    "cast": ("spell", [
        "gathering a spell: {CAST_GATHER}",
        "releasing the spell: {CAST_RELEASE}"]),
}
CAST_DEFAULTS = ("one hand raised before the chest with a small glowing light gathering in the palm, the other arm "
                 "drawn back, eyes intent",
                 "the hand thrust forward at the enemy with a small burst of light leaving it, leaning forward")


def strip_count(kind):
    """Figures on a strip of `kind` (frame 1 included)."""
    return 1 + len(V2_KINDS[kind][1]) if kind in V2_KINDS else 3


def prompt(kind, spec, view):
    if kind in V2_KINDS:
        action, frames = V2_KINDS[kind]
        gather, release = spec.get("cast_gather", CAST_DEFAULTS[0]), spec.get("cast_release", CAST_DEFAULTS[1])
        if spec.get("unarmed"):
            # A hero who fights bare-handed or with magic (a monk, a warlock): Gemini otherwise hands them a weapon.
            frames = [f.replace("raising the weapon high", "drawing back a fist or a hand gathering a spell")
                      .replace("weapon held close", "hands held close") for f in frames]
        lines = " ".join(f"Frame {i + 2}: {f}." for i, f in enumerate(frames))
        text = (ROOT / "art" / "prompts" / "keyframes_v2.txt").read_text().strip()
        if kind.startswith("walk") or kind in ("sneak", "hurt"):
            text += (" Weapons and gear stay carried exactly as in the reference (a sheathed sword stays in its sheath,"
                     " a shield stays on the arm). No magic: no glow, sparks, flames or spell effects.")
        if spec.get("unarmed"):
            text += f" {spec['who'].split(',')[0]} carries no weapon: the hands stay empty."
        if spec.get("gear") and (kind.startswith("walk") or kind == "sneak"):
            # What Gemini tends to drop from a pose or two (a staff), named for every frame.
            text += f" In every frame {spec['gear']}."
        if kind == "ride":
            # A rider can't be drawn seated on nothing: the horse is drawn as a flat magenta silhouette that
            # blender/render_keys.py keys out, leaving the rider astride (the far leg hidden, as on any mount).
            text += (" In frames 2 to 4 the horse is a plain flat solid pure magenta (#FF00FF) silhouette with no"
                     " black outline, no shading, lines, saddle or details; only the rider is drawn normally, in the"
                     " same colours as the reference.")
        fields = {"COUNT": str(1 + len(frames)), "WHO": spec["who"], "VIEW": VIEW_TEXT[view], "ACTION": action,
                  "FRAMES": lines}
        for k, v in fields.items():
            text = text.replace("{" + k + "}", v)
        for k, v in {"ATTACK": spec["attack"], "WINDUP": spec["windup"], "STRIKE": spec["strike"],
                     "CAST_GATHER": gather, "CAST_RELEASE": release}.items():
            text = text.replace("{" + k + "}", v)
        return text
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
        if not gemini_budget.take():
            print(f"STOP {asset_id} {kind}_{view}: the Gemini call budget is spent ({gemini_budget.used()})", flush=True)
            return False
        r = subprocess.run([sys.executable, str(ROOT / "tools" / "art" / "generate_gemini.py"), f"{kind}_{view}",
                            f"anim/{asset_id}", text, "--model", model(), "--aspect", "21:9", "--ref", str(ref)]
                           + (["--size", "2K"] if kind in V2_KINDS else []),
                           capture_output=True, text=True)
        if "per_day" in (r.stderr + r.stdout) or "credits are depleted" in (r.stderr + r.stdout):
            print(f"STOP {asset_id} {kind}_{view}: Gemini's daily quota or credits are used up", flush=True)
            return False
        limited = "rate limit" in (r.stderr + r.stdout) or "(429)" in (r.stderr + r.stdout)
        if r.returncode == 0 or not limited or wait is None:
            break
        print(f"rate limited ({asset_id} {kind}_{view}); waiting {wait} s", flush=True)
        time.sleep(wait)
    ok = r.returncode == 0
    print(f"{'ok ' if ok else 'FAILED'} {asset_id} {kind}_{view}" + ("" if ok else f": {(r.stderr or r.stdout).strip()[-300:]}"),
          flush=True)
    return ok


def check(asset_id, kind="attack"):
    """Views of `asset_id` whose `kind` strip should be drawn again, with the reasons."""
    script, extra = ("render_attack.py", []) if kind == "attack" else ("render_keys.py", ["--kind", kind])
    r = subprocess.run([BLENDER, "-b", "--python", str(ROOT / "blender" / script), "--",
                        "--id", asset_id, "--check", *extra], capture_output=True, text=True)
    for line in r.stdout.splitlines():
        if line.startswith("CHECK "):
            return json.loads(line[6:])
    sys.exit(f"{asset_id}: check failed\n{r.stdout[-800:]}{r.stderr[-800:]}")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--only", nargs="*")
    p.add_argument("--kind", choices=["attack", "walk", *V2_KINDS], default="attack")
    p.add_argument("--views", nargs="*", help="regenerate just these views (implies --force for them)")
    p.add_argument("--force", action="store_true")
    p.add_argument("--jobs", type=int, default=2)
    p.add_argument("--retry", type=int, default=0)
    p.add_argument("--recheck", action="store_true", help="check every strip first and redraw the flagged ones")
    a = p.parse_args()
    reg = json.loads(REGISTRY.read_text())
    ids = a.only or sorted(reg)
    for i in [i for i in ids if i not in reg]:
        print(f"skip {i}: not in {REGISTRY.relative_to(ROOT)} yet", flush=True)
    ids = [i for i in ids if i in reg]
    flags = walk_flags()
    if a.kind == "walk":
        ids = [i for i in ids if flags.get(i, {}).get("BODY") == "quadruped"]
    ready = [i for i in ids if i in flags and (ROOT / flags[i]["source"]).exists()]
    for i in sorted(set(ids) - set(ready)):
        print(f"skip {i}: no walk sheet or turnaround yet", flush=True)
    ids = ready
    with tempfile.TemporaryDirectory(prefix="anim_refs_") as tmp:
        refs_cache = {}

        def refs_for(asset_id):
            if asset_id not in refs_cache:
                refs_cache[asset_id] = cut_refs(asset_id, Path(tmp) / asset_id)
            return refs_cache[asset_id]

        def job(asset_id, view):
            refs_for(asset_id)
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
        checks = a.kind == "attack" or a.kind in V2_KINDS
        if a.recheck and checks:
            with ThreadPoolExecutor(max_workers=4) as pool:
                verdicts = dict(zip(ids, pool.map(lambda i: check(i, a.kind), ids)))
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
            if not checks or attempt == a.retry:
                break
            touched = sorted({j[0] for j in jobs})
            with ThreadPoolExecutor(max_workers=4) as pool:
                verdicts = dict(zip(touched, pool.map(lambda i: check(i, a.kind), touched)))
            jobs = []
            for asset_id, bad in verdicts.items():
                for view, why in bad.items():
                    print(f"redo {asset_id} {view}: {'; '.join(why)}", flush=True)
                    jobs.append(job(asset_id, view))
    if failed:
        sys.exit(f"{failed} strips failed")


if __name__ == "__main__":
    main()
