"""Where the game's data and engine sources are (docs/plans/engine_split.md): the rules data, schemas and engine code live
in the dnd_core submodule (addons/dnd_core), the game's own data and code beside it. The game's file of a name replaces
the core's. Stdlib only.

    data_files("spells")           every data/spells/*.json of the core and the game, by file name
    schema_file("spell.schema.json")   the schema of that name, wherever it is
    engine_file("story/trade.gd")  an engine source file, in the core or the game
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def roots(root=None):
    """The folders that hold data/, the core's first; the game's own last (it wins on a name both have)."""
    root = Path(root) if root else ROOT
    core = root / "addons" / "dnd_core"
    return [core, root] if core.is_dir() else [root]


def data_files(folder, root=None, pattern="*.json"):
    by = {}
    for r in roots(root):
        d = r / "data" / folder
        if d.is_dir():
            for f in d.glob(pattern):
                by[f.name] = f
    return [by[n] for n in sorted(by)]


def schema_files(root=None):
    return data_files("schemas", root, "*.schema.json")


def schema_file(name, root=None):
    for r in reversed(roots(root)):
        p = r / "data" / "schemas" / name
        if p.exists():
            return p
    raise FileNotFoundError(name)


def engine_file(rel, root=None):
    """A source file under rules/, combat/ or story/ (or any path the engine owns): where it exists."""
    for r in reversed(roots(root)):
        if (r / rel).exists():
            return r / rel
    return Path(root or ROOT) / rel

