"""tools/data/option_ends.py: the checker judges made-up conversations right, the game's own options carry the mark
exactly where they close a quest, and the tag reads the same in the lint and the reach walk."""
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "data"))
import dialogue_lint  # noqa: E402
import option_ends  # noqa: E402
import story_reach  # noqa: E402


class OptionEnds(unittest.TestCase):
    def test_selftest(self):
        self.assertEqual(option_ends.selftest(), [])

    def test_the_game_has_no_unmarked_or_misplaced_option(self):
        self.assertEqual(option_ends.findings(ROOT), [])

    def test_allowed_entries_are_still_needed(self):
        # A stale entry hides nothing but says something false: each must still be a finding without the list.
        files, quests = option_ends.load(ROOT)
        live = {f"{k}:{n}:{line}:" for k, n, line, _ in option_ends.analyse(files, quests)}
        stale = [k for k in option_ends.ALLOWED if not any(k.startswith(p) for p in live)]
        self.assertEqual(stale, [])

    def test_the_tag_reads_in_the_lint_and_the_reach_walk(self):
        import tempfile
        text = ("~ start\n"
                "* [ends:the_fourth_sister] [Cleric] Take it. -> END\n"
                "* [ends:the_priests_son if flag.late and not flag.early] Another. -> END\n"
                "* [ends:Bad Quest] Broken. -> END\n")
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "x.dialogue"
            p.write_text(text)
            lint = dialogue_lint.parse_file(p)
            reach = story_reach.parse_dialogue(p)["start"]
        self.assertEqual([q for q, _ in lint["ends"]], ["the_fourth_sister", "the_priests_son"])
        self.assertEqual(len(lint["errors"]), 1, lint["errors"])
        self.assertIn("malformed tag", lint["errors"][0])
        self.assertEqual(lint["selectors"], [("class:cleric", "x.dialogue:2")], "the tag is no selector")
        self.assertEqual(reach[0]["ends"], ["the_fourth_sister"])
        self.assertEqual(reach[1]["ends"], ["the_priests_son"])
        self.assertEqual(reach[0]["gates"], ["Cleric"], "and no gate")


if __name__ == "__main__":
    unittest.main()
