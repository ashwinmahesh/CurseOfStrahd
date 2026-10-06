#!/usr/bin/env python3
"""Every line the game can voice, and the clip each one plays (ADR 0012).

A clip is keyed by its speaker and a hash of its text: res://audio/voice/<speaker>/<key>.mp3, where key is the first
16 hex digits of the SHA-1 of the line's text (VoiceOver.key in core/voice_over.gd computes the same). An edited line
gets a new key, so only new or changed lines are generated, and a line written twice shares one clip.

Voiced: NPC lines and story allies' interjections in conversations, Madam Eva's Tarokka verses, the Narrator's lines
in conversations and its trigger variants, and the Narrator text in location and travel data (first visit, encounter
intros, traps, barred exits). Not voiced: player options, rolls, notices, party members' lines (interjections, banter,
"Player:"), book and letter text, and any line holding {name}, {leader} or {target} (filled in at run time).

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

RE_LINE = re.compile(r"^([A-Za-z][A-Za-z_ ]*?)(?:\s*\[([a-z]+)\])?:\s+(.+)$")
RE_OPTION = re.compile(r"^\*\s+")
RE_INTERJECT = re.compile(r"^interject\s+([a-z]+:[a-z0-9_]+):\s+(.+)$")
RE_VARIANT = re.compile(r"^\|\s*(?:\[([^\]]+)\]\s*)?(.+)$")
RE_SET = re.compile(r"^set\s+[a-z][a-z0-9_]*")
RE_CHECK = re.compile(r"^check\s+[A-Za-z][A-Za-z ]*?\s+DC\s+\d+\s*->")
COMMANDS = ("quest", "give", "take", "gold", "attitude", "xp", "sacrifice", "tarokka", "dark_gift", "shop", "respec",
            "time", "join", "leave", "combat", "narrate")


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


def _dialogue_lines(npcs):
    for f in sorted((ROOT / "narrative").glob("*/*.dialogue")):
        region = f.parent.name
        if region == "banter":
            continue  # banter plays as one joined box of party lines
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
                continue
            m = RE_LINE.match(line)
            if m:
                who = m.group(1).strip()
                if who.lower() == "player":
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


def lines():
    """{(speaker, key): {"speaker", "key", "text", "sources": [...]}} for every voiced line."""
    npcs = _npcs()
    out = {}
    for speaker, text, where in list(_dialogue_lines(npcs)) + list(_data_lines()):
        text = text.strip()
        if "{" in text:
            continue
        k = (speaker, key(text))
        entry = out.setdefault(k, {"speaker": speaker, "key": k[1], "text": text, "sources": []})
        entry["sources"].append(where)
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
