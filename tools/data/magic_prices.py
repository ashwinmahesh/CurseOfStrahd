#!/usr/bin/env python3
"""Magic item prices from Sane Magical Prices (Ashwin, 2026-10-14; data/treasure/magic_prices.json), each held inside
its rarity's band around the 2024 DMG's value (Ashwin, 2026-10-17; the table's `bands`).

    python3 tools/data/magic_prices.py           # check: every priced item's cost_gp is what the table makes it
    python3 tools/data/magic_prices.py --apply   # write those prices into the item files (make magic-prices)

The table says how each item's price follows from the guide (its `_note`); this works the numbers out and keeps each
item file's `cost_gp` line in place, so nothing else in the file moves. tests/unit/test_magic_shops.gd checks the same.
"""
import json
import re
import statistics
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TABLE = ROOT / "data" / "treasure" / "magic_prices.json"
FOLDERS = [ROOT / "data" / "magic_items", ROOT / "data" / "items"]
## The 2024 DMG's price by rarity (MagicItems.PRICE; consumables half), for `rule: book`.
BOOK = {"common": 100, "uncommon": 400, "rare": 4000, "very_rare": 40000, "legendary": 200000}


def is_consumable(item):
    if "consumable" in item:
        return bool(item["consumable"])
    return item.get("category") in ("potion", "scroll")


def medians(guide):
    groups = {}
    for row in guide.values():
        groups.setdefault((row["rarity"], row["list"] == "consumable"), []).append(row["gp"])
    return {k: statistics.median(v) for k, v in groups.items()}


def price(item, how, guide, med):
    """The gp the table gives `item` (its data) by `how` (its entry)."""
    if "gp" in how:
        return how["gp"]
    if "guide" in how or "like" in how:
        names = how.get("guide", how.get("like"))
        names = names if isinstance(names, list) else [names]
        return sum(guide[n]["gp"] for n in names) * how.get("times", 1)
    rarity = item.get("magic", {}).get("rarity", "")
    if how.get("rule") == "book":
        return BOOK[rarity] / (2 if is_consumable(item) else 1)
    if how.get("rule") == "median":
        return med[(rarity, is_consumable(item))]
    raise ValueError(f"{item['id']}: no way to price {how}")


def band_price(item, gp, table):
    """`gp` held inside the band for the item's rarity (`bands`; half for a consumable, ammunition by the stack)."""
    band = table["bands"].get(item.get("magic", {}).get("rarity", ""))
    if band is None:
        return gp
    ammo = item.get("category") == "ammunition"
    share = (0.5 if is_consumable(item) or ammo else 1) / (table["ammunition_stack"] if ammo else 1)
    return min(max(gp, band[0] * share), band[1] * share)


def table_price(item, how, table, med):
    """The item's price: a 2024 book's own price if it prints one, else the guide's (price) held in its band."""
    names = how.get("guide")
    if isinstance(names, str) and names in table["book"] and how.get("times", 1) == 1:
        return table["book"][names]
    return band_price(item, price(item, how, table["guide"], med), table)


def tidy(gp):
    return int(gp) if float(gp).is_integer() else round(float(gp), 2)


def run(apply=False):
    """[errors], number of files written."""
    table = json.loads(TABLE.read_text())
    guide, med = table["guide"], medians(table["guide"])
    errors, changed = [], 0
    files = {f.stem: f for folder in FOLDERS for f in folder.glob("*.json")}
    for id_, how in table["items"].items():
        if id_ not in files:
            errors.append(f"{id_}: no such item")
            continue
        f = files[id_]
        text = f.read_text()
        item = json.loads(text)
        want = tidy(table_price(item, how, table, med))
        if float(item.get("cost_gp", -1)) == float(want):
            continue
        if not apply:
            errors.append(f"{f.relative_to(ROOT)}: cost_gp {item.get('cost_gp')}, the guide makes it {want}")
            continue
        new, n = re.subn(r'("cost_gp": )[0-9.]+', lambda m: m.group(1) + json.dumps(want), text, count=1)
        if n != 1:
            errors.append(f"{f.relative_to(ROOT)}: no cost_gp line to write")
            continue
        f.write_text(new)
        changed += 1
    for id_ in table["excluded"]:
        if id_ not in files:
            errors.append(f"excluded {id_}: no such item")
    return errors, changed


def findings():
    """For validate_data.py: what's out of step with the table."""
    return [f"magic prices: {e}" for e in run()[0]]


def main():
    errors, changed = run("--apply" in sys.argv)
    for e in errors:
        print("  FAIL ", e)
    print(f"{len(json.loads(TABLE.read_text())['items'])} priced items, {changed} written, {len(errors)} errors")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
