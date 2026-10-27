"""Native build boundaries: verified dependencies, no needless engine build, reproducible test targets."""
import importlib.util
import hashlib
import json
import os
from pathlib import Path
import plistlib
import sys
import tempfile
import unittest
from unittest.mock import patch

RELEASE = Path(__file__).resolve().parents[2] / 'tools/release'


def load(name):
    spec = importlib.util.spec_from_file_location(name, RELEASE / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


native = load('ios_native')
simulator = load('ios_simulator')
ui_tests = load('ios_ui_tests')


class NativeBuildTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.framework = self.root / 'xcode/CurseOfStrahd.xcframework'
        self.framework.mkdir(parents=True)
        (self.framework / 'Info.plist').write_bytes(plistlib.dumps({'AvailableLibraries': [{
            'SupportedPlatformVariant': 'simulator', 'LibraryIdentifier': 'simulator', 'LibraryPath': 'libgodot.a'}]}))

    def test_existing_arm_engine_does_not_download_or_compile(self):
        library = self.framework / 'simulator/libgodot.a'
        library.parent.mkdir()
        library.write_bytes(b'verified simulator engine')
        profile = {'profile': simulator.PROFILE, 'source_sha256': simulator.SOURCE_SHA256,
                   'patch_sha256': simulator.PATCH_SHA256,
                   'library_sha256': hashlib.sha256(library.read_bytes()).hexdigest()}
        (self.framework / simulator.PROFILE_FILE).write_text(json.dumps(profile))
        with patch.object(simulator.subprocess, 'check_output', return_value='x86_64 arm64'), \
             patch.object(simulator.urllib.request, 'urlretrieve') as download, \
             patch.object(simulator.subprocess, 'run') as build:
            simulator.ensure_arm64(self.root)
            download.assert_not_called()
            build.assert_not_called()

    def test_unexpected_slice_fails_before_building(self):
        with patch.object(simulator.subprocess, 'check_output', return_value='armv7'), \
             patch.object(simulator.subprocess, 'run') as build:
            with self.assertRaisesRegex(ValueError, 'architecture'):
                simulator.ensure_arm64(self.root)
            build.assert_not_called()

    def test_tampered_engine_source_cannot_build_or_replace_library(self):
        (self.root / 'godot-4.7.2.tar.gz').write_bytes(b'tampered')
        for architecture in ['x86_64', 'x86_64 arm64']:
            with self.subTest(architecture=architecture), \
                 patch.dict(os.environ, {'IOS_ENGINE_CACHE': str(self.root)}), \
                 patch.object(simulator.subprocess, 'check_output', return_value=architecture), \
                 patch.object(simulator.subprocess, 'run') as build:
                with self.assertRaisesRegex(ValueError, 'checksum'):
                    simulator.ensure_arm64(self.root)
                build.assert_not_called()

    def test_simulator_source_scale_fixes_are_guarded_and_idempotent(self):
        originals = {}
        for name, (before, _) in simulator.SOURCE_FIXES.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            originals[name] = '// pinned source before\n' + before + '\n// pinned source after\n'
            path.write_text(originals[name])
        first = simulator.logical_point_fixes(self.root)
        self.assertEqual(len(first), 2)
        for name, (before, after) in simulator.SOURCE_FIXES.items():
            patched = (self.root / name).read_text()
            self.assertIn('TARGET_OS_SIMULATOR', patched)
            self.assertIn('#else\n' + before, patched, 'the device Retina branch stays verbatim')
            self.assertEqual(patched.replace(after, before), originals[name])
        self.assertEqual(simulator.logical_point_fixes(self.root), first)

    def test_unknown_source_aborts_before_any_scale_fix_is_written(self):
        names = list(simulator.SOURCE_FIXES)
        for name, (before, _) in simulator.SOURCE_FIXES.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(before)
        original = (self.root / names[0]).read_text()
        (self.root / names[1]).write_text('unexpected source revision')
        with self.assertRaisesRegex(ValueError, 'Unexpected pinned simulator source'):
            simulator.logical_point_fixes(self.root)
        self.assertEqual((self.root / names[0]).read_text(), original)

    def test_simulator_cache_profile_requires_exact_library_and_patch(self):
        library = self.root / 'simulator.a'
        library.write_bytes(b'verified')
        path = self.framework / simulator.PROFILE_FILE
        profile = {'profile': simulator.PROFILE, 'source_sha256': simulator.SOURCE_SHA256,
                   'patch_sha256': simulator.PATCH_SHA256,
                   'library_sha256': hashlib.sha256(library.read_bytes()).hexdigest()}
        self.assertFalse(simulator.current_profile(self.framework, library))
        path.write_text(json.dumps(profile))
        self.assertTrue(simulator.current_profile(self.framework, library))
        library.write_bytes(b'replaced behind the profile')
        self.assertFalse(simulator.current_profile(self.framework, library))
        library.write_bytes(b'verified')
        profile['patch_sha256'] = 'old patch'
        path.write_text(json.dumps(profile))
        self.assertFalse(simulator.current_profile(self.framework, library))

    def test_tampered_bindings_cannot_build_or_edit_stage(self):
        (self.root / 'godot-cpp.tar.gz').write_bytes(b'tampered')
        with patch.dict(os.environ, {'IOS_NATIVE_CACHE': str(self.root)}), \
             patch.object(native.subprocess, 'run') as build:
            with self.assertRaisesRegex(ValueError, 'checksum'):
                native.build(self.root / 'stage', self.root / 'build.log')
            build.assert_not_called()
            self.assertFalse((self.root / 'stage').exists())

    def test_ui_test_attachment_is_idempotent_and_keeps_app_settings(self):
        project = self.root / 'Game.xcodeproj'
        project.mkdir()
        original = {'rootObject': 'root', 'objects': {
            'root': {'targets': ['app'], 'mainGroup': 'group'},
            'group': {'children': []},
            'app': {'name': 'Game', 'productType': 'com.apple.product-type.application', 'signing': 'unchanged'}}}
        with patch.object(ui_tests.subprocess, 'check_output', return_value=json.dumps(original)):
            ui_tests.attach(project, self.root / 'Test.swift')
        first = plistlib.loads((project / 'project.pbxproj').read_bytes())
        with patch.object(ui_tests.subprocess, 'check_output', return_value=json.dumps(first)):
            ui_tests.attach(project, self.root / 'Test.swift')
        second = plistlib.loads((project / 'project.pbxproj').read_bytes())
        self.assertEqual(first, second)
        self.assertEqual(second['objects']['app'], original['objects']['app'])
        self.assertEqual(len(second['objects']['root']['targets']), 2)
        self.assertTrue((project / 'xcshareddata/xcschemes/NativeQA.xcscheme').exists())
