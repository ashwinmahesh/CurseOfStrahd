#!/usr/bin/env python3
"""Parses narrative/**/*.dialogue (docs/contracts/dialogue.md) for validate_data.py: syntax, jumps, and every
flag, speaker, item, quest, skill and encounter a file uses. Stdlib only.

parse_file(path) -> {"nodes": {id: line_no}, "jumps": [(target, line)], "flags_read": {id: [where]},
                     "flags_set": {id: [where]}, "speakers": [(id, line)], "items": [...], "quests": [...],
                     "skills": [...], "encounters": [...], "selectors": [...], "errors": [str]}
"""
import re
from pathlib import Path

SKILLS = {"acrobatics", "animal_handling", "arcana", "athletics", "deception", "history", "insight", "intimidation",
          "investigation", "medicine", "nature", "perception", "performance", "persuasion", "religion",
          "sleight_of_hand", "stealth", "survival", "strength", "dexterity", "constitution", "intelligence", "wisdom",
          "charisma"}
MOODS = {"neutral", "smile", "angry", "afraid", "sad", "sly", "weary"}
ID = r"[a-z][a-z0-9_]*"

RE_NODE = re.compile(rf"^~\s+({ID}(?::{ID}(?::{ID})*)?|[a-z]+:[a-z0-9_:]+)$")
RE_LINE = re.compile(r"^([A-Za-z][A-Za-z_ ]*?)(?:\s*\[([a-z]+)\])?:\s+(.+)$")
RE_OPTION = re.compile(r"^\*\s+(.*?)\s*->\s*([A-Za-z0-9_:/]+|END)(?:\s*\|\s*([A-Za-z0-9_:/]+|END))?\s*$")
RE_TAG = re.compile(r"^\[([^\]]+)\]\s*")
RE_CHECK_TAG = re.compile(r"^([A-Za-z][A-Za-z ]*?)\s+DC\s+(\d+)$")
RE_JUMP = re.compile(r"^->\s*([A-Za-z0-9_:/]+|END)$")
RE_SET = re.compile(rf"^set\s+({ID})(?:\s*(=|\+=|-=)\s*(.+))?$")
RE_QUEST = re.compile(rf"^quest\s+({ID})\s+({ID})$")
RE_GIVE = re.compile(rf"^(give|take)\s+({ID})(?:\s+(\d+))?$")
RE_GOLD = re.compile(r"^gold\s+([+-]\d+)$")
RE_ATT = re.compile(rf"^attitude\s+({ID})\s+(hostile|indifferent|friendly)$")
RE_CHECK = re.compile(r"^check\s+([A-Za-z][A-Za-z ]*?)\s+DC\s+(\d+)\s*->\s*([A-Za-z0-9_:/]+|END)(?:\s*\|\s*([A-Za-z0-9_:/]+|END))?$")
RE_INTERJECT = re.compile(r"^interject\s+([a-z]+:[a-z0-9_]+):\s+(.+)$")
RE_COMBAT = re.compile(rf"^combat\s+({ID})$")
RE_NARRATE = re.compile(r"^narrate\s+([a-z0-9_:]+)$")
RE_IF = re.compile(r"^(if|elif)\s+(.+)$")
RE_VARIANT = re.compile(r"^\|\s*(?:\[([^\]]+)\]\s*)?(.+)$")
RE_COOLDOWN = re.compile(r"^(cooldown\s+\d+|once)$")
RE_XP = re.compile(r"^xp\s+milestone$")
RE_FLAG_REF = re.compile(rf"\bflag\.({ID})")
CLASS_TAGS = {"fighter", "rogue", "cleric", "wizard", "barbarian", "bard", "druid", "monk", "paladin", "ranger",
              "sorcerer", "warlock"}


def _skill_id(name):
    return name.strip().lower().replace(" ", "_")


def conditions_flags(expr):
    return RE_FLAG_REF.findall(expr)


