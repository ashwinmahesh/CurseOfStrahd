#!/usr/bin/env python3
"""Parses narrative/**/*.dialogue (docs/contracts/dialogue.md) for validate_data.py: syntax, jumps, and every
flag, speaker, item, quest, skill and encounter a file uses. Stdlib only.

parse_file(path) -> {"nodes": {id: line_no}, "jumps": [(target, line)], "flags_read": {id: [where]},
                     "flags_set": {id: [where]}, "speakers": [(id, line)], "items": [...], "quests": [...],
                     "skills": [...], "encounters": [...], "selectors": [...], "errors": [str]}
                     (+ "end_games": [where] for each `end_game`, when a file has one)
                     "ends": [(quest id, where)] for each `[ends:<quest>]` option tag
                     (+ "casts": [(spell id, where)] for `cast`, "reveals": [(prop id, where)] for `reveal`)
                     (+ "leads": [(npc id, target, where)] for `lead <npc> to <target>`, target a place id, an id on a map or "x,y")
                     (+ "moves": [(location id, spawn name, where)] for `move`, the spawn "default" when none is named)
                     (+ "approvals": [(companion id, delta, where)] for `approve`, "inspires": [(selector, where)] for
                     `inspire`, and "approval_terms": [(companion id, rhs or "", where)] for `approval.<id>` in conditions)
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
RE_LINE = re.compile(r"^([A-Za-z][A-Za-z_ ]*?)(?:\s*\[([a-z:]+(?:\s*,\s*[a-z:]+)*)\])?:\s+(.+)$")
## The turn cues a line's bracket may hold beside its mood (docs/ui/busts.md).
AWAY = {"away", "away:party"}
RE_OPTION = re.compile(r"^\*\s+(.*?)\s*->\s*([A-Za-z0-9_:/]+|END)(?:\s*\|\s*([A-Za-z0-9_:/]+|END))?\s*$")
RE_TAG = re.compile(r"^\[([^\]]+)\]\s*")
RE_ENDS_TAG = re.compile(rf"^ends:({ID})(?:\s+if\s+(.+))?$")
RE_CHECK_TAG = re.compile(r"^([A-Za-z][A-Za-z ]*?)\s+DC\s+(\d+)$")
RE_JUMP = re.compile(r"^->\s*([A-Za-z0-9_:/]+|END)$")
RE_SET = re.compile(rf"^set\s+({ID})(?:\s*(=|\+=|-=)\s*(.+))?$")
RE_QUEST = re.compile(rf"^quest\s+({ID})\s+({ID})$")
RE_GIVE = re.compile(rf"^(give|take)\s+({ID})(?:\s+(\d+))?(?:\s+to\s+([a-z]+:[a-z0-9_]+))?$")
RE_GOLD = re.compile(r"^gold\s+([+-]\d+)$")
RE_ATT = re.compile(rf"^attitude\s+({ID})\s+(hostile|indifferent|friendly)$")
RE_CHECK = re.compile(r"^check\s+([A-Za-z][A-Za-z ]*?)\s+DC\s+(\d+)\s*->\s*([A-Za-z0-9_:/]+|END)(?:\s*\|\s*([A-Za-z0-9_:/]+|END))?$")
RE_INTERJECT = re.compile(r"^interject\s+([a-z]+:[a-z0-9_]+):\s+(.+)$")
RE_COMBAT = re.compile(rf"^combat\s+({ID})$")
RE_MOVE = re.compile(rf"^move\s+({ID})(?::({ID}))?$")
RE_NARRATE = re.compile(r"^narrate\s+([a-z0-9_:]+)$")
RE_CAST = re.compile(rf"^cast\s+({ID})$")
RE_REVEAL = re.compile(rf"^reveal\s+({ID})$")
RE_LEAD = re.compile(rf"^lead\s+({ID})\s+to\s+({ID}(?::{ID})?|\d+,\d+)$")
RE_CUTSCENE = re.compile(r"^cutscene\s+([a-z][a-z0-9_]*)$")
RE_IF = re.compile(r"^(if|elif)\s+(.+)$")
RE_VARIANT = re.compile(r"^\|\s*(?:\[([^\]]+)\]\s*)?(.+)$")
RE_COOLDOWN = re.compile(r"^(cooldown\s+\d+|once)$")
RE_XP = re.compile(r"^xp\s+milestone$")
RE_XP_FIGHT = re.compile(rf"^xp\s+fight\s+({ID})$")
RE_SACRIFICE = re.compile(r"^sacrifice$")
RE_TAROKKA_GIVE = re.compile(r"^tarokka\s+give\s+([a-z][a-z0-9_]*(?::[a-z][a-z0-9_]*)?)$")
RE_DARK_GIFT = re.compile(r"^dark_gift\s+([a-z][a-z0-9_]*)$")
RE_TAROKKA = re.compile(r"^tarokka\s+(draw|read\s+(tome|symbol|sword|ally|enemy)(\s+[a-z][a-z0-9_]*)?)$")
RE_TIME = re.compile(r"^time\s+(\+\d+|until\s+\d{1,2})$")
RE_SHOP = re.compile(r"^(shop|services|respec)$")
RE_END_GAME = re.compile(r"^end_game$")
RE_GUEST = re.compile(rf"^(join|leave)\s+({ID})$")
RE_STAGE = re.compile(rf"^(appear\s+({ID})(?:\s+at\s+({ID}))?|vanish\s+({ID}))$")
# A flag a condition reads: `flag.x`, or `days_since.x` (a flag stamped with `set x = now`, docs/contracts/dialogue.md).
RE_FLAG_REF = re.compile(rf"\b(?:flag|days_since)\.({ID})")
RE_QUEST_DAYS_REF = re.compile(rf"\bquest_days\.({ID})")
RE_APPROVE = re.compile(r"^approve\s+((?:[a-z][a-z0-9_]*\s+[+-]\d+\s*)+)(?::\s*(.*))?$")
RE_INSPIRE = re.compile(r"^inspire\s+(party|[a-z]+:[a-z0-9_]+)(?::\s*(.+))?$")
RE_APPROVAL_REF = re.compile(r"\bapproval\.([a-z][a-z0-9_]*)(?:\s*(==|!=|>=|<=|>|<)\s*([a-z0-9_+-]+))?")
RE_HERO_NAMED = re.compile(r"\bhero_named:([^\s()=!<>]*)")
RE_ONCE_WORD = re.compile(r"\bonce\b")
CLASS_TAGS = {"fighter", "rogue", "cleric", "wizard", "barbarian", "bard", "druid", "monk", "paladin", "ranger",
              "sorcerer", "warlock"}


def _skill_id(name):
    return name.strip().lower().replace(" ", "_")


def conditions_flags(expr):
    return RE_FLAG_REF.findall(expr)


# What a condition's terms may be (story/story_conditions.gd): a bare word, a `kind.name` or a `kind:name`. Anything else is
# a warning and false at run time, so a condition in new data (a quest's `closes`) is checked against them.
CONDITION_WORDS = {"true", "false", "night", "day", "indoors", "hour", "attention", "weather", "gold", "level", "check.last"}
CONDITION_DOTTED = {"flag", "quest", "quest_days", "days_since", "attitude", "approval", "tarokka"}
CONDITION_COLONED = {"final_room", "guest", "treasure_at", "gift", "gifted", "fallen", "spell", "at", "region", "option", "visited", "leader", "item",
                     "class", "species", "background", "tag", "name", "knows"}
RE_CONDITION_TOKEN = re.compile(r'\(|\)|==|!=|>=|<=|=|>|<|"[^"]*"|[^\s()=!<>]+')
CONDITION_OPS = {"==", "!=", ">=", "<=", "=", ">", "<"}


def condition_problems(expr):
    """[what is wrong] with a condition: unbalanced parentheses, an `and`, `or` or `not` with nothing to join, an operator with
    no value, a term the game doesn't know. Empty is fine (always true)."""
    toks = RE_CONDITION_TOKEN.findall(expr or "")
    problems = []
    i = 0

    def peek():
        return toks[i] if i < len(toks) else ""

    def take():
        nonlocal i
        i += 1
        return toks[i - 1] if i - 1 < len(toks) else ""

    def either(joiner, inner):
        inner()
        while peek() == joiner:
            take()
            inner()

    def term():
        word = take()
        if word in ("", ")", "and", "or") or word in CONDITION_OPS:
            problems.append(f"'{word or 'end of the condition'}' where a term belongs")
            return
        if peek() in CONDITION_OPS:
            take()
            if peek() in ("", ")", "and", "or") or peek() in CONDITION_OPS:
                problems.append(f"'{word}' compared with nothing")
            else:
                take()
        head = re.match(r"^([a-z_]+)([.:])", word)
        known = word in CONDITION_WORDS or (head is not None and head.group(1) in (CONDITION_DOTTED if head.group(2) == "." else CONDITION_COLONED))
        if not known:
            problems.append(f"unknown term '{word}'")

    def unary():
        if peek() == "not":
            take()
            unary()
        elif peek() == "(":
            take()
            either("or", conj)
            if peek() == ")":
                take()
            else:
                problems.append("a '(' is never closed")
        else:
            term()

    def conj():
        either("and", unary)

    if toks:
        either("or", conj)
        if i < len(toks):
            problems.append(f"'{toks[i]}' is left over (an unmatched ')' or a missing and/or)")
    return problems


