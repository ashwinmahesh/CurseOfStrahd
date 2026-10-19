#!/usr/bin/env python3
"""Options that close a quest wear [ends:<quest>] (Side Quest Failure Plan, F4; owner, 2026-10-19). For make validate.

Rule 4 of the plan: no failure the player couldn't have seen coming. An option that sends a conversation to a line that
moves a side quest (or companion quest) to a *failure* ending carries `[ends:<quest>]` (or `[ends:<quest> if <condition>]`
where it only closes the quest in some states, e.g. `[ends:the_dancing_bear if flag.tser_pool_brawl_won]`); the dialogue
box then draws a broken seal on it and says "Ends <quest name>".

For every option the checker follows where it leads up to the next menu: through jumps and `check` lines, optimistic about
`if` guards (as story_reach.py and fail_routes.py are), and stopping at a node that shows options of its own. A roll takes
only its success branch: a failed roll never closes a quest (rule 5), and the few that still do are for fail_routes.py and
the packages that remove them. An option fails the check when

  * it reaches a failure ending of a non-main quest and doesn't carry that quest's tag, or
  * it carries a quest's tag and reaches none of that quest's endings. A walk-away that starts a `closes` rule of the
    quest (F1: data/quests/<id>.json "closes") may carry the tag by hand: the quest's data says why, so it's accepted.

Main-story quests are left alone (their endings are the story's own). ALLOWED lists options that reach a failure ending
without a tag on purpose, each with its reason.

findings(root) -> [error strings]; python3 tools/data/option_ends.py [--all] prints them (--all ignores ALLOWED).
selftest() -> [error strings]: a few made-up conversations the checker must judge right; validate runs it too.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fail_routes  # noqa: E402
import story_reach  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]

## "file key:node:line:quest.stage" -> why the option closes the quest without the mark. Empty when the plan's F4 landed.
ALLOWED: dict[str, str] = {}


def load(root: Path):
    """({file key: {node: [statement]}}, {quest id: {"kind", "ends": {stage: success/failure/""}, "closes": bool}})."""
    files, quests = fail_routes.load(root)
    for f in sorted((root / "data" / "quests").glob("*.json")):
        quests[f.stem]["closes"] = bool(json.loads(f.read_text()).get("closes"))
    return files, quests


def reach(files, quests, start):
    """The (quest, stage) endings a conversation reaches from (file key, node) before its next menu."""
    seen, found, todo = set(), set(), [start]
    while todo:
        cur = todo.pop()
        if cur in seen:
            continue
        seen.add(cur)
        for s in files[cur[0]][cur[1]]:
            if s["t"] == "quest" and quests.get(s["quest"], {}).get("ends", {}).get(s["stage"]):
                found.add((s["quest"], s["stage"]))
            elif s["t"] == "jump":
                # A `check` line takes its success branch (to[0]); a plain jump has the one target.
                for t in s["to"][:1] if s.get("is_check") else s["to"]:
                    nxt = fail_routes._resolve(files, cur[0], t)
                    if nxt:
                        todo.append(nxt)
    return found


def analyse(files, quests):
    """[(file key, node, line, message)] for each option whose mark is missing or has nothing to mark."""
    out = []
    for key, nodes in files.items():
        for node, sts in nodes.items():
            for st in sts:
                if st["t"] != "option":
                    continue
                # An option's own roll: its success branch is the choice (to[0]); the fail branch is a dice result.
                targets = st["to"][:1] if st.get("check") else st["to"]
                hit = set()
                for t in targets:
                    nxt = fail_routes._resolve(files, key, t)
                    if nxt:
                        hit |= reach(files, quests, nxt)
                tagged = set(st.get("ends", []))
                for quest, stage in sorted(hit):
                    q = quests[quest]
                    if q["kind"] == "main" or q["ends"][stage] != "failure" or quest in tagged:
                        continue
                    out.append((key, node, st["line"],
                                f"leads to {quest} {stage}, a failure ending, but has no [ends:{quest}] tag"))
                for quest in sorted(tagged):
                    q = quests.get(quest)
                    if q is None:
                        continue   # validate_data reports the unknown quest
                    if not any(qq == quest for qq, _ in hit) and not q["closes"]:
                        out.append((key, node, st["line"], f"carries [ends:{quest}] but doesn't lead to any ending of {quest}"))
    return out


def findings(root=ROOT, use_allowed=True):
    root = Path(root)
    files, quests = load(root)
    errors = [f"option_ends selftest: {e}" for e in selftest()]
    for key, node, line, msg in analyse(files, quests):
        ident = f"{key}:{node}:{line}"
        if use_allowed and any(k.startswith(ident + ":") for k in ALLOWED):
            continue
        errors.append(f"narrative/{key}.dialogue:{line}: the option in '{node}' {msg}; mark options that close a quest with"
                      f" [ends:<quest>] (docs/contracts/dialogue.md), or list it in tools/data/option_ends.py ALLOWED with the reason")
    return errors


def _check(text: str, quests: dict):
    """The analyse() findings for made-up dialogue text."""
    import tempfile
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "x.dialogue"
        p.write_text(text)
        return analyse({"x": story_reach.parse_dialogue(p)}, quests)


def selftest():
    """The checker judges a few made-up conversations right."""
    quests = {"q": {"kind": "side", "closes": False, "ends": {"open": "", "good": "success", "bad": "failure"}},
              "r": {"kind": "side", "closes": True, "ends": {"open": "", "bad": "failure"}},
              "m": {"kind": "main", "closes": False, "ends": {"open": "", "bad": "failure"}}}
    cases = [
        ("an unmarked option that reaches a failure is flagged", """~ start
