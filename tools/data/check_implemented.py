#!/usr/bin/env python3
"""Checks the `implemented` labels on features, feats, species traits and monster traits against the code.

A feature marked "engine" must be read by code: its id (or one of its flag values) appears as a string literal in
rules/ or combat/. Run with --fix to set false "engine" labels to "text" and to mark features the code reads (but that
are labelled "text"/"data") as "engine". Exit 1 when a label is wrong (without --fix).
"""
import glob, json, re, sys

FIX = "--fix" in sys.argv
code = ""
for f in glob.glob("rules/**/*.gd", recursive=True) + glob.glob("combat/**/*.gd", recursive=True):
    code += open(f).read()
literals = set(re.findall(r'"([a-z0-9_:]+)"', code))


## Parts of a feature the code doesn't do yet (out-of-combat or later-phase systems), whatever literals exist.
NOT_BUILT = {"fast_wrestler", "lore_knowledge", "keen_observer", "war_caster_somatic_components", "amorphous",
             "versatile_trickster", "commanding_presence", "tactical_assessment", "relentless", "improved_war_magic"}


## Containers whose parts are built (Combat Superiority: the dice and the maneuvers).
BUILT = {"combat_superiority", "monks_focus", "defensive_tactics"}


def read_by_code(f, owner=""):
    if f.get("id") in NOT_BUILT:
        return False
    if f.get("id") in BUILT:
        return True
    if owner and owner in literals:
        return True
    ids = {f.get("id", "")}
    for m in f.get("modifiers", []):
        if m.get("stat") == "flag":
            ids.add(str(m.get("value", "")))
    for k in ("aura", "absorb", "sunlight"):
        if k in f:
            return True
    return any(i and (i in literals or any(l.startswith(i + ":") for l in literals)) for i in ids)


def features(d):
    if "levels" in d:
        for lv in d["levels"]:
            yield from lv.get("features", [])
    for x in d.get("features", []):
        yield x.get("feature", x)
    yield from d.get("traits", [])
    yield from d.get("benefits", [])
    if "drawback" in d:
        yield d["drawback"]
    for x in d.get("lineages", []):
        yield from x.get("traits", [])


def walk(f):
    yield f
    ch = f.get("choice", {})
    for o in ch.get("options", []) if isinstance(ch, dict) else []:
        yield o


bad = []
changed = set()
for path in sorted(glob.glob("data/classes/*.json") + glob.glob("data/subclasses/*.json") + glob.glob("data/feats/*.json")
                   + glob.glob("data/species/*.json") + glob.glob("data/monsters/*.json")):
    d = json.load(open(path))
    for top in features(d):
        for f in walk(top):
            label = f.get("implemented")
            if label is None:
                continue
            reads = read_by_code(f, d.get("id", "") if path.startswith("data/feats/") else "")
            passive_numbers = f.get("action", "passive") == "passive" and any(m.get("stat") != "flag" for m in f.get("modifiers", []))
            if label == "engine" and not reads and not passive_numbers:
                bad.append("%s: %s says engine but no code reads it" % (path, f.get("id")))
                if FIX:
                    f["implemented"] = "text"; changed.add(path)
            elif label in ("text", "data") and reads and f.get("id") not in ("subclass_feature", "ability_score_improvement", "epic_boon"):
                if FIX:
                    f["implemented"] = "engine"; changed.add(path)
    if path in changed:
        with open(path, "w") as fh:
            json.dump(d, fh, indent=2, ensure_ascii=False); fh.write("\n")
for b in bad:
    print("  " + b)
print("%d wrong engine labels%s" % (len(bad), " (fixed %d files)" % len(changed) if FIX else ""))
sys.exit(1 if bad and not FIX else 0)
