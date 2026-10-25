#!/usr/bin/env python3
"""Builds the content of the private core repo DndCoreEngine from this game (docs/plans/engine_split.md).

Until the game switches to the submodule (addons/dnd_core, one planned full-download release), the game keeps its own
copies and the core is a mirror this script writes from tools/core/manifest.json: the engine code, the shareable data
(entries of the books; this campaign's own CoS/custom entries stay here), the schemas and the test framework.

    python3 tools/core/extract.py                      what would move: counts and the leaks (dry run)
    python3 tools/core/extract.py --leaks              every reference from a moving file to a file that stays
    python3 tools/core/extract.py --write [DEST]       write the files into DEST (default ~/Documents/DndCoreEngine),
                                                       deleting files there that are no longer in the set (not .git)
    python3 tools/core/extract.py --list               every path that moves

A "leak" is a moving script naming a class (or autoload) or res:// script that stays in the game: each one is a
dependency the core cannot build without, to be moved, hooked (story/campaign_module.gd) or left to the game.
"""
import fnmatch
import json
import re
import shutil
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = json.loads((ROOT / "tools" / "core" / "manifest.json").read_text())
SKIP_DIRS = {".git", ".godot", "captures", "builds", "node_modules"}


def glob_match(path, pattern):
    # ** crosses folders, * does not
    rx = re.escape(pattern).replace(r"\*\*", ".*").replace(r"\*", "[^/]*")
    return re.fullmatch(rx, path) is not None


def all_files():
    out = []
    for p in ROOT.rglob("*"):
        if p.is_file() and not (set(p.relative_to(ROOT).parts) & SKIP_DIRS):
            out.append(p.relative_to(ROOT).as_posix())
    return sorted(out)


def code_text(path):
    """A script's code with comments and string contents blanked (res:// paths are collected apart)."""
    src = (ROOT / path).read_text(errors="replace")
    paths = re.findall(r'res://[\w/.\-]+\.gd', src)
    out = []
    for line in src.split("\n"):
        buf, quote, i = [], None, 0
        while i < len(line):
            c = line[i]
            if quote:
                if c == "\\":
                    i += 2
                    continue
                if c == quote:
                    quote = None
                buf.append(" ")
            elif c in "\"'":
                quote = c
                buf.append(" ")
            elif c == "#":
                break
            else:
                buf.append(c)
            i += 1
        out.append("".join(buf))
    return "\n".join(out), paths


def class_names():
    names = {}
    for f in all_files():
        if f.endswith(".gd") and not f.startswith(("addons/", "captures/")):
            m = re.search(r"^class_name\s+(\w+)", (ROOT / f).read_text(errors="replace"), re.M)
            if m:
                names[m.group(1)] = f
    for m in re.finditer(r'^(\w+)="\*?res://([^"]+)"', (ROOT / "project.godot").read_text(), re.M):
        names.setdefault(m.group(1), m.group(2))   # autoloads
    return names


def data_entries(folder):
    """(moving, staying) file lists of one data folder, by each entry's source book."""
    moving, staying = [], []
    for f in sorted((ROOT / "data" / folder).glob("*.json")):
        book = json.loads(f.read_text()).get("source", {}).get("book", "")
        (staying if book in MANIFEST["data_leave_in_game_books"] else moving).append(f.relative_to(ROOT).as_posix())
    return moving, staying


def hits(path, names):
    n = 0
    for line in (ROOT / path).read_text(errors="replace").split("\n"):
        s = line.strip()
        if s and not s.startswith("#") and any(w in s.lower() for w in names):
            n += 1
    return n


def selection():
    files = all_files()
    code = {f for f in files if any(glob_match(f, p) for p in MANIFEST["include"])
            and not any(glob_match(f, p) for p in MANIFEST["exclude"])}
    for f in list(code):
        if f.endswith(".gd") and (ROOT / (f + ".uid")).exists():
            code.add(f + ".uid")
    data, left = [], []
    for folder in MANIFEST["data_folders"]:
        m, s = data_entries(folder)
        data += m
        left += s
    return sorted(code), data, left


def leaks_of(moving_gd, moving_set, names):
    """{moving file: sorted [(what it names, where that lives)]} for everything that stays in the game."""
    found = defaultdict(set)
    pattern = re.compile(r"\b(" + "|".join(sorted(names, key=len, reverse=True)) + r")\b")
    for f in moving_gd:
        text, paths = code_text(f)
        for name in set(pattern.findall(text)):
            if names[name] not in moving_set and names[name] != f:
                found[f].add((name, names[name]))
        for p in paths:
            rel = p[len("res://"):]
            if rel not in moving_set and rel != f:
                found[f].add((p, rel))
    return found


def unit_tests(code_set, names):
    """The unit tests and test helpers that name no campaign id and need nothing that stays; shrinks until it settles."""
    candidates = [f for f in all_files() if re.fullmatch(r"tests/(unit/test_|support/)[\w]+\.gd", f)
                  and hits(f, MANIFEST["campaign_names"]) == 0]
    chosen = set(candidates)
    while True:
        moving = code_set | chosen | {f + ".uid" for f in chosen}
        drop = {f for f in chosen if f in leaks_of([f], moving, names)}
        if not drop:
            return sorted(chosen)
        chosen -= drop


def main():
    names = class_names()
    code, data, left = selection()
    code_set = set(code)
    moving_gd = [f for f in code if f.endswith(".gd")]
    tests = unit_tests(code_set, names)
    tests_all = tests + [t + ".uid" for t in tests if (ROOT / (t + ".uid")).exists()]
    moving = sorted(code_set | set(data) | set(tests_all))
    leaks = leaks_of(moving_gd + tests, set(moving), names)
    if "--list" in sys.argv:
        print("\n".join(moving))
        return
    if "--leaks" in sys.argv:
        for f in sorted(leaks):
            print(f)
            for name, where in sorted(leaks[f]):
                print(f"    {name}  ({where})")
        return
    ucount = len([t for t in tests if t.startswith("tests/unit/")])
    by = defaultdict(int)
    for f in moving:
        by[f.split("/")[0] if not f.startswith("data/") else "/".join(f.split("/")[:2])] += 1
    print(f"{len(moving)} files move to the core: " + ", ".join(f"{k} {v}" for k, v in sorted(by.items())))
    print(f"  {len(data)} data entries move, {len(left)} (CoS/custom) stay in the game; {ucount} unit tests and {len(tests) - ucount} test helpers move "
          f"(of {len(list((ROOT / 'tests' / 'unit').glob('test_*.gd')))})")
    ext = defaultdict(set)
    for f, items in leaks.items():
        for name, where in items:
            ext[(name, where)].add(f)
    print(f"  {len(leaks)} moving scripts still name {len(ext)} things that stay in the game (--leaks lists them)")
    if "--write" in sys.argv:
        i = sys.argv.index("--write")
        dest = Path(sys.argv[i + 1] if len(sys.argv) > i + 1 and not sys.argv[i + 1].startswith("-") else "~/Documents/DndCoreEngine").expanduser()
        if not dest.is_dir():
            sys.exit(f"{dest} isn't a folder (clone the core repo there first)")
        keep = set(moving)
        for p in list(dest.rglob("*")):
            rel = p.relative_to(dest).as_posix()
            if p.is_file() and not rel.startswith((".git/", "README")) and rel not in keep and rel != ".gitignore":
                p.unlink()
        for rel in moving:
            (dest / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / rel, dest / rel)
        print(f"written to {dest}")


if __name__ == "__main__":
    main()
