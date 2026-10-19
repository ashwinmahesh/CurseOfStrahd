"""`[once]` Narrator variants and `hero_named:` in the data checks (docs/contracts/dialogue.md): the dialogue lint accepts
`| [once] Text` and `| [once and <condition>] Text`, reads the flags in the condition after `once and`, and refuses
`once` anywhere else in a variant's brackets and a `hero_named:` with no usable name.

    python3 -m unittest discover -s tests/tools -p 'test_dialogue_once.py' -v
"""
import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / "data" / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


lint = _load("dialogue_lint")


def _parse(body):
    """The lint's result for one made-up Narrator file."""
    with tempfile.TemporaryDirectory() as d:
        folder = Path(d) / "narrator"
        folder.mkdir()
        path = folder / "test.dialogue"
        path.write_text(body)
        return lint.parse_file(path)


class OnceVariants(unittest.TestCase):
    def test_once_alone_and_once_and_a_condition_are_fine(self):
        out = _parse("~ test:a\n| [once] One.\n| [once and flag.seen_it] Two.\n| [flag.seen_it] Three.\n| Four.\n")
        self.assertEqual(out["errors"], [])
        self.assertEqual(sorted(out["flags_read"]), ["seen_it"], "the condition after `once and` is still read")

    def test_once_has_to_lead_the_brackets(self):
        for cond in ("flag.seen_it and once", "once or flag.seen_it", "not once", "once and", "once  and flag.x"):
            out = _parse(f"~ test:a\n| [{cond}] Text.\n")
            self.assertEqual(len(out["errors"]), 1, f"[{cond}]: {out['errors']}")
            self.assertIn("once", out["errors"][0])

    def test_a_flag_that_only_contains_the_word_is_not_once(self):
        out = _parse("~ test:a\n| [flag.once_upon_a_time] Text.\n")
        self.assertEqual(out["errors"], [])

    def test_the_trigger_level_once_still_works(self):
        out = _parse("~ test:a\n| Line.\nonce\n")
        self.assertEqual(out["errors"], [])


class HeroNamed(unittest.TestCase):
    def test_a_name_is_letters_digits_and_underscores(self):
        for term in ("hero_named:vesper", "hero_named:Vesper", "hero_named:vesper_brightwater", "(hero_named:vesper)"):
            out = _parse(f"~ test:a\n| [{term}] Text.\n")
            self.assertEqual(out["errors"], [], term)

    def test_an_empty_or_odd_name_is_refused(self):
        for term in ("hero_named:", "hero_named:ves-per", "hero_named:ves.per", "hero_named: vesper"):
            out = _parse(f"~ test:a\n| [{term}] Text.\n")
            self.assertTrue(any("hero_named" in e for e in out["errors"]), f"{term}: {out['errors']}")

    def test_it_is_checked_in_ordinary_conditions_too(self):
        out = _parse("~ test:a\n| Line.\n")  # a narrator file parses `if` lines as plain statements; use a story file
        self.assertEqual(out["errors"], [])
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "story.dialogue"
            path.write_text("~ start\nif hero_named:\nNarrator: Hm.\nendif\n-> END\n")
            self.assertTrue(any("hero_named" in e for e in lint.parse_file(path)["errors"]))


if __name__ == "__main__":
    unittest.main()
