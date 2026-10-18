"""tools/data/fail_routes.py: the checker judges made-up conversations right, and the game's own conversations pass."""
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "data"))
import fail_routes  # noqa: E402


class FailRoutes(unittest.TestCase):
    def test_selftest(self):
        self.assertEqual(fail_routes.selftest(), [])

    def test_the_game_has_no_unlisted_lock(self):
        self.assertEqual(fail_routes.findings(ROOT), [])

    def test_allowed_entries_are_still_needed(self):
        # A stale entry hides nothing but says something false: each must still be a finding without the list.
        files, quests = fail_routes.load(ROOT)
        live = {f"{k}:{n}:{s}:{m[0]}.{m[1]}" for k, n, s, _, m in fail_routes.analyse(files, quests)}
        self.assertEqual(sorted(set(fail_routes.ALLOWED) - live), [])


if __name__ == "__main__":
    unittest.main()
