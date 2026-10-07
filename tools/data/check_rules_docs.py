#!/usr/bin/env python3
"""Keeps docs/rules/coverage.md and docs/rules/deviations.md honest (P12). Part of make validate.

Fails on:
  - a deviations.md row whose Revisit is a plan phase that is already built;
  - a coverage.md row still waiting on a built phase ("[Phase 3]");
  - a coverage.md row marked "not started" or "data" that names a feature, feat, spell or item the data says the
    engine already reads (`implemented: engine`, which tools/data/check_implemented.py keeps true to the code).
A phase is built once its exit task (docs/tasks/P<n>-*.md, titled "Exit...") is in review or done. Point a row that
is still due at what will close it instead: an item in the Improvement Ideas note (F4, F10 ...) or "—" for none.
Stdlib only.
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PHASE = re.compile(r"\bPhase (\d+)\b")


def built_phase() -> int:
    """The last plan phase whose exit task is in review or done (every phase before it too)."""
    built = {}
    for path in glob.glob(os.path.join(ROOT, "docs", "tasks", "P*-*.md")):
        text = open(path, encoding="utf-8").read()
        head = text.split("---")[1] if text.startswith("---") else ""
        title = re.search(r"^title:\s*(.*)$", head, re.M)
        status = re.search(r"^status:\s*(\w+)", head, re.M)
        n = re.match(r"P(\d+)-", os.path.basename(path))
        if n and title and status and title.group(1).lower().startswith("exit"):
            built[int(n.group(1))] = status.group(1) in ("review", "done")
    last = -1
    for n in sorted(built):
        if not built[n]:
            break
        last = n
    return last


def table_rows(path: str) -> list[tuple[int, list[str]]]:
    """(line number, cells) for every table row below a header row."""
    rows = []
    for i, line in enumerate(open(path, encoding="utf-8").read().splitlines(), 1):
        if not line.startswith("|") or re.match(r"^\|[\s|:-]+\|$", line):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if cells and cells[0] in ("Rule", "Idea", ""):
            continue
        rows.append((i, cells))
    return rows


def engine_names() -> dict[str, str]:
    """Lower-case name -> data file, for everything the data marks `implemented: engine`."""
    out = {}

    def walk(node, path):
        if isinstance(node, dict):
            if isinstance(node.get("name"), str) and str(node.get("implemented", "")).startswith("engine"):
                out.setdefault(node["name"].lower(), path)
            for v in node.values():
                walk(v, path)
        elif isinstance(node, list):
            for v in node:
                walk(v, path)

    for path in glob.glob(os.path.join(ROOT, "data", "**", "*.json"), recursive=True):
        try:
            walk(json.load(open(path, encoding="utf-8")), os.path.relpath(path, ROOT))
        except (OSError, ValueError):
            pass
    return out


def names_in(rule: str) -> list[str]:
    """The names a coverage row lists: its parts split at commas, semicolons and colons, without "(Class 10)"."""
    plain = re.sub(r"\([^)]*\)", "", rule)
    return [p.strip(" .") for p in re.split(r"[,;:]| and ", plain) if p.strip(" .")]


def main() -> int:
    built = built_phase()
    problems = []
    dev = os.path.join(ROOT, "docs", "rules", "deviations.md")
    for line, cells in table_rows(dev):
        if len(cells) < 4:
            continue
        m = PHASE.search(cells[3])
        if m and int(m.group(1)) <= built:
            problems.append("deviations.md:%d %s: revisit at Phase %s, which is built" % (line, cells[0][:60], m.group(1)))
    cov = os.path.join(ROOT, "docs", "rules", "coverage.md")
    engine = engine_names()
    for line, cells in table_rows(cov):
        if len(cells) < 3:
            continue
        for m in re.finditer(r"\[Phase (\d+)\]", " ".join(cells[1:])):
            if int(m.group(1)) <= built:
                problems.append("coverage.md:%d %s: waits on Phase %s, which is built" % (line, cells[0][:60], m.group(1)))
        status = cells[2].lower()
        if status.startswith("not started") or status.startswith("data"):
            for name in names_in(cells[0]):
                if name.lower() in engine:
                    problems.append("coverage.md:%d %s is marked \"%s\", but %s says the engine reads it"
                                    % (line, name, cells[2][:30], engine[name.lower()]))
    print("rules docs: built through Phase %d, %d problem%s" % (built, len(problems), "" if len(problems) == 1 else "s"))
    for p in problems:
        print("  " + p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
