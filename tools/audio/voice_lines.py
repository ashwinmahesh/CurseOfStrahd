#!/usr/bin/env python3
"""Every line the game can voice, and the clip each one plays (ADR 0013).

A clip is keyed by its speaker and a hash of its text: res://audio/voice/<speaker>/<key>.mp3, where key is the first
16 hex digits of the SHA-1 of the line's text (VoiceOver.key in core/voice_over.gd computes the same). An edited line
gets a new key, so only new or changed lines are generated, and a line written twice shares one clip.

Voiced: NPC lines and story allies' interjections in conversations and banter, Madam Eva's Tarokka verses, the
Narrator's lines in conversations, banter and its trigger variants, the Narrator text in location and travel data
(first visit, encounter intros, traps, barred exits), and the party's lines: a hero's own (`name:`) lines in that
hero's voice, and every line any party member could say (`class:`, `species:`, `background:`, `tag:`, "Player:") in
the voice of each prebuilt hero it fits and in both custom-hero voices (VoiceOver.voice_for picks the one that
speaks). Not voiced: player options, rolls, notices, book and letter text, and any line holding {name}, {leader} or
{target} (filled in at run time).

In fights (narrative/combat/barks.json): each kind of talking enemy's battle cries, taunts, pain and death lines as
the speaker bark_<kind>, and each kind of creature's noises as noise_<kind>, where a noise's text is the prompt it is
made from (a sound effect, with its length in seconds) rather than words.

Usage: tools/audio/voice_lines.py [--speaker narrator] [--json]   (prints counts per speaker, or the lines as JSON)
"""
import argparse
import hashlib
import json
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
NARRATOR = "narrator"

RE_LINE = re.compile(r"^([A-Za-z][A-Za-z_ ]*?)(?:\s*\[([a-z:]+(?:\s*,\s*[a-z:]+)*)\])?:\s+(.+)$")
RE_OPTION = re.compile(r"^\*\s+")
RE_INTERJECT = re.compile(r"^interject\s+([a-z]+:[a-z0-9_]+):\s+(.+)$")
RE_VARIANT = re.compile(r"^\|\s*(?:\[([^\]]+)\]\s*)?(.+)$")
RE_SET = re.compile(r"^set\s+[a-z][a-z0-9_]*")
RE_CHECK = re.compile(r"^check\s+[A-Za-z][A-Za-z ]*?\s+DC\s+\d+\s*->")
COMMANDS = ("quest", "give", "take", "gold", "attitude", "xp", "sacrifice", "tarokka", "dark_gift", "shop", "services", "respec",
            "time", "join", "leave", "combat", "narrate", "approve", "inspire")


def key(text):
    """The clip key for a line's text (what VoiceOver.key computes in the game)."""
    return hashlib.sha1(text.strip().encode("utf-8")).hexdigest()[:16]


def _npcs():
    out = []
    for f in sorted((ROOT / "data" / "npcs").glob("*.json")):
        d = json.loads(f.read_text())
        out.append((str(d.get("id", f.stem)), str(d.get("name", ""))))
    return out


def speaker_id(name, npcs):
    """The npc id a dialogue speaker name resolves to (DialogueRunner._npc_for)."""
    low = name.lower()
    ids = {i for i, _ in npcs}
    if low.replace(" ", "_") in ids:
        return low.replace(" ", "_")
    for i, n in npcs:
        n = n.lower()
        if n == low or n.split(" ")[0] == low:
            return i
    return low


HERO_VOICES = ["hero_female", "hero_male"]   # the custom character's two voices (build.appearance.voice)


def _heroes():
    """{pregen id: {class, species, background, tag, name}} for the party selectors (StoryState.member_matches)."""
    out = {}
    for f in sorted((ROOT / "data" / "pregens").glob("*.json")):
        d = json.loads(f.read_text())
        b = d.get("build", {})
        classes = {lv.get("class") for lv in b.get("levels", []) + d.get("level_plan", [])}
        out[d["id"]] = {"class": classes, "species": {b.get("species")}, "background": {b.get("background")},
                        "tag": set((b.get("identity") or {}).get("tags", [])), "name": {d["id"]}}
    return out


def party_voices(selector, heroes):
    """The voices that may speak an interjection: a named hero's own, or every hero it fits plus both custom voices."""
    kind, _, value = selector.partition(":")
    if kind == "name":
        return [value] if value in heroes else []
    return [h for h, facts in heroes.items() if value in facts.get(kind, set())] + HERO_VOICES


