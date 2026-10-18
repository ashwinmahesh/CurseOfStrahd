"""`move <location>[:<spawn>]` in the data checks (Dungeon Expansion Plan E1, docs/contracts/dialogue.md): the dialogue
lint reads it, make validate fails on a location or a spawn that does not exist, and the reach walk follows it.

    python3 -m unittest discover -s tests/tools -p 'test_dialogue_move.py' -v
"""
import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "data"))


def _load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / "data" / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


lint = _load("dialogue_lint")
validate = _load("validate_data")
reach = _load("story_reach")

LOCATIONS = {
    "hall": {"spawns": {"default": [1, 1], "cell": [6, 2]}},
    "vault": {"spawns": {"default": [1, 1], "landing": [7, 2]}},
}


def _parse(text):
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "scene.dialogue"
        path.write_text(text)
        return lint.parse_file(path)


def _errors(text):
    errors = []
    validate.move_checks(LOCATIONS, _parse(text), errors)
    return errors


class MoveLintTests(unittest.TestCase):
    def test_a_location_and_a_spawn_read(self):
        out = _parse("~ drop\nNarrator: Down you go.\ntime +240\nmove vault:landing\n")
        self.assertEqual(out["errors"], [])
        self.assertEqual([(a, b) for a, b, _ in out["moves"]], [("vault", "landing")])

    def test_no_spawn_means_the_default_one(self):
        out = _parse("~ drop\nmove vault\n")
        self.assertEqual(out["errors"], [])
        self.assertEqual([(a, b) for a, b, _ in out["moves"]], [("vault", "default")])

    def test_a_move_that_does_not_read_is_an_error(self):
        for bad in ("move", "move a:b:c", "move a:", "move :b", "move Vault", "move a b"):
            out = _parse(f"~ drop\n{bad}\n")
            self.assertTrue(out["errors"], f"'{bad}' should not read")


class MoveValidateTests(unittest.TestCase):
    def test_a_real_location_and_spawn_pass(self):
        self.assertEqual(_errors("~ drop\nmove vault:landing\n"), [])
        self.assertEqual(_errors("~ drop\nmove hall:cell\n"), [])
        self.assertEqual(_errors("~ drop\nmove vault\n"), [])

    def test_a_spawn_that_does_not_exist_fails(self):
        errors = _errors("~ drop\nmove vault:nowhere\n")
        self.assertEqual(len(errors), 1)
        self.assertIn("vault has no spawn 'nowhere'", errors[0])

    def test_a_location_that_does_not_exist_fails(self):
        errors = _errors("~ drop\nmove attic:default\n")
        self.assertEqual(len(errors), 1)
        self.assertIn("'attic' isn't a location", errors[0])


class MoveReachTests(unittest.TestCase):
    def test_the_walk_follows_a_move_to_its_spawn(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "scene.dialogue"
            path.write_text("~ drop\nmove vault:landing\n~ same\nmove hall\n")
            nodes = reach.parse_dialogue(path)
        self.assertEqual([s["t"] for s in nodes["drop"]], ["move"])
        self.assertEqual((nodes["drop"][0]["loc"], nodes["drop"][0]["spawn"]), ("vault", "landing"))
        self.assertEqual(nodes["same"][0]["spawn"], "default")


if __name__ == "__main__":
    unittest.main()
