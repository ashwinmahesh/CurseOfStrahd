#!/usr/bin/env python3
"""Build a verified logical-point ARM64 simulator slice from pinned engine source.

The device library and installed templates are never changed. Upstream Intel is retained when present.
"""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
VERSION = '4.7.2'
SOURCE_SHA256 = 'e954996374cbd1cb5d72e0e3781cc537408e6ce73b010b12c6c2f308a820690a'
PROFILE = 'arm64-simulator-logical-points-v1'
PROFILE_FILE = 'godot-simulator-profile.json'
SOURCE_FIXES = {
    'drivers/apple_embedded/godot_view_apple_embedded.mm': (
        '\tself.contentScaleFactor = [UIScreen mainScreen].scale;',
        '\t// The software iOS simulator presents a logical-point drawable; device Retina is unchanged.\n'
        '#if defined(IOS_ENABLED) && TARGET_OS_SIMULATOR\n'
        '\tself.contentScaleFactor = 1.0;\n'
        '#else\n'
        '\tself.contentScaleFactor = [UIScreen mainScreen].scale;\n'
        '#endif'),
    'platform/ios/display_server_ios.mm': (
        '\treturn [UIScreen mainScreen].scale;',
        '\t// Keep window, safe-area, keyboard and touch pixel coordinates on the drawable scale.\n'
        '#if TARGET_OS_SIMULATOR\n'
        '\treturn 1.0f;\n'
        '#else\n'
        '\treturn [UIScreen mainScreen].scale;\n'
        '#endif'),
}

PATCH_SHA256 = hashlib.sha256(json.dumps(SOURCE_FIXES, sort_keys=True).encode()).hexdigest()


def logical_point_fixes(source: Path) -> list[dict]:
    # Check every pinned hunk before writing any file. Unknown upstream edits must fail closed.
    edits = []
    for name, (before, after) in SOURCE_FIXES.items():
        path = source / name
        text = path.read_text()
        if text.count(after) == 1:
            updated = text
        elif after not in text and text.count(before) == 1:
            updated = text.replace(before, after, 1)
        else:
            raise ValueError('Unexpected pinned simulator source: ' + name)
        edits.append((path, updated))
    records = []
    for path, updated in edits:
        if path.read_text() != updated:
            path.write_text(updated)
        records.append({'path': str(path.relative_to(source)),
                        'sha256': hashlib.sha256(updated.encode()).hexdigest()})
    return records


def current_profile(framework: Path, library: Path) -> bool:
    try:
        profile = json.loads((framework / PROFILE_FILE).read_text())
        return (profile.get('profile') == PROFILE and profile.get('source_sha256') == SOURCE_SHA256
                and profile.get('patch_sha256') == PATCH_SHA256
                and profile.get('library_sha256') == hashlib.sha256(library.read_bytes()).hexdigest())
    except (OSError, ValueError):
        return False


