#!/usr/bin/env python3
"""make check: the check a lane hands off with; the build thread runs the full suite once per batch of hand-offs.

Reads the files changed since the branch left main (committed, staged, unstaged and untracked) and runs what covers
them:
  docs (*.md, docs/)                       nothing, but docs/rules/ and docs/tasks/ run make validate (rules docs)
  art and audio files, their pipelines     make import, and the tests that name the file, its folder or its art
                                           collection (art/sprites/, art/portraits/ ...)
  data/, narrative/                        make validate, test_data_integrity, the tests that quote a changed id and
                                           the tests that read the changed table ("spells", "locations" ...)
  tests/saves/ (golden saves)              test_golden_saves
  scripts, scenes, shaders, art JSON       make validate, make lint, test_scripts_compile (every script compiles, so a
                                           parse error anywhere fails however far its users are), and the tests up to
                                           DEPTH scripts away from the change: a test that uses it (1), uses a script
                                           that does (2), and so on; scenes and resources in between are free.
                                           Autoload scripts load in every run, so a change to one runs everything
  Makefile targets other than ci's         make -n of the targets the change reaches (a recipe or a variable they
                                           use); a change to import, validate, lint, test, ci or a variable they
                                           use runs make ci
  project.godot, the test runner, anything not listed: make ci
DEPTH is 1 by default: the tests that use what changed. Every script compiles whatever the depth, and what a change
breaks further away is the batch run's to catch. On the 40 merges before 2026-10-07 the median hand-off ran 48% of the
suite's test time at depth 1, 97% at depth 2 and all of it at 3: the playthrough tests and the spell sweep sit a few
scripts downstream of nearly everything. DEPTH=all follows every user.
Lint and tests skip the import (make check has already imported if anything changed since the last one).
make check [BASE=<branch>] [DEPTH=n|all] [DRY=1]  (DRY prints the plan only). Stdlib only.
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEST_DIRS = ("tests/unit/", "tests/integration/")
DOCS_EXT = {".md", ".txt", ".url", ".uid"}  # a .uid goes with its script, which is in the list too
DOCS = ("docs/", ".gitignore", "skills/")
ASSET_EXT = {".png", ".jpg", ".jpeg", ".webp", ".svg", ".ogg", ".wav", ".mp3", ".glb", ".gltf", ".blend", ".import",
             ".gpl", ".jsonl", ".gdignore", ".ttf", ".otf"}
ASSET_DIRS = ("blender/", "tools/art/", "tools/audio/", "tools/ui/", "art/generated/", "art/sourced/")
CODE_EXT = {".gd", ".tscn", ".tres", ".gdshader", ".gdshaderinc"}
EVERYTHING = ("Makefile", "project.godot", "addons/", "tests/test_runner.", "tools/run_tests.py", "tools/logcheck.sh",
              "tools/lint_gd.sh")
LINTED = ("rules/", "combat/", "story/")
GOLDEN = "tests/saves/"  # the golden saves: test_golden_saves loads them all (P4)
RULES_DOCS = ("docs/rules/", "docs/tasks/")  # make validate checks them against the plan and the data (P12)
DEPTH = 1  # how many scripts away a test may use a change from (see above); None follows every user
COMPILE_TEST = "tests/unit/test_scripts_compile.gd"
CI_TARGETS = {"import", "validate", "lint", "test", "ci", "check"}


def git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=True).stdout


def changed_files(base: str) -> tuple[str, list[str]]:
    fork = git("merge-base", "HEAD", base).strip()
    files = set(git("diff", "--name-only", "--no-renames", fork).split())
    files |= set(git("ls-files", "--others", "--exclude-standard").split())
    return fork, sorted(files)


def read(path: str, fork: str) -> str:
    """The file now, or as it was at the fork if the branch deleted it."""
    full = os.path.join(ROOT, path)
    if os.path.exists(full):
        with open(full, encoding="utf-8", errors="replace") as f:
            return f.read()
    try:
        return git("show", f"{fork}:{path}")
    except subprocess.CalledProcessError:
        return ""


def make_units(text: str) -> dict[str, str]:
    """Each Makefile target's prerequisites and recipe, and each variable's value ("$NAME"); comments dropped."""
    units: dict[str, str] = {}
    lines = text.splitlines()
    target = None
    i = 0
    while i < len(lines):
        line = lines[i]
        while line.endswith("\\") and i + 1 < len(lines):
            i += 1
            line = line[:-1] + " " + lines[i].strip()
        i += 1
        if line.startswith("\t"):
            if target:
                units[target] += line.strip() + "\n"
            continue
        target = None
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        var = re.match(r"^([\w.]+)\s*(?::=|\?=|\+=|=)\s*(.*)$", line)
        if var:
            units["$" + var.group(1)] = units.get("$" + var.group(1), "") + var.group(2) + "\n"
            continue
        rule = re.match(r"^([\w.-]+)[\w.\s-]*:(?!=)(.*)$", line)
        if rule and rule.group(1) != ".PHONY":
            target = rule.group(1)
            units[target] = rule.group(2).strip() + "\n"
    return units


def makefile_reach(old: str, new: str) -> tuple[bool, list[str]]:
    """(touches ci, targets to dry-run) for a Makefile edit."""
    a, b = make_units(old), make_units(new)
    changed = {k for k in set(a) | set(b) if a.get(k) != b.get(k)}

    def used_by(names: set[str], units: dict[str, str]) -> set[str]:
        """The names plus every variable and prerequisite they use, transitively."""
        seen, todo = set(), list(names)
        while todo:
            n = todo.pop()
            if n in seen or n not in units:
                seen.add(n)
                continue
            seen.add(n)
            todo += ["$" + v for v in re.findall(r"\$[({](\w+)", units[n])]
            if not n.startswith("$"):
                todo += units[n].splitlines()[0].split()
        return seen

    ci = used_by(CI_TARGETS, b) | used_by(CI_TARGETS, a) | {"$SHELL", "$.SHELLFLAGS"}
    if changed & ci:
        return True, sorted(changed & ci)
    reach = [t for t in b if not t.startswith("$") and used_by({t}, b) & changed]
    return False, sorted(reach)


def kind(path: str) -> str:
    ext = os.path.splitext(path)[1].lower()
    if path.startswith(EVERYTHING):
        return "everything"
    if ext in DOCS_EXT or path.startswith(DOCS):
        return "docs"
    if ext in ASSET_EXT or (path.startswith(ASSET_DIRS) and ext not in CODE_EXT):
        return "asset"
    if path.startswith(("data/", "narrative/")):
        return "data"
    if ext in CODE_EXT or (ext == ".json" and path.startswith(("art/", "audio/", "tests/", "tools/"))):
        return "code"
    if path.startswith("tools/") and ext in ("", ".py", ".m"):
        return "tool"
    return "everything"


class Index:
    """What every script, scene and shader outside art/ refers to: class names, autoloads, res:// paths, file names."""

    def __init__(self) -> None:
        listed = git("ls-files", "--cached", "--others", "--exclude-standard").split()
        self.files = [p for p in listed if os.path.splitext(p)[1] in CODE_EXT and not p.startswith("art/")
                      and os.path.exists(os.path.join(ROOT, p))]
        self.text: dict[str, str] = {}
        self.tokens: dict[str, set[str]] = {}
        for p in self.files:
            with open(os.path.join(ROOT, p), encoding="utf-8", errors="replace") as f:
                self.text[p] = f.read()
            self.tokens[p] = set(re.findall(r"[A-Za-z_]\w*", self.text[p]))
        self.autoloads: dict[str, str] = {}
        with open(os.path.join(ROOT, "project.godot"), encoding="utf-8") as f:
            for name, path in re.findall(r'^(\w+)="\*?res://([^"]+)"', f.read(), re.M):
                self.autoloads[path] = name

    def users(self, path: str, source: str) -> set[str]:
        """Files that refer to `path` (whose text is `source`)."""
        names = set(re.findall(r"^class_name\s+(\w+)", source, re.M)) if path.endswith(".gd") else set()
        if path in self.autoloads:
            names.add(self.autoloads[path])
        needle = "res://" + path
        base = os.path.basename(path) if path.startswith(("art/", "audio/")) else None
        found = set()
        for p in self.files:
            if p == path:
                continue
            if names & self.tokens[p] or needle in self.text[p] or (base and base in self.text[p]):
                found.add(p)
        return found

    def mentioning(self, needles: list[str], under: tuple[str, ...] = ("tests/",)) -> set[str]:
        """Files under `under` whose text contains any of `needles`."""
        return {p for p in self.files if p.startswith(under) and any(n in self.text[p] for n in needles)}


