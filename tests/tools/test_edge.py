"""make run's edge build (tools/edge/edge.py): the manifest, the assembly of main plus unmerged branches, and the copy of
the owner's saves it runs on. Every test works in a temporary repository and a temporary home; no Godot, no lane.
Run with: make edge-test"""
import argparse
import contextlib
import importlib.util
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("edge", Path(__file__).resolve().parents[2] / "tools/edge/edge.py")
edge = importlib.util.module_from_spec(SPEC)
sys.modules["edge"] = edge   # dataclasses look their module up here
SPEC.loader.exec_module(edge)

ENV = dict(os.environ, GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_SYSTEM="/dev/null", LC_ALL="C")


def git(repo, *args):
    done = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True, env=ENV)
    assert done.returncode == 0, done.stderr
    return done.stdout.strip()


def commit(repo, files, message):
    for name, text in files.items():
        path = Path(repo) / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        git(repo, "add", name)
    git(repo, "commit", "-q", "-m", message)
    return git(repo, "rev-parse", "HEAD")


class Repo:
    """main with a shared file and a save version, plus the branches the cases need."""

    def __init__(self, test):
        self.tmp = Path(tempfile.mkdtemp(prefix="edge_test_")).resolve()
        test.addCleanup(lambda: subprocess.run(["rm", "-rf", str(self.tmp)]))
        self.repo = self.tmp / "game"
        self.repo.mkdir()
        git(self.repo, "init", "-q", "-b", "main")
        git(self.repo, "config", "user.name", "Test")
        git(self.repo, "config", "user.email", "test@example.com")
        commit(self.repo, {"shared.txt": "one\ntwo\nthree\n", "core/game_state.gd": "const SAVE_VERSION := 2\n"}, "main")
        self.wt = self.tmp / "edge_wt"
        git(self.repo, "worktree", "add", "-q", "--detach", str(self.wt), "main")

    def branch(self, name, files, message=None, start="main"):
        git(self.repo, "checkout", "-q", "-b", name, start)
        sha = commit(self.repo, files, message or name)
        git(self.repo, "checkout", "-q", "main")
        return sha

    def entries(self, *names):
        return edge.resolve(self.repo, names)

    def build(self, *names, force=False):
        base = git(self.repo, "rev-parse", "main")
        return edge.assemble(self.wt, "main", base, self.entries(*names), force)


class ManifestTests(unittest.TestCase):
    def setUp(self):
        self.path = Path(tempfile.mkdtemp(prefix="edge_manifest_")) / "edge" / "branches.txt"
        self.addCleanup(lambda: subprocess.run(["rm", "-rf", str(self.path.parent.parent)]))

    def test_a_missing_file_lists_nothing(self):
        self.assertEqual(edge.read_manifest(self.path), [])

    def test_add_makes_the_file_with_its_header_and_keeps_order(self):
        self.assertEqual(edge.add_branches(self.path, ["b", "a", "b"]), ["b", "a"])
        self.assertEqual(edge.read_manifest(self.path), ["b", "a"])
        self.assertTrue(self.path.read_text().startswith("# Branches the edge build"))

    def test_add_skips_what_is_listed_and_remove_keeps_comments_and_the_rest(self):
        self.path.parent.mkdir(parents=True)
        self.path.write_text("# first\nwalls-look  # the windows\n\nitem-audit\n")
        self.assertEqual(edge.add_branches(self.path, ["walls-look", "npc-plan"]), ["npc-plan"])
        self.assertEqual(edge.remove_branches(self.path, ["walls-look", "nothing"]), ["walls-look"])
        self.assertEqual(edge.read_manifest(self.path), ["item-audit", "npc-plan"])
        self.assertIn("# first", self.path.read_text())
        self.assertNotIn("the windows", self.path.read_text())

    def test_remove_from_no_file_is_quiet(self):
        self.assertEqual(edge.remove_branches(self.path, ["x"]), [])


