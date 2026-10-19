#!/usr/bin/env python3
"""A failed roll never locks a quest, and never fails one (owner, 2026-10-17 and 2026-10-19; docs/plans/npc_depth_and_quests.md,
the side quest failure plan). For make validate.

For every Persuasion, Intimidation, Deception, Performance or Insight option whose success moves a quest on past a
stage, walk the same conversation with every roll failed: each check takes its fail branch (the success branch when it
has none), every plain option is open, and `if` guards are ignored (optimistic, like story_reach.py). If the quest
stage the success sets can't be reached that way, one bad roll closes that route for good, because a failed social
option is spent (story/dialogue_runner.gd); any other check can be tried again, so it can't lock anything. A fight
reachable in that walk counts as a way on: the stage a won fight sets lives in the node the fight returns to.

Second, for every check of any skill (an option's `[Skill DC n]` tag or a `check` line) with a branch of its own for a failed
roll: follow that branch through jumps and further failed rolls up to the next menu, a fight or a move, and refuse a side
quest's failure ending set on the way (a failed roll may cost a route, gold, a wound or a fight, but the quest ends in failure
only through a choice, a story beat or a clock: the side quest failure plan, rule 5).

Main-story quests are left to their own tests (they have hand-built second routes); every other quest is checked.
ALLOWED names the checks whose other route lives somewhere this static walk can't see, each with its reason.

findings(root) -> [error strings]; python3 tools/data/fail_routes.py [--all] prints them (--all ignores ALLOWED).
selftest() -> [error strings]: a few made-up conversations the checker must judge right; validate runs it too.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import story_reach  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
END = "END"
SOCIAL = story_reach.SOCIAL   # persuasion, intimidation, deception, performance, insight: spent once failed

## "file key:node:skill:quest.stage" -> why a failed roll there can't lock the quest. Batches 2 to 6 of the NPC plan
## (docs/plans/npc_depth_and_quests.md) take their regions' entries out as each is reshaped or given a second route.
ALLOWED: dict[str, str] = {
    "svalich_road/grey_mare:asks:insight:the_grey_mare.bargain":
        "`bargain` is a journal detail (why Radu sold her); `where` leads to the milestone either way",
    "svalich_road/grey_mare:asks:persuasion:the_grey_mare.bargain": "same: the journal detail, not the way on",
    "krezk/dumitrus_visitor:cousins_try:deception:dumitrus_visitor.done":
        "the other route is Ambrose Fennimore (fennimore:menu to fennimore_ask, then the visit at Krezk's gate), which"
        " starts in another conversation this walk can't follow",
    "vallaki/black_roses:asks:insight:black_roses.fed":
        "`fed` is a journal detail (Catalina feeds on her father); the watch option goes on to the vigil without it",
    # A failed roll that ends a quest in failure (the side quest failure plan, rule 5): each goes when its package changes it.
    "amber_temple/vestiges:tarakamedes_kasimir:persuasion:patrinas_wail.restored":
        "Kasimir's bargain after a failed Persuasion; package A1 gives it a choice (stand in his way, or let him) instead",
    "castle_ravenloft/spires_escher:heart_ask:intimidation:escher_petition.refused":
        "a failed Intimidation scares Escher off; packages S3 and C1 rework his refusal (a choice, not a roll)",
    "vallaki/vistani_camp:bluto:persuasion:missing_arabelle.lost":
        "Bluto's menu: package VA2 gives it a way out and makes the dives cost a level of Exhaustion, not the girl",
    "vallaki/vistani_camp:bluto:intimidation:missing_arabelle.lost": "same: Bluto's menu (VA2)",
    "vallaki/vistani_camp:bluto:athletics:missing_arabelle.lost": "same: Bluto's menu (VA2)",
    "vallaki/vistani_camp:dive:athletics:missing_arabelle.lost": "the first dive: package VA2",
    "vallaki/vistani_camp:dive_again:perception:missing_arabelle.lost": "the second dive: package VA2",
}


def _key(path: Path, root: Path) -> str:
    return path.relative_to(root / "narrative").with_suffix("").as_posix()


def load(root: Path):
    """({file key: {node: [statement]}}, {quest id: {"kind": main or side, "ends": {stage: success/failure/""}}})."""
    files = {}
    for f in sorted((root / "narrative").rglob("*.dialogue")):
        files[_key(f, root)] = story_reach.parse_dialogue(f)
    quests = {}
    for f in sorted((root / "data" / "quests").glob("*.json")):
        q = json.loads(f.read_text())
        quests[f.stem] = {"kind": q.get("kind", "side"), "ends": {st["id"]: st.get("ends", "") for st in q["stages"]}}
    return files, quests


def _resolve(files, key, target):
    """(file key, node) a jump goes to, or None for END or a node that doesn't exist (validate reports those)."""
    if target == END:
        return None
    k, n = (target.rsplit(":", 1) if ":" in target else (key, target))
    return (k, n) if n in files.get(k, {}) else None


