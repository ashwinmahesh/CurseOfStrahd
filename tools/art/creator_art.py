#!/usr/bin/env python3
"""The character creator's paper-doll art (docs/art/creator.md): draws what's missing through the pinned Gemini model
and cuts it into the pieces the game puts together (blender/creator_pieces.py).

Usage: tools/art/creator_art.py [--generate] [--only bases bodies heads hair beards strips portraits] [--ids a b ...]
                                [--jobs 2] [--dry] [--budget N] [--process] [--force]

Reads art/creator/catalog.json. Everything is drawn on chroma keys: skin flat lime green, hair and beards flat magenta.
- bases:     base_<gender>_<build>.png, a fresh bald, lime-skinned figure per build (an edit can't change a build).
- bodies:    body_<gender>_<build>_<outfit>.png, each base dressed in an outfit (an edit of the base).
- heads:     head_<gender>_<head>.png, the average base with another face (an edit); "plain" is the base itself.
- hair:      hair_<style>.png, the male average base with magenta hair (an edit). beards: beard_<style>.png alike.
- strips:    anim/<body>/attack_<view>.png, three attack keyframes per view (art/prompts/attack_keyframes.txt) from
             each body's view, cut by blender/creator_refs.py.
- portraits: portrait_<id>.png, then `make portrait` into art/portraits/<id>.png.

--generate draws what is missing (or --force: everything named), --dry only counts, --budget stops after N calls
(failed calls count too), --process runs blender/creator_pieces.py for every piece whose source exists. Calls go
through tools/art/generate_gemini.py, so every one is logged in art/generation_log.jsonl. On a 429 or 402 the run
stops. The key comes from GEMINI_API_KEY as for every other tool; it is never read or printed here.
"""
import argparse
import json
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gemini_budget  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "art" / "generated" / "creator"
CATALOG = ROOT / "art" / "creator" / "catalog.json"
BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"
VIEWS = ("front", "front34", "side", "back34", "back")
VIEW_TEXT = {
    "front": "the front, facing the viewer",
    "front34": "a front three-quarter angle, turned toward the right of the picture",
    "side": "the side, in profile facing right",
    "back34": "a back three-quarter angle, facing away from the viewer toward the upper right",
    "back": "behind, facing straight away from the viewer",
}
PERSON = {"female": "woman", "male": "man"}
PRONOUN = {"female": "she", "male": "he"}
POSSESSIVE = {"female": "her", "male": "his"}

SKIN = ("Every bit of visible skin (face, scalp, ears, neck, arms, hands) is painted one flat bright lime green, a "
        "chroma-key green like #7CFC00, with darker lime green cel shading (never grey, blue, purple or red shading "
        "on the skin) and the usual black ink outlines, like a compositing mask; nothing else in the picture is green.")
VIEWS_TAIL = ("Exactly five full-body views of the same figure in one row, left to right: front, front three-quarter, "
              "side profile facing right, back three-quarter, back. Relaxed neutral standing pose with arms at the "
              "sides and the hands a little away from the hips, same scale and height, evenly spaced with clear "
              "gaps, on a plain flat white background, no ground shadow.")
KEEP = ("Keep everything else exactly as in the reference image: the same five views in the same places, the same "
        "relaxed pose, body, proportions and size, and the same flat lime green skin with darker lime green shading "
        "wherever skin shows. Plain flat white background, no ground shadow.")
MAGENTA = ("Paint the {what} entirely in flat bright magenta, a chroma-key pink like #FF00FF, with darker magenta cel "
           "shading and the usual black ink outlines, like a compositing mask; nothing else is magenta.")


def catalog():
    return json.loads(CATALOG.read_text())


def ids(cat, key):
    return [str(o["id"]) for o in cat[key]]


def opt(cat, key, oid):
    return next(o for o in cat[key] if str(o["id"]) == oid)


# ---------- jobs: (name, output path, prompt, aspect, refs) ----------

def base_jobs(cat):
    out = []
    for g in ids(cat, "genders"):
        for b in cat["builds"]:
            body = b["prompt"].replace("{person}", f"human {PERSON[g]}")
            clothes = ("a plain fitted sleeveless knee-length linen shift in dull grey" if g == "female" else
                       "a plain fitted sleeveless linen undershirt and knee-length breeches in dull grey")
            p = (f"Character turnaround sheet of a base figure for a character creator: {body} in "
                 f"{POSSESSIVE[g]} late twenties with a calm neutral face, "
                 + ("clean-shaven, " if g == "male" else "")
                 + f"completely bald with a smooth round scalp and no hair anywhere. {SKIN} "
                 f"{PRONOUN[g].capitalize()} wears only {clothes} and simple flat dark brown shoes. {VIEWS_TAIL}")
            name = f"base_{g}_{b['id']}"
            out.append((name, SRC / f"{name}.png", p, "16:9", []))
    return out


