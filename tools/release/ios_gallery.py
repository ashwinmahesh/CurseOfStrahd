#!/usr/bin/env python3
"""Build an isolated simulator UI gallery from an already prepared full-game simulator stage.

Uses the existing representative capture scenes on native iOS; it does not simulate player navigation.
The app has its own bundle/save container. Production exports never include the runner or fixtures.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

import ios

ROOT = Path(__file__).resolve().parents[2]


def write_inventory(source: Path, output: Path) -> None:
    inherited = json.loads((source / 'source-inventory.json').read_text())
    stage = output / 'project'
    files = []
    for path in sorted(stage.rglob('*')):
        if path.is_file() and '.godot' not in path.relative_to(stage).parts:
            with path.open('rb') as stream:
                digest = hashlib.file_digest(stream, 'sha256').hexdigest()
            files.append({'path': path.relative_to(stage).as_posix(), 'bytes': path.stat().st_size, 'sha256': digest})
    inventory = {'simulator': True, 'bundle_identifier': 'app.curseofstrahd.uigallery',
        'evidence': 'Native simulator UI fixtures, not gameplay E2E',
        'parent_source_inventory': inherited, 'gallery_tool_revision': ios.probe(['git', '-C', str(ROOT), 'rev-parse', 'HEAD']),
        'gallery_tool_dirty': bool(ios.probe(['git', '-C', str(ROOT), 'status', '--porcelain'])),
        'files': files, 'source_bytes': sum(item['bytes'] for item in files)}
    (output / 'source-inventory.json').write_text(json.dumps(inventory, indent=2) + '\n')


def build(source: Path, output: Path) -> None:
    source, output = source.resolve(), output.resolve()
    if not (source / 'project/project.godot').is_file():
        raise ValueError('Source must be an existing prepared full-game simulator output')
    if output.exists() or output == ROOT or ROOT in output.parents or source in output.parents:
        raise ValueError('Choose a fresh output directory outside the checkout and source output')
    output.mkdir(parents=True)
    stage = output / 'project'
    subprocess.run(['cp', '-cR', str(source / 'project'), str(stage)], check=True)
    fixtures = stage / 'tools/capture'
    fixtures.mkdir(parents=True, exist_ok=True)
    for name in ['mobile_ui', 'mobile_menu', 'mobile_secondary', 'mobile_recovery', 'mobile_controller']:
        for suffix in ['.gd', '.tscn']:
            shutil.copy2(ROOT / 'tools/capture' / (name + '_capture' + suffix), fixtures)
    support = stage / 'tests/support'
    support.mkdir(parents=True, exist_ok=True)
    for name in ['test_combat.gd', 'test_chars.gd']:
        shutil.copy2(ROOT / 'tests/support' / name, support)
    gallery = stage / 'qa_gallery'
    gallery.mkdir()
    shutil.copy2(ROOT / 'tests/ios/gallery.gd', gallery / 'main.gd')
    (gallery / 'main.tscn').write_text('[gd_scene load_steps=2 format=3]\n'
        '[ext_resource type="Script" path="res://qa_gallery/main.gd" id="1"]\n'
        '[node name="NativeGallery" type="Node"]\nscript = ExtResource("1")\n')
    ios.project_values(stage / 'project.godot', 'application', {
        'config/name': '"Strahd UI Gallery"', 'run/main_scene': '"res://qa_gallery/main.tscn"'})
    config = ios.config(stage / 'export_presets.cfg')
    section = next(s for s in config.sections() if config[s].get('name') == '"iOS"')
    excluded = json.loads(config[section]['exclude_filter'])
    config[section]['exclude_filter'] = json.dumps(','.join(p for p in excluded.split(',') if p.strip() != 'tools/*'))
    config[section + '.options']['application/bundle_identifier'] = '"app.curseofstrahd.uigallery"'
    ios.write_config(stage / 'export_presets.cfg', config)
    godot = os.environ.get('GODOT', '/Applications/Godot.app/Contents/MacOS/Godot')
    ios.logged([godot, '--headless', '--editor', '--path', str(stage), '--import'], output / 'import.log', check_errors=True)
    ios.simulator_atlas_dimensions(stage)
    write_inventory(source, output)
    (output / 'xcode').mkdir()
    ios.logged([godot, '--headless', '--path', str(stage), '--export-release', 'iOS',
                str(output / 'xcode/CurseOfStrahd.xcodeproj')], output / 'export.log', check_errors=True)
    ios.simulator_build(output)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-output', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    build(args.source_output, args.output)
