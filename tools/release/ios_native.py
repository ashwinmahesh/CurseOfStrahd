#!/usr/bin/env python3
"""Build the iOS-only native utility extension into an isolated export stage."""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
REVISION = '507ed9d840c01a3c5b2a39af8bb4000bfac30bf5'  # godot-cpp 10.0.0 stable; API 4.7
SHA256 = '30da4ac295997061a6af81ae531510efd4e6a86e506eb4466edc0898ef3fe048'


def build(stage: Path, log: Path) -> None:
    cache = Path(os.environ.get('IOS_NATIVE_CACHE', ROOT.parent / 'strahd-builds/ios-native-toolchain'))
    cache.mkdir(parents=True, exist_ok=True)
    archive = cache / 'godot-cpp.tar.gz'
    if not archive.exists():
        temporary = archive.with_suffix('.download')
        urllib.request.urlretrieve(f'https://github.com/godotengine/godot-cpp/archive/{REVISION}.tar.gz', temporary)
        temporary.replace(archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != SHA256:
        raise ValueError('godot-cpp download checksum mismatch')
    bindings = cache / ('godot-cpp-' + REVISION)
    if not bindings.exists():
        with tarfile.open(archive) as source:
            for member in source.getmembers():
                path = Path(member.name)
                if path.is_absolute() or '..' in path.parts or member.issym() or member.islnk():
                    raise ValueError('Unsafe dependency archive member')
            source.extractall(cache)
    env = dict(os.environ, GODOT_CPP=str(bindings))
    work = cache / 'source'
    work.mkdir(exist_ok=True)
    for name in ['SConstruct', 'profile.json', 'strahd_ios.mm', 'host_stub.c']:
        shutil.copy2(ROOT / 'tools/native_ios' / name, work / name)
    with log.open('w') as stream:
        def run(args):
            subprocess.run([str(a) for a in args], cwd=work, env=env, stdout=stream, stderr=subprocess.STDOUT, check=True)
        venv = cache / 'venv'
        if not (venv / 'bin/scons').exists():
            run(['python3', '-m', 'venv', venv])
            run([venv / 'bin/python3', '-m', 'pip', 'install', 'scons==4.9.1'])
        products = []
        for simulator in [False, True]:
            run([venv / 'bin/python3', '-m', 'SCons', 'platform=ios', 'arch=arm64', 'target=template_release',
                 'ios_simulator=' + ('yes' if simulator else 'no'), 'ios_min_version=16.0',
                 'build_profile=' + str(work / 'profile.json'), '-j4'])
            suffix = '.ios.template_release.arm64' + ('.simulator' if simulator else '')
            product = cache / ('libstrahd' + suffix + '.a')
            run(['xcrun', 'libtool', '-static', '-o', product,
                 work / ('bin/libstrahd' + suffix), bindings / ('bin/libgodot-cpp' + suffix + '.a')])
            products.append(product)
        destination = stage / 'addons/ios_native'
        destination.mkdir(parents=True, exist_ok=True)
        framework = destination / 'StrahdIOS.xcframework'
        if framework.exists():
            shutil.rmtree(framework)
        run(['xcodebuild', '-create-xcframework', '-library', products[0], '-library', products[1], '-output', framework])
        run(['xcrun', 'clang', '-dynamiclib', '-arch', 'arm64', '-arch', 'x86_64', '-I', bindings / 'gen/include',
             work / 'host_stub.c', '-o', destination / 'host_stub.dylib'])
    (destination / 'native.gdextension').write_text('''[configuration]
entry_symbol="strahd_ios_init"
compatibility_minimum="4.7"
[libraries]
ios="./StrahdIOS.xcframework"
macos="./host_stub.dylib"
''')
    # The export plugin supplies the Apple system framework; it exists only in isolated iOS stages.
    (destination / 'plugin.cfg').write_text('[plugin]\nname="iOS native export"\ndescription="Native file utilities"\nauthor="Strahd"\nversion="1"\nscript="export.gd"\n')
    (destination / 'export.gd').write_text('''@tool
extends EditorPlugin
class NativeExport extends EditorExportPlugin:
    func _get_name() -> String:
        return "StrahdIOS"
    func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
        add_ios_linker_flags("-framework UniformTypeIdentifiers")
        add_ios_plist_content('<key>GCSupportsControllerUserInteraction</key><true/><key>GCSupportedGameControllers</key><array><dict><key>ProfileName</key><string>ExtendedGamepad</string></dict></array>')
var exporter := NativeExport.new()
func _enter_tree() -> void:
    add_export_plugin(exporter)
func _exit_tree() -> void:
    remove_export_plugin(exporter)
''')
    from ios import project_values
    project_values(stage / "project.godot", "editor_plugins", {"enabled": 'PackedStringArray("res://addons/ios_native/plugin.cfg")'})
    shutil.copy2(bindings / 'LICENSE.md', destination / 'GODOT_CPP_LICENSE.txt')
    files = [{"path": str(path.relative_to(stage)), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
             for path in sorted(destination.rglob('*')) if path.is_file()]
    (stage.parent / 'native-inventory.json').write_text(json.dumps({
        "godot_cpp_revision": REVISION, "godot_cpp_source_sha256": SHA256, "api": "4.7",
        "minimum_ios": "16.0", "scons": "4.9.1", "files": files,
        "sources": {name: hashlib.sha256((work / name).read_bytes()).hexdigest()
                    for name in ['SConstruct', 'profile.json', 'strahd_ios.mm', 'host_stub.c']}
    }, indent=2) + '\n')