def _moves(sts):
    return {(s["quest"], s["stage"]) for s in sts if s["t"] == "quest"}


def _targets(st, failing):
    """Where a statement leads when every roll fails. A plain option or jump goes on to all its targets; a check takes
    only its fail branch (its success one when it has none)."""
    to = st["to"]
    if (st["t"] == "option" and st.get("check")) or st.get("is_check"):
        return [to[-1]] if len(to) > 1 else to
    return to


def walk_failing(files, start):
    """(set of quest moves reachable, whether a fight is) from (file key, node) with every roll failed."""
    seen, moves, fight, todo = set(), set(), False, [start]
    while todo:
        cur = todo.pop()
        if cur in seen:
            continue
        seen.add(cur)
        sts = files[cur[0]][cur[1]]
        moves |= _moves(sts)
        fight = fight or any(s["t"] == "combat" for s in sts)
        for s in sts:
            if s["t"] in ("option", "jump"):
                for t in _targets(s, True):
                    nxt = _resolve(files, cur[0], t)
                    if nxt:
                        todo.append(nxt)
    return moves, fight


def _success_moves(files, key, node, st):
    """Quest moves the success branch of a check statement makes, following jumps (not menus' options)."""
    first = st["to"][0]
    out, seen, todo = set(), set(), [first]
    while todo:
        t = todo.pop()
        nxt = _resolve(files, key, t)
        if not nxt or nxt in seen:
            continue
        seen.add(nxt)
        sts = files[nxt[0]][nxt[1]]
        out |= _moves(sts)
        for s in sts:
            if s["t"] == "jump":
                todo.extend(f"{nxt[0]}:{x}" if ":" not in x and x != END else x for x in s["to"])
    return out


def _other_ending(quests, move, reach):
    """Whether `move` is one of a quest's endings and the failed walk reaches another: a choice between endings."""
    ends = quests.get(move[0], {}).get("ends", {})
    return bool(ends.get(move[1])) and any(q == move[0] and ends.get(s) for q, s in reach)


def _until_menu(files, key, node):
    """Quest moves a conversation makes from (key, node) with every roll failed, up to the next menu, fight or move: the
    statements before the node's first option, following its jumps and the fail branch of any further roll."""
    moves, seen, todo = set(), set(), [(key, node)]
    while todo:
        cur = todo.pop()
        if cur in seen:
            continue
        seen.add(cur)
        for s in files[cur[0]][cur[1]]:
            if s["t"] in ("option", "combat", "move"):
                break
            if s["t"] == "quest":
                moves.add((s["quest"], s["stage"]))
            elif s["t"] == "jump":
                for t in _targets(s, True):
                    nxt = _resolve(files, cur[0], t)
                    if nxt:
                        todo.append(nxt)
    return moves


