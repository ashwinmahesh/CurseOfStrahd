"""data/quests `then` and `closes` (side quest failure plan, F1): make validate judges them, and story_reach counts a closure
as the thing that sets its stage.

    python3 -m unittest discover -s tests/tools -p 'test_quest_closes.py' -v
"""
import copy
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "data"))
import dialogue_lint  # noqa: E402
import story_reach  # noqa: E402
import validate_data  # noqa: E402

QUEST = "rose_and_thorn"   # met, remains (open); at_rest (success), left_behind (failure)


class QuestClosesChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = validate_data.load_all()
        cls.base = copy.deepcopy(cls.data["quests"][QUEST])

    @classmethod
    def tearDownClass(cls):
        cls.data["quests"][QUEST] = cls.base

    def problems(self, closes=None, patch=None):
        q = copy.deepcopy(self.base)
        q.pop("closes", None)
        if closes is not None:
            q["closes"] = closes
        if patch:
            patch(q)
        self.data["quests"][QUEST] = q
        errors, _ = validate_data.semantic_checks(self.data)
        schema = []
        validate_data.validate(q, validate_data.load_schema("quest.schema.json"), "quest.schema.json", "$", schema)
        return [e for e in errors + schema if QUEST in e or "closes" in e]

    def test_a_good_rule_passes(self):
        rule = {"stage": "left_behind", "when": "quest_days.rose_and_thorn >= 3", "from": ["met"], "warn": "Time is short."}
        self.assertEqual(self.problems([rule]), [])

    def test_a_rule_ends_the_quest_from_open_stages_on_a_condition(self):
        bad = {
            "a stage that isn't there": {"stage": "nowhere", "when": "true"},
            "a stage that doesn't end the quest": {"stage": "remains", "when": "true"},
            "a from stage that is an ending": {"stage": "left_behind", "when": "true", "from": ["at_rest"]},
            "a region nobody is in": {"stage": "left_behind", "leave": "atlantis"},
            "no when and no leave": {"stage": "left_behind"},
            "old_saves with leave": {"stage": "left_behind", "leave": "village_of_barovia", "old_saves": True},
            "an empty warning": {"stage": "left_behind", "when": "true", "warn": " "},
            "a condition that doesn't parse": {"stage": "left_behind", "when": "flag.zzz_nope and"},
            "a flag nobody sets": {"stage": "left_behind", "when": "flag.zzz_nope"},
            "a clock on a flag nobody stamps": {"stage": "left_behind", "when": "days_since.zzz_nope >= 2"},
            "a clock on a quest that isn't": {"stage": "left_behind", "when": "quest_days.not_a_quest >= 2"},
            "a key the schema doesn't know": {"stage": "left_behind", "when": "true", "bogus": 1},
        }
        for name, rule in bad.items():
            with self.subTest(name):
                self.assertTrue(self.problems([rule]), f"{name} should be refused")

    def test_then_names_other_stages_of_a_stage_that_ends(self):
        def open_stage(q):
            q["stages"][0]["then"] = ["at_rest"]

        def unknown(q):
            q["stages"][-1]["then"] = ["nowhere"]

        def itself(q):
            q["stages"][-1]["then"] = ["left_behind"]

        for name, patch in {"an open stage": open_stage, "a stage that isn't there": unknown, "the stage itself": itself}.items():
            with self.subTest(name):
                self.assertTrue(self.problems(patch=patch), f"`then` on {name} should be refused")


class ConditionsParse(unittest.TestCase):
    def test_what_the_game_reads_passes(self):
        for expr in ["", "true", "flag.x", "not flag.x", "quest_days.the_sun_cake >= 3", "days_since.rang_the_bell > 1",
                     "quest.q == asked or quest.q == held", "night and (flag.a or not flag.b)", "attitude.nelu == friendly",
                     "guest:ireena and region:castle_ravenloft", "flag.strahd_invitation == \"accepted\"", "level >= 3 and gold > 10"]:
            with self.subTest(expr):
                self.assertEqual(dialogue_lint.condition_problems(expr), [])

    def test_what_it_cannot_read_is_named(self):
        for expr in ["flag.x and", "or flag.x", "(flag.x", "flag.x)", "flag.x >=", "banana", "flag.x flag.y", "not", "quest_days.x ="]:
            with self.subTest(expr):
                self.assertTrue(dialogue_lint.condition_problems(expr), f"'{expr}' should not read")


class ClosuresReach(unittest.TestCase):
    def reached(self, rules):
        s = story_reach.Story(ROOT)
        q = s.quests[QUEST]
        q["stages"].append({"id": "lost_x", "journal": "x", "ends": "failure"})
        q["closes"] = rules
        s.run()
        return ("quest", QUEST, "lost_x") in s.facts

    def test_a_closure_is_what_sets_its_stage(self):
        self.assertFalse(self.reached([]))
        self.assertTrue(self.reached([{"stage": "lost_x", "when": "quest_days.rose_and_thorn >= 3", "from": ["met"]}]))

    def test_a_closure_needs_a_stage_to_be_reached_and_a_condition_that_could_hold(self):
        self.assertFalse(self.reached([{"stage": "lost_x", "when": "true", "from": ["nonexistent"]}]))
        self.assertFalse(self.reached([{"stage": "lost_x", "when": "flag.never_set_flag_x"}]))


if __name__ == "__main__":
    unittest.main()
