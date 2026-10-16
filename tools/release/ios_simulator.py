#!/usr/bin/env python3
"""Repair an Intel-only upstream simulator slice by building the pinned ARM64 engine source.

The device library and installed templates are never changed. The generated Xcode project gets a universal slice.
"""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tarfile
import urllib.request

VERSION = '4.7.2'
SOURCE_SHA256 = 'e954996374cbd1cb5d72e0e3781cc537408e6ce73b010b12c6c2f308a820690a'


def ensure_arm64(output: Path) -> None:
    framework = output / 'xcode/CurseOfStrahd.xcframework'
    info = plistlib.loads((framework / 'Info.plist').read_bytes())
    entry = next(lib for lib in info['AvailableLibraries'] if lib.get('SupportedPlatformVariant') == 'simulator')
    library = framework / entry['LibraryIdentifier'] / entry['LibraryPath']
    architectures = subprocess.check_output(['xcrun', 'lipo', '-archs', str(library)], text=True).split()
    if 'arm64' in architectures:
        return
    if architectures != ['x86_64']:
        raise ValueError('Unexpected simulator library architecture: ' + ', '.join(architectures))
    cache = Path(os.environ.get('IOS_ENGINE_CACHE', Path.home() / 'Library/Caches/CurseOfStrahd/ios-engine'))
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
    with (output / 'simulator-engine.log').open('w') as log:
        def run(args):
            subprocess.run([str(arg) for arg in args], cwd=source, stdout=log, stderr=subprocess.STDOUT, check=True)
        venv = cache / 'venv'
        if not (venv / 'bin/scons').exists():
            run(['python3', '-m', 'venv', venv])
            run([venv / 'bin/pip', 'install', 'scons==4.9.1'])
        print('Building missing ARM64 simulator engine; log: ' + str(output / 'simulator-engine.log'), flush=True)
        run([venv / 'bin/scons', 'platform=ios', 'target=template_release', 'arch=arm64', 'simulator=yes',
             'metal=no', 'vulkan=no', 'production=yes', 'debug_symbols=no', '-j4'])
        arm = source / 'bin/libgodot.ios.template_release.arm64.simulator.a'
        run(['xcrun', 'lipo', arm, '-verify_arch', 'arm64'])
        combined = library.with_suffix('.universal.a')
        run(['xcrun', 'lipo', '-create', library, arm, '-output', combined])
        actual = subprocess.check_output(['xcrun', 'lipo', '-archs', str(combined)], text=True).split()
        if set(actual) != {'arm64', 'x86_64'}:
            raise ValueError('Combined simulator library does not contain both architectures')
        combined.replace(library)
    (output / 'simulator-engine.json').write_text(json.dumps({
        'version': VERSION, 'source_sha256': SOURCE_SHA256, 'renderer': 'Compatibility',
        'architectures': ['arm64', 'x86_64'], 'device_library_changed': False,
        'arm64_sha256': hashlib.sha256(arm.read_bytes()).hexdigest()
    }, indent=2) + '\n')
