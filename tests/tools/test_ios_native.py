"""Native build boundaries: verified dependencies, no needless engine build, reproducible test targets."""
import importlib.util
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
        with patch.dict(os.environ, {'IOS_ENGINE_CACHE': str(self.root)}), \
             patch.object(simulator.subprocess, 'check_output', return_value='x86_64'), \
             patch.object(simulator.subprocess, 'run') as build:
            with self.assertRaisesRegex(ValueError, 'checksum'):
                simulator.ensure_arm64(self.root)
            build.assert_not_called()

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