def parse_file(path):
    text = Path(path).read_text()
    out = {"nodes": {}, "jumps": [], "flags_read": {}, "flags_set": {}, "speakers": [], "items": [], "quests": [],
           "skills": [], "encounters": [], "selectors": [], "narrates": [], "errors": []}
    node = None
    depth = 0
    narrator_file = "/narrator/" in str(path).replace("\\", "/")

    def read(flags, where):
        for f in flags:
            out["flags_read"].setdefault(f, []).append(where)

    for n, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        where = f"{Path(path).name}:{n}"
        m = RE_NODE.match(line)
        if m:
            if depth != 0:
                out["errors"].append(f"{where}: node starts inside an unclosed if (depth {depth})")
                depth = 0
            node = m.group(1)
            if node in out["nodes"]:
                out["errors"].append(f"{where}: duplicate node '{node}'")
            out["nodes"][node] = n
            continue
        if node is None:
            out["errors"].append(f"{where}: statement before the first ~ node")
            continue
        if RE_COOLDOWN.match(line):
            continue
        m = RE_VARIANT.match(line)
        if m and narrator_file:
            if m.group(1):
                read(conditions_flags(m.group(1)), where)
            continue
        m = RE_OPTION.match(line)
        if m:
            label, ok, fail = m.group(1), m.group(2), m.group(3)
            while True:
                t = RE_TAG.match(label)
                if not t:
                    break
                tag = t.group(1).strip()
                label = label[t.end():]
                cm = RE_CHECK_TAG.match(tag)
                if cm:
                    sk = _skill_id(cm.group(1))
                    out["skills"].append((sk, where))
                    if sk not in SKILLS:
                        out["errors"].append(f"{where}: unknown skill '{cm.group(1)}'")
                elif tag.startswith("if "):
                    read(conditions_flags(tag[3:]), where)
                elif ":" in tag:
                    out["selectors"].append((tag, where))
                elif tag.lower() in CLASS_TAGS:
                    out["selectors"].append(("class:" + tag.lower(), where))
                else:
                    out["selectors"].append(("label:" + tag, where))
            if not label.strip():
                out["errors"].append(f"{where}: option has no text")
            out["jumps"].append((ok, where))
            if fail:
                out["jumps"].append((fail, where))
            continue
        if line.startswith("*"):
            out["errors"].append(f"{where}: option needs '-> node' at the end: {line}")
            continue
        m = RE_JUMP.match(line)
        if m:
            out["jumps"].append((m.group(1), where))
            continue
        m = RE_IF.match(line)
        if m:
            if m.group(1) == "if":
                depth += 1
            elif depth == 0:
                out["errors"].append(f"{where}: elif without if")
            read(conditions_flags(m.group(2)), where)
            continue
        if line == "else":
            if depth == 0:
                out["errors"].append(f"{where}: else without if")
            continue
        if line == "endif":
            depth -= 1
            if depth < 0:
                out["errors"].append(f"{where}: endif without if")
                depth = 0
            continue
        m = RE_SET.match(line)
        if m:
            out["flags_set"].setdefault(m.group(1), []).append(where)
            if m.group(2) in ("+=", "-="):
                read([m.group(1)], where)
            continue
        m = RE_QUEST.match(line)
        if m:
            out["quests"].append((m.group(1), m.group(2), where))
            continue
        m = RE_GIVE.match(line)
        if m:
            out["items"].append((m.group(2), where))
            continue
        if RE_GOLD.match(line) or RE_XP.match(line):
            continue
        m = RE_ATT.match(line)
        if m:
            out["speakers"].append((m.group(1), where))
            continue
        m = RE_CHECK.match(line)
        if m:
            sk = _skill_id(m.group(1))
            out["skills"].append((sk, where))
            if sk not in SKILLS:
                out["errors"].append(f"{where}: unknown skill '{m.group(1)}'")
            out["jumps"].append((m.group(3), where))
            if m.group(4):
                out["jumps"].append((m.group(4), where))
            continue
        m = RE_INTERJECT.match(line)
        if m:
            out["selectors"].append((m.group(1), where))
            continue
        m = RE_COMBAT.match(line)
        if m:
            out["encounters"].append((m.group(1), where))
            continue
        m = RE_NARRATE.match(line)
        if m:
            out["narrates"].append((m.group(1), where))
            continue
        m = RE_LINE.match(line)
        if m:
            speaker = m.group(1).strip()
            mood = m.group(2)
            if mood and mood not in MOODS:
                out["errors"].append(f"{where}: unknown mood '{mood}' (use {', '.join(sorted(MOODS))})")
            out["speakers"].append((speaker, where))
            if len(m.group(3).split()) > 60:
                out["errors"].append(f"{where}: line over 60 words (plan §5.7 keeps NPC lines near 40)")
            continue
        out["errors"].append(f"{where}: can't read this line: {line}")
    if depth != 0:
        out["errors"].append(f"{Path(path).name}: an if block is never closed")
    return out
