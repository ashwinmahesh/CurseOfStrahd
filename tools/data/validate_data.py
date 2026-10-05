#!/usr/bin/env python3
"""Validates every data/<type>/*.json against data/schemas/<type>.schema.json.

Stdlib only (no jsonschema install needed). Supports the subset of JSON Schema the project uses:
type, enum, const, required, properties, additionalProperties (bool), items, minItems, maxItems,
minimum, maximum, minLength, pattern, $ref (local '#/...' and sibling 'file.json#/...').
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
    "items": "item", "magic_items": "item", "monsters": "monster",
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
        for key, sub in value.items():
            if key in props:
                validate(sub, props[key], base, f"{path}.{key}", errors)
            elif schema.get("additionalProperties") is False:
                errors.append(f"{path}: unexpected property '{key}'")


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
    for e in errors:
        print("  FAIL ", e)
    print(f"{checked} data files checked, {len(errors)} errors")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