class AssemblyTests(unittest.TestCase):
    def setUp(self):
        self.r = Repo(self)

    def status_of(self, build):
        return {e.name: e.status for e in build.entries}

    def test_independent_branches_are_merged_in_order(self):
        self.r.branch("walls", {"walls.txt": "w\n"})
        self.r.branch("items", {"items.txt": "i\n"})
        build = self.r.build("walls", "items")
        self.assertEqual(self.status_of(build), {"walls": "merged", "items": "merged"})
        self.assertTrue((self.r.wt / "walls.txt").is_file() and (self.r.wt / "items.txt").is_file())
        self.assertEqual(git(self.r.wt, "rev-parse", "HEAD"), build.head)
        self.assertEqual(git(self.r.wt, "status", "--porcelain", "--untracked-files=no"), "")

    def test_the_repository_branches_do_not_move(self):
        self.r.branch("walls", {"walls.txt": "w\n"})
        before = git(self.r.repo, "for-each-ref", "--format=%(refname) %(objectname)")
        self.r.build("walls")
        self.assertEqual(git(self.r.repo, "for-each-ref", "--format=%(refname) %(objectname)"), before)

    def test_a_branch_already_in_main_is_skipped(self):
        self.r.branch("old", {"old.txt": "o\n"})
        git(self.r.repo, "merge", "-q", "--no-ff", "-m", "merge old", "old")
        build = self.r.build("old")
        self.assertEqual(self.status_of(build), {"old": "in-main"})
        self.assertEqual(build.head, git(self.r.repo, "rev-parse", "main"))

    def test_a_branch_inside_an_earlier_one_is_skipped(self):
        first = self.r.branch("plan", {"plan.txt": "1\n"})
        git(self.r.repo, "checkout", "-q", "-b", "plan2", "plan")
        commit(self.r.repo, {"plan2.txt": "2\n"}, "more")
        git(self.r.repo, "checkout", "-q", "main")
        build = self.r.build("plan2", "plan")
        self.assertEqual(self.status_of(build), {"plan2": "merged", "plan": "in-edge"})
        self.assertEqual(first, next(e.sha for e in build.entries if e.name == "plan"))

    def test_a_conflict_is_named_and_left_out_and_the_rest_still_merge(self):
        self.r.branch("a", {"shared.txt": "one\nA\nthree\n"})
        self.r.branch("b", {"shared.txt": "one\nB\nthree\n"})
        self.r.branch("c", {"c.txt": "c\n"})
        build = self.r.build("a", "b", "c")
        self.assertEqual(self.status_of(build), {"a": "merged", "b": "conflict", "c": "merged"})
        b = build.entries[1]
        self.assertIn("shared.txt", b.detail)
        self.assertEqual((self.r.wt / "shared.txt").read_text(), "one\nA\nthree\n")
        self.assertEqual(git(self.r.wt, "status", "--porcelain", "--untracked-files=no"), "")
        self.assertFalse((Path(git(self.r.wt, "rev-parse", "--absolute-git-dir")) / "MERGE_HEAD").exists())

    def test_a_missing_branch_is_named_and_the_rest_still_merge(self):
        self.r.branch("a", {"a.txt": "a\n"})
        build = self.r.build("typo", "a")
        self.assertEqual(self.status_of(build), {"typo": "missing", "a": "merged"})

    def test_the_build_starts_from_the_base_every_time(self):
        self.r.branch("a", {"a.txt": "a\n"})
        self.r.build("a")
        build = self.r.build()
        self.assertFalse((self.r.wt / "a.txt").exists())
        self.assertEqual(build.head, git(self.r.repo, "rev-parse", "main"))

    def test_the_same_base_and_tips_leave_the_folder_alone(self):
        self.r.branch("a", {"a.txt": "a\n"})
        first = self.r.build("a")
        (self.r.wt / "a.txt").write_text("touched\n")   # a marker: a rebuild would put the branch's file back
        again = self.r.build("a")
        self.assertTrue(again.reused)
        self.assertEqual(again.head, first.head)
        self.assertEqual((self.r.wt / "a.txt").read_text(), "touched\n")
        self.assertEqual(self.status_of(again), {"a": "merged"})
        self.assertFalse(self.r.build("a", force=True).reused)
        self.assertEqual((self.r.wt / "a.txt").read_text(), "a\n")

    def test_a_branch_with_a_new_commit_rebuilds(self):
        self.r.branch("a", {"a.txt": "a\n"})
        self.r.build("a")
        git(self.r.repo, "checkout", "-q", "a")
        commit(self.r.repo, {"a2.txt": "more\n"}, "a again")
        git(self.r.repo, "checkout", "-q", "main")
        build = self.r.build("a")
        self.assertFalse(build.reused)
        self.assertTrue((self.r.wt / "a2.txt").is_file())

    def test_a_merge_left_half_done_is_cleared_by_the_next_build(self):
        self.r.branch("a", {"shared.txt": "one\nA\nthree\n"})
        git(self.r.repo, "checkout", "-q", "main")
        commit(self.r.repo, {"shared.txt": "one\nMAIN\nthree\n"}, "main moves")
        subprocess.run(["git", "-C", str(self.r.wt), "checkout", "-q", "--detach", "main"], env=ENV)
        subprocess.run(["git", "-C", str(self.r.wt), "merge", "--no-edit", "a"], capture_output=True, env=ENV)
        build = self.r.build()
        self.assertEqual(git(self.r.wt, "status", "--porcelain", "--untracked-files=no"), "")
        self.assertEqual(build.head, git(self.r.repo, "rev-parse", "main"))

    def test_a_branch_that_raises_the_save_version_is_flagged(self):
        self.r.branch("migrates", {"core/game_state.gd": "const SAVE_VERSION := 3\n"})
        self.r.branch("plain", {"p.txt": "p\n"})
        build = self.r.build("migrates", "plain")
        self.assertEqual(build.save_version, 2)
        self.assertEqual([e.save_version for e in build.entries], [3, 2])
        self.assertEqual(self.status_of(build), {"migrates": "merged", "plain": "merged"})

    def test_a_base_without_the_save_file_reads_none(self):
        self.assertIsNone(edge.save_version(self.r.repo, "main:core"))
        self.assertEqual(edge.save_version(self.r.repo, "main"), 2)


class DataTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="edge_data_")).resolve()
        self.addCleanup(lambda: subprocess.run(["rm", "-rf", str(self.tmp)]))
        self.support = self.tmp / "Library" / "Application Support"
        self.real = self.support / "Godot" / "app_userdata" / "Curse of Strahd"
        self.fan = self.support / "Curse of Strahd Fan Game"
        self.edge = self.support / "Curse of Strahd Edge"
        (self.real / "saves" / "errors").mkdir(parents=True)
        (self.real / "saves" / "slot_1.json").write_text('{"v": 2}')
        (self.real / "saves" / "autosave_1.json").write_text('{"v": 2, "auto": true}')
        (self.real / "settings.cfg").write_text("[game]\nturn_based=false\n")
        (self.real / "shader_cache").mkdir()
        (self.real / "shader_cache" / "real").write_text("cache")
        self.fan.mkdir(parents=True)
        (self.fan / "keep.json").write_text("{}")

    def snapshot(self, folder):
        return {str(p.relative_to(folder)): (p.read_bytes(), p.stat().st_mtime_ns)
                for p in sorted(folder.rglob("*")) if p.is_file()}

    def test_the_copy_matches_the_saves_and_settings_and_the_originals_are_untouched(self):
        before, fan_before = self.snapshot(self.real), self.snapshot(self.fan)
        edge.refresh_data(self.real, self.edge, [self.fan])
        self.assertEqual((self.edge / "saves" / "slot_1.json").read_text(), '{"v": 2}')
        self.assertEqual((self.edge / "settings.cfg").read_text(), "[game]\nturn_based=false\n")
        self.assertFalse((self.edge / "shader_cache").exists())   # caches are the build's own
        self.assertEqual(self.snapshot(self.real), before)
        self.assertEqual(self.snapshot(self.fan), fan_before)

    def test_saves_made_in_the_edge_are_replaced_and_its_caches_stay(self):
        edge.refresh_data(self.real, self.edge, [self.fan])
        (self.edge / "saves" / "made_in_edge.json").write_text("{}")
        (self.edge / "saves" / "slot_1.json").write_text("changed in the edge")
        (self.edge / "shader_cache").mkdir()
        (self.edge / "shader_cache" / "mine").write_text("cache")
        edge.refresh_data(self.real, self.edge, [self.fan])
        self.assertFalse((self.edge / "saves" / "made_in_edge.json").exists())
        self.assertEqual((self.edge / "saves" / "slot_1.json").read_text(), '{"v": 2}')
        self.assertTrue((self.edge / "shader_cache" / "mine").is_file())

    def test_the_copy_keeps_the_save_times_the_game_sorts_by(self):
        old = self.real / "saves" / "slot_1.json"
        os.utime(old, (1_700_000_000, 1_700_000_000))
        edge.refresh_data(self.real, self.edge, [self.fan])
        self.assertEqual(int((self.edge / "saves" / "slot_1.json").stat().st_mtime), 1_700_000_000)

    def test_no_saves_yet_makes_an_empty_folder(self):
        subprocess.run(["rm", "-rf", str(self.real)])
        edge.refresh_data(self.real, self.edge, [self.fan])
        self.assertTrue(self.edge.is_dir())
        self.assertFalse((self.edge / "saves").exists())

    def test_a_destination_that_is_real_game_data_is_refused_and_nothing_is_written(self):
        before = self.snapshot(self.real)
        for bad in (self.real, self.real / "saves", self.fan, self.support / "Godot", self.support):
            with self.assertRaises(edge.EdgeError, msg=str(bad)):
                edge.refresh_data(self.real, bad, [self.fan])
        with self.assertRaises(edge.EdgeError):
            edge.refresh_data(self.real, self.support / "Godot" / "app_userdata" / ".." / "app_userdata" / "Curse of Strahd", [self.fan])
        self.assertEqual(self.snapshot(self.real), before)

    def test_override_cfg_points_the_game_at_the_edge_folder(self):
        text = edge.override_text("Curse of Strahd", "Curse of Strahd Edge")
        self.assertIn("[application]", text)
        self.assertIn('config/custom_user_dir_name="Curse of Strahd Edge"', text)
        self.assertIn("config/use_custom_user_dir=true", text)
        self.assertIn('config/name="Curse of Strahd (edge)"', text)


