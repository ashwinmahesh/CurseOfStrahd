#!/usr/bin/env python3
"""Side quests that can be left stuck (Side Quest Failure Plan, package F3). For make validate.

A side quest strands when it stands at an open stage and everything that could move it on has gone from the world for
good: the camp turned and took the only person who pays, the NPC who closes it was killed, the town changed hands. The
static walk here finds the open stages whose ways on all hang on such a thing.

For every open stage of a side quest (not a main quest, not a companion's) it collects the ways on: each dialogue node
that moves the quest to a later stage or an ending, each fight whose win does, and each `closes` rule that applies there
(a rule is a way on that can't vanish: the stage is covered). Then, for each node, the places in the world that open a
conversation reaching it: an NPC's, a prop's or a container's `dialogue`, a schedule event's, a camp talk, a guest's talk,
a visit, a road event. A way on is lost for good when every place that opens it carries a `when` with a `not flag.X`
term for a flag X that some other part of the story sets (a flag set only where this quest itself moves on is progress,
not a loss) and nothing clears again. Conversations opened from anywhere else (camp, banter, visits, the road) are taken
as always there. A stage is reported when all its ways on can be lost that way, naming the flags that lose them.

It is a heuristic: optimistic about everything but those flags. ALLOWED names the stages a human has looked at, with why
they can't strand (the flag can't be set while the quest stands there, or the NPC's absence is the story's own end).

findings(root) -> [error strings]; python3 tools/data/quest_strands.py [--all] prints them (--all ignores ALLOWED).
"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import story_reach  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
END = "END"
RE_TOK = re.compile(r'"[^"]*"|==|!=|>=|<=|[=><()]|[^\s=!<>()]+')
RE_FLAG_NAME = re.compile(r"\bflag\.([a-z][a-z0-9_]*)")

## "quest.stage" -> why that stage can't strand though every way on hangs on a flag the story sets elsewhere.
ALLOWED: dict[str, str] = {
    "stanimirs_fire.challenged":
        "set as the contest begins (svalich_road/stanimir:fire_challenge) and ended at `done` in the same sitting: the rounds"
        " have no way out, so the camp can't turn on the party in between",
    "exethanters_notes.asked":
        "a known stuck state, not a safe one: with Exethanter attacked or destroyed (exethanter_hostile, exethanter_destroyed)"
        " nobody can finish the notes. The Amber Temple package (A1, Side Quest Failure Plan) closes it at `unread`; take"
        " this entry out when it lands",
}


def _load(root):
    files = {}
    for f in sorted((root / "narrative").rglob("*.dialogue")):
        files[f.relative_to(root / "narrative").with_suffix("").as_posix()] = story_reach.parse_dialogue(f)
    tables = {n: story_reach._table(root, n) for n in ("quests", "locations", "schedule", "npcs", "random_encounters",
                                                       "visits", "strahd")}
    return files, tables


def _edges(files):
    """{(file, node): {(file, node)}} for every jump, option and check target."""
    out = {}
    for fk, nodes in files.items():
        for node, stmts in nodes.items():
            to = set()
            for s in stmts:
                for t in s.get("to", []):
                    if t == END:
                        continue
                    if "/" in t and ":" in t:
                        f2, n2 = t.rsplit(":", 1)
                        to.add((f2, n2))
                    else:
                        to.add((fk, t))
            out[(fk, node)] = to
    return out


def _reach(edges, start):
    seen, todo = set(), [start]
    while todo:
        k = todo.pop()
        if k in seen or k not in edges:
            continue
        seen.add(k)
        todo.extend(edges[k])
    return seen


def _ref(ref):
    return tuple(ref.rsplit(":", 1)) if ref and ":" in ref else None


def _setters(files, tables):
    """{flag: [(value, where)]}: every `set` in a conversation (where is (file, node)) and every flag the world sets on its
    own (a fight's, a prop's, a door's, a container's, a trap's, a withdrawal's, a schedule event's; where is "world")."""
    out = {}
    for fk, nodes in files.items():
        for node, stmts in nodes.items():
            for s in stmts:
                if s.get("t") == "set":
                    out.setdefault(s["flag"], []).append((s["value"], (fk, node)))
    for loc in tables["locations"].values():
        for kind in ("props", "containers", "doors", "traps", "encounters"):
            for e in loc.get(kind, []):
                for f in (e.get("flag"), (e.get("withdraw") or {}).get("flag"), (e.get("hangs") or {}).get("flag")):
                    if f:
                        out.setdefault(f, []).append((True, "world"))
    for sch in tables["schedule"].values():
        for e in sch.get("events", []):
            for f, v in (e.get("set") or {}).items():
                out.setdefault(f, []).append((v, "world"))
    return out


def _truthy(v):
    return v not in (False, 0, "", None)


def _compare(v, op, rhs):
    rhs = rhs.strip('"')
    if op == "":
        return _truthy(v)
    if isinstance(v, bool) or isinstance(v, str):
        same = str(v).lower() == rhs.lower() or (v is True and rhs == "true")
        return same if op == "==" else (not same if op == "!=" else True)
    try:
        a, b = float(v), float(rhs)
    except (TypeError, ValueError):
        return True
    return {"==": a == b, "!=": a != b, ">=": a >= b, "<=": a <= b, ">": a > b, "<": a < b}.get(op, True)


def _outcomes(expr, flag, value):
    """{True, False}: what `expr` can come to with flag `flag` holding `value` and every other term free (either way)."""
    toks = RE_TOK.findall(expr or "")
    pos = [0]

    def peek():
        return toks[pos[0]] if pos[0] < len(toks) else ""

    def take():
        pos[0] += 1
        return toks[pos[0] - 1] if pos[0] - 1 < len(toks) else ""

    def or_():
        v = and_()
        while peek() == "or":
            take()
            w = and_()
            v = {a or b for a in v for b in w}
        return v

    def and_():
        v = not_()
        while peek() == "and":
            take()
            w = not_()
            v = {a and b for a in v for b in w}
        return v

    def not_():
        if peek() == "not":
            take()
            return {not a for a in not_()}
        if peek() == "(":
            take()
            v = or_()
            if peek() == ")":
                take()
            return v
        t, op, rhs = take(), "", ""
        if peek() in ("==", "!=", ">=", "<=", ">", "<", "="):
            op = "==" if take() == "=" else toks[pos[0] - 1]
            rhs = take()
        if t == "true":
            return {True}
        if t == "false":
            return {False}
        if t == "flag." + flag:
            return {_compare(value, op, rhs)}
        return {True, False}

    return or_() if toks else {True}


def _entries(files, tables):
    """[(entry ref (file, node), its condition, where)]: everything in the world that opens a conversation. A condition of
    None means always there (camp talks, banter, visits, the road)."""
    out = []
    for lid, loc in tables["locations"].items():
        for kind in ("npcs", "props", "containers", "doors"):
            for e in loc.get(kind, []):
                for key in ("dialogue", "call"):
                    r = _ref(e.get(key, ""))
                    if r:
                        out.append((r, e.get("when", ""), f"data/locations/{lid}.json {kind[:-1]} {e.get('id', e.get('npc', ''))}"))
        for en in loc.get("encounters", []):
            r = _ref(en.get("dialogue", ""))
            if r:
                out.append((r, en.get("when", ""), f"data/locations/{lid}.json encounter {en['id']}"))
        for t in loc.get("triggers", []) + loc.get("areas", []):
            r = _ref(t.get("dialogue", ""))
            if r:
                out.append((r, t.get("when", ""), f"data/locations/{lid}.json {t.get('id', '')}"))
    for sid, sch in tables["schedule"].items():
        for e in sch.get("events", []):
            r = _ref(e.get("dialogue", ""))
            if r:
                out.append((r, None, f"data/schedule/{sid}.json {e['id']}"))
    # Everything else that starts a conversation without a place: taken as always there.
    for fk, nodes in files.items():
        top = fk.split("/")[0]
        if top in ("camp", "banter"):
            for node in nodes:
                out.append(((fk, node), None, f"narrative/{fk}.dialogue"))
    for nid, npc in tables["npcs"].items():
        r = _ref(npc.get("guest_talk", ""))
        if r:
            out.append((r, None, f"data/npcs/{nid}.json guest_talk"))
    for vid, v in list(tables["visits"].items()) + list(tables["strahd"].items()):
        for e in (v.get("visits", []) if isinstance(v, dict) else []):
            r = _ref(e.get("dialogue", ""))
            if r:
                out.append((r, None, f"visits {vid}"))
    for rid, t in tables["random_encounters"].items():
        for e in (t.get("events", []) + t.get("entries", []) if isinstance(t, dict) else []):
            r = _ref(e.get("dialogue", "")) if isinstance(e, dict) else None
            if r:
                out.append((r, None, f"data/random_encounters/{rid}.json"))
    return out


def _need_of(exprs, qid, stages):
    """The furthest stage of `qid` the conditions ask it to have reached already (-1 for none)."""
    need = -1
    for g in exprs:
        if re.search(rf"not\s*\(?\s*quest\.{qid}\b", g):
            continue
        for m in re.finditer(rf"quest\.{qid}\s*(==|>=|>)\s*([a-z][a-z0-9_]*)", g):
            if m.group(2) in stages:
                need = max(need, stages.index(m.group(2)) + (1 if m.group(1) == ">" else 0))
    return need


def _node_needs(files, starts, qid, stages):
    """{(file, node): the stage `qid` must have reached for the conversation to get there}: from every place that opens a
    conversation (need -1), each jump or option passing on the most its own conditions and `if`s ask."""
    need = {k: -1 for k in starts}
    todo = list(starts)
    while todo:
        fk, node = todo.pop()
        here = need[(fk, node)]
        for st in files.get(fk, {}).get(node, []):
            for t in st.get("to", []):
                if t == END:
                    continue
                key = tuple(t.rsplit(":", 1)) if ("/" in t and ":" in t) else (fk, t)
                n = max(here, _need_of(st["guards"] + st.get("conds", []), qid, stages))
                if key not in need or n < need[key]:
                    need[key] = n
                    todo.append(key)
    return need


def findings(root=ROOT, use_allowed=True):
    root = Path(root)
    files, tables = _load(root)
    edges = _edges(files)
    setters = _setters(files, tables)
    entries = _entries(files, tables)
    starts = {ref for ref, _c, _w in entries}
    reach = {}
    for ref, cond, where in entries:
        for k in _reach(edges, ref):
            reach.setdefault(k, []).append((cond, where))
    out = []
    for qid, q in sorted(tables["quests"].items()):
        if q.get("kind") == "main" or q.get("region") == "companions":
            continue
        stages = [s["id"] for s in q["stages"]]
        ends = {s["id"] for s in q["stages"] if s.get("ends")}
        # Nodes that move the quest, by the stage they set; and the nodes of this quest's own progress.
        movers, own = {}, set()
        for fk, nodes in files.items():
            for node, stmts in nodes.items():
                for s in stmts:
                    if s.get("t") == "quest" and s["quest"] == qid and s["stage"] in stages:
                        # The furthest stage its `if` guards ask the quest to be at already (a line that finishes the
                        # quest only once it is found is no way on from before it was found).
                        movers.setdefault(s["stage"], set()).add((fk, node, _need_of(s["guards"], qid, stages)))
                        own.add((fk, node))
        fights = {}
        for lid, loc in tables["locations"].items():
            for en in loc.get("encounters", []):
                qq = en.get("quest") or {}
                if qq.get("id") == qid:
                    fights.setdefault(qq["stage"], []).append((en.get("when", ""), f"data/locations/{lid}.json encounter {en['id']}"))
        needs = _node_needs(files, starts, qid, stages)
        for i, st in enumerate(stages):
            if st in ends:
                continue
            if any(not r.get("from") or st in r["from"] for r in q.get("closes", [])):
                continue   # a rule can end it from here: never stuck
            later = [s for j, s in enumerate(stages) if j > i or s in ends]
            ways = []   # (condition or None, where) for each way on
            for s in later:
                for fk, node, need in movers.get(s, ()):
                    if max(need, needs.get((fk, node), -1)) <= i:
                        ways += reach.get((fk, node), [])
                ways += fights.get(s, [])
            if not ways:
                continue   # nothing moves it on at all: story_reach.py's business
            killers = None   # the losses that close every way on at once
            safe = False
            for cond, where in ways:
                if cond is None:
                    safe = True
                    break
                lost = set()
                for f in set(RE_FLAG_NAME.findall(cond)):
                    sets = setters.get(f, [])
                    if any(not _truthy(v) for v, _w in sets if v != "+"):
                        continue   # something clears it again: not for good
                    for v, w in sets:
                        if v == "+" or w in own:
                            continue
                        if True not in _outcomes(cond, f, v):
                            lost.add(f if v is True else f"{f} = {json.dumps(v)}")
                killers = lost if killers is None else killers & lost
                if not killers:
                    safe = True
                    break
            if safe:
                continue
            ident = f"{qid}.{st}"
            if use_allowed and ident in ALLOWED:
                continue
            out.append(f"data/quests/{qid}.json: stage '{st}' can be left stuck: every way on goes once "
                       f"{' or '.join(sorted(killers))}; give it another way on or a `closes` "
                       f"rule (or list it in tools/data/quest_strands.py ALLOWED with the reason)")
    return out


def selftest():
    """The checker judges a few made-up worlds right: [error strings]."""
    import tempfile

    camp = {"id": "camp", "region": "r", "npcs": [], "props": []}

    def world(talker_when, quest_extra=None, gone_set_in="brawl"):
        d = Path(tempfile.mkdtemp())
        (d / "data" / "quests").mkdir(parents=True)
        (d / "data" / "locations").mkdir(parents=True)
        (d / "narrative" / "t").mkdir(parents=True)
        q = {"id": "q", "name": "Q", "summary": "", "region": "r", "stages": [
            {"id": "asked", "journal": "", "hint": "", "ends": ""}, {"id": "done", "journal": "", "ends": "success"},
            {"id": "lost", "journal": "", "ends": "failure"}]}
        q.update(quest_extra or {})
        (d / "data" / "quests" / "q.json").write_text(json.dumps(q))
        loc = dict(camp, npcs=[{"npc": "a", "cell": [1, 1], "dialogue": "t/a:start", "when": w} for w in talker_when]
                   + [{"npc": "b", "cell": [2, 2], "dialogue": "t/b:start", "when": ""}])
        (d / "data" / "locations" / "camp.json").write_text(json.dumps(loc))
        own = "set camp_gone\n" if gone_set_in == "own" else ""
        (d / "narrative" / "t" / "a.dialogue").write_text(f"~ start\n{own}quest q done\n-> END\n")
        brawl = "set camp_gone\n" if gone_set_in == "brawl" else ""
        (d / "narrative" / "t" / "b.dialogue").write_text(f"~ start\nquest q asked\n-> fight\n\n~ fight\n{brawl}set camp_mood = \"cold\"\n-> END\n")
        return d

    cases = [
        ("the only way on is gone once the camp turns", world(["not flag.camp_gone"]), 1),
        ("a closes rule covers the stage", world(["not flag.camp_gone"], {"closes": [{"stage": "lost", "when": "flag.camp_gone"}]}), 0),
        ("a flag set where the quest itself moves on is progress", world(["not flag.camp_gone"], gone_set_in="own"), 0),
        ("two places that cover each other's absence", world(["flag.camp_mood != \"cold\"", "flag.camp_mood == \"cold\""]), 0),
        ("a value that closes the only way on", world(["flag.camp_mood != \"cold\""]), 1),
    ]
    errors = []
    for label, root, want in cases:
        got = len(findings(root, use_allowed=False))
        if got != want:
            errors.append(f"tools/data/quest_strands.py selftest: {label}: {got} finding(s), wanted {want}")
    return errors


if __name__ == "__main__":
    bad = selftest()
    for b in bad:
        print(b)
    fs = findings(ROOT, "--all" not in sys.argv)
    for f in fs:
        print(f)
    print(f"{len(fs)} stuck stage(s)")