def ensure_arm64(output: Path) -> None:
    framework = output / 'xcode/CurseOfStrahd.xcframework'
    info = plistlib.loads((framework / 'Info.plist').read_bytes())
    entry = next(lib for lib in info['AvailableLibraries'] if lib.get('SupportedPlatformVariant') == 'simulator')
    library = framework / entry['LibraryIdentifier'] / entry['LibraryPath']
    architectures = subprocess.check_output(['xcrun', 'lipo', '-archs', str(library)], text=True).split()
    if 'arm64' in architectures and current_profile(framework, library):
        return
    if not architectures or not set(architectures) <= {'arm64', 'x86_64'}:
        raise ValueError('Unexpected simulator library architecture: ' + ', '.join(architectures))
    cache = Path(os.environ.get('IOS_ENGINE_CACHE', ROOT.parent / 'strahd-builds/ios-engine-source'))
    cache.mkdir(parents=True, exist_ok=True)
    archive = cache / f'godot-{VERSION}.tar.gz'
    if not archive.exists():
        temporary = archive.with_suffix('.download')
        urllib.request.urlretrieve(f'https://github.com/godotengine/godot/archive/refs/tags/{VERSION}-stable.tar.gz', temporary)
        temporary.replace(archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != SOURCE_SHA256:
        raise ValueError('Godot simulator source checksum mismatch')
    source = cache / f'godot-{VERSION}-stable'
    if not source.exists():
        with tarfile.open(archive) as stream:
            for member in stream.getmembers():
                path = Path(member.name)
                if path.is_absolute() or '..' in path.parts or member.issym() or member.islnk():
                    raise ValueError('Unsafe engine archive member')
            stream.extractall(cache)
    fixes = logical_point_fixes(source)
    device_hashes = {}
    for item in info['AvailableLibraries']:
        if item.get('SupportedPlatformVariant') != 'simulator':
            path = framework / item['LibraryIdentifier'] / item['LibraryPath']
            device_hashes[str(path.relative_to(framework))] = hashlib.sha256(path.read_bytes()).hexdigest()
    with (output / 'simulator-engine.log').open('w') as log:
        def run(args):
            subprocess.run([str(arg) for arg in args], cwd=source, stdout=log, stderr=subprocess.STDOUT, check=True)
        venv = cache / 'venv'
        if not (venv / 'bin/scons').exists():
            run(['python3', '-m', 'venv', venv])
            run([venv / 'bin/python3', '-m', 'pip', 'install', 'scons==4.9.1'])
        print('Building logical-point ARM64 simulator engine; log: ' + str(output / 'simulator-engine.log'), flush=True)
        run([venv / 'bin/python3', '-m', 'SCons', 'platform=ios', 'target=template_release', 'arch=arm64', 'simulator=yes',
             'metal=no', 'vulkan=no', 'production=yes', 'debug_symbols=no', '-j4'])
        arm = source / 'bin/libgodot.ios.template_release.arm64.simulator.a'
        run(['xcrun', 'lipo', arm, '-verify_arch', 'arm64'])
        combined = library.with_suffix('.universal.a')
        if 'x86_64' in architectures:
            original = library
            if 'arm64' in architectures:
                original = output / 'simulator-upstream-x86_64.a'
                run(['xcrun', 'lipo', library, '-thin', 'x86_64', '-output', original])
            run(['xcrun', 'lipo', '-create', original, arm, '-output', combined])
        else:
            shutil.copy2(arm, combined)
        actual = subprocess.check_output(['xcrun', 'lipo', '-archs', str(combined)], text=True).split()
        if set(actual) != set(architectures) | {'arm64'}:
            raise ValueError('Combined simulator library does not contain both architectures')
        combined.replace(library)
    for name, expected in device_hashes.items():
        if hashlib.sha256((framework / name).read_bytes()).hexdigest() != expected:
            raise ValueError('Simulator build changed the device library: ' + name)
    entry['SupportedArchitectures'] = actual
    (framework / 'Info.plist').write_bytes(plistlib.dumps(info))
    profile = {'profile': PROFILE, 'source_sha256': SOURCE_SHA256, 'patch_sha256': PATCH_SHA256,
               'library_sha256': hashlib.sha256(library.read_bytes()).hexdigest(),
               'arm64_drawable_scale': 1.0, 'upstream_x86_64_preserved': 'x86_64' in architectures,
               'source_fixes': fixes, 'device_library_hashes': device_hashes}
    (framework / PROFILE_FILE).write_text(json.dumps(profile, indent=2) + '\n')
    (output / 'simulator-engine.json').write_text(json.dumps({
        'version': VERSION, 'source_sha256': SOURCE_SHA256, 'renderer': 'Compatibility',
        'architectures': actual, 'device_library_changed': False, 'profile': profile,
        'arm64_sha256': hashlib.sha256(arm.read_bytes()).hexdigest()
    }, indent=2) + '\n')