def body_jobs(cat):
    out = []
    for g in ids(cat, "genders"):
        for b in ids(cat, "builds"):
            for o in cat["outfits"]:
                p = (f"Using the reference image as the base, dress this exact figure in {o['prompt']}. The head stays "
                     "completely bald. No hood, hat, helmet, mask or scarf, and nothing covering the face or neck. "
                     f"Nothing green except the skin. {KEEP}")
                name = f"body_{g}_{b}_{o['id']}"
                out.append((name, SRC / f"{name}.png", p, "16:9", [SRC / f"base_{g}_{b}.png"]))
    return out


def head_jobs(cat):
    out = []
    for g in ids(cat, "genders"):
        for h in cat["heads"]:
            if not h.get("prompt"):
                continue
            p = (f"Using the reference image as the base, change only this figure's face and head shape in all five "
                 f"views: {h['prompt']}. The head stays completely bald, with no hair anywhere, at the same size and "
                 f"in the same position. Keep the same clothes. {KEEP}")
            name = f"head_{g}_{h['id']}"
            out.append((name, SRC / f"{name}.png", p, "16:9", [SRC / f"base_{g}_average.png"]))
    return out


def hair_jobs(cat, key, prefix, what):
    out = []
    for h in cat[key]:
        if not h.get("prompt"):
            continue
        extra = ("The face stays clean-shaven." if key == "hair" else
                 "The head stays completely bald, with no hair on the scalp. Keep the same face under the beard.")
        p = (f"Using the reference image as the base, give this exact figure {h['prompt']}, seen correctly from each "
             f"of the five angles. {MAGENTA.format(what=what)} {extra} Keep the same clothes. {KEEP}")
        name = f"{prefix}_{h['id']}"
        out.append((name, SRC / f"{name}.png", p, "16:9", [SRC / "base_male_average.png"]))
    return out


def strip_jobs(cat, refs_dir):
    """Attack keyframes per body and view; the view references are cut from each body (blender/creator_refs.py)."""
    template = (ROOT / "art" / "prompts" / "attack_keyframes.txt").read_text().strip()
    out = []
    for g in ids(cat, "genders"):
        for b in ids(cat, "builds"):
            for o in cat["outfits"]:
                body = f"{g}_{b}_{o['id']}"
                if not (SRC / f"body_{body}.png").exists():
                    continue
                a = o["attack"]
                who = (f"a bald {PERSON[g]} with flat bright lime green skin (a chroma-key mask colour that must stay "
                       "exactly the same lime green in every frame, with darker lime green shading, never grey or blue) "
                       f"wearing {o['prompt'].split(': ', 1)[-1]}")
                for v in VIEWS:
                    text = template
                    for k, val in {"WHO": who, "VIEW": VIEW_TEXT[v], "ACTION": a["action"],
                                   "WINDUP": a["windup"].replace("{they}", PRONOUN[g]),
                                   "STRIKE": a["strike"].replace("{they}", PRONOUN[g])}.items():
                        text = text.replace("{" + k + "}", val)
                    text += " The head stays completely bald in every frame."
                    path = SRC / "anim" / body / f"attack_{v}.png"
                    out.append((f"attack_{v}", path, text, "21:9", [refs_dir / body / f"{v}.png"], f"creator/anim/{body}"))
    return out


def portrait_jobs(cat):
    template = (ROOT / "art" / "prompts" / "portrait.txt").read_text().strip()
    out = []
    for p in cat["portraits"]:
        text = template.replace("{DESCRIPTION}", p["prompt"]).replace("{EXPRESSION}", p["expression"])
        text += " Plain dark purple background, no props, candles or scenery in the frame."
        name = f"portrait_{p['id']}"
        out.append((name, SRC / f"{name}.png", text, "1:1", []))
    return out


def cut_refs(bodies, out_dir):
    """Cuts each body's five views into reference images for its attack strips."""
    for body in bodies:
        r = subprocess.run([BLENDER, "-b", "--python", str(ROOT / "blender" / "creator_refs.py"), "--",
                            str(SRC / f"body_{body}.png"), str(out_dir / body)], capture_output=True, text=True)
        if r.returncode != 0 or not (out_dir / body / "back.png").exists():
            sys.exit(f"{body}: could not cut the views\n{r.stdout[-600:]}{r.stderr[-600:]}")


# ---------- running ----------

class Stop(Exception):
    pass