def analyse_endings(files, quests):
    """[(key, node, skill, line, move)] for each side quest failure ending a failed roll sets before the next menu."""
    out = []
    for key, nodes in files.items():
        for node, sts in nodes.items():
            for st in sts:
                is_roll = (st["t"] == "option" and st.get("check")) or st.get("is_check")
                if not is_roll or len(st["to"]) < 2:
                    continue   # a roll with no branch of its own for a failure doesn't make one
                nxt = _resolve(files, key, st["to"][-1])
                if not nxt:
                    continue
                skill = st.get("check") or st.get("skill") or "check"
                for quest, stage in sorted(_until_menu(files, nxt[0], nxt[1])):
                    q = quests.get(quest, {})
                    if q.get("kind") != "main" and q.get("ends", {}).get(stage) == "failure":
                        out.append((key, node, skill, st["line"], (quest, stage)))
    return out


def analyse(files, quests):
    """[(key, node, skill, line, move)] for each success move a failed roll would close for good."""
    out = []
    for key, nodes in files.items():
        for node, sts in nodes.items():
            fails = None
            for st in sts:
                # Only a spent option can lock: the others come back (a failed Athletics roll can be tried again, and a
                # `check` line rolls again when the conversation does), the social ones never do (dialogue_runner).
                if not (st["t"] == "option" and st.get("check") in SOCIAL):
                    continue
                skill = st["check"]
                gained = {m for m in _success_moves(files, key, node, st) if quests.get(m[0], {}).get("kind") != "main"}
                if not gained:
                    continue
                if fails is None:
                    fails = walk_failing(files, (key, node))
                reach, fight = fails
                for m in sorted(gained - reach):
                    if fight or _other_ending(quests, m, reach):
                        continue
                    out.append((key, node, skill, st["line"], m))
    return out


def findings(root=ROOT, use_allowed=True):
    root = Path(root)
    files, quests = load(root)
    errors = [f"fail_routes selftest: {e}" for e in selftest()]
    for key, node, skill, line, (quest, stage) in analyse(files, quests):
        ident = f"{key}:{node}:{skill}:{quest}.{stage}"
        if use_allowed and ident in ALLOWED:
            continue
        errors.append(f"narrative/{key}.dialogue:{line}: a failed {skill.replace('_', ' ')} roll in '{node}' closes the"
                      f" way to {quest} {stage} ({ident}); give the fail branch a way on or another option that"
                      f" reaches it, or list it in tools/data/fail_routes.py ALLOWED with the reason")
    for key, node, skill, line, (quest, stage) in analyse_endings(files, quests):
        ident = f"{key}:{node}:{skill}:{quest}.{stage}"
        if use_allowed and ident in ALLOWED:
            continue
        errors.append(f"narrative/{key}.dialogue:{line}: a failed {skill.replace('_', ' ')} roll in '{node}' fails {quest}"
                      f" ({stage}) before the next menu ({ident}); a failed roll may cost something but never ends a quest:"
                      f" give the fail branch a menu first, or list it in tools/data/fail_routes.py ALLOWED with the reason")
    return errors


def _fixture(text: str):
    """{node: [statement]} from dialogue text, the way story_reach reads a file."""
    import tempfile
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "x.dialogue"
        p.write_text(text)
        return story_reach.parse_dialogue(p)