class RunTests(unittest.TestCase):
    def test_the_game_starts_as_make_run_starts_it(self):
        cfg = edge.Config(repo=Path("/x"), home=Path("/h"), root=Path("/r"), base="main", godot="/g/Godot",
                          data_name="d", support=Path("/s"), keep_data=False, no_run=False)
        argv, env = edge.launch_command(cfg, Path("/r/CurseOfStrahdGame-edge"))
        self.assertEqual(argv, ["/g/Godot", "--path", "/r/CurseOfStrahdGame-edge"])
        self.assertEqual(env["__CFBundleIdentifier"], "org.godotengine.godot")

    def test_what_needs_an_import_follows_the_makefile_rule(self):
        tmp = Path(tempfile.mkdtemp(prefix="edge_import_")).resolve()
        self.addCleanup(lambda: subprocess.run(["rm", "-rf", str(tmp)]))
        (tmp / ".godot").mkdir()
        (tmp / "builds").mkdir()
        self.assertTrue(edge.needs_import(tmp))                       # no stamp yet
        stamp = tmp / ".godot" / ".last_import"
        stamp.touch()
        os.utime(stamp, (2_000_000_000, 2_000_000_000))
        (tmp / "notes.md").write_text("x")
        (tmp / "builds" / "newer.png").write_text("x")
        (tmp / ".godot" / "newer.gd").write_text("x")
        self.assertFalse(edge.needs_import(tmp))                      # only ignored folders and other kinds are newer
        os.utime(tmp / "builds" / "newer.png", (2_000_000_100, 2_000_000_100))
        os.utime(tmp / "notes.md", (2_000_000_100, 2_000_000_100))
        self.assertFalse(edge.needs_import(tmp))
        (tmp / "story.gd").write_text("x")
        os.utime(tmp / "story.gd", (2_000_000_100, 2_000_000_100))
        self.assertTrue(edge.needs_import(tmp))

    def test_one_assembly_at_a_time(self):
        tmp = Path(tempfile.mkdtemp(prefix="edge_lock_")).resolve()
        self.addCleanup(lambda: subprocess.run(["rm", "-rf", str(tmp)]))
        with edge.Lock(tmp / "assemble.lock"):
            with self.assertRaises(edge.EdgeError):
                with edge.Lock(tmp / "assemble.lock"):
                    pass
        with edge.Lock(tmp / "assemble.lock"):   # released after the first
            pass
        (tmp / "assemble.lock").mkdir()
        (tmp / "assemble.lock" / "pid").write_text("999999")   # a PID nothing has: a stale lock is cleared
        with edge.Lock(tmp / "assemble.lock"):
            pass

    def test_the_record_lists_what_the_last_build_held(self):
        r = Repo(self)
        r.branch("a", {"a.txt": "a\n"})
        r.build("a", "typo")
        record = json.loads((r.wt / edge.RECORD).read_text())
        self.assertEqual([(e["name"], e["status"]) for e in record["entries"]], [("a", "merged"), ("typo", "missing")])
        self.assertEqual(record["base_sha"], git(r.repo, "rev-parse", "main"))