def generate(job, model):
    name, path, prompt, aspect, refs = job[:5]
    folder = job[5] if len(job) > 5 else "creator"
    cmd = [sys.executable, str(ROOT / "tools" / "art" / "generate_gemini.py"), name, folder, prompt, "--model", model,
           "--aspect", aspect]
    for r in refs:
        cmd += ["--ref", str(r)]
    r = subprocess.run(cmd, capture_output=True, text=True)
    text = r.stdout + r.stderr
    ok = r.returncode == 0
    print(f"{'ok ' if ok else 'FAILED'} {path.relative_to(ROOT)}" + ("" if ok else f": {text.strip()[-300:]}"), flush=True)
    if "(429)" in text or "(402)" in text or "rate limit" in text:
        raise Stop(text.strip()[-200:])
    return ok


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--generate", action="store_true")
    p.add_argument("--process", action="store_true")
    p.add_argument("--only", nargs="*", default=["bases", "bodies", "heads", "hair", "beards", "strips", "portraits"])
    p.add_argument("--ids", nargs="*", help="limit to these output names (e.g. body_female_slender_scholar)")
    p.add_argument("--jobs", type=int, default=2)
    p.add_argument("--dry", action="store_true")
    p.add_argument("--force", action="store_true")
    p.add_argument("--budget", type=int, default=0, help="stop after this many calls")
    a = p.parse_args()
    cat = catalog()
    model = json.loads((ROOT / "art" / "manifest.json").read_text())["image_model"]
    spent = 0
    with tempfile.TemporaryDirectory(prefix="creator_refs_") as tmp:
        refs_dir = Path(tmp)
        for kind in ("bases", "bodies", "heads", "hair", "beards", "portraits", "strips"):
            if kind not in a.only:
                continue
            if kind == "strips":
                bodies = sorted({j[1].parent.name for j in strip_jobs(cat, refs_dir)})
                if a.generate and not a.dry:
                    cut_refs(bodies, refs_dir)
                jobs = strip_jobs(cat, refs_dir)
            else:
                jobs = {"bases": base_jobs, "bodies": body_jobs, "heads": head_jobs, "portraits": portrait_jobs,
                        "hair": lambda c: hair_jobs(c, "hair", "hair", "hair"),
                        "beards": lambda c: hair_jobs(c, "beards", "beard", "beard")}[kind](cat)
            if a.ids:
                jobs = [j for j in jobs if j[1].stem in a.ids or f"{j[1].parent.name}/{j[1].stem}" in a.ids]
            todo = [j for j in jobs if a.force or not j[1].exists()]
            todo = [j for j in todo if all(Path(r).exists() or kind == "strips" for r in j[4])]
            print(f"{kind}: {len(jobs)} wanted, {len(todo)} to draw", flush=True)
            if not a.generate or a.dry or not todo:
                continue
            if a.budget:
                todo = todo[: max(0, a.budget - spent)]
            gemini_budget.preflight(len(todo), "", f"creator {kind}", model)   # stops before a batch it can't finish
            try:
                with ThreadPoolExecutor(max_workers=a.jobs) as pool:
                    for j in todo:
                        j[1].parent.mkdir(parents=True, exist_ok=True)
                    results = list(pool.map(lambda j: generate(j, model), todo))
                spent += len(results)
            except Stop as e:
                sys.exit(f"stopped: {e}")
            if a.budget and spent >= a.budget:
                print(f"budget of {a.budget} calls reached", flush=True)
                break
    if a.process:
        process(cat, a.jobs)


def process(cat, jobs):
    """blender/creator_pieces.py for every piece whose source art exists (bodies need all five attack strips)."""
    work = []
    for g in ids(cat, "genders"):
        for b in ids(cat, "builds"):
            for o in cat["outfits"]:
                body = f"{g}_{b}_{o['id']}"
                if (SRC / f"body_{body}.png").exists() and all((SRC / "anim" / body / f"attack_{v}.png").exists() for v in VIEWS):
                    work.append(["body", body] + (["--casts"] if o["attack"].get("casts") else []))
        for h in ids(cat, "heads"):
            src = SRC / f"head_{g}_{h}.png"
            if h == "plain" and (SRC / f"base_{g}_average.png").exists() and not src.exists():
                src.write_bytes((SRC / f"base_{g}_average.png").read_bytes())
            if src.exists():
                work.append(["head", f"{g}_{h}"])
    for key, prefix in (("hair", "hair"), ("beards", "beard")):
        for h in ids(cat, key):
            if (SRC / f"{prefix}_{h}.png").exists():
                work.append([prefix, h])

    def run(args):
        r = subprocess.run([BLENDER, "-b", "--python", str(ROOT / "blender" / "creator_pieces.py"), "--"] + args,
                           capture_output=True, text=True)
        lines = [l for l in r.stdout.splitlines() if l.startswith(("body ", "head ", "hair ", "beard ", "WARNING"))]
        print(("ok " if r.returncode == 0 else "FAILED ") + " ".join(args) + ("\n  " + "\n  ".join(lines) if lines else "")
              + ("" if r.returncode == 0 else "\n" + (r.stdout + r.stderr)[-800:]), flush=True)
        return r.returncode == 0

    with ThreadPoolExecutor(max_workers=max(1, jobs)) as pool:
        results = list(pool.map(run, work))
    for p in cat["portraits"]:
        src, out = SRC / f"portrait_{p['id']}.png", ROOT / "art" / "portraits" / f"{p['id']}.png"
        if src.exists() and not out.exists():
            r = subprocess.run([BLENDER, "-b", "--python", str(ROOT / "blender" / "portrait.py"), "--", "--in", str(src),
                                "--id", p["id"]], capture_output=True, text=True)
            print(("ok " if r.returncode == 0 else "FAILED ") + f"portrait {p['id']}", flush=True)
            results.append(r.returncode == 0)
    if not all(results):
        sys.exit(f"{results.count(False)} pieces failed")


if __name__ == "__main__":
    main()