def is_test(path: str) -> bool:
    return path.startswith(TEST_DIRS) and os.path.basename(path).startswith("test_") and path.endswith(".gd")


def reach(index: Index, start: dict[str, int], fork: str, depth: int | None) -> set[str]:
    """Every file within `depth` scripts of the files in `start` (file -> its cost so far); scenes cost nothing."""
    cost = dict(start)
    frontier = list(start)
    while frontier:
        nxt = []
        for p in frontier:
            for user in index.users(p, read(p, fork)):
                c = cost[p] + (1 if user.endswith(".gd") else 0)
                if (depth is None or c <= depth) and c < cost.get(user, 1 << 30):
                    cost[user] = c
                    nxt.append(user)
        frontier = nxt
    return set(cost)


def plan(files: list[str], fork: str, depth: int | None = DEPTH) -> dict:
    kinds = {p: kind(p) for p in files}
    out = {"validate": False, "lint": False, "import": False, "tests": [], "why": [], "dry": []}
    if "Makefile" in kinds:
        try:
            old = git("show", f"{fork}:Makefile")
        except subprocess.CalledProcessError:
            old = ""
        touches_ci, names = makefile_reach(old, read("Makefile", fork))
        kinds["Makefile"] = "everything" if touches_ci else "makefile"
        if touches_ci:
            out["why"].append("Makefile (%s)" % ", ".join(names))
        out["dry"] = [] if touches_ci else names
    data = [p for p, k in kinds.items() if k == "data"]
    code = [p for p, k in kinds.items() if k == "code"]
    assets = [p for p, k in kinds.items() if k == "asset" and p.startswith(("art/", "audio/"))]
    index = Index() if data or code or assets else None
    if index is not None:
        for p in code:
            if p in index.autoloads:
                kinds[p] = "autoload"   # it loads in every run, before any test
    if any(k in ("everything", "autoload") for k in kinds.values()):
        out["tests"] = "all"
        out["why"] += [p if k == "everything" else "%s (the autoload %s)" % (p, index.autoloads[p])
                       for p, k in kinds.items() if k in ("everything", "autoload") and p != "Makefile"]
        return out
    out["import"] = any(k == "asset" for k in kinds.values())
    out["validate"] = any(k in ("data", "code", "tool") for k in kinds.values()) or any(p.startswith(RULES_DOCS) for p in files)
    out["lint"] = any(p.endswith(".gd") for p in files)
    tests: set[str] = set()
    if index is not None:
        tests_all = [p for p in index.files if is_test(p)]
        start: dict[str, int] = {p: 0 for p in code}
        if code:
            tests.add(COMPILE_TEST)
        if data:
            tests.update(p for p in tests_all if p.endswith("/test_data_integrity.gd"))
            for p in data:
                stem = os.path.splitext(os.path.basename(p))[0]
                quoted = re.compile(r'["/]%s["./:]' % re.escape(stem))
                tests.update(t for t in tests_all if quoted.search(index.text[t]))
                if p.startswith("data/"):
                    # A test (or a test's helper) that reads the whole table: Compendium.all("spells"), table("spells").
                    for helper in index.mentioning(['"%s"' % p.split("/")[1]]):
                        start.setdefault(helper, 1)
        for p in assets:
            # Tests that check art by its path, its folder or its collection (every sprite walks, every icon credited).
            parts = p.split("/")
            needles = ["res://" + p, os.path.basename(p), os.path.dirname(p) + "/", "/".join(parts[:2]) + "/"]
            for helper in index.mentioning(needles):
                start.setdefault(helper, 1)
        tests.update(p for p in reach(index, start, fork, depth) if is_test(p))
    if any(p.startswith(GOLDEN) for p in files):
        tests.add("tests/integration/test_golden_saves.gd")
    out["tests"] = sorted(os.path.basename(t) for t in tests if os.path.exists(os.path.join(ROOT, t)))
    return out