def _dialogue_lines(npcs):
    heroes = _heroes()
    for f in sorted((ROOT / "narrative").glob("*/*.dialogue")):
        region = f.parent.name
        file_key = f"{region}/{f.stem}"
        node = ""
        for raw in f.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("~ "):
                node = line[2:].strip()
                continue
            where = f"{file_key}:{node}"
            if line.startswith("|"):
                m = RE_VARIANT.match(line)
                if m and region == "narrator":
                    yield NARRATOR, m.group(2), where
                continue
            if RE_OPTION.match(line) or line.startswith("->") or RE_SET.match(line) or RE_CHECK.match(line):
                continue
            if line.split(" ")[0] in COMMANDS or line.split(" ")[0] in ("if", "elif", "else", "endif", "once", "cooldown"):
                continue
            m = RE_INTERJECT.match(line)
            if m:
                sel = m.group(1)
                if sel.startswith("guest:"):
                    yield sel[6:], m.group(2), where
                else:
                    for voice in party_voices(sel, heroes):
                        yield voice, m.group(2), where
                continue
            m = RE_LINE.match(line)
            if m:
                who = m.group(1).strip()
                if who.lower() == "player":
                    for voice in list(heroes) + HERO_VOICES:
                        yield voice, m.group(3), where
                    continue
                yield (NARRATOR if who.lower() == "narrator" else speaker_id(who, npcs)), m.group(3), where


def _data_lines():
    for f in sorted((ROOT / "data" / "locations").glob("*.json")):
        d = json.loads(f.read_text())
        where = f"locations/{f.stem}"
        if d.get("text"):
            yield NARRATOR, d["text"], where
        for t in d.get("traps", []):
            if t.get("text"):
                yield NARRATOR, t["text"], f"{where}:trap:{t.get('id', '')}"
        for e in d.get("encounters", []):
            if e.get("text"):
                yield NARRATOR, e["text"], f"{where}:encounter:{e.get('id', '')}"
        for x in d.get("exits", []):
            if x.get("locked_text"):
                yield NARRATOR, x["locked_text"], f"{where}:exit"
    for f in sorted((ROOT / "data" / "random_encounters").glob("*.json")):
        d = json.loads(f.read_text())
        for e in d.get("entries", []):
            if e.get("text") and e.get("monsters"):
                yield NARRATOR, e["text"], f"random_encounters/{f.stem}"
    outcomes = json.loads((ROOT / "data" / "tarokka" / "outcomes.json").read_text())
    for slot, cards in outcomes.items():
        if isinstance(cards, dict):
            for card, o in cards.items():
                if isinstance(o, dict) and o.get("verse"):
                    yield "madam_eva", o["verse"], f"tarokka/{slot}:{card}"


def _bark_lines():
    f = ROOT / "narrative" / "combat" / "barks.json"
    if not f.exists():
        return
    d = json.loads(f.read_text())
    for kind, v in d.get("voices", {}).items():
        for moment, said in v.get("lines", {}).items():
            for t in said:
                yield f"bark_{kind}", t, f"barks/{kind}:{moment}"
    for kind, v in d.get("noises", {}).items():
        for moment, sounds in v.get("sounds", {}).items():
            for snd in sounds:
                yield f"noise_{kind}", snd["prompt"], f"barks/{kind}:{moment}", {"seconds": float(snd["seconds"])}


def lines():
    """{(speaker, key): {"speaker", "key", "text", "sources": [...]}} for every voiced line (a noise also has its
    "seconds")."""
    npcs = _npcs()
    out = {}
    for speaker, text, where, *extra in list(_dialogue_lines(npcs)) + list(_data_lines()) + list(_bark_lines()):
        text = text.strip()
        if "{" in text:
            continue
        k = (speaker, key(text))
        entry = out.setdefault(k, {"speaker": speaker, "key": k[1], "text": text, "sources": []})
        entry["sources"].append(where)
        for e in extra:
            entry.update(e)
    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--speaker", action="append", default=[])
    p.add_argument("--json", action="store_true")
    a = p.parse_args()
    found = [e for e in lines().values() if not a.speaker or e["speaker"] in a.speaker]
    if a.json:
        print(json.dumps(found, indent=1, ensure_ascii=False))
        return
    per = defaultdict(lambda: [0, 0])
    for e in found:
        per[e["speaker"]][0] += 1
        per[e["speaker"]][1] += len(e["text"])
    for s, (n, c) in sorted(per.items(), key=lambda x: -x[1][1]):
        print(f"{s:28s}{n:6d} lines{c:10,d} chars")
    print(f"{'total':28s}{sum(v[0] for v in per.values()):6d} lines{sum(v[1] for v in per.values()):10,d} chars "
          f"({len(per)} speakers)")


if __name__ == "__main__":
    main()
