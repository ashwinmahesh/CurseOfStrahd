"""The Godot slot pools and the slots the build lane keeps (tools/godot_slot.sh and tools/run_tests.py): which slot
numbers a development lane and the build lane may claim, that the shell and the Python halves agree, what a full pool does
to each, and how a run counts as the build lane's. Every test works in a temporary slot folder; no Godot, no lane.
Run with: make slots-test"""
import importlib.util
import itertools
import os
import subprocess
import sys
import tempfile
import threading
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "tools" / "godot_slot.sh"
SPEC = importlib.util.spec_from_file_location("run_tests_slots", REPO / "tools" / "run_tests.py")
rt = importlib.util.module_from_spec(SPEC)
sys.modules["run_tests_slots"] = rt
SPEC.loader.exec_module(rt)

KNOBS = ("BUILD_LANE", "BUILD_TEST_SLOTS", "BUILD_IMPORT_SLOTS", "GODOT_SLOTS", "TEST_SLOTS", "IMPORT_SLOTS")


def dead_pid() -> int:
    done = subprocess.Popen(["true"])
    done.wait()
    return done.pid


class Case(unittest.TestCase):
    """A temporary slot folder, and none of the owner's knobs in the environment."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="slots_test_")).resolve()
        self.addCleanup(lambda: subprocess.run(["rm", "-rf", str(self.tmp)]))
        self.root = self.tmp / "slots"
        saved = {k: os.environ.pop(k, None) for k in KNOBS}
        self.addCleanup(lambda: [os.environ.pop(k, None) for k in KNOBS])
        self.addCleanup(lambda: os.environ.update({k: v for k, v in saved.items() if v is not None}))
        old_root, old_repo = rt.SLOT_ROOT, rt.ROOT
        rt.SLOT_ROOT = str(self.root)
        rt.ROOT = str(self.tmp / "checkout")
        (self.tmp / "checkout" / ".godot").mkdir(parents=True)
        # The shell reads the build-lane marker of the checkout its script is in, so it runs from a copy in the temporary
        # one, not from this folder (which holds the marker where the builder has opted in).
        (self.tmp / "checkout" / "tools").mkdir()
        self.script = self.tmp / "checkout" / "tools" / "godot_slot.sh"
        self.script.write_text(SCRIPT.read_text())
        self.addCleanup(lambda: setattr(rt, "SLOT_ROOT", old_root))
        self.addCleanup(lambda: setattr(rt, "ROOT", old_repo))
        rt._told.clear()

    def held(self, pool: str) -> list[int]:
        d = self.root / pool
        return sorted(int(p.name) for p in d.iterdir()) if d.is_dir() else []

    def take(self, pool: str, limit: int, giveup: bool = True):
        """One take_slot call that gives up at once when every slot it may claim is in use."""
        flag = threading.Event()
        if giveup:
            flag.set()
        return rt.take_slot(pool, limit, flag)

    @staticmethod
    def reap(proc: subprocess.Popen) -> None:
        proc.kill()
        proc.wait()
        for pipe in (proc.stdout, proc.stderr):
            if pipe:
                pipe.close()

    def sh(self, snippet: str, script: Path | None = None, **env) -> subprocess.CompletedProcess:
        script = script or self.script
        full = {k: v for k, v in os.environ.items() if k not in KNOBS}
        full.update(STRAHD_SLOT_ROOT=str(self.root), **{k: str(v) for k, v in env.items()})
        return subprocess.run(["bash", "-c", '. "%s"; %s' % (script, snippet)], capture_output=True, text=True,
                              env=full, cwd=str(self.tmp))


class Layout(Case):
    def test_a_development_lane_never_claims_the_top_slots(self):
        self.assertEqual(rt.slot_candidates("test", 8, False), [1, 2, 3])
        self.assertEqual(rt.slot_candidates("import", 3, False), [1, 2])

    def test_the_build_lane_tries_the_reserved_slots_first_and_may_use_them_all(self):
        self.assertEqual(rt.slot_candidates("test", 8, True), [4, 5, 6, 7, 8, 1, 2, 3])
        self.assertEqual(rt.slot_candidates("import", 3, True), [3, 1, 2])

    def test_the_total_is_unchanged(self):
        for pool, size in (("test", 8), ("import", 3)):
            lanes, build = rt.slot_candidates(pool, size, False), rt.slot_candidates(pool, size, True)
            self.assertEqual(sorted(build), list(range(1, size + 1)), pool)
            self.assertEqual(sorted(set(build) - set(lanes)), rt.reserved_slots(pool), pool)

    def test_a_smaller_limit_still_cuts_a_run_down(self):
        self.assertEqual(rt.slot_candidates("test", 2, False), [1, 2])
        self.assertEqual(rt.slot_candidates("test", 2, True), [4, 5])
        self.assertEqual(rt.slot_candidates("test", 6, True), [4, 5, 6, 7, 8, 1])
        self.assertEqual(rt.slot_candidates("test", 0, False), [1])

    def test_a_bigger_limit_adds_slots_for_both(self):
        self.assertEqual(rt.slot_candidates("test", 10, False), [1, 2, 3, 9, 10])
        self.assertEqual(rt.slot_candidates("test", 10, True), [4, 5, 6, 7, 8, 1, 2, 3, 9, 10])

    def test_the_reserve_is_set_by_its_variable_and_always_leaves_the_lanes_a_slot(self):
        os.environ["BUILD_TEST_SLOTS"] = "0"
        self.assertEqual(rt.slot_candidates("test", 8, False), list(range(1, 9)))
        os.environ["BUILD_TEST_SLOTS"] = "99"
        self.assertEqual(rt.slot_candidates("test", 8, False), [1])
        self.assertEqual(rt.slot_candidates("test", 8, True), [2, 3, 4, 5, 6, 7, 8, 1])
        os.environ["BUILD_TEST_SLOTS"] = "two"
        self.assertEqual(rt.slot_candidates("test", 8, False), [1, 2, 3])
        os.environ["BUILD_TEST_SLOTS"] = "3"
        self.assertEqual(rt.slot_candidates("test", 8, False), [1, 2, 3, 4, 5])
        os.environ["BUILD_IMPORT_SLOTS"] = "2"
        self.assertEqual(rt.slot_candidates("import", 3, False), [1])

    def test_the_shell_and_python_agree_on_every_case(self):
        settings = ({}, {"BUILD_TEST_SLOTS": "0", "BUILD_IMPORT_SLOTS": "0"}, {"BUILD_TEST_SLOTS": "2", "BUILD_IMPORT_SLOTS": "2"},
                    {"BUILD_TEST_SLOTS": "99", "BUILD_IMPORT_SLOTS": "99"}, {"BUILD_TEST_SLOTS": "x", "BUILD_IMPORT_SLOTS": "x"})
        for env, (pool, limit), build in itertools.product(settings, itertools.product(("test", "import"), (1, 2, 3, 5, 8, 12)),
                                                           (False, True)):
            for k in ("BUILD_TEST_SLOTS", "BUILD_IMPORT_SLOTS"):
                os.environ.pop(k, None)
            os.environ.update(env)
            want = " ".join(map(str, rt.slot_candidates(pool, limit, build)))
            got = self.sh('slot_candidates %s %d %d' % (pool, limit, 1 if build else 0), **env)
            self.assertEqual(got.stdout.strip(), want, (env, pool, limit, build, got.stderr))


class Python(Case):
    def test_development_lanes_stop_at_their_slots_while_the_reserved_ones_are_free(self):
        got = [self.take("test", 8) for _ in range(4)]
        self.assertEqual(sorted(Path(g).name for g in got[:3]), ["1", "2", "3"])
        self.assertIsNone(got[3])
        self.assertEqual(self.held("test"), [1, 2, 3])

    def test_the_build_lane_gets_a_slot_at_once_when_the_lanes_have_filled_theirs(self):
        for _ in range(3):
            self.take("test", 8)
        os.environ["BUILD_LANE"] = "1"
        got = [Path(self.take("test", 8)).name for _ in range(5)]
        self.assertEqual(sorted(got), ["4", "5", "6", "7", "8"])
        self.assertIsNone(self.take("test", 8))
        self.assertEqual(self.held("test"), list(range(1, 9)))

    def test_the_build_lane_takes_the_reserved_slots_first_then_borrows_the_lanes_free_ones(self):
        os.environ["BUILD_LANE"] = "1"
        names = [Path(self.take("test", 8)).name for _ in range(8)]
        self.assertEqual(sorted(names[:5]), ["4", "5", "6", "7", "8"])
        self.assertEqual(sorted(names[5:]), ["1", "2", "3"])
        self.assertIsNone(self.take("test", 8))

    def test_a_lane_waits_for_a_lane_slot_even_when_the_build_lane_is_idle(self):
        for _ in range(3):
            self.take("test", 8)
        waited = self.take("test", 8)
        self.assertIsNone(waited)
        self.assertEqual(self.held("test"), [1, 2, 3])

    def test_the_import_pool_keeps_one_slot_too(self):
        got = [self.take("import", 3) for _ in range(3)]
        self.assertEqual(sorted(Path(g).name for g in got[:2]), ["1", "2"])
        self.assertIsNone(got[2])
        os.environ["BUILD_LANE"] = "1"
        self.assertEqual(Path(self.take("import", 3)).name, "3")
        self.assertIsNone(self.take("import", 3))

    def test_only_the_build_lanes_slots_are_marked(self):
        lane = Path(self.take("test", 8))
        os.environ["BUILD_LANE"] = "1"
        build = Path(self.take("test", 8))
        self.assertFalse((lane / "build").exists())
        self.assertEqual((build / "build").read_text().strip(), "build")
        self.assertEqual((build / "pid").read_text(), str(os.getpid()))

    def test_a_slot_whose_holder_is_gone_is_cleared_for_either_kind_of_run(self):
        for n in (1, 4, 5, 6, 7, 8):
            d = self.root / "test" / str(n)
            d.mkdir(parents=True)
            (d / "pid").write_text(str(dead_pid()))
        self.assertEqual(Path(self.take("test", 1)).name, "1")
        os.environ["BUILD_LANE"] = "1"
        got = Path(self.take("test", 5))
        self.assertIn(got.name, ("4", "5", "6", "7", "8"))
        self.assertEqual((got / "pid").read_text(), str(os.getpid()))

    def test_the_cap_off_takes_nothing(self):
        os.environ["GODOT_SLOTS"] = "off"
        self.assertEqual(self.take("test", 8), "")
        self.assertEqual(self.held("test"), [])

    def test_the_waiting_note_says_who_the_slots_are_for(self):
        import contextlib
        import io
        out = io.StringIO()
        for _ in range(3):
            self.take("test", 8)
        flag = threading.Event()
        threading.Timer(0.5, flag.set).start()   # the note comes on the first pass that finds every slot in use
        with contextlib.redirect_stdout(out):
            self.assertIsNone(rt.take_slot("test", 8, flag))
        self.assertIn("3 at once for the development lanes", out.getvalue())
        self.assertIn("kept for the build lane", out.getvalue())


class Marker(Case):
    def test_the_environment_variable_makes_a_build_run(self):
        self.assertFalse(rt.is_build_lane())
        for value, want in (("1", True), ("yes", True), ("0", False), ("", False)):
            os.environ["BUILD_LANE"] = value
            self.assertEqual(rt.is_build_lane(), want, value)

    def test_a_folder_marked_with_its_own_path_is_the_build_lanes(self):
        (Path(rt.ROOT) / ".godot" / "build-lane").write_text(os.path.realpath(rt.ROOT) + "\n")
        self.assertTrue(rt.is_build_lane())

    def test_a_marker_copied_from_another_folder_counts_for_nothing(self):
        (Path(rt.ROOT) / ".godot" / "build-lane").write_text("/Users/someone/CurseOfStrahdGame-spare1\n")
        self.assertFalse(rt.is_build_lane())

    def test_the_shell_reads_the_same_marker(self):
        checkout = self.tmp / "folder"
        (checkout / "tools").mkdir(parents=True)
        (checkout / ".godot").mkdir()
        script = checkout / "tools" / "godot_slot.sh"
        script.write_text(SCRIPT.read_text())
        self.assertNotEqual(self.sh("slot_build_lane", script).returncode, 0)
        (checkout / ".godot" / "build-lane").write_text(str(checkout.resolve()) + "\n")
        self.assertEqual(self.sh("slot_build_lane", script).returncode, 0)
        (checkout / ".godot" / "build-lane").write_text("/elsewhere\n")
        self.assertNotEqual(self.sh("slot_build_lane", script).returncode, 0)
        self.assertEqual(self.sh("slot_build_lane", script, BUILD_LANE="1").returncode, 0)
        self.assertNotEqual(self.sh("slot_build_lane", script, BUILD_LANE="0").returncode, 0)


class Shell(Case):
    LOOP = 'mkdir -p "$slot_root/test"; for _ in %s; do if try_slot test 8; then echo "${held_slot##*/}"; else echo none; fi; done'

    def test_try_slot_follows_the_same_rules(self):
        # One shell holds what it takes (its PID is alive), so each pass moves on to the next free slot.
        got = self.sh(self.LOOP % "1 2 3 4")
        self.assertEqual(got.stdout.split(), ["1", "2", "3", "none"])
        self.assertFalse((self.root / "test" / "1" / "build").exists())

    def test_the_build_lane_in_the_shell_takes_the_reserved_slots_first(self):
        got = self.sh(self.LOOP % "1 2 3 4 5 6 7 8 9", BUILD_LANE="1")
        self.assertEqual(got.stdout.split(), ["4", "5", "6", "7", "8", "1", "2", "3", "none"])
        self.assertTrue((self.root / "test" / "4" / "build").exists())

    def test_a_slot_the_shell_holds_blocks_python_and_the_other_way_round(self):
        holder = subprocess.Popen(["bash", "-c", '. "%s"; mkdir -p "$slot_root/test"; try_slot test 8; echo "${held_slot##*/}"; sleep 20' % self.script],
                                  stdout=subprocess.PIPE, text=True,
                                  env=dict(os.environ, STRAHD_SLOT_ROOT=str(self.root), BUILD_LANE="1"))
        self.addCleanup(self.reap, holder)
        first = holder.stdout.readline().strip()
        self.assertIn(first, ("4", "5", "6", "7", "8"))
        os.environ["BUILD_LANE"] = "1"
        got = {Path(self.take("test", 8)).name for _ in range(4)}
        self.assertEqual(got | {first}, {"4", "5", "6", "7", "8"})

    def test_take_slot_waits_in_the_shell_and_says_so(self):
        for n in range(1, 4):
            d = self.root / "test" / str(n)
            d.mkdir(parents=True)
            (d / "pid").write_text(str(os.getpid()))
        proc = subprocess.Popen(["bash", "-c", '. "%s"; take_slot test 8; echo got' % self.script], stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, text=True, env=dict(os.environ, STRAHD_SLOT_ROOT=str(self.root)))
        self.addCleanup(self.reap, proc)
        try:
            proc.wait(timeout=3)
            self.fail("a lane took a reserved slot")
        except subprocess.TimeoutExpired:
            pass
        proc.kill()
        proc.wait()
        self.assertIn("3 at once for the development lanes", proc.stderr.read())
        self.assertEqual(self.held("test"), [1, 2, 3])


if __name__ == "__main__":
    unittest.main()
