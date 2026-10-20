#!/usr/bin/env python3
"""Validates every data/<type>/*.json against data/schemas/<type>.schema.json.

Stdlib only (no jsonschema install needed). Supports the subset of JSON Schema the project uses:
type, enum, const, required, properties, additionalProperties (bool or schema), items, minItems,
maxItems, minimum, maximum, minLength, pattern, anyOf, $ref (local '#/...' and sibling 'file.json#/...').
Also checks that every file's `id` matches its filename and is unique. Exit 1 on any error.
"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import dialogue_lint  # noqa: E402
import fail_routes  # noqa: E402
import magic_prices  # noqa: E402
import option_ends  # noqa: E402
import quest_strands  # noqa: E402
import story_reach  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SCHEMAS = ROOT / "data" / "schemas"

# Data folder -> schema name. Folders not listed have no schema yet and are skipped.
FOLDERS = {
    "classes": "class", "subclasses": "subclass", "species": "species",
    "backgrounds": "background", "feats": "feat", "spells": "spell",
    "items": "item", "magic_items": "item", "monsters": "monster", "conditions": "condition", "pregens": "pregen",
    "encounters": "encounter", "locations": "location", "npcs": "npc", "quests": "quest",
    "tarokka": {"cards": "tarokka_cards", "outcomes": "tarokka_outcomes"}, "travel": "travel",
    "random_encounters": "random_table", "dark_gifts": "dark_gift",
    "endings": "ending",
    "cutscenes": "cutscene",
    "strahd": {"visits": "strahd_visits", "attention": "strahd_attention"},
    "visits": "ally_visits",
    "schedule": "schedule",
    "objects": {"kinds": "object_kinds"},
    "weather": "weather",
    "camp": {"night_visitors": "night_visitors"},
    "progression": {"xp": "xp"},
    "achievements": "achievements",
}

TYPES = {
    "object": dict, "array": list, "string": str, "boolean": bool, "null": type(None),
}

_schema_cache = {}


def load_schema(name):
    if name not in _schema_cache:
        _schema_cache[name] = json.loads((SCHEMAS / name).read_text())
    return _schema_cache[name]


def resolve(ref, base):
    file_part, _, pointer = ref.partition("#")
    file_name = file_part or base
    node = load_schema(file_name)
    for part in [p for p in pointer.split("/") if p]:
        node = node[part]
    return node, file_name


def type_ok(value, t):
    if t == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if t == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    return isinstance(value, TYPES[t])


def validate(value, schema, base, path, errors):
    if "$ref" in schema:
        target, target_base = resolve(schema["$ref"], base)
        validate(value, target, target_base, path, errors)
        return
    if "anyOf" in schema:
        for option in schema["anyOf"]:
            trial = []
            validate(value, option, base, path, trial)
            if not trial:
                break
        else:
            errors.append(f"{path}: {value!r} matches none of the allowed forms")
            return
    if "type" in schema:
        types = schema["type"] if isinstance(schema["type"], list) else [schema["type"]]
        if not any(type_ok(value, t) for t in types):
            errors.append(f"{path}: expected {schema['type']}, got {type(value).__name__}")
            return
    if "enum" in schema and value not in schema["enum"]:
        errors.append(f"{path}: {value!r} not one of {schema['enum']}")
    if "const" in schema and value != schema["const"]:
        errors.append(f"{path}: expected {schema['const']!r}")
    if isinstance(value, str):
        if "minLength" in schema and len(value) < schema["minLength"]:
            errors.append(f"{path}: shorter than {schema['minLength']}")
        if "pattern" in schema and not re.search(schema["pattern"], value):
            errors.append(f"{path}: {value!r} does not match {schema['pattern']}")
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if "minimum" in schema and value < schema["minimum"]:
            errors.append(f"{path}: {value} < {schema['minimum']}")
        if "maximum" in schema and value > schema["maximum"]:
            errors.append(f"{path}: {value} > {schema['maximum']}")
    if isinstance(value, list):
        if "minItems" in schema and len(value) < schema["minItems"]:
            errors.append(f"{path}: fewer than {schema['minItems']} items")
        if "maxItems" in schema and len(value) > schema["maxItems"]:
            errors.append(f"{path}: more than {schema['maxItems']} items")
        if "items" in schema:
            for i, item in enumerate(value):
                validate(item, schema["items"], base, f"{path}[{i}]", errors)
    if isinstance(value, dict):
        for key in schema.get("required", []):
            if key not in value:
                errors.append(f"{path}: missing required '{key}'")
        props = schema.get("properties", {})
        extra = schema.get("additionalProperties")
        for key, sub in value.items():
            if key in props:
                validate(sub, props[key], base, f"{path}.{key}", errors)
            elif extra is False:
                errors.append(f"{path}: unexpected property '{key}'")
            elif isinstance(extra, dict):
                validate(sub, extra, base, f"{path}.{key}", errors)


# Content beyond this character level may reference data that later phases add (level 4+ spells).
PHASE_MAX_LEVEL = 11


def load_all():
    data = {}
    for folder in FOLDERS:
        data[folder] = {}
        for f in sorted((ROOT / "data" / folder).glob("*.json")):
            try:
                d = json.loads(f.read_text())
            except json.JSONDecodeError:
                continue
            if isinstance(d, dict) and "id" in d:
                data[folder][d["id"]] = d
    return data


def walk_features(features, level=0):
    """Yields (feature, level) for features and their inline options."""
    for f in features or []:
        yield f, level
        for c in [f.get("choice")] + list(f.get("choices", [])):
            if c and c.get("options"):
                yield from walk_features(c["options"], level)


def semantic_checks(data):
    """Cross-file checks: every id one file names must exist in its folder. Returns (errors, pending)."""
    errors, pending = [], []
    items, feats, spells = data["items"], data["feats"], data["spells"]
    skills = set(json.loads((SCHEMAS / "common.schema.json").read_text())["$defs"]["skill"]["enum"])

    def need(kind, table, ident, where, level=0):
        if ident in table or (kind == "item" and ident in data.get("magic_items", {})):
            return
        if kind == "item" and "__" in ident:
            # A magic item template on a base (ADR 0012): "<template>__<base>", e.g. spell_scroll__bless.
            tid, _, base = ident.partition("__")
            tpl = data.get("magic_items", {}).get(tid, {}).get("template")
            if tpl is not None and base in (data["spells"] if tpl.get("on") == "spell" else items):
                return
        if kind == "spell" and level > PHASE_MAX_LEVEL:
            pending.append(f"{where}: spell '{ident}' (level {level} content, added in a later phase)")
        else:
            errors.append(f"{where}: unknown {kind} '{ident}'")

    def check_features(features, where, level=0):
        for f, lv in walk_features(features, level):
            at = max(lv, f.get("at_level", 0))
            for m in f.get("modifiers", []):
                if m.get("stat") == "spell" and not str(m.get("value", "")).startswith("@"):
                    need("spell", spells, m["value"], f"{where} {f['id']}",
                         max(at, m.get("at_level", 0), m.get("at_class_level", 0)))
            for c in [f.get("choice")] + list(f.get("choices", [])):
                if not c:
                    continue
                if c.get("kind") == "skill":
                    for sk in c.get("from", []):
                        if sk not in skills and sk not in items:
                            errors.append(f"{where} {f['id']}: unknown skill '{sk}'")

    for cid, c in data["classes"].items():
        for opt in c.get("starting_equipment", []):
            for it in opt.get("items", []):
                need("item", items, it["id"], f"classes/{cid} equipment")
        for lvl in c["levels"]:
            check_features(lvl["features"], f"classes/{cid} level {lvl['level']}", lvl["level"])
        for sk in c["skill_choices"].get("from", []):
            if sk not in skills:
                errors.append(f"classes/{cid}: unknown skill '{sk}'")
        if c.get("spellcasting") and not any(c["spellcasting"]["list"] in s["classes"] for s in spells.values()):
            errors.append(f"classes/{cid}: no spells on the {c['spellcasting']['list']} list")
    for sid, sc in data["subclasses"].items():
        if sc["class"] not in data["classes"]:
            errors.append(f"subclasses/{sid}: unknown class '{sc['class']}'")
        for lv, ids in sc.get("always_prepared", {}).items():
            for sp in ids:
                need("spell", spells, sp, f"subclasses/{sid} always prepared at {lv}", int(lv))
        for entry in sc["features"]:
            check_features([entry["feature"]], f"subclasses/{sid} level {entry['level']}", entry["level"])
    for bid, b in data["backgrounds"].items():
        need("feat", feats, b["feat"], f"backgrounds/{bid}")
        need("item", items, b["tool"]["id"], f"backgrounds/{bid} tool")
        for opt in b["equipment"]:
            for it in opt.get("items", []):
                need("item", items, it["id"], f"backgrounds/{bid} equipment")
    for spid, sp in data["species"].items():
        check_features(sp["traits"], f"species/{spid}")
        for lin in sp.get("lineages", []):
            check_features(lin.get("traits", []), f"species/{spid} {lin['id']}")
    for fid, f in feats.items():
        check_features(f.get("benefits", []) + ([f["drawback"]] if "drawback" in f else []), f"feats/{fid}")
    for iid, it in items.items():
        for c in it.get("contents", []):
            need("item", items, c["id"], f"items/{iid} contents")
    for mid, m in data["monsters"].items():
        ids = {a["id"] for key in ("actions", "bonus_actions", "reactions") for a in m.get(key, [])}
        for a in m.get("actions", []):
            for ma in a.get("multiattack", []):
                if ma["action"] not in ids:
                    errors.append(f"monsters/{mid}: multiattack names unknown action '{ma['action']}'")
            sm = a.get("summon", {})
            for ch in sm.get("choices", []) if isinstance(sm, dict) else []:
                if ch.get("monster") not in data["monsters"]:
                    errors.append(f"monsters/{mid}: {a['id']} summons unknown monster '{ch.get('monster')}'")
        la = m.get("legendary_actions", {})
        for opt in la.get("options", []) if isinstance(la, dict) else []:
            if "action" in opt and opt["action"] not in ids:
                errors.append(f"monsters/{mid}: legendary action '{opt['id']}' names unknown action '{opt['action']}'")
        sc = m.get("spellcasting", {})
        for sp in sc.get("at_will", []) + [x for v in sc.get("per_day", {}).values() for x in v]:
            if sp not in spells:
                pending.append(f"monsters/{mid}: spell '{sp}' (not in Phase 1 spell data)")
    # A found spellbook lists the spells a Wizard can copy out of it (Character.copy_spell).
    for iid, it in items.items():
        for sp in it.get("spells", []):
            if sp not in spells:
                errors.append(f"items/{iid}: spellbook spell '{sp}' isn't in data/spells")
    # Encounters: who's in it exists, everyone stands on open floor inside the map, nobody overlaps, and the
    # difficulty matches the 2024 DMG XP budget for the party.
    # The budgets are data/progression/xp.json's (the same table XP levelling reads); the arena encounters stop at level 5.
    xp_rows = data.get("progression", {}).get("xp", {}).get("budgets", [])
    budget = {i + 1: tuple(row) for i, row in enumerate(xp_rows[:5])}
    sizes = {"tiny": 1, "small": 1, "medium": 1, "large": 2, "huge": 3, "gargantuan": 4}
    for eid, enc in data["encounters"].items():
        rows = enc["map"]["rows"]
        taken = {}

        def place(cell, size, who):
            x, z = cell
            for dz in range(size):
                for dx in range(size):
                    cx, cz = x + dx, z + dz
                    if cz >= len(rows) or cx >= len(rows[cz]) or rows[cz][cx] not in ".~1234_":
                        errors.append(f"encounters/{eid}: {who} at {cell} isn't on open floor")
                        return
                    if (cx, cz) in taken:
                        errors.append(f"encounters/{eid}: {who} overlaps {taken[(cx, cz)]}")
                    taken[(cx, cz)] = who
        for p in enc["party"]:
            if p["pregen"] not in data["pregens"]:
                errors.append(f"encounters/{eid}: unknown pregen '{p['pregen']}'")
            for sp in p.get("precast", []):
                need("spell", spells, sp, f"encounters/{eid} precast")
            place(p["cell"], 1, p["pregen"])
        xp = 0
        for m in enc["enemies"]:
            mon = data["monsters"].get(m["monster"])
            if mon is None:
                errors.append(f"encounters/{eid}: unknown monster '{m['monster']}'")
                continue
            xp += mon.get("xp", 0)
            place(m["cell"], sizes.get(mon["size"], 1), m["monster"])
        level = enc["party_level"]
        if "difficulty" in enc and level in budget:
            low, mod, high = (b * len(enc["party"]) for b in budget[level])
            band = "high" if xp >= high else ("moderate" if xp >= mod else "low")
            if band != enc["difficulty"]:
                errors.append(f"encounters/{eid}: {xp} XP is a {band} encounter for {len(enc['party'])} level {level} characters, not {enc['difficulty']}")
    story_checks(data, errors, need)
    object_checks(data, errors)
    camp_checks(data, errors)
    achievement_checks(data, errors)
    xp_checks(data, errors)
    waiting_checks(data, errors)
    pending.extend(pending_list)
    pending_list.clear()
    campaign_checks(data, errors, pending)
    return errors, pending


# The fights that wait in plain view (F7) from before every one of them said which way it faces: their foes face the middle
# of their group (docs/contracts/locations.md). Every fight made `waiting` since (overworld stealth, docs/design/
# overworld_stealth.md) gives each foe in view a `facing`, so its sight cone points where the room's design wants it.
LEGACY_WAITING = {"frozen_watch", "cat_sleepers", "cauldron_coven", "ghakis_keepers", "wachter_cellar_cult",
                  "tower_night_visitors", "night_streets_dead", "den_guards", "cellar_dig"}


def waiting_checks(data, errors):
    """A fight that waits in plain view: every variant of its id waits, each has a foe in view (not `unseen`: a fight of
    unseen foes only can't be slipped past), and every foe in view has a `facing`."""
    for lid, loc in data["locations"].items():
        variants = {}
        for en in loc.get("encounters", []):
            variants.setdefault(en["id"], []).append(en)
        for eid, entries in variants.items():
            if eid in LEGACY_WAITING or not any(e.get("waiting") for e in entries):
                continue
            where = f"locations/{lid}: encounter {eid}"
            if not all(e.get("waiting") for e in entries):
                errors.append(f"{where}: some variants wait in plain view and some don't (a variant is picked by its `when`, "
                              "so every variant of the id must say `waiting`)")
            for i, e in enumerate(entries):
                if not e.get("waiting"):
                    continue
                in_view = [m for m in e["monsters"] if not m.get("unseen")]
                if not in_view:
                    errors.append(f"{where} (variant {i}): every foe is `unseen`: nothing to see before the fight, nothing to slip past")
                for m in in_view:
                    if "facing" not in m:
                        errors.append(f"{where} (variant {i}): {m['monster']} at {m['cell']} has no `facing` (or `unseen`)")


def xp_checks(data, errors):
    """Experience-point levelling (data/progression/xp.json, docs/plans/xp_mode.md): the tables run in order, every quest
    and monster it names exists, every award the game asks for is there, and a milestone quest does end in success."""
    xp = data.get("progression", {}).get("xp")
    if not xp:
        return
    w = "progression/xp.json"
    th = xp["thresholds"]
    if th[0] != 0 or any(b <= a for a, b in zip(th, th[1:])):
        errors.append(f"{w}: thresholds must start at 0 and rise")
    for i, (lo, mo, hi) in enumerate(xp["budgets"]):
        if not lo < mo < hi:
            errors.append(f"{w}: the level {i + 1} budget should run Low < Moderate < High")
    if len(xp["budgets"]) < 11:
        errors.append(f"{w}: budgets must reach the level cap (11)")
    for kind in ("milestone", "main_quest", "side_quest", "place", "location", "find", "check", "trap_noticed", "trap_disarmed", "lore",
                 "strahd_withdraws"):
        if kind not in xp["awards"]:
            errors.append(f"{w}: no award for '{kind}'")
    for mon, award in xp["withdraw_pays"].items():
        if mon not in data["monsters"]:
            errors.append(f"{w}: withdraw_pays names unknown monster '{mon}'")
        if award not in xp["awards"]:
            errors.append(f"{w}: withdraw_pays names unknown award '{award}'")
    for key in ("milestone_quests", "no_xp_quests"):
        for qid in xp[key]:
            q = data["quests"].get(qid)
            if q is None:
                errors.append(f"{w}: {key} names unknown quest '{qid}'")
            elif key == "milestone_quests" and not any(s.get("ends") == "success" for s in q["stages"]):
                errors.append(f"{w}: milestone quest '{qid}' has no stage that ends in success")


def camp_checks(data, errors):
    """The camp's night visitors (data/camp/night_visitors.json, F16): every monster exists, and every land a region
    or a setting (town, indoors) has, and the default, has a group for every party level from 1 to the level cap."""
    nv = data.get("camp", {}).get("night_visitors")
    if not nv:
        return
    w = "camp/night_visitors.json"
    groups = nv.get("groups", [])
    for g in groups:
        for m in g.get("monsters", []):
            if m not in data["monsters"]:
                errors.append(f"{w} {g['id']}: unknown monster '{m}'")
        lo, hi = g["levels"]
        if lo > hi:
            errors.append(f"{w} {g['id']}: levels {lo} to {hi} run backwards")
    for land in sorted(set(nv.get("lands", {}).values()) | set(nv.get("settings", {}).values()) | {nv.get("default_land")}):
        for level in range(1, 12):
            n = sum(1 for g in groups if g["land"] == land and g["levels"][0] <= level <= g["levels"][1])
            if n == 0:
                errors.append(f"{w}: nothing comes for a level {level} camp in the {land}")


def achievement_checks(data, errors):
    """Hidden achievements (data/achievements/<package>.json, core/achievements.gd, docs/story/eggs.md): an id is unique
    across the files, the sixteen in Achievements.LIST and the endings' own (ending_<id>), a name is unique among them
    and the endings' titles, and a `when` condition (docs/contracts/dialogue.md) has balanced parentheses and quotes.
    The flags a `when` reads are checked with the rest, in story_checks."""
    listed = {m[0]: m[1] for m in re.findall(r'^\t"([a-z_0-9]+)": \["([^"]+)", "[^"]+"\]', (ROOT / "core" / "achievements.gd").read_text(), re.M)}
    names = {name: f"Achievements.LIST {aid}" for aid, name in listed.items()}
    for end in data.get("endings", {}).values():
        names.setdefault(str(end.get("title", "")), f"ending {end['id']}")
    ids = {}
    for pid, f in sorted(data.get("achievements", {}).items()):
        for a in f.get("achievements", []):
            w = f"data/achievements/{pid}.json {a['id']}"
            if a["id"] in listed or a["id"].startswith("ending_"):
                errors.append(f"{w}: id clashes with a listed achievement or an ending's own")
            if a["id"] in ids:
                errors.append(f"{w}: id also in {ids[a['id']]}")
            ids[a["id"]] = f"data/achievements/{pid}.json"
            if a["name"] in names:
                errors.append(f"{w}: name '{a['name']}' is already {names[a['name']]}")
            names[a["name"]] = w
            when = a.get("when", "")
            if "when" in a and not when.strip():
                errors.append(f"{w}: an empty `when` (leave it out to earn the achievement in code)")
            if when.count("(") != when.count(")") or when.count('"') % 2:
                errors.append(f"{w}: `when` has unbalanced parentheses or quotes: {when}")


def object_checks(data, errors):
    """data/objects/kinds.json (F5): every kind it names exists, and each kind's numbers come from its tables."""
    ok = data.get("objects", {}).get("kinds")
    if not ok:
        return
    kinds, w = ok["kinds"], "data/objects/kinds.json"
    named = [("default_kind", ok["default_kind"]), ("doors.default", ok["doors"]["default"])]
    named += [(f"themes.{t}", k) for t, k in ok["themes"].items()]
    named += [(f"doors.rules[{i}]", r["kind"]) for i, r in enumerate(ok["doors"]["rules"])]
    for where, kid in named:
        if kid not in kinds:
            errors.append(f"{w}: {where} names unknown kind '{kid}'")
    seen = {}
    for kid, k in kinds.items():
        if "ac" not in k and k.get("substance") not in ok["substances"]:
            errors.append(f"{w}: kind {kid} needs an ac or a substance from substances")
        if "hp" not in k and (k.get("size") not in ok["hit_points"] or k.get("resilience") not in ("fragile", "resilient")):
            errors.append(f"{w}: kind {kid} needs hp, or a size from hit_points and a resilience")
        if k.get("hangs") and "fall" not in k:
            errors.append(f"{w}: kind {kid} hangs but has no fall")
        if k.get("moves") and "move_dc" not in k:
            errors.append(f"{w}: kind {kid} can be moved but has no move_dc")
        if k.get("moves") == "topple" and "topple" not in k:
            errors.append(f"{w}: kind {kid} topples but says nothing of how it falls (topple)")
        if k.get("throwable") and k.get("size") not in ("tiny", "small"):
            errors.append(f"{w}: kind {kid} is throwable but bigger than Small")
        for art in k.get("art", []):
            if art in seen:
                errors.append(f"{w}: art '{art}' is both {seen[art]} and {kid}")
            seen[art] = kid
    for mid, m in data["monsters"].items():
        for a in m.get("actions", []) + m.get("bonus_actions", []):
            for rd in a.get("on_fail", []) + a.get("on_hit", []):
                if rd.get("object") and rd["object"] not in kinds:
                    errors.append(f"monsters/{mid}: {a['id']} holds its target with unknown object kind '{rd['object']}'")


# Regions later phases build (plan §6). References into them are pending, not errors.
LATER_REGIONS: set = set()  # every region is built (the castle in Phase 6, ADR 0014)


def campaign_checks(data, errors, pending):
    """The Tarokka, travel maps, random encounter tables, shops and guests (ADR 0010)."""
    locations, npcs, monsters, items = data["locations"], data["npcs"], data["monsters"], data["items"]

    spot_places = {pl for loc in locations.values() for pl in loc.get("treasure_spots", {})}
    final_rooms = {en["final_battle"] for loc in locations.values() for en in loc.get("encounters", [])
                   if en.get("final_battle")} | {"castle_ravenloft"}  # mists: he roams the enemy rooms

    def place_ok(ref, region, where, kind="place"):
        loc = ref.split(":")[0]
        if loc in locations or ref in spot_places or (kind == "room" and ref in final_rooms):
            return
        if region in LATER_REGIONS or any(loc.startswith(r) for r in LATER_REGIONS):
            pending.append(f"{where}: {kind} '{ref}' (region {region}, a later phase)")
        else:
            errors.append(f"{where}: unknown {kind} '{ref}'")

    tk = data.get("tarokka", {})
    cards = {c["id"]: c for c in tk.get("cards", {}).get("cards", [])}
    if cards:
        high = {i for i, c in cards.items() if c["deck"] == "high"}
        common = {i for i, c in cards.items() if c["deck"] == "common"}
        if len(high) != 14 or len(common) != 40:
            errors.append(f"data/tarokka/cards.json: expected 14 high and 40 common cards, got {len(high)} and {len(common)}")
        out = tk.get("outcomes")
        if out is None:
            errors.append("data/tarokka/outcomes.json: missing")
        else:
            for slot, deck in (("tome", common), ("symbol", common), ("sword", common), ("ally", high), ("enemy", high)):
                table = out.get(slot, {})
                for cid in deck - set(table):
                    errors.append(f"data/tarokka/outcomes.json: {slot} has no outcome for card '{cid}'")
                for cid, o in table.items():
                    w = f"data/tarokka/outcomes.json {slot}.{cid}"
                    if cid not in deck:
                        errors.append(f"{w}: not a {'high' if deck is high else 'common'} card")
                    if slot in ("tome", "symbol", "sword"):
                        place_ok(o["place"], o["region"], w)
                    elif slot == "ally":
                        if o["npc"] == "":
                            continue  # a card that names no ally (the Darklord)
                        if o["npc"] not in npcs:
                            (pending if o["region"] in LATER_REGIONS else errors).append(f"{w}: npc '{o['npc']}'" + (" (a later phase)" if o["region"] in LATER_REGIONS else " unknown"))
                    else:
                        place_ok(o["room"], "castle_ravenloft", w, "room")
    def grounds_ok(grounds, home, w):
        """A table's or a road's battle grounds (story/road_grounds.gd): outdoor maps with a road on, and foe spots on
        every one but the table's own map (whose fights' cells are written for it)."""
        for g in grounds:
            loc = locations.get(g)
            if loc is None:
                errors.append(f"{w}: unknown battle ground '{g}'")
                continue
            if not loc["map"].get("outdoors"):
                errors.append(f"{w}: battle ground '{g}' isn't outdoors")
            if not any(ex.get("to") == "travel" for ex in loc.get("exits", [])):
                errors.append(f"{w}: battle ground '{g}' has no road on (an exit to travel)")
            if g != home and len(loc.get("foe_spots", [])) < MIN_FOE_SPOTS:
                errors.append(f"{w}: battle ground '{g}' needs at least {MIN_FOE_SPOTS} foe_spots for other tables' fights")

    for lid, loc in locations.items():
        spots = loc.get("foe_spots", [])
        rows = loc["map"]["rows"]
        sx, sz = loc.get("spawns", {}).get("default", [0, 0])
        reach = _floor_reach(rows, (sx, sz)) if spots else set()
        exit_cells = {tuple(ex["cell"]) for ex in loc.get("exits", [])}
        seen = set()
        for x, z in spots:
            w = f"data/locations/{lid}.json: foe spot [{x}, {z}]"
            if not (0 <= z < len(rows) and 0 <= x < len(rows[z]) and rows[z][x] in OPEN_FLOOR):
                errors.append(f"{w} isn't open floor")
            elif (x, z) not in reach:
                errors.append(f"{w} can't be walked to from the default spawn")
            if max(abs(x - sx), abs(z - sz)) < 3:
                errors.append(f"{w} is in the party's way (within 2 squares of the default spawn)")
            if (x, z) in exit_cells or (x, z) in seen:
                errors.append(f"{w} is an exit or listed twice")
            seen.add((x, z))

    tables = data.get("random_encounters", {})
    for tid, t in tables.items():
        w = f"random_encounters/{tid}"
        if t["map"] not in locations:
            errors.append(f"{w}: unknown map location '{t['map']}'")
        grounds_ok(t.get("grounds", []), t["map"], w)
        for e in t["entries"]:
            if not e.get("monsters") and not e.get("dialogue"):
                errors.append(f"{w}: an entry needs monsters or a dialogue")
            rows = locations.get(t["map"], {}).get("map", {}).get("rows", [])
            for m in e.get("monsters", []):
                if m["monster"] not in monsters:
                    errors.append(f"{w}: unknown monster '{m['monster']}'")
                x, z = m["cell"]
                if rows and not (0 <= z < len(rows) and 0 <= x < len(rows[z]) and rows[z][x] in ".~1234_"):
                    errors.append(f"{w}: {m['monster']} at {m['cell']} isn't on open floor of {t['map']}")
    # Every travel file is part of one map (ADR 0011): roads may join places from any file; place ids are unique.
    all_places = {}
    for mid, tm in data.get("travel", {}).items():
        for p in tm["places"]:
            if p["id"] in all_places:
                errors.append(f"travel/{mid}: place '{p['id']}' is already in travel/{all_places[p['id']]}")
            all_places[p["id"]] = mid
    for mid, tm in data.get("travel", {}).items():
        w = f"travel/{mid}"
        ids = set(all_places)
        for p in tm["places"]:
            place_ok(p["location"], p["region"], f"{w} place {p['id']}", "location")
        for r in tm["roads"]:
            for end in (r["from"], r["to"]):
                if end not in ids:
                    errors.append(f"{w} road {r['id']}: unknown place '{end}'")
            if r.get("table") and r["table"] not in tables:
                errors.append(f"{w} road {r['id']}: unknown random encounter table '{r['table']}'")
            if r.get("grounds"):
                if not r.get("table"):
                    errors.append(f"{w} road {r['id']}: battle grounds but no random encounter table")
                grounds_ok(r["grounds"], tables.get(r.get("table", ""), {}).get("map", ""), f"{w} road {r['id']}")

    def item_known(iid):
        # A template item on a base ("spell_scroll__daylight", "weapon_plus_1__longsword") needs both halves.
        t, _, base = iid.partition("__")
        return iid in items or iid in data.get("magic_items", {}) or bool(
            base and t in data.get("magic_items", {}) and (base in items or base in data.get("spells", {})))

    for nid, n in npcs.items():
        for e in n.get("shop", {}).get("sells", []):
            if not item_known(e["id"]):
                errors.append(f"npcs/{nid}: shop sells unknown item '{e['id']}'")
        rot = n.get("shop", {}).get("rotating", {})
        for iid in rot.get("pool", []) + [i for g in rot.get("groups", []) for i in g.get("pool", [])]:
            if not item_known(iid):
                errors.append(f"npcs/{nid}: shop's rotating pool has unknown item '{iid}'")
        if "guest_fights" in n and not n.get("guest"):
            errors.append(f"npcs/{nid}: guest_fights only means something on a guest (guest: true)")
        gb = n.get("guest_build", {})
        if gb.get("monster") and gb["monster"] not in monsters:
            errors.append(f"npcs/{nid}: guest_build monster '{gb['monster']}' unknown")
        if gb.get("pregen") and gb["pregen"] not in data["pregens"]:
            errors.append(f"npcs/{nid}: guest_build pregen '{gb['pregen']}' unknown")


OPEN_FLOOR = ".~1234_"
# A road battle ground's foe spots (story/road_grounds.gd): enough for most fights (the rest take open ground).
MIN_FOE_SPOTS = 8


def _floor_reach(rows, start):
    """Open-floor squares reachable from `start` in 8 directions (an NPC's walking route)."""
    seen = {start}
    todo = [start]
    while todo:
        x, z = todo.pop()
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                n = (x + dx, z + dz)
                if n in seen or n[1] < 0 or n[1] >= len(rows) or n[0] < 0 or n[0] >= len(rows[n[1]]):
                    continue
                if rows[n[1]][n[0]] in OPEN_FLOOR:
                    seen.add(n)
                    todo.append(n)
    return seen
pending_list = []


def treasure_checks(data, parsed, errors, pending):
    """Treasure spots, `tarokka give`, allies and dark gifts (ADR 0011)."""
    out = data.get("tarokka", {}).get("outcomes", {})
    places = {}
    for slot in ("tome", "symbol", "sword"):
        for cid, o in out.get(slot, {}).items():
            places[o["place"]] = o["region"]
    spot_of = {}
    for lid, loc in data["locations"].items():
        w = f"locations/{lid}"
        cts = {c["id"] for c in loc.get("containers", [])}
        encs = {e["id"] for e in loc.get("encounters", [])}
        for place, spot in loc.get("treasure_spots", {}).items():
            if place not in places:
                errors.append(f"{w}: treasure spot '{place}' isn't a place in data/tarokka/outcomes.json")
            if place in spot_of:
                errors.append(f"{w}: treasure spot '{place}' is already in locations/{spot_of[place]}")
            spot_of[place] = lid
            if "container" in spot and spot["container"] not in cts:
                errors.append(f"{w}: treasure spot '{place}': no container '{spot['container']}' here")
            if "encounter" in spot and spot["encounter"] not in encs:
                errors.append(f"{w}: treasure spot '{place}': no encounter '{spot['encounter']}' here")
            if "dialogue" in spot:
                fkey, _, node = spot["dialogue"].rpartition(":")
                if fkey not in parsed or node not in parsed[fkey]["nodes"]:
                    errors.append(f"{w}: treasure spot '{place}': no dialogue node '{spot['dialogue']}'")
                elif not any(pl == place for pl, _ in parsed[fkey].get("tarokka_give", [])):
                    errors.append(f"{w}: treasure spot '{place}': {fkey} never says `tarokka give {place}`")
    gives = {}
    for key, p in parsed.items():
        for place, where in p.get("tarokka_give", []):
            gives.setdefault(place, []).append(where)
            if place not in places:
                errors.append(f"narrative/{where}: tarokka give '{place}' isn't a Tarokka place")
        for gid, where in p.get("dark_gifts", []):
            if gid not in data.get("dark_gifts", {}):
                errors.append(f"narrative/{where}: unknown dark gift '{gid}'")
    for place, region in sorted(places.items()):
        if place in spot_of:
            continue
        msg = f"data/tarokka/outcomes.json: place '{place}' (region {region}) has no treasure spot in any location"
        (pending if region in LATER_REGIONS else errors).append(msg)
    joins = set()
    for f in (ROOT / "narrative").rglob("*.dialogue"):
        for line in f.read_text().splitlines():
            t = line.strip()
            if t.startswith("join "):
                joins.add(t.split()[1])
    for cid, o in out.get("ally", {}).items():
        npc = o.get("npc", "")
        if npc == "":
            continue
        n = data["npcs"].get(npc)
        later = o["region"] in LATER_REGIONS
        if n is None:
            continue  # reported by campaign_checks
        if not n.get("guest") or not (n.get("guest_build") or n.get("monster")):
            (pending if later else errors).append(f"npcs/{npc}: the {cid} card's ally needs guest: true and a guest_build (or monster)")
        if n.get("guest_fights") is False:
            errors.append(f"npcs/{npc}: the {cid} card's ally sees the end through beside the party, so guest_fights can't be false")
        if npc not in joins:
            (pending if later else errors).append(f"data/tarokka/outcomes.json ally.{cid}: no conversation says `join {npc}`")


def castle_checks(data, parsed, errors, cond, flags_set, dialogue_refs):
    """Final battles, endings and Strahd's visits (ADR 0014)."""
    out = data.get("tarokka", {}).get("outcomes", {})
    rooms = {o["room"] for o in out.get("enemy", {}).values()} - {"castle_ravenloft"}
    finals = {}
    for lid, loc in data["locations"].items():
        for en in loc.get("encounters", []):
            room = en.get("final_battle")
            w = f"locations/{lid}: encounter {en['id']}"
            if en.get("withdraw"):
                if en["withdraw"].get("flag"):
                    flags_set.setdefault(en["withdraw"]["flag"], []).append(f"locations/{lid}")
                if en["withdraw"].get("who") not in {m["monster"] for m in en["monsters"]}:
                    errors.append(f"{w}: withdraw names '{en['withdraw'].get('who')}', who isn't in the fight")
            if not room:
                continue
            # Variants of one encounter (the same id, picked by their `when`: the Sunsword's line-up and the plain one) are one battle.
            if w not in finals.setdefault(room, []):
                finals[room].append(w)
            if room not in rooms:
                errors.append(f"{w}: final_battle '{room}' isn't an enemy room in data/tarokka/outcomes.json")
            if not en.get("lair"):
                errors.append(f"{w}: a final battle needs lair: true")
            if "strahd_von_zarovich" not in {m["monster"] for m in en["monsters"]}:
                errors.append(f"{w}: a final battle needs Strahd (strahd_von_zarovich)")
    for room in sorted(rooms):
        n = len(finals.get(room, []))
        if n != 1:
            errors.append(f"data/tarokka/outcomes.json: enemy room '{room}' has {n} final battle encounters (needs exactly 1)"
                          + (f": {', '.join(finals[room])}" if n else ""))

    endings = data.get("endings", {})
    if len(endings) < 3:
        errors.append(f"data/endings: {len(endings)} endings (the Phase 6 exit needs at least 3)")
    for eid, e in endings.items():
        w = f"endings/{eid}"
        cond(e.get("when", ""), w)
        dialogue_refs.append((e["narration"], w))
        for i, sl in enumerate(e.get("epilogue", [])):
            cond(sl.get("when", ""), f"{w} epilogue {i}")

    locations, monsters = data["locations"], data["monsters"]
    for src, v in visits_to_check(data):
        w = f"{src} {v['id']}"
        cond(v.get("when", ""), w)
        if v.get("dialogue"):
            dialogue_refs.append((v["dialogue"], w))
        # The visit's own first step (a fight or a ride of its own), then what follows its conversation.
        for step in [v] + list(v.get("then", [])):
            cond(step.get("when", ""), w)
            enc = step.get("encounter")
            if enc:
                ids = {m["monster"] for m in enc.get("monsters", [])}
                for mid in ids - set(monsters):
                    errors.append(f"{w}: unknown monster '{mid}'")
                wd = enc.get("withdraw")
                if wd:
                    if wd.get("who") not in ids:
                        errors.append(f"{w}: withdraw names '{wd.get('who')}', who isn't in the fight")
                    if wd.get("flag"):
                        flags_set.setdefault(wd["flag"], []).append(w)
                if enc.get("flag"):
                    flags_set.setdefault(enc["flag"], []).append(w)
                if enc.get("after"):
                    dialogue_refs.append((enc["after"], w))
            if step.get("go"):
                lid, _, spawn = step["go"].partition(":")
                if lid not in locations:
                    errors.append(f"{w}: go to unknown location '{lid}'")
                elif spawn and spawn not in locations[lid].get("spawns", {}):
                    errors.append(f"{w}: {lid} has no spawn '{spawn}'")
            if step.get("dialogue") and step is not v:
                dialogue_refs.append((step["dialogue"], w))
    ally_visit_checks(data, errors)


def visits_to_check(data):
    """Every visit with the file it is in: Strahd's (data/strahd/visits.json), then each character's (data/visits/)."""
    for v in data.get("strahd", {}).get("visits", {}).get("visits", []):
        yield "strahd/visits.json", v
    for npc, f in sorted(data.get("visits", {}).items()):
        for v in f.get("visits", []):
            yield f"visits/{npc}.json", v


def ally_visit_checks(data, errors):
    """Ally visits (data/visits/<npc>.json, story/strahd_presence.gd): the file is a character's, every visit's id is its own
    (the game remembers visits by id, Strahd's included), each plays a conversation and is limited (or it would come at
    every event), and the places it names exist."""
    seen = {v["id"]: "strahd/visits.json" for v in data.get("strahd", {}).get("visits", {}).get("visits", [])}
    for npc, f in sorted(data.get("visits", {}).items()):
        if npc not in data["npcs"]:
            errors.append(f"visits/{npc}.json: no NPC '{npc}' in data/npcs (a file is named for its character)")
        for v in f.get("visits", []):
            w = f"visits/{npc}.json {v['id']}"
            if v["id"] in seen:
                errors.append(f"{w}: this id is already {seen[v['id']]}'s (visits are remembered by id, across all files)")
            seen[v["id"]] = f"visits/{npc}.json"
            if not v.get("dialogue"):
                errors.append(f"{w}: an ally visit plays a conversation (`dialogue`)")
            if not (v.get("once") or v.get("max") or v.get("cooldown_hours")):
                errors.append(f"{w}: needs `once`, `max` or `cooldown_hours`, or it comes at every event")
            for lid in v["trigger"].get("at", []):
                if lid not in data["locations"]:
                    errors.append(f"{w}: trigger names unknown location '{lid}'")


def schedule_checks(data, errors, cond, flags_set, dialogue_refs):
    """Things that happen on a day and an hour (story/schedule.gd, F2): their conditions and places, the
    conversations they start and the flags they set."""
    ids = set()
    for sid, sch in data.get("schedule", {}).items():
        for e in sch.get("events", []):
            w = f"schedule/{sid}.json {e['id']}"
            if e["id"] in ids:
                errors.append(f"{w}: another schedule event has this id")
            ids.add(e["id"])
            cond(e.get("when", ""), w)
            if e.get("location") and e["location"] not in data["locations"]:
                errors.append(f"{w}: unknown location '{e['location']}'")
            if e.get("dialogue"):
                dialogue_refs.append((e["dialogue"], w))
            for fid in e.get("set", {}):
                flags_set.setdefault(fid, []).append(w)


def cutscene_checks(data, parsed, errors):
    """Story cutscenes (story/cutscenes.gd, docs/ui/cutscenes.md): every picture is in art/cutscenes, every trigger is a
    Narrator key some narrator file has (`read:<magic item>` names an item and has its first caption), every `then` names a
    scene with a `caption` Narrator key some file has, every `more` caption is a Narrator key too, and every
    `cutscene <id>` in a conversation names one (or is `end`)."""
    narrator_keys = {n for key, p in parsed.items() if key.startswith("narrator/") for n in p["nodes"]}
    for cid, c in data.get("cutscenes", {}).items():
        w = f"data/cutscenes/{cid}.json"
        for take in c["images"]:
            if not (ROOT / "art" / "cutscenes" / f"{take['image']}.jpg").exists():
                errors.append(f"{w}: no picture art/cutscenes/{take['image']}.jpg")
        trig = c.get("trigger", "")
        if trig.startswith("find:"):
            if trig[5:] not in data.get("magic_items", {}):
                errors.append(f"{w}: trigger '{trig}' names no magic item")
        elif trig.startswith("read:"):
            if trig[5:] not in data.get("magic_items", {}):
                errors.append(f"{w}: trigger '{trig}' names no magic item")
            if trig not in narrator_keys:
                errors.append(f"{w}: trigger '{trig}' isn't a node in any narrative/narrator file (its first caption)")
        elif trig and trig not in narrator_keys:
            errors.append(f"{w}: trigger '{trig}' isn't a node in any narrative/narrator file")
        nxt = c.get("then", "")
        if nxt:
            if nxt not in data.get("cutscenes", {}):
                errors.append(f"{w}: then '{nxt}' isn't a cutscene")
            elif not data["cutscenes"][nxt].get("caption"):
                errors.append(f"{w}: then '{nxt}' has no `caption` Narrator key to read over its picture")
        cap = c.get("caption", "")
        if cap and cap not in narrator_keys:
            errors.append(f"{w}: caption '{cap}' isn't a node in any narrative/narrator file")
        for more in c.get("more", []):
            if more not in narrator_keys:
                errors.append(f"{w}: more '{more}' isn't a node in any narrative/narrator file")
        if cap and trig:
            errors.append(f"{w}: a scene with a `caption` follows another (`then`) and has no trigger of its own")
    for key, p in parsed.items():
        for cid, where in p["cutscenes"]:
            if cid != "end" and cid not in data.get("cutscenes", {}):
                errors.append(f"narrative/{where}: cutscene '{cid}' isn't in data/cutscenes")


def approval_checks(data, p, errors):
    """Companion approval and Heroic Inspiration in one parsed dialogue file (story/approval.gd, story/in_character.gd):
    `approve` and `approval.<id>` name roster companions, and a condition compares with a tier or a number."""
    companions = {pid for pid, pg in data["pregens"].items() if pg.get("roster", True)}
    tiers = set(re.findall(r'"id": "([a-z_]+)", "name"', (ROOT / "story" / "approval.gd").read_text()))
    for cid, delta, where in p.get("approvals", []):
        if cid not in companions:
            errors.append(f"narrative/{where}: approve: '{cid}' isn't one of the six companions ({', '.join(sorted(companions))})")
        if delta == 0 or abs(delta) > 20:
            errors.append(f"narrative/{where}: approve: a change of {delta:+d} (use -20 to +20, never 0)")
    for cid, rhs, where in p.get("approval_terms", []):
        if cid not in companions:
            errors.append(f"narrative/{where}: approval.{cid}: not one of the six companions")
        if rhs and rhs not in tiers and not re.fullmatch(r"[+-]?\d+", rhs):
            errors.append(f"narrative/{where}: approval.{cid}: compare with a tier ({', '.join(sorted(tiers))}) or a number, not '{rhs}'")
    for sel, where in p.get("inspires", []):
        if sel == "party":
            continue
        kind = sel.split(":", 1)[0]
        if kind not in ("name", "class", "species", "background", "tag", "knows"):
            errors.append(f"narrative/{where}: inspire {sel}: use name:, class:, species:, background:, tag: or knows:")
        elif kind == "name" and sel.split(":", 1)[1] not in data["pregens"]:
            errors.append(f"narrative/{where}: inspire {sel}: no pregen called that")


def move_checks(locations, p, errors):
    """`move <location>[:<spawn>]` in one parsed dialogue file (story/dialogue_runner.gd, docs/contracts/dialogue.md): the
    party goes to a real map location, to a spawn that map has ("default" when none is named)."""
    for loc_id, spawn, where in p.get("moves", []):
        if loc_id not in locations:
            errors.append(f"narrative/{where}: move: '{loc_id}' isn't a location (data/locations/{loc_id}.json)")
        elif spawn not in locations[loc_id].get("spawns", {}):
            errors.append(f"narrative/{where}: move: {loc_id} has no spawn '{spawn}'")


def world_check_checks(loc, w, data, need, cond, flags_set, check_lines, errors, on_floor):
    """Skill checks on things (story/world_checks.gd, docs/story/world_checks.md): unique ids, real items, a codex entry
    whole, things revealed, disarmed, unlocked and opened that exist, a square to move to that's open floor, and side flags
    only (registered in data/flags/world_checks.json, so a check never moves the main story). Each result needs words:
    a Narrator line or its own text (checked once the dialogue files are read)."""
    locations = data["locations"]
    ids = set()
    things = {k: {t["id"]: t for t in loc.get(k, [])} for k in ("props", "doors", "containers", "traps")}
    for key in ("props", "doors", "containers"):
        for t in loc.get(key, []):
            for c in t.get("checks", []):
                where = f"{w} {key[:-1]} {t['id']} check {c['id']}"
                if c["id"] in ids:
                    errors.append(f"{where}: check id used twice in this location")
                ids.add(c["id"])
                cond(c.get("when", ""), w)
                for result in ("success", "failure"):
                    out = c.get(result)
                    if out is None:
                        continue
                    check_lines.append((f"check:{c['skill']}:{c['id']}:{result}", bool(out.get("text")) or result == "failure", where))
                    for it in out.get("items", []):
                        need("item", data["items"], it["id"], where)
                    if out.get("flag"):
                        flags_set.setdefault(out["flag"], []).append(w)
                        check_lines.append(("flag:" + out["flag"], True, where))
                    for ref in out.get("reveal", []):
                        if ":" in ref:
                            lid, _, pid = ref.partition(":")
                            other = locations.get(lid)
                            if other is None or not any(p["id"] == pid and p["kind"] == "search" for p in other.get("props", [])):
                                errors.append(f"{where}: reveals '{ref}', which isn't a hiding place (search prop) there")
                        elif not (things["props"].get(ref, {}).get("kind") == "search" or things["doors"].get(ref, {}).get("secret_dc")
                                  or ref in things["traps"]):
                            errors.append(f"{where}: reveals '{ref}', which isn't a hiding place, secret door or trap here")
                    for tr in out.get("disarm", []):
                        if tr not in things["traps"]:
                            errors.append(f"{where}: disarms unknown trap '{tr}'")
                    for u in out.get("unlock", []):
                        if u not in things["doors"] and u not in things["containers"]:
                            errors.append(f"{where}: unlocks unknown door or chest '{u}'")
                    for o in out.get("open", []):
                        if o not in things["doors"]:
                            errors.append(f"{where}: opens unknown door '{o}'")
                    if "move" in out:
                        on_floor(out["move"], f"{where} move")
                    codex = out.get("codex")
                    if codex and result != "success":
                        errors.append(f"{where}: only a success adds to the codex")


def story_checks(data, errors, need):
    """Locations, NPCs, quests, the flag registry and every .dialogue file (ADR 0008, ADR 0009)."""
    flags = {}
    engine_flags = {}   # flags the game itself sets from code ("set_by": "engine" in the registry), e.g. Achievements.note_fight
    for f in sorted((ROOT / "data" / "flags").glob("*.json")) if (ROOT / "data" / "flags").exists() else []:
        try:
            reg = json.loads(f.read_text())
        except json.JSONDecodeError as e:
            errors.append(f"data/flags/{f.name}: invalid JSON: {e}")
            continue
        for fl in reg.get("flags", []):
            if not isinstance(fl, dict) or "id" not in fl or fl.get("type") not in ("bool", "int", "string"):
                errors.append(f"data/flags/{f.name}: each flag needs an id and a type (bool, int, string): {fl}")
                continue
            if fl["id"] in flags:
                errors.append(f"data/flags/{f.name}: flag '{fl['id']}' also registered in {flags[fl['id']]}")
            flags[fl["id"]] = f.name
            if "set_by" in fl:
                if fl["set_by"] != "engine":
                    errors.append(f"data/flags/{f.name}: flag '{fl['id']}': set_by is \"engine\" or left out")
                else:
                    engine_flags[fl["id"]] = f.name
    flags_read, flags_set = {}, {}

    def read(flag_ids, where):
        for fid in flag_ids:
            flags_read.setdefault(fid, []).append(where)

    def cond(expr, where):
        if expr:
            read(dialogue_lint.conditions_flags(expr), where)
            for qid in dialogue_lint.conditions_quest_days(expr):
                if qid not in data["quests"]:
                    errors.append(f"{where}: quest_days.{qid}: no such quest")
            # `fallen:<hero>` and `gifted:<hero>` name a hero by pregen id (story/story_conditions.gd).
            for kind, hero in dialogue_lint.conditions_heroes(expr):
                if hero not in data["pregens"]:
                    errors.append(f"{where}: {kind}:{hero}: no such hero (a pregen id)")

    # A hidden achievement's `when` reads flags like any condition (data/achievements, core/achievements.gd).
    for pid, ach in sorted(data.get("achievements", {}).items()):
        for a in ach.get("achievements", []):
            cond(a.get("when", ""), f"data/achievements/{pid}.json {a['id']}")

    npcs, quests, locations = data["npcs"], data["quests"], data["locations"]
    encounter_ids = set()
    dialogue_refs = []
    check_lines = []   # (narrator trigger, has text of its own, where) for each world check result
    for lid, loc in locations.items():
        rows = loc["map"]["rows"]
        w = f"locations/{lid}"
        # The lie of the land (natural elevation) lies square for square under the rows.
        elevation = loc["map"].get("elevation", [])
        if elevation and (len(elevation) != len(rows) or any(len(e) > len(r) for e, r in zip(elevation, rows))):
            errors.append(f"{w}: map elevation must have a row per map row, none longer than its row")

        def cell_char(rows, cell):
            x, z = cell
            return rows[z][x] if 0 <= z < len(rows) and 0 <= x < len(rows[z]) else ""

        def on_floor(cell, what, allow_wall=False):
            x, z = cell
            if z >= len(rows) or x >= len(rows[z]):
                errors.append(f"{w}: {what} at {cell} is outside the map")
                return
            if rows[z][x] not in OPEN_FLOOR and not (allow_wall and rows[z][x] in "#="):
                errors.append(f"{w}: {what} at {cell} isn't on open floor ('{rows[z][x]}')")

        area_ids = set()
        for a in loc.get("areas", []):
            area_ids.add(a["id"])
            for c in a["cells"]:
                if c[1] >= len(rows) or c[0] >= len(rows[0]):
                    errors.append(f"{w}: area {a['id']} corner {c} is outside the map")
        for name, c in loc.get("spawns", {}).items():
            on_floor(c, f"spawn '{name}'")
        if "default" not in loc.get("spawns", {}):
            errors.append(f"{w}: needs a 'default' spawn")
        for ex in loc.get("exits", []):
            on_floor(ex["cell"], f"exit {ex['id']}", allow_wall=True)
            if ex["to"] == "travel":
                pass  # the travel map (ADR 0010)
            elif ex["to"] not in locations:
                errors.append(f"{w}: exit {ex['id']} leads to unknown location '{ex['to']}'")
            elif ex.get("spawn") and ex["spawn"] not in locations[ex["to"]].get("spawns", {}):
                errors.append(f"{w}: exit {ex['id']} uses spawn '{ex['spawn']}' that {ex['to']} doesn't have")
            cond(ex.get("when", ""), w)
            sq = ex.get("sets_quest")
            if sq:
                if sq["id"] not in quests:
                    errors.append(f"{w}: exit {ex['id']} moves unknown quest '{sq['id']}'")
                else:
                    stage_ids = {st["id"] for st in quests[sq["id"]]["stages"]}
                    for sid in [sq["stage"]] + [f for f in sq["from"] if f]:
                        if sid not in stage_ids:
                            errors.append(f"{w}: exit {ex['id']}: quest {sq['id']} has no stage '{sid}'")
        for d in loc.get("doors", []):
            on_floor(d["cell"], f"door {d['id']}")
            cond(d.get("when", ""), w)
            if d.get("key"):
                need("item", data["items"], d["key"], f"{w} door {d['id']} key")
            if d.get("flag"):
                flags_set.setdefault(d["flag"], []).append(w)
        trap_ids = {t["id"] for t in loc.get("traps", [])}
        for pr in loc.get("props", []):
            cond(pr.get("when", ""), w)
            cond(pr.get("call_when", ""), w)
            if pr.get("item"):
                need("item", data["items"], pr["item"], f"{w} prop {pr['id']}")
            if pr.get("flag"):
                flags_set.setdefault(pr["flag"], []).append(w)
            # A chandelier (F5): its squares on open floor, its trap here, its kind real; its flag is set when it falls.
            hangs = pr.get("hangs")
            if hangs:
                for c in hangs["cells"]:
                    on_floor(c, f"prop {pr['id']} (hangs)")
                if hangs.get("trap") and hangs["trap"] not in trap_ids:
                    errors.append(f"{w}: prop {pr['id']} hangs from unknown trap '{hangs['trap']}'")
                kinds = data.get("objects", {}).get("kinds", {}).get("kinds", {})
                if kinds and hangs.get("kind", "chandelier") not in kinds:
                    errors.append(f"{w}: prop {pr['id']} hangs as unknown object kind '{hangs.get('kind')}'")
                if hangs.get("flag"):
                    # Set when it falls and read when the place is drawn (world/combat/battle_scenery.gd).
                    flags_set.setdefault(hangs["flag"], []).append(w)
                    read([hangs["flag"]], w)
            # What it is in a fight (F5): a real kind, standing on a '=' square (only those become battlefield objects).
            if pr.get("object"):
                kinds = data.get("objects", {}).get("kinds", {}).get("kinds", {})
                if kinds and pr["object"] not in kinds:
                    errors.append(f"{w}: prop {pr['id']} is unknown object kind '{pr['object']}'")
                x, z = pr["cell"]
                if z >= len(rows) or x >= len(rows[z]) or rows[z][x] != "=":
                    errors.append(f"{w}: prop {pr['id']} names an object kind but doesn't stand on a '=' square")
            if pr.get("dialogue"):
                dialogue_refs.append((pr["dialogue"], w))
            if pr.get("call"):
                dialogue_refs.append((pr["call"], w))   # a prop that speaks first as the party comes near (a vestige's call)
        for ct in loc.get("containers", []):
            on_floor(ct["cell"], f"container {ct['id']}", allow_wall=True)
            for it in ct.get("items", []):
                need("item", data["items"], it["id"], f"{w} container {ct['id']}")
            if ct.get("key"):
                need("item", data["items"], ct["key"], f"{w} container {ct['id']} key")
            cond(ct.get("when", ""), w)
            if ct.get("flag"):
                flags_set.setdefault(ct["flag"], []).append(w)
        world_check_checks(loc, w, data, need, cond, flags_set, check_lines, errors, on_floor)
        for tr in loc.get("traps", []):
            for c in tr["cells"]:
                on_floor(c, f"trap {tr['id']}")
            cond(tr.get("when", ""), w)
            if tr.get("flag"):
                flags_set.setdefault(tr["flag"], []).append(w)
        for n in loc.get("npcs", []):
            # Someone lying on the furniture of a low-cover square (Vasilka on the surgery table) lies on it.
            lies_on_it = bool(n.get("lying")) and cell_char(rows, n["cell"]) == "="
            if not lies_on_it:
                on_floor(n["cell"], f"npc {n['npc']}")
            # A waypoint is [x, y], [x, y, seconds] or {"at": [x, y], ...} (a stop at work, npc_routes.gd).
            stops = [(p["at"] if isinstance(p, dict) else p) for p in n.get("path", [])]
            for p in stops:
                on_floor([int(p[0]), int(p[1])], f"npc {n['npc']} path waypoint")
            if n.get("path"):
                walkable = _floor_reach(rows, tuple(n["cell"]))
                for p in stops:
                    if (int(p[0]), int(p[1])) not in walkable:
                        errors.append(f"{w}: npc {n['npc']} path waypoint {p[:2]} can't be walked to from {n['cell']}")
            if n["npc"] not in npcs:
                errors.append(f"{w}: unknown npc '{n['npc']}'")
            if n.get("dialogue"):
                dialogue_refs.append((n["dialogue"], w))
            cond(n.get("when", ""), w)
        for en in loc.get("encounters", []):
            encounter_ids.add(en["id"])
            cond(en.get("when", ""), w)
            trig = en["trigger"]
            if trig.startswith("enter_area:") and trig.split(":", 1)[1] not in area_ids:
                errors.append(f"{w}: encounter {en['id']} triggers on unknown area '{trig.split(':', 1)[1]}'")
            if trig.startswith("flag:"):
                read([trig.split(":", 1)[1]], w)
            if trig.startswith("check:"):
                # A fight a skill check sets off (story/world_checks.gd): check:<check id>:success|failure, a check here.
                cid, _, result = trig[6:].rpartition(":")
                here = {c["id"] for k in ("props", "doors", "containers") for t in loc.get(k, []) for c in t.get("checks", [])}
                if cid not in here or result not in ("success", "failure"):
                    errors.append(f"{w}: encounter {en['id']} triggers on '{trig}', which isn't a check here going one way")
            if en.get("flag"):
                flags_set.setdefault(en["flag"], []).append(w)
            if en.get("quest"):
                q = en["quest"]
                if q["id"] not in quests:
                    errors.append(f"{w}: encounter {en['id']} moves unknown quest '{q['id']}'")
                elif q["stage"] not in {st["id"] for st in quests[q["id"]]["stages"]}:
                    errors.append(f"{w}: encounter {en['id']}: quest {q['id']} has no stage '{q['stage']}'")
            for m in en["monsters"]:
                if m["monster"] not in data["monsters"]:
                    errors.append(f"{w}: encounter {en['id']} uses unknown monster '{m['monster']}'")
                else:
                    on_floor(m["cell"], f"encounter {en['id']} monster")
    for nid, n in npcs.items():
        if n.get("monster") and n["monster"] not in data["monsters"]:
            errors.append(f"npcs/{nid}: unknown monster '{n['monster']}'")
    # Dialogue files.
    # Hidden finds a conversation can show (`reveal`): search props and traps by id, counted over every location.
    search_props = {}
    for loc in locations.values():
        for pr in loc.get("props", []):
            if pr.get("kind") == "search":
                search_props[pr["id"]] = search_props.get(pr["id"], 0) + 1
        for tr in loc.get("traps", []):
            search_props[tr["id"]] = search_props.get(tr["id"], 0) + 1
    # Where a conversation can lead the party (`lead <npc> to <target>`): a place (optionally "place:spawn"), a square
    # ("x,y") or the id of a door, prop, container, exit or area on a map.
    lead_things = set()
    for loc in locations.values():
        for kind in ("doors", "props", "containers", "exits", "areas"):
            lead_things.update(t["id"] for t in loc.get(kind, []) if "id" in t)
    narrative = ROOT / "narrative"
    parsed = {}
    for f in sorted(narrative.rglob("*.dialogue")) if narrative.exists() else []:
        key = str(f.relative_to(narrative).with_suffix(""))
        parsed[key] = dialogue_lint.parse_file(f)
    names = {"narrator", "player"}
    for nid, n in npcs.items():
        names.add(nid)
        names.add(n["name"].lower())
        names.add(n["name"].split()[0].lower())
    for pid, pg in data["pregens"].items():
        names.add(pid)
        names.add(pg["name"].split()[0].lower())
    for key, p in parsed.items():
        w = f"narrative/{key}.dialogue"
        errors.extend(f"narrative/{e}" if not e.startswith("narrative") else e for e in
                      [f"{key.rsplit('/', 1)[0]}/{e}" for e in p["errors"]])
        for target, where in p["jumps"]:
            if target == "END":
                continue
            fkey, _, node = target.rpartition(":") if ":" in target and "/" in target else ("", "", target)
            if fkey:
                if fkey not in parsed or node not in parsed[fkey]["nodes"]:
                    errors.append(f"narrative/{where}: jump to unknown '{target}'")
            elif node not in p["nodes"]:
                errors.append(f"narrative/{where}: jump to unknown node '{node}'")
        for sp, where in p["speakers"]:
            if sp.lower() not in names:
                errors.append(f"narrative/{where}: unknown speaker '{sp}' (an npc id or name, Narrator or Player)")
        for it, where in p["items"]:
            need("item", data["items"], it, f"narrative/{where}")
        for qid, stage, where in p["quests"]:
            if qid not in quests:
                errors.append(f"narrative/{where}: unknown quest '{qid}'")
            elif stage not in {s["id"] for s in quests[qid]["stages"]}:
                errors.append(f"narrative/{where}: quest {qid} has no stage '{stage}'")
        for qid, where in p.get("ends", []):
            if qid not in quests:
                errors.append(f"narrative/{where}: [ends:{qid}] names an unknown quest")
        for enc, where in p["encounters"]:
            if enc not in encounter_ids:
                errors.append(f"narrative/{where}: combat '{enc}' isn't an encounter in any location")
        for enc, where in p.get("xp_fights", []):
            if enc not in encounter_ids:
                errors.append(f"narrative/{where}: xp fight '{enc}' isn't an encounter in any location")
        for sid, where in p.get("casts", []):
            if sid not in data["spells"]:
                errors.append(f"narrative/{where}: cast '{sid}' isn't a spell")
        for pid, where in p.get("reveals", []):
            if search_props.get(pid, 0) != 1:
                errors.append(f"narrative/{where}: reveal '{pid}' must name one hidden find (a search prop) or trap in one location"
                              f" (found {search_props.get(pid, 0)})")
        for lead_npc, target, where in p.get("leads", []):
            place, _, spawn = target.partition(":")
            if re.fullmatch(r"\d+,\d+", target) or (place in lead_things and not spawn):
                continue
            if place not in locations:
                errors.append(f"narrative/{where}: lead {lead_npc} to '{target}': no place, door, prop, container, exit or area by that id")
            elif spawn and spawn not in locations[place].get("spawns", {}):
                errors.append(f"narrative/{where}: lead {lead_npc} to '{target}': {place} has no spawn '{spawn}'")
        for fid, wh in p["flags_read"].items():
            flags_read.setdefault(fid, []).extend(wh)
        for fid, wh in p["flags_set"].items():
            flags_set.setdefault(fid, []).extend(wh)
        approval_checks(data, p, errors)
        for qid, where in p.get("quest_days_terms", []):
            if qid not in quests:
                errors.append(f"narrative/{where}: quest_days.{qid}: no such quest")
        move_checks(locations, p, errors)
    narrator_keys = set()
    for key, p in parsed.items():
        if key.startswith("narrator/"):
            narrator_keys.update(p["nodes"])
    for trig, has_text, where in check_lines:
        if trig.startswith("flag:"):
            if flags.get(trig[5:]) not in (None, "world_checks.json"):
                errors.append(f"{where}: sets '{trig[5:]}', a {flags[trig[5:]]} flag: checks set only side flags (data/flags/world_checks.json)")
        elif not has_text and trig not in narrator_keys:
            errors.append(f"{where}: no Narrator line '{trig}' and no text of its own")
    treasure_checks(data, parsed, errors, pending_list)
    cutscene_checks(data, parsed, errors)
    castle_checks(data, parsed, errors, cond, flags_set, dialogue_refs)
    schedule_checks(data, errors, cond, flags_set, dialogue_refs)
    attention = data.get("strahd", {}).get("attention", {})
    for m in attention.get("marks", []):
        cond(m["when"], f"strahd/attention.json {m['id']}")
        if re.search(r"\battention\b", m["when"]):
            errors.append(f"strahd/attention.json {m['id']}: a mark can't read attention itself")
    tier_ids = [t["id"] for t in attention.get("tiers", [])]
    for wid, w in data.get("weather", {}).items():
        where = f"weather/{wid}.json"
        for cid, weights in w["climates"].items():
            for k in weights:
                if k not in w["kinds"]:
                    errors.append(f"{where}: climate {cid} weighs unknown kind '{k}'")
        if w["default_climate"] not in w["climates"]:
            errors.append(f"{where}: default_climate '{w['default_climate']}' isn't a climate")
        for region, cid in w["regions"].items():
            if cid not in w["climates"]:
                errors.append(f"{where}: region {region} has unknown climate '{cid}'")
            if region not in {l.get("region") for l in data["locations"].values()}:
                errors.append(f"{where}: no location is in region '{region}'")
        for tier in w.get("storm_by_attention", {}):
            if tier not in tier_ids:
                errors.append(f"{where}: storm_by_attention names '{tier}', which isn't an attention tier")
    if attention and sorted(t["min"] for t in attention["tiers"]) != [t["min"] for t in attention["tiers"]]:
        errors.append("strahd/attention.json: tiers go from the lowest min to the highest")
    for ref, w in dialogue_refs:
        fkey, _, node = ref.rpartition(":")
        if fkey not in parsed:
            errors.append(f"{w}: dialogue file '{fkey}' doesn't exist")
        elif node not in parsed[fkey]["nodes"]:
            errors.append(f"{w}: dialogue {fkey} has no node '{node}'")
    # Every stage that doesn't end its quest says what to do next: the journal's Hint (Storyline QA, 2026-10-09).
    for qid, q in sorted(quests.items()):
        for st in q["stages"]:
            if not st.get("ends") and not str(st.get("hint", "")).strip():
                errors.append(f"data/quests/{qid}.json: stage '{st['id']}' has no hint (what to do next, for the journal)")
    # `then` names a failure's comebacks (StoryState.set_quest_stage): stages of the same quest, on a stage that ends.
    for qid, q in sorted(quests.items()):
        ids = {st["id"] for st in q["stages"]}
        for st in q["stages"]:
            if "then" not in st:
                continue
            if not st.get("ends"):
                errors.append(f"data/quests/{qid}.json: stage '{st['id']}' has `then` but doesn't end the quest")
            for nxt in st["then"]:
                if nxt == st["id"] or nxt not in ids:
                    errors.append(f"data/quests/{qid}.json: stage '{st['id']}' lists `then` stage '{nxt}', which isn't another stage of the quest")
    # `closes` rules end a quest on their own (story/quest_closures.gd): each moves it to one of its endings, from stages that
    # are open, on a condition that parses, as the party leaves a region that exists.
    regions = {l.get("region") for l in locations.values()}
    for qid, q in sorted(quests.items()):
        ids = {st["id"] for st in q["stages"]}
        open_ids = {st["id"] for st in q["stages"] if not st.get("ends")}
        ends = {st["id"]: st.get("ends", "") for st in q["stages"]}
        for i, rule in enumerate(q.get("closes", [])):
            w = f"data/quests/{qid}.json: closes[{i}]"
            if rule["stage"] not in ids:
                errors.append(f"{w}: stage '{rule['stage']}' isn't a stage of the quest")
            elif not ends[rule["stage"]]:
                errors.append(f"{w}: stage '{rule['stage']}' doesn't end the quest (a rule moves it to an ending)")
            for s in rule.get("from", []):
                if s not in open_ids:
                    errors.append(f"{w}: from '{s}', which isn't an open stage of the quest")
            if rule.get("leave") and rule["leave"] not in regions:
                errors.append(f"{w}: leave '{rule['leave']}', which no location is in")
            if not str(rule.get("when", "")).strip() and not rule.get("leave"):
                errors.append(f"{w}: no `when` and no `leave`: it would end the quest at once")
            if rule.get("old_saves") and rule.get("leave"):
                errors.append(f"{w}: old_saves with leave: a departure never happens on load")
            if "warn" in rule and not str(rule["warn"]).strip():
                errors.append(f"{w}: warn is empty")
            for problem in dialogue_lint.condition_problems(rule.get("when", "")):
                errors.append(f"{w}: when: {problem}")
            cond(rule.get("when", ""), f"data/quests/{qid}.json")
            if "warn_when" in rule and not rule.get("warn"):
                errors.append(f"{w}: warn_when without a warn")
            for problem in dialogue_lint.condition_problems(rule.get("warn_when", "")):
                errors.append(f"{w}: warn_when: {problem}")
            cond(rule.get("warn_when", ""), f"data/quests/{qid}.json")
    for fid, wh in sorted(flags_read.items()):
        if fid not in flags:
            errors.append(f"{wh[0]}: flag '{fid}' isn't registered in data/flags/")
        if fid not in flags_set and fid not in engine_flags:
            errors.append(f"{wh[0]}: flag '{fid}' is read but never set")
    for fid, wh in sorted(flags_set.items()):
        if fid not in flags:
            errors.append(f"{wh[0]}: flag '{fid}' isn't registered in data/flags/")
        if fid in engine_flags:
            errors.append(f"{wh[0]}: flag '{fid}' is set by the engine ({engine_flags[fid]}); data doesn't set it")
        elif fid not in flags_read:
            errors.append(f"{wh[0]}: flag '{fid}' is set but never read")


def main():
    errors = []
    checked = 0
    for schema_file in sorted(SCHEMAS.glob("*.schema.json")):
        try:
            json.loads(schema_file.read_text())
        except json.JSONDecodeError as e:
            errors.append(f"{schema_file.name}: invalid JSON: {e}")
    for folder, schema_name in FOLDERS.items():
        schema_file = f"{schema_name}.schema.json" if isinstance(schema_name, str) else ""
        seen = {}
        for data_file in sorted((ROOT / "data" / folder).glob("*.json")):
            rel = data_file.relative_to(ROOT)
            if isinstance(schema_name, dict):
                if data_file.stem not in schema_name:
                    errors.append(f"{rel}: unexpected file (expected {', '.join(schema_name)})")
                    continue
                schema_file = f"{schema_name[data_file.stem]}.schema.json"
            try:
                data = json.loads(data_file.read_text())
            except json.JSONDecodeError as e:
                errors.append(f"{rel}: invalid JSON: {e}")
                continue
            file_errors = []
            validate(data, load_schema(schema_file), schema_file, "$", file_errors)
            if isinstance(data, dict):
                if data.get("id") != data_file.stem:
                    file_errors.append(f"$.id: {data.get('id')!r} should match filename '{data_file.stem}'")
                if data.get("id") in seen:
                    file_errors.append(f"$.id: duplicate of {seen[data['id']]}")
                seen[data.get("id")] = rel
            errors.extend(f"{rel}: {e}" for e in file_errors)
            checked += 1
    sem_errors, pending = semantic_checks(load_all()) if not errors else ([], [])
    errors.extend(sem_errors)
    # Whether a playthrough can reach it all: quest stages, conversations, props and containers, the flags conditions
    # read, and quest content only a random road encounter opens (tools/data/story_reach.py, Storyline QA).
    if not errors:
        errors.extend(story_reach.findings(ROOT))
        # A failed roll never locks a quest: a spent social option can't be the only way to a stage (tools/data/fail_routes.py).
        errors.extend(fail_routes.findings(ROOT))
        # An option that closes a quest wears [ends:<quest>], and only such an option does (tools/data/option_ends.py).
        errors.extend(option_ends.findings(ROOT))
        # A side quest isn't left stuck: no open stage whose every way on goes when one flag the story sets elsewhere is set
        # (the Tser Pool camp turning, an NPC killed), unless a `closes` rule covers it (tools/data/quest_strands.py, F3).
        errors.extend(quest_strands.selftest())
        errors.extend(quest_strands.findings(ROOT))
    # Magic item prices follow Sane Magical Prices (data/treasure/magic_prices.json, tools/data/magic_prices.py).
    errors.extend(magic_prices.findings())
    for e in errors:
        print("  FAIL ", e)
    if pending and "--pending" in sys.argv:
        for p in pending:
            print("  later", p)
    print(f"{checked} data files checked, {len(errors)} errors"
          + (f", {len(pending)} references to later-phase content (--pending lists them)" if pending else ""))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
