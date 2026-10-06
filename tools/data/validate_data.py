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

ROOT = Path(__file__).resolve().parents[2]
SCHEMAS = ROOT / "data" / "schemas"

# Data folder -> schema name. Folders not listed have no schema yet and are skipped.
FOLDERS = {
    "classes": "class", "subclasses": "subclass", "species": "species",
    "backgrounds": "background", "feats": "feat", "spells": "spell",
    "items": "item", "magic_items": "item", "monsters": "monster", "conditions": "condition", "pregens": "pregen",
    "encounters": "encounter",
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
PHASE_MAX_LEVEL = 5


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
        if ident in table:
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
                    need("spell", spells, m["value"], f"{where} {f['id']}", max(at, m.get("at_level", 0)))
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
        check_features(f.get("benefits", []), f"feats/{fid}")
    for iid, it in items.items():
        for c in it.get("contents", []):
            need("item", items, c["id"], f"items/{iid} contents")
    for mid, m in data["monsters"].items():
        ids = {a["id"] for key in ("actions", "bonus_actions", "reactions") for a in m.get(key, [])}
        for a in m.get("actions", []):
            for ma in a.get("multiattack", []):
                if ma["action"] not in ids:
                    errors.append(f"monsters/{mid}: multiattack names unknown action '{ma['action']}'")
        sc = m.get("spellcasting", {})
        for sp in sc.get("at_will", []) + [x for v in sc.get("per_day", {}).values() for x in v]:
            if sp not in spells:
                pending.append(f"monsters/{mid}: spell '{sp}' (not in Phase 1 spell data)")
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
    return errors, pending


def main():
    errors = []
    checked = 0
    for schema_file in sorted(SCHEMAS.glob("*.schema.json")):
        try:
            json.loads(schema_file.read_text())
        except json.JSONDecodeError as e:
            errors.append(f"{schema_file.name}: invalid JSON: {e}")
    for folder, schema_name in FOLDERS.items():
        schema_file = f"{schema_name}.schema.json"
        seen = {}
        for data_file in sorted((ROOT / "data" / folder).glob("*.json")):
            rel = data_file.relative_to(ROOT)
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
