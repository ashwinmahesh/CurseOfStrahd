"""The host quick check follows changed engine tests across the submodule boundary."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('check', Path(__file__).resolve().parents[2] / 'tools/check.py')
check = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(check)


class EngineCheckTests(unittest.TestCase):
    def test_dirty_engine_tests_and_the_moved_compile_test_are_checked(self):
        with tempfile.TemporaryDirectory() as directory:
            host = Path(directory)
            engine = host / 'addons/dnd_core'
            engine.mkdir(parents=True)

            def git(root, *args):
                return subprocess.check_output(['git', '-C', str(root), *args], stderr=subprocess.DEVNULL, text=True)

            for repo in [host, engine]:
                git(repo, 'init', '-q')
                git(repo, 'config', 'user.name', 'Test')
                git(repo, 'config', 'user.email', 'test@example.invalid')
            unit = engine / 'tests/unit'
            unit.mkdir(parents=True)
            (unit / 'test_scripts_compile.gd').write_text('extends TestCase\n')
            git(engine, 'add', '.')
            git(engine, 'commit', '-qm', 'engine base')
            pin = git(engine, 'rev-parse', 'HEAD').strip()
            git(host, 'update-index', '--add', '--cacheinfo', '160000,' + pin + ',addons/dnd_core')
            git(host, 'commit', '-qm', 'host base')
            (unit / 'test_mobile_contract.gd').write_text('extends TestCase\n')
            with patch.object(check, 'ROOT', str(host)):
                _, files = check.changed_files('HEAD')
                self.assertIn('addons/dnd_core/tests/unit/test_mobile_contract.gd', files)
                plan = check.quick_plan(files)
            self.assertIn('test_mobile_contract.gd', plan['tests'])
            self.assertIn('test_scripts_compile.gd', plan['tests'])
            self.assertTrue(plan['compile'])
            self.assertNotEqual(plan['tests'], 'all')