def main() -> int:
    sys.stdout.reconfigure(line_buffering=True)  # the plan prints before the make output it describes
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--base", default="main")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--files", nargs="*", help="check these paths instead of the branch's changes")
    ap.add_argument("--depth", default=str(DEPTH), help="how many scripts away a test may use a change from, or all")
    a = ap.parse_args()
    depth = None if a.depth == "all" else int(a.depth)
    if a.files is not None:
        fork, files = "HEAD", a.files
    else:
        fork, files = changed_files(a.base)
    if not files:
        print("make check: nothing changed since %s" % a.base)
        return 0
    p = plan(files, fork, depth)
    print("make check: %d changed file%s since %s" % (len(files), "" if len(files) == 1 else "s", a.base))
    steps: list[list[str]] = []
    if p["tests"] == "all":
        print("  everything (%s): make ci" % ", ".join(p["why"][:5]))
        steps.append(["ci"])
    else:
        if p["import"]:
            steps.append(["import"])
        if p["validate"]:
            steps.append(["validate"])
        if p["lint"]:
            steps.append(["-o", "import", "lint"])
        if p["tests"]:
            steps.append(["-o", "import", "test", "FILES=" + ",".join(p["tests"])])
        if p["dry"]:
            steps.append(["-n", *p["dry"]])
        print("  tests: %s" % (", ".join(p["tests"]) if p["tests"] else "none"))
        print("  runs: %s" % (" · ".join("make " + " ".join(s) for s in steps) if steps else "nothing (docs only)"))
    if a.dry_run:
        return 0
    for s in steps:
        if subprocess.run(["make", *s], cwd=ROOT).returncode != 0:
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