def selftest():
    """The checker judges a few made-up conversations right (quest 'q' is a side quest)."""
    cases = [
        ("a roll that is the only way on is flagged", """~ start
* [Persuasion DC 12] Please. -> ok | bad
* Goodbye. -> END

~ ok
quest q found
-> END

~ bad
Guard: No.
-> END
""", 1),
        ("a fail branch that reaches the same stage passes", """~ start
* [Persuasion DC 12] Please. -> ok | bad
* Goodbye. -> END

~ ok
-> told

~ bad
Guard: Fine, but it'll cost you.
-> told

~ told
quest q found
-> END
""", 0),
        ("another plain option to the stage passes", """~ start
* [Intimidation DC 14] Talk. -> ok | bad
* Pay ten gold. -> pay
* Goodbye. -> END

~ ok
quest q found
-> END

~ bad
Guard: No.
-> start

~ pay
quest q found
-> END
""", 0),
        ("a second check is no way on when every roll fails", """~ start
* [Persuasion DC 12] Please. -> ok | bad
* [Deception DC 12] Lie. -> ok2 | bad
* Goodbye. -> END

~ ok
quest q found
-> END

~ ok2
quest q found
-> END

~ bad
Guard: No.
-> start
""", 2),
        ("a fight on the fail branch is a way on", """~ start
* [Persuasion DC 12] Please. -> ok | bad
* Goodbye. -> END

~ ok
quest q found
-> END

~ bad
combat guards
""", 0),
        ("a choice between two endings is not a lock", """~ start
* [Persuasion DC 12] Please. -> ok | bad
* Goodbye. -> END

~ ok
quest q good
-> END

~ bad
quest q bad
-> END
""", 0),
        ("a check that moves nothing is fine", """~ start
* [Insight DC 12] Look at him. -> ok | bad
* Goodbye. -> END

~ ok
Narrator: He is lying.
-> start

~ bad
Narrator: He is a man.
-> start
""", 0),
    ]
    ending_cases = [
        ("a failed roll straight into a failure ending is flagged", """~ start
* [Athletics DC 12] Dive. -> ok | bad
* Goodbye. -> END

~ ok
quest q good
-> END

~ bad
quest q bad
-> END
""", 1),
        ("so is a `check` line, through a jump", """~ start
check Perception DC 12 -> ok | bad

~ ok
-> END

~ bad
-> lost

~ lost
quest q bad
-> END
""", 1),
        ("a menu between the roll and the ending is fine", """~ start
* [Persuasion DC 12] Please. -> ok | bad
* Goodbye. -> END

~ ok
quest q good
-> END

~ bad
Guard: No.
* Give up. -> giveup
* Try another way. -> start

~ giveup
quest q bad
-> END
""", 0),
        ("a fight on the fail branch ends the walk", """~ start
* [Intimidation DC 12] Glare. -> ok | bad
* Goodbye. -> END

~ ok
-> END

~ bad
combat guards
quest q bad
""", 0),
        ("a roll with no branch of its own for a failure makes none", """~ start
* [Persuasion DC 12] Plead. -> bad
* Goodbye. -> END

~ bad
quest q bad
-> END
""", 0),
        ("a success ending on the fail branch is not a failure", """~ start
* [Persuasion DC 12] Plead. -> ok | fine
* Goodbye. -> END

~ ok
-> END

~ fine
quest q good
-> END
""", 0),
        ("a main quest is left to its own tests", """~ start
* [Persuasion DC 12] Plead. -> ok | bad
* Goodbye. -> END

~ ok
-> END

~ bad
quest m bad
-> END
""", 0),
    ]
    errors = []
    for name, text, want in cases:
        nodes = _fixture(text)
        files, quests = {"x": nodes}, {"q": {"kind": "side", "ends": {"good": "success", "bad": "failure"}}}
        got = len(analyse(files, quests))
        if got != want:
            errors.append(f"{name}: expected {want} finding(s), got {got}")
    for name, text, want in ending_cases:
        nodes = _fixture(text)
        files = {"x": nodes}
        quests = {"q": {"kind": "side", "ends": {"good": "success", "bad": "failure"}},
                  "m": {"kind": "main", "ends": {"bad": "failure"}}}
        got = len(analyse_endings(files, quests))
        if got != want:
            errors.append(f"{name}: expected {want} finding(s), got {got}")
    return errors


def main():
    errors = findings(ROOT, use_allowed="--all" not in sys.argv)
    for e in errors:
        print("  FAIL ", e)
    print(f"{len(errors)} failed-roll lock(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
