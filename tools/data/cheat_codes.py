#!/usr/bin/env python3
"""Writes Cheat Codes.md in the vault: every playable item's cheat code, from the item data (`make cheat-codes`).

The codes are story/cheat_codes.gd's (the game's Cheat codes page): the first six hex digits of sha256("cheat:<id>"),
upper case. Two ids that share a code are settled in id order over every item file, playable or not: the first keeps
it, the next hashes "cheat:<id>#1" (then #2...). Only playable items are listed, since only they answer to a code. An
item built on a base (a +1 Weapon, a Spell Scroll) has one code, and the player picks the base in the game.

    python3 tools/data/cheat_codes.py [--out <path>] [--stdout]
"""
import argparse
import datetime
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = Path.home() / "Documents" / "Obsidian Vault" / "CurseOfStrahd" / "Cheat Codes.md"
FOLDERS = ["items", "magic_items"]
SALT = "cheat:"
LENGTH = 6
# tests/unit/test_cheat_codes.gd pins the same codes, so the game and this list can't drift apart.
PINNED = {"arrow": "359A02", "sunsword": "68D169", "weapon_plus_1": "3360D9"}
RARITIES = ["common", "uncommon", "rare", "very_rare", "legendary", "artifact"]
BASE_WORDS = {"weapon": "a weapon", "armor": "an armor", "shield": "a shield", "ammunition": "ammunition",
              "weapon_or_ammunition": "a weapon or ammunition", "spell": "a spell"}


def hash_code(item_id, n=0):
    key = SALT + item_id if n == 0 else f"{SALT}{item_id}#{n}"
    return hashlib.sha256(key.encode("utf-8")).hexdigest()[:LENGTH].upper()


def assign(ids):
    taken, out = set(), {}
    for item_id in sorted(ids):
        n = 0
        code = hash_code(item_id, n)
        while code in taken:
            n += 1
            code = hash_code(item_id, n)
        taken.add(code)
        out[item_id] = code
    return out


def load(folder):
    out = {}
    for f in sorted((ROOT / "data" / folder).glob("*.json")):
        d = json.loads(f.read_text())
        out[str(d.get("id", f.stem))] = d
    return out


def playable(d):
    return bool(d.get("playable", True))


def kind(d):
    return str(d.get("category", "item")).replace("_", " ").capitalize()


def pick_note(d):
    t = d.get("template")
    if t is None:
        return ""
    items = t.get("items", [])
    if len(items) == 1:
        return ""
    return f"pick {BASE_WORDS.get(t.get('on', 'weapon'), 'a base')}"


def esc(text):
    return str(text).replace("|", "\\|")


def render(items, magic, codes):
    gear = sorted((d for d in items.values() if playable(d)), key=lambda d: str(d.get("name", d["id"])))
    wonders = [d for d in magic.values() if playable(d)]
    lines = [
        "# Cheat Codes",
        "",
        f"Every item in the game and its code: {len(gear) + len(wonders)} items, {len(wonders)} of them magic. Rebuilt "
        f"from the game's item data by `make cheat-codes` on {datetime.date.today().isoformat()}; the next run "
        "rewrites this note, so don't edit it by hand.",
        "See also: [[Current State]]",
        "",
        "## How to use a code",
        "",
        "1. Press **Esc** for the pause menu and choose **Cheat codes**.",
        "2. Pick the hero to get the item (the one you have selected is picked already), type the code and press "
        "**Give** or Enter.",
        "3. A code works as many times as you like. Ammunition comes as a bundle (20 Arrows), and magic items arrive "
        "identified.",
        "4. A code marked *pick* is an item built on a base, like a +1 Weapon or a Spell Scroll: choose the weapon, "
        "armor or spell in the box before you give it.",
        "",
        "Codes never change when new items are added. Story items such as the Sunsword count as found for the story "
        "too, so giving them early can skip ahead.",
        "",
        "## Magic items",
    ]
    for rarity in RARITIES:
        group = sorted((d for d in wonders if str((d.get("magic") or {}).get("rarity", "")) == rarity),
                       key=lambda d: str(d.get("name", d["id"])))
        if not group:
            continue
        lines += ["", f"### {rarity.replace('_', ' ').capitalize()}", "", "| Item | Code | Kind | Pick |", "|---|---|---|---|"]
        for d in group:
            lines.append(f"| {esc(d.get('name', d['id']))} | `{codes[d['id']]}` | {kind(d)} | {pick_note(d)} |")
    other = sorted((d for d in wonders if str((d.get("magic") or {}).get("rarity", "")) not in RARITIES),
                   key=lambda d: str(d.get("name", d["id"])))
    if other:
        lines += ["", "### Other", "", "| Item | Code | Kind | Pick |", "|---|---|---|---|"]
        for d in other:
            lines.append(f"| {esc(d.get('name', d['id']))} | `{codes[d['id']]}` | {kind(d)} | {pick_note(d)} |")
    lines += ["", "## Gear, weapons and armor", "", "| Item | Code | Kind |", "|---|---|---|"]
    for d in gear:
        lines.append(f"| {esc(d.get('name', d['id']))} | `{codes[d['id']]}` | {kind(d)} |")
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", type=Path, default=OUT, help="where to write the note (default: the vault's Cheat Codes.md)")
    ap.add_argument("--stdout", action="store_true", help="print the note instead of writing it")
    args = ap.parse_args()
    items, magic = load("items"), load("magic_items")
    codes = assign(list(items) + list(magic))
    for item_id, code in PINNED.items():
        if codes.get(item_id) != code:
            raise SystemExit(f"cheat_codes.py: {item_id} came out {codes.get(item_id)}, not {code}: the game and this "
                             "tool no longer agree (story/cheat_codes.gd)")
    text = render(items, magic, codes)
    if args.stdout:
        print(text, end="")
        return
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(text)
    listed = sum(1 for d in list(items.values()) + list(magic.values()) if playable(d))
    print(f"Wrote {listed} cheat codes to {args.out}")


if __name__ == "__main__":
    main()