* Do it. -> doit
* Goodbye. -> END

~ doit
quest q bad
-> END
""", 1),
        ("a marked option passes", """~ start
* [ends:q] Do it. -> doit

~ doit
quest q bad
-> END
""", 0),
        ("a condition on the tag is part of the tag", """~ start
* [ends:q if flag.a] Do it. -> doit

~ doit
quest q bad
-> END
""", 0),
        ("the mark is found through jumps", """~ start
* Do it. -> a

~ a
Guard: Fine.
-> b

~ b
quest q bad
-> END
""", 1),
        ("the walk stops at the next menu", """~ start
* Go on. -> menu2

~ menu2
Guard: Well?
* Do it. -> doit
* Goodbye. -> END

~ doit
quest q bad
-> END
""", 1),
        ("a failed roll is no choice, a passed one is", """~ start
* [Persuasion DC 10] Talk. -> good | bad
* Goodbye. -> END

~ good
quest q good
-> END

~ bad
quest q bad
-> END
""", 0),
        ("a roll whose success closes the quest needs the mark", """~ start
* [Persuasion DC 10] Talk. -> bad | good

~ good
quest q good
-> END

~ bad
quest q bad
-> END
""", 1),
        ("a quest ending in success needs no mark", """~ start
* Do it. -> doit

~ doit
quest q good
-> END
""", 0),
        ("a main quest's failure needs no mark", """~ start
* Do it. -> doit

~ doit
quest m bad
-> END
""", 0),
        ("a mark that leads nowhere is flagged", """~ start
* [ends:q] Do it. -> doit

~ doit
Guard: Nothing happens.
-> END
""", 1),
        ("a mark on a walk-away of a quest with closure rules is accepted", """~ start
* [ends:r] Leave. -> END
""", 0),
        ("one option can close two quests", """~ start
* [ends:q] Do it. -> doit

~ doit
quest q bad
quest r bad
-> END
""", 1),
    ]
    errors = []
    for name, text, want in cases:
        got = len(_check(text, quests))
        if got != want:
            errors.append(f"{name}: expected {want} finding(s), got {got}")
    return errors


def main():
    errors = findings(ROOT, use_allowed="--all" not in sys.argv)
    for e in errors:
        print("  FAIL ", e)
    print(f"{len(errors)} unmarked or misplaced [ends:] option(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
