#!/usr/bin/env python3
"""Full art for new creatures in one batch: turnaround, turn-bar portrait, manifest and animation entries, heights.

Usage: tools/art/new_creatures.py <spec.json> turnarounds|register|portraits [--only id ...] [--jobs 2]

The Phase 5 creature pass used art/anim/creature_specs.json. The spec maps each creature id to:
  look       what it looks like (the turnaround and portrait prompts' description)
  shape      "person" (art/prompts/character_turnaround.txt, 16:9) or "animal"/"creature" (five views of a beast,
             21:9, posed as `pose`)
  pose       the standing pose for animals and creatures ("standing on all four legs in a neutral pose")
  body       BODY flag for make sprite (quadruped, float, hop, slither, lumber, swarm); none for the humanoid rig
  sat        optional SAT flag (chroma boost before the palette snap)
  height     world units for CombatToken.HEIGHTS (a person is about 1.25)
  expression the portrait's expression
  who, attack, windup, strike, casts   its art/anim/animations.json entry (docs/art/animation.md)

turnarounds  draws the missing sheets (two Gemini calls at a time) and redraws any that blender/check_turnaround.py
             rejects (figures merged, cut off or at different scales), up to two more times.
register     adds the art/manifest.json entries (with sprite_flags), the animations.json entries and the heights.
portraits    draws the missing turn-bar portraits from each turnaround and runs make portrait (BG=ash_violet).
Then: tools/art/anim_keyframes.py --only ... --retry 2 (and --kind walk), and make anims ONLY="...".
"""
import argparse
import json
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"
CHARS = ROOT / "art" / "generated" / "characters"
PORTRAITS = ROOT / "art" / "generated" / "portraits"
BEAST = ("Character turnaround sheet of {LOOK}. Exactly five full-body views of the same {KIND} in one row, left to "
         "right: front (facing the viewer), front three-quarter (facing the viewer, turned toward the right), side "
         "profile facing right, back three-quarter (facing away, turned toward the right), back (seen from behind). "
         "{POSE}, same scale, evenly spaced with wide clear gaps so no view touches another, every view wholly inside "
         "the picture, on a plain flat white background, no ground shadow.")
PORTRAIT = ("Bust portrait of {LOOK}, head and shoulders, three-quarter view, {EXPRESSION} expression, lit by candlelight "
            "from below against a plain dark purple background. The reference image is this {KIND}'s turnaround sheet: "
            "draw the same {KIND} (same face, colours and features) as one single bust portrait, not a sheet. Plain dark "
            "purple background, no props, candles or scenery in the frame.")


def model():
    return json.loads((ROOT / "art" / "manifest.json").read_text())["image_model"]


def gemini(name, folder, prompt, aspect, ref=None):
    cmd = [sys.executable, str(ROOT / "tools" / "art" / "generate_gemini.py"), name, folder, prompt,
           "--model", model(), "--aspect", aspect] + (["--ref", str(ref)] if ref else [])
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        out = (r.stderr or r.stdout).strip()[-300:]
        if "402" in out or "credits are depleted" in out:
            sys.exit(f"Gemini credits are depleted (stopped at {name})")
        if "(429)" in out and "per_day" in (r.stderr + r.stdout):
            sys.exit(f"Gemini's daily request quota is used up (stopped at {name}); it resets at midnight Pacific")
        print(f"FAILED {name}: {out}", flush=True)
        return False
    return True


def turnaround_prompt(cid, s):
    if s["shape"] == "person":
        text = (ROOT / "art" / "prompts" / "character_turnaround.txt").read_text().strip()
        return text.replace("{DESCRIPTION}", s["look"]), "16:9"
    return BEAST.replace("{LOOK}", s["look"]).replace("{KIND}", s["shape"]).replace("{POSE}", s["pose"]), "21:9"


def check(cid):
    r = subprocess.run([BLENDER, "-b", "--python", str(ROOT / "blender" / "check_turnaround.py"), "--",
                        "--in", str(CHARS / f"{cid}_turnaround.png")], capture_output=True, text=True)
    for line in r.stdout.splitlines():
        if line.startswith("CHECK "):
            return json.loads(line[6:])["problems"]
    return [f"check failed: {r.stderr[-200:]}"]


def turnarounds(spec, ids, jobs):
    def one(cid):
        prompt, aspect = turnaround_prompt(cid, spec[cid])
        for attempt in range(3):
            path = CHARS / f"{cid}_turnaround.png"
            if not path.exists() and not gemini(f"{cid}_turnaround", "characters", prompt, aspect):
                continue
            problems = check(cid)
            if not problems:
                print(f"ok  {cid}" + (f" (try {attempt + 1})" if attempt else ""), flush=True)
                return True
            print(f"redo {cid}: {'; '.join(problems)}", flush=True)
            path.unlink(missing_ok=True)
        print(f"GAVE UP {cid}", flush=True)
        return False
    with ThreadPoolExecutor(max_workers=jobs) as pool:
        results = list(pool.map(one, ids))
    print(f"{results.count(True)} of {len(ids)} turnarounds ready", flush=True)


