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
    "strahd": {"visits": "strahd_visits"},
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
    budget = {1: (50, 75, 100), 2: (100, 150, 200), 3: (150, 225, 400), 4: (250, 375, 500), 5: (500, 750, 1100)}
    sizes = {"tiny": 1, "small": 1, "medium": 1, "large": 2, "huge": 3, "gargantuan": 4}
    for eid, enc in data["encounters"].items():
        rows = enc["map"]["rows"]
        taken = {}

        def place(cell, size, who):
            x, z = cell
            for dz in range(size):
                for dx in range(size):
                    cx, cz = x + dx, z + dz
                    if cz >= len(rows) or cx >= len(rows[cz]) or rows[cz][cx] not in ".~1234":
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
    pending.extend(pending_list)
    pending_list.clear()
    campaign_checks(data, errors, pending)
    return errors, pending


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
    tables = data.get("random_encounters", {})
    for tid, t in tables.items():
        w = f"random_encounters/{tid}"
        if t["map"] not in locations:
            errors.append(f"{w}: unknown map location '{t['map']}'")
        for e in t["entries"]:
            if not e.get("monsters") and not e.get("dialogue"):
                errors.append(f"{w}: an entry needs monsters or a dialogue")
            rows = locations.get(t["map"], {}).get("map", {}).get("rows", [])
            for m in e.get("monsters", []):
                if m["monster"] not in monsters:
                    errors.append(f"{w}: unknown monster '{m['monster']}'")
                x, z = m["cell"]
                if rows and not (0 <= z < len(rows) and 0 <= x < len(rows[z]) and rows[z][x] in ".~1234"):
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
    for nid, n in npcs.items():
        for e in n.get("shop", {}).get("sells", []):
            if e["id"] not in items and e["id"] not in data.get("magic_items", {}):
                errors.append(f"npcs/{nid}: shop sells unknown item '{e['id']}'")
        gb = n.get("guest_build", {})
        if gb.get("monster") and gb["monster"] not in monsters:
            errors.append(f"npcs/{nid}: guest_build monster '{gb['monster']}' unknown")
        if gb.get("pregen") and gb["pregen"] not in data["pregens"]:
            errors.append(f"npcs/{nid}: guest_build pregen '{gb['pregen']}' unknown")


OPEN_FLOOR = ".~1234"


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
            finals.setdefault(room, []).append(w)
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
    for v in data.get("strahd", {}).get("visits", {}).get("visits", []):
        w = f"strahd/visits.json {v['id']}"
        cond(v.get("when", ""), w)
        if v.get("dialogue"):
            dialogue_refs.append((v["dialogue"], w))
        for step in v.get("then", []):
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
            if step.get("go"):
                lid, _, spawn = step["go"].partition(":")
                if lid not in locations:
                    errors.append(f"{w}: go to unknown location '{lid}'")
                elif spawn and spawn not in locations[lid].get("spawns", {}):
                    errors.append(f"{w}: {lid} has no spawn '{spawn}'")
            if step.get("dialogue"):
                dialogue_refs.append((step["dialogue"], w))


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


def story_checks(data, errors, need):
    """Locations, NPCs, quests, the flag registry and every .dialogue file (ADR 0008, ADR 0009)."""
    flags = {}
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
    flags_read, flags_set = {}, {}

    def read(flag_ids, where):
        for fid in flag_ids:
            flags_read.setdefault(fid, []).append(where)

    def cond(expr, where):
        if expr:
            read(dialogue_lint.conditions_flags(expr), where)

    npcs, quests, locations = data["npcs"], data["quests"], data["locations"]
    encounter_ids = set()
    dialogue_refs = []
    for lid, loc in locations.items():
        rows = loc["map"]["rows"]
        w = f"locations/{lid}"

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
        for d in loc.get("doors", []):
            on_floor(d["cell"], f"door {d['id']}")
            cond(d.get("when", ""), w)
            if d.get("key"):
                need("item", data["items"], d["key"], f"{w} door {d['id']} key")
            if d.get("flag"):
                flags_set.setdefault(d["flag"], []).append(w)
        for pr in loc.get("props", []):
            cond(pr.get("when", ""), w)
            if pr.get("item"):
                need("item", data["items"], pr["item"], f"{w} prop {pr['id']}")
            if pr.get("flag"):
                flags_set.setdefault(pr["flag"], []).append(w)
            if pr.get("dialogue"):
                dialogue_refs.append((pr["dialogue"], w))
        for ct in loc.get("containers", []):
            on_floor(ct["cell"], f"container {ct['id']}", allow_wall=True)
            for it in ct.get("items", []):
                need("item", data["items"], it["id"], f"{w} container {ct['id']}")
            if ct.get("key"):
                need("item", data["items"], ct["key"], f"{w} container {ct['id']} key")
            cond(ct.get("when", ""), w)
            if ct.get("flag"):
                flags_set.setdefault(ct["flag"], []).append(w)
        for tr in loc.get("traps", []):
            for c in tr["cells"]:
                on_floor(c, f"trap {tr['id']}")
            cond(tr.get("when", ""), w)
            if tr.get("flag"):
                flags_set.setdefault(tr["flag"], []).append(w)
        for n in loc.get("npcs", []):
            on_floor(n["cell"], f"npc {n['npc']}")
            for p in n.get("path", []):
                on_floor([int(p[0]), int(p[1])], f"npc {n['npc']} path waypoint")
            if n.get("path"):
                walkable = _floor_reach(rows, tuple(n["cell"]))
                for p in n["path"]:
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
        for enc, where in p["encounters"]:
            if enc not in encounter_ids:
                errors.append(f"narrative/{where}: combat '{enc}' isn't an encounter in any location")
        for fid, wh in p["flags_read"].items():
            flags_read.setdefault(fid, []).extend(wh)
        for fid, wh in p["flags_set"].items():
            flags_set.setdefault(fid, []).extend(wh)
        approval_checks(data, p, errors)
    treasure_checks(data, parsed, errors, pending_list)
    castle_checks(data, parsed, errors, cond, flags_set, dialogue_refs)
    for ref, w in dialogue_refs:
        fkey, _, node = ref.rpartition(":")
        if fkey not in parsed:
            errors.append(f"{w}: dialogue file '{fkey}' doesn't exist")
        elif node not in parsed[fkey]["nodes"]:
            errors.append(f"{w}: dialogue {fkey} has no node '{node}'")
    for fid, wh in sorted(flags_read.items()):
        if fid not in flags:
            errors.append(f"{wh[0]}: flag '{fid}' isn't registered in data/flags/")
        if fid not in flags_set:
            errors.append(f"{wh[0]}: flag '{fid}' is read but never set")
    for fid, wh in sorted(flags_set.items()):
        if fid not in flags:
            errors.append(f"{wh[0]}: flag '{fid}' isn't registered in data/flags/")
        if fid not in flags_read:
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