RE_HERO_REF = re.compile(rf"\b(fallen|gifted):({ID})")


def conditions_heroes(expr):
    """[(kind, hero id)] for each `fallen:<hero>` and `gifted:<hero>` term."""
    return RE_HERO_REF.findall(expr or "")


def conditions_quest_days(expr):
    """The quests a condition's `quest_days.<id>` terms name."""
    return RE_QUEST_DAYS_REF.findall(expr)


def conditions_approval(expr):
    """[(companion id, rhs)] for each `approval.<id> [op rhs]` term (rhs "" when there's no operator)."""
    return [(m.group(1), m.group(3) or "") for m in RE_APPROVAL_REF.finditer(expr)]


def parse_file(path):
    text = Path(path).read_text()
    out = {"nodes": {}, "jumps": [], "flags_read": {}, "flags_set": {}, "speakers": [], "items": [], "quests": [],
           "skills": [], "encounters": [], "selectors": [], "narrates": [], "cutscenes": [], "ends": [], "errors": []}
    node = None
    depth = 0
    narrator_file = "/narrator/" in str(path).replace("\\", "/")

    def read(flags, where, expr=None):
        for f in flags:
            out["flags_read"].setdefault(f, []).append(where)
        if expr:
            for cid, rhs in conditions_approval(expr):
                out.setdefault("approval_terms", []).append((cid, rhs, where))
            for arg in RE_HERO_NAMED.findall(expr):
                if not re.fullmatch(r"[A-Za-z0-9_]+", arg):
                    out["errors"].append(f"{where}: hero_named:{arg} needs a name: letters and digits, `_` for a space")
            for qid in conditions_quest_days(expr):
                out.setdefault("quest_days_terms", []).append((qid, where))

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
                cond = m.group(1)
                if RE_ONCE_WORD.search(cond):
                    # `[once]` / `[once and <condition>]`: the Narrator plays the variant one time (story/narrator.gd).
                    if cond != "once" and not (cond.startswith("once and ") and cond[9:].strip()):
                        out["errors"].append(f"{where}: `once` only leads a variant's brackets: `[once]` or "
                                             f"`[once and <condition>]`, not [{cond}]")
                read(conditions_flags(cond), where, cond)
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
                    read(conditions_flags(tag[3:]), where, tag[3:])
                elif tag.startswith("ends:"):
                    # `[ends:<quest>]` or `[ends:<quest> if <condition>]`: choosing it closes the quest (tools/data/option_ends.py)
                    em = RE_ENDS_TAG.match(tag)
                    if not em:
                        out["errors"].append(f"{where}: malformed tag [{tag}] (want [ends:<quest id>] or [ends:<quest id> if <condition>])")
                    else:
                        out["ends"].append((em.group(1), where))
                        if em.group(2):
                            read(conditions_flags(em.group(2)), where, em.group(2))
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
            read(conditions_flags(m.group(2)), where, m.group(2))
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
            if m.group(4):
                out["selectors"].append((m.group(4), where))
            continue
        m = RE_TAROKKA_GIVE.match(line)
        if m:
            out.setdefault("tarokka_give", []).append((m.group(1), where))
            continue
        m = RE_DARK_GIFT.match(line)
        if m:
            out.setdefault("dark_gifts", []).append((m.group(1), where))
            continue
        if RE_GOLD.match(line) or RE_XP.match(line) or RE_SACRIFICE.match(line) or RE_TAROKKA.match(line) or RE_SHOP.match(line) or RE_TIME.match(line):
            continue
        if RE_END_GAME.match(line):
            out.setdefault("end_games", []).append(where)  # the campaign ends here (ADR 0014)
            continue
        m = RE_GUEST.match(line)
        if m:
            out["speakers"].append((m.group(2), where))
            continue
        m = RE_STAGE.match(line)
        if m:
            out["speakers"].append((m.group(2) or m.group(4), where))   # the npc must exist
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
        if line.startswith("approve"):
            m = RE_APPROVE.match(line)
            if not m:
                out["errors"].append(f"{where}: approve needs companion ids with signed changes, then an optional"
                                     f" ': reason' (approve thistle +2 kip_smudgewick -1: You freed the wolves): {line}")
                continue
            for cid, delta in re.findall(r"([a-z][a-z0-9_]*)\s+([+-]\d+)", m.group(1)):
                out.setdefault("approvals", []).append((cid, int(delta), where))
            continue
        if line.startswith("inspire"):
            m = RE_INSPIRE.match(line)
            if not m:
                out["errors"].append(f"{where}: inspire needs a selector and an optional ': reason'"
                                     f" (inspire name:thistle: spoke her mind): {line}")
                continue
            out.setdefault("inspires", []).append((m.group(1), where))
            if m.group(1) != "party":
                out["selectors"].append((m.group(1), where))
            continue
        m = RE_COMBAT.match(line)
        if m:
            out["encounters"].append((m.group(1), where))
            continue
        m = RE_MOVE.match(line)
        if m:
            out.setdefault("moves", []).append((m.group(1), m.group(2) or "default", where))   # the party goes there (story/dialogue_runner.gd)
            continue
        m = RE_XP_FIGHT.match(line)
        if m:
            out.setdefault("xp_fights", []).append((m.group(1), where))   # a fight talked or tricked away pays its XP (story/xp.gd)
            continue
        m = RE_NARRATE.match(line)
        if m:
            out["narrates"].append((m.group(1), where))
            continue
        m = RE_CAST.match(line)
        if m:
            out.setdefault("casts", []).append((m.group(1), where))
            continue
        m = RE_REVEAL.match(line)
        if m:
            out.setdefault("reveals", []).append((m.group(1), where))
            continue
        m = RE_LEAD.match(line)
        if m:
            out["speakers"].append((m.group(1), where))   # the npc must exist
            out.setdefault("leads", []).append((m.group(1), m.group(2), where))
            continue
        m = RE_CUTSCENE.match(line)
        if m:
            out["cutscenes"].append((m.group(1), where))
            continue
        m = RE_LINE.match(line)
        if m:
            speaker = m.group(1).strip()
            tags = [t.strip() for t in (m.group(2) or "").split(",") if t.strip()]
            moods = [t for t in tags if t not in AWAY]
            for mood in moods:
                if mood not in MOODS:
                    out["errors"].append(f"{where}: unknown mood '{mood}' (use {', '.join(sorted(MOODS))}, and away or away:party to turn)")
            if len(moods) > 1 or len(tags) - len(moods) > 1:
                out["errors"].append(f"{where}: one mood and one turn cue at most: [{m.group(2)}]")
            out["speakers"].append((speaker, where))
            if len(m.group(3).split()) > 60:
                out["errors"].append(f"{where}: line over 60 words (plan §5.7 keeps NPC lines near 40)")
            continue
        out["errors"].append(f"{where}: can't read this line: {line}")
    if depth != 0:
        out["errors"].append(f"{Path(path).name}: an if block is never closed")
    return out