def flags(s):
    return ([f"BODY={s['body']}"] if s.get("body") else []) + ([f"SAT={s['sat']}"] if s.get("sat") else [])


def register(spec, ids):
    mpath = ROOT / "art" / "manifest.json"
    manifest = json.loads(mpath.read_text())
    have = {a["id"] for a in manifest["assets"]}
    added = []
    for cid in ids:
        if cid in have or not (CHARS / f"{cid}_turnaround.png").exists():
            continue
        s = spec[cid]
        prompt, aspect = turnaround_prompt(cid, s)
        manifest["assets"].append({
            "id": cid, "kind": "character" if s["shape"] == "person" else "creature", "status": "generated",
            "source": f"art/generated/characters/{cid}_turnaround.png", "sprites": f"art/sprites/{cid}/walk.tres",
            "portrait": f"art/portraits/{cid}.png", "model": model(), "prompt": prompt,
            "notes": f"5-view turnaround ({aspect}) -> make sprite{''.join(' ' + f for f in flags(s))} -> 8 directions x "
                     f"8-frame walk, 384 px cells; attack from art/anim/animations.json (docs/art/animation.md); "
                     f"turn-bar portrait (BG=ash_violet). Phase 5 creature pass (2026-10-06). Needs art QA before final.",
            **({"sprite_flags": flags(s)} if flags(s) else {}),
        })
        added.append(cid)
    mpath.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    # Attack entries (art/anim/animations.json keeps one character per block).
    rpath = ROOT / "art" / "anim" / "animations.json"
    reg = json.loads(rpath.read_text())
    text = rpath.read_text().rstrip()
    for cid in ids:
        if cid in reg or not (CHARS / f"{cid}_turnaround.png").exists():
            continue
        s = spec[cid]
        head = ", ".join(f'{json.dumps(k)}: {json.dumps(v)}' for k, v in (("casts", True),) if s.get("casts"))
        head = (head + ", " if head else "") + f'"who": {json.dumps(s["who"])}'
        rest = ",\n".join(f'    "{k}": {json.dumps(s[k])}' for k in ("attack", "windup", "strike"))
        text = text[:-1].rstrip() + f',\n  "{cid}": {{{head},\n{rest}}}\n}}'
    json.loads(text)
    rpath.write_text(text + "\n")
    # Heights.
    tpath = ROOT / "world" / "combat" / "combat_token.gd"
    src = tpath.read_text()
    m = re.search(r"const HEIGHTS := \{(.*?)\}\n", src, re.S)
    known = set(re.findall(r'"(\w+)":', m.group(1)))
    new = [f'"{cid}": {spec[cid]["height"]}' for cid in ids if cid not in known and "height" in spec[cid]]
    if new:
        body = m.group(1).rstrip()
        lines, line = [], "\t"
        for item in new:
            if len(line) + len(item) > 110:
                lines.append(line.rstrip())
                line = "\t"
            line += item + ", "
        lines.append(line.rstrip().rstrip(","))
        body = body + ",\n" + "\n".join(lines)
        tpath.write_text(src[:m.start(1)] + body + src[m.end(1):])
    print(f"registered {len(added)} manifest entries, {len(new)} heights", flush=True)


def portraits(spec, ids, jobs):
    def one(cid):
        s = spec[cid]
        out = PORTRAITS / f"{cid}_portrait.png"
        kind = "character" if s["shape"] == "person" else s["shape"]
        if not out.exists():
            prompt = PORTRAIT.replace("{LOOK}", s["look"]).replace("{EXPRESSION}", s["expression"]).replace("{KIND}", kind)
            if not gemini(f"{cid}_portrait", "portraits", prompt, "1:1", CHARS / f"{cid}_turnaround.png"):
                return False
        r = subprocess.run(["make", "--no-print-directory", "portrait", f"SRC={out}", f"ID={cid}", "BG=ash_violet"]
                           + ([f"SAT={s['sat']}"] if s.get("sat") else []), cwd=ROOT, capture_output=True, text=True)
        ok = r.returncode == 0
        print(f"{'ok ' if ok else 'FAILED'} {cid} portrait", flush=True)
        return ok
    with ThreadPoolExecutor(max_workers=jobs) as pool:
        results = list(pool.map(one, ids))
    print(f"{results.count(True)} of {len(ids)} portraits ready", flush=True)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("spec")
    p.add_argument("step", choices=["turnarounds", "register", "portraits"])
    p.add_argument("--only", nargs="*")
    p.add_argument("--jobs", type=int, default=2)
    a = p.parse_args()
    spec = json.loads(Path(a.spec).read_text())
    ids = a.only or list(spec)
    if a.step == "turnarounds":
        turnarounds(spec, [i for i in ids if i in spec], a.jobs)
    elif a.step == "register":
        register(spec, [i for i in ids if i in spec])
    else:
        portraits(spec, [i for i in ids if i in spec and (CHARS / f"{i}_turnaround.png").exists()], a.jobs)


if __name__ == "__main__":
    main()
