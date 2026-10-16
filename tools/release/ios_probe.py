#!/usr/bin/env python3
"""Build and run native Files/accessibility smoke tests in a small, isolated simulator app.

This verifies the real UIKit bridge; it is not a substitute for full-game journeys or device Metal tests.
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess

import ios
import ios_native
import ios_simulator
import ios_ui_tests

ROOT = Path(__file__).resolve().parents[2]


def run(output: Path, device: str) -> None:
    output = output.resolve()
    if output.exists() or output == ROOT or ROOT in output.parents:
        raise ValueError('Choose a fresh output directory outside the checkout')
    output.mkdir(parents=True)
    stage = output / 'project'
    stage.mkdir()
    shutil.copy2(ROOT / 'tests/ios/probe.gd', stage / 'main.gd')
    shutil.copy2(ROOT / 'art/ui/app_icon_ios.png', stage / 'icon.png')
    (stage / 'main.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://main.gd" id="1"]\n[node name="NativeProbe" type="Control"]\nscript=ExtResource("1")\n')
    (stage / 'project.godot').write_text('''config_version=5
[application]
config/name="Strahd Native QA"
config/icon="res://icon.png"
run/main_scene="res://main.tscn"
run/max_fps=30
[rendering]
textures/vram_compression/import_etc2_astc=true
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
[display]
window/size/viewport_width=844
window/size/viewport_height=390
window/stretch/mode="canvas_items"
window/handheld/orientation=0
''')
    presets = ios.config(ROOT / 'export_presets.cfg')
    section = next(name for name in presets.sections() if presets[name].get('name') == '"iOS"')
    cfg = ios.config(stage / 'export_presets.cfg')
    cfg['preset.0'] = dict(presets[section])
    cfg['preset.0.options'] = dict(presets[section + '.options'])
    cfg['preset.0.options'].update({'application/app_store_team_id':'"SIMULATOR0"',
                                   'application/bundle_identifier':'"app.curseofstrahd.nativeprobe"',
                                   'icons/icon_1024x1024':'"res://icon.png"'})
    ios.write_config(stage / 'export_presets.cfg', cfg)
    ios_native.build(stage, output / 'native-build.log')
    godot = os.environ.get('GODOT', '/Applications/Godot.app/Contents/MacOS/Godot')
    ios.logged([godot, '--headless', '--editor', '--path', str(stage), '--import'], output / 'import.log', check_errors=True)
    xcode = output / 'xcode'
    xcode.mkdir()
    project = xcode / 'CurseOfStrahd.xcodeproj'
    ios.logged([godot, '--headless', '--path', str(stage), '--export-release', 'iOS', str(project)], output / 'export.log', check_errors=True)
    ios_simulator.ensure_arm64(output)
    ios_ui_tests.attach(project, ROOT / 'tests/ios/NativeUtilityTests.swift')
    # The named device must already exist; no user devices are erased or reset.
    result = subprocess.run(['xcrun', 'simctl', 'boot', device], capture_output=True, text=True)
    if result.returncode and 'Booted' not in result.stderr:
        raise RuntimeError(result.stderr)
    subprocess.run(['xcrun', 'simctl', 'bootstatus', device, '-b'], check=True)
    with (output / 'uitest.log').open('w') as log:
        subprocess.run(['xcodebuild', '-project', str(project), '-scheme', 'NativeQA',
                        '-destination', 'platform=iOS Simulator,id=' + device,
                        '-derivedDataPath', str(output / 'derived'), '-resultBundlePath', str(output / 'tests.xcresult'),
                        'CODE_SIGNING_ALLOWED=NO', 'CODE_SIGNING_REQUIRED=NO', 'CODE_SIGN_IDENTITY=', 'DEVELOPMENT_TEAM=', 'test'],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    print('Native utility tests passed: ' + str(output / 'tests.xcresult'))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--device', required=True)
    args = parser.parse_args()
    run(args.output, args.device)
