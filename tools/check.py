#!/usr/bin/env python3
"""make check: the quick check for a branch. CLAUDE.md says when it is enough; make ci still runs before a merge.

Reads the files changed since the branch left main (committed, staged, unstaged and untracked) and runs only what
covers them:
  docs (*.md, docs/)                       nothing
  art and audio files, their pipelines     make import
  data/, narrative/                        make validate, test_data_integrity and the tests that quote a changed id
  scripts, scenes, shaders, art JSON       make validate, make lint when rules/, combat/ or story/ changed, and the
                                           tests that use a changed file directly or through one other script
                                           (a scene in between is free)
  the Makefile, project.godot, the test runner, anything not listed: make ci
Lint and tests skip the import (make check has already imported if anything changed since the last one).
make check [BASE=<branch>] [DRY=1]  (DRY prints the plan only). Stdlib only.
"""
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
CODE_EXT = {".gd", ".tscn", ".tres", ".gdshader"}
EVERYTHING = ("Makefile", "project.godot", "addons/", "tests/test_runner.", "tools/logcheck.sh", "tools/lint_gd.sh")
LINTED = ("rules/", "combat/", "story/")
MAX_COST = 2  # a test that uses the change (1) or uses a script that does (2); scenes and resources cost nothing


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
    if path.startswith("tools/") and ext == ".py":
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


def is_test(path: str) -> bool:
    return path.startswith(TEST_DIRS) and os.path.basename(path).startswith("test_") and path.endswith(".gd")


def plan(files: list[str], fork: str) -> dict:
    kinds = {p: kind(p) for p in files}
    out = {"validate": False, "lint": False, "import": False, "tests": [], "why": []}
    if any(k == "everything" for k in kinds.values()):
        out["tests"] = "all"
        out["why"] = [p for p, k in kinds.items() if k == "everything"]
        return out
    out["import"] = any(k == "asset" for k in kinds.values())
    out["validate"] = any(k in ("data", "code", "tool") for k in kinds.values())
    out["lint"] = any(p.endswith(".gd") and p.startswith(LINTED) for p in files)
    tests: set[str] = set()
    data = [p for p, k in kinds.items() if k == "data"]
    code = [p for p, k in kinds.items() if k == "code"]
    if data or code:
        index = Index()
        tests_all = [p for p in index.files if is_test(p)]
        if data:
            tests.update(p for p in tests_all if p.endswith("/test_data_integrity.gd"))
            for p in data:
                stem = os.path.splitext(os.path.basename(p))[0]
                quoted = re.compile(r'["/]%s["./]' % re.escape(stem))
                tests.update(t for t in tests_all if quoted.search(index.text[t]))
        # Cheapest way to reach each file from a change: a script costs 1, a scene or resource nothing.
        cost = {p: 0 for p in code}
        frontier = list(code)
        while frontier:
            nxt = []
            for p in frontier:
                for user in index.users(p, read(p, fork)):
                    c = cost[p] + (1 if user.endswith(".gd") else 0)
                    if c <= MAX_COST and c < cost.get(user, MAX_COST + 1):
                        cost[user] = c
                        nxt.append(user)
            frontier = nxt
        tests.update(p for p in cost if is_test(p))
    out["tests"] = sorted(os.path.basename(t) for t in tests if os.path.exists(os.path.join(ROOT, t)))
    return out


def main() -> int:
    sys.stdout.reconfigure(line_buffering=True)  # the plan prints before the make output it describes
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--base", default="main")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--files", nargs="*", help="check these paths instead of the branch's changes")
    a = ap.parse_args()
    if a.files is not None:
        fork, files = "HEAD", a.files
    else:
        fork, files = changed_files(a.base)
    if not files:
        print("make check: nothing changed since %s" % a.base)
        return 0
    p = plan(files, fork)
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