class RunFlowTests(unittest.TestCase):
    """cmd_run end to end with a stub import script and no game: the glue between the pieces."""

    def setUp(self):
        self.r = Repo(self)
        tools = self.r.repo / "tools"
        tools.mkdir()
        (tools / "import.sh").write_text("#!/bin/sh\necho imported >> \"$(dirname \"$0\")/../builds/imports.txt\"\n")
        (tools / "import.sh").chmod(0o755)
        (self.r.repo / "project.godot").write_text('config_version=5\n\n[application]\n\nconfig/name="Curse of Strahd"\n')
        git(self.r.repo, "add", "tools/import.sh", "project.godot")
        git(self.r.repo, "update-index", "--chmod=+x", "tools/import.sh")
        git(self.r.repo, "commit", "-q", "-m", "tools")
        subprocess.run(["rm", "-rf", str(self.r.wt)])
        git(self.r.repo, "worktree", "prune")
        self.root = self.r.tmp / "root"
        self.root.mkdir()
        self.wt = self.root / "CurseOfStrahdGame-edge"
        git(self.r.repo, "worktree", "add", "-q", "--detach", str(self.wt), "main")
        (Path(git(self.wt, "rev-parse", "--absolute-git-dir")) / edge.MARKER).write_text("edge\n")
        self.support = self.r.tmp / "Library" / "Application Support"
        self.real = self.support / "Godot" / "app_userdata" / "Curse of Strahd"
        (self.real / "saves").mkdir(parents=True)
        (self.real / "saves" / "slot_1.json").write_text("{}")
        (self.real / "settings.cfg").write_text("[game]\n")
        self.cfg = edge.Config(repo=self.r.repo, home=self.r.tmp / "home", root=self.root, base="main", godot="/bin/true",
                               data_name="Curse of Strahd Edge", support=self.support, keep_data=False, no_run=True)
        self.args = argparse.Namespace(cmd="build")

    def run_edge(self, cfg=None):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            status = edge.cmd_run(cfg or self.cfg, self.args)
        return status, out.getvalue()

    def snapshot(self):
        return {str(p.relative_to(self.real)): (p.read_bytes(), p.stat().st_mtime_ns)
                for p in sorted(self.real.rglob("*")) if p.is_file()}

    def test_a_build_lists_its_branches_copies_the_saves_imports_and_leaves_the_originals_alone(self):
        self.r.branch("walls", {"walls.txt": "w\n"})
        self.r.branch("clash", {"shared.txt": "x\n"})
        self.r.branch("other", {"shared.txt": "y\n"})
        edge.add_branches(self.cfg.manifest, ["walls", "clash", "other", "gone"])
        before = self.snapshot()
        status, out = self.run_edge()
        self.assertEqual(status, 0)
        for text in ("walls", "merged in", "other", "LEFT OUT", "gone", "no such branch", "SAVE_VERSION 2",
                     "Curse of Strahd Edge", "only read, never written"):
            self.assertIn(text, out)
        self.assertIn(edge.short(git(self.r.repo, "rev-parse", "walls")), out)
        self.assertTrue((self.wt / "walls.txt").is_file())
        override = (self.wt / "override.cfg").read_text()
        self.assertIn('config/custom_user_dir_name="Curse of Strahd Edge"', override)
        self.assertEqual((self.support / "Curse of Strahd Edge" / "saves" / "slot_1.json").read_text(), "{}")
        self.assertEqual((self.wt / "builds" / "imports.txt").read_text(), "imported\n")
        self.assertTrue((self.wt / ".godot" / ".last_import").is_file())
        self.assertEqual(self.snapshot(), before)

    def test_a_second_run_with_nothing_new_neither_merges_nor_imports(self):
        self.r.branch("walls", {"walls.txt": "w\n"})
        edge.add_branches(self.cfg.manifest, ["walls"])
        self.run_edge()
        head = git(self.wt, "rev-parse", "HEAD")
        status, out = self.run_edge()
        self.assertEqual(status, 0)
        self.assertIn("nothing to merge", out)
        self.assertEqual(git(self.wt, "rev-parse", "HEAD"), head)
        self.assertEqual((self.wt / "builds" / "imports.txt").read_text(), "imported\n")

    def test_keeping_the_edge_saves_leaves_them_alone(self):
        self.run_edge()
        (self.support / "Curse of Strahd Edge" / "saves" / "made_in_edge.json").write_text("{}")
        self.cfg.keep_data = True
        status, out = self.run_edge()
        self.assertTrue((self.support / "Curse of Strahd Edge" / "saves" / "made_in_edge.json").is_file())
        self.assertIn("EDGE_KEEP_DATA=1", out)

    def test_a_data_folder_that_is_the_real_one_stops_before_anything_is_touched(self):
        self.cfg.data_name = "Godot/app_userdata/Curse of Strahd"
        head = git(self.wt, "rev-parse", "HEAD")
        with self.assertRaises(edge.EdgeError):
            self.run_edge()
        self.assertEqual(git(self.wt, "rev-parse", "HEAD"), head)
        self.assertFalse((self.wt / "override.cfg").exists())

    def test_a_folder_that_is_not_the_edge_worktree_is_refused(self):
        (Path(git(self.wt, "rev-parse", "--absolute-git-dir")) / edge.MARKER).unlink()
        with self.assertRaises(edge.EdgeError):
            self.run_edge()

    def test_a_failed_import_stops_the_run_and_leaves_no_stamp(self):
        (self.r.repo / "tools" / "import.sh").write_text("#!/bin/sh\nexit 75\n")   # a refused import (disk nearly full)
        git(self.r.repo, "commit", "-q", "-am", "refuse")
        status, out = self.run_edge()
        self.assertEqual(status, 75)
        self.assertFalse((self.wt / ".godot" / ".last_import").exists())


if __name__ == "__main__":
    unittest.main()
