#!/usr/bin/env python3
"""CI deployment probe and App Store Connect checks; no third-party Python dependencies."""
import argparse
import base64
import json
import os
from pathlib import Path
import re
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request


def encoded(data):
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode()


def token(key):
    now = int(time.time())
    header = encoded(json.dumps({'alg': 'ES256', 'kid': os.environ['KEY_ID'], 'typ': 'JWT'}).encode())
    payload = encoded(json.dumps({'iss': os.environ['ISSUER_ID'], 'iat': now - 30,
                                 'exp': now + 600, 'aud': 'appstoreconnect-v1'}).encode())
    message = (header + '.' + payload).encode()
    signature = subprocess.run(['openssl', 'dgst', '-sha256', '-sign', str(key)], input=message,
                               capture_output=True, check=True).stdout
    # OpenSSL returns ASN.1 DER; JWT ES256 requires two fixed-width unsigned integers.
    if signature[:1] != b'\x30' or signature[2:3] != b'\x02':
        raise ValueError('Expected an EC P-256 API key')
    length = signature[3]
    r = int.from_bytes(signature[4:4 + length], 'big')
    offset = 4 + length
    if signature[offset] != 2:
        raise ValueError('Invalid ECDSA signature')
    s = int.from_bytes(signature[offset + 2:offset + 2 + signature[offset + 1]], 'big')
    return message.decode() + '.' + encoded(r.to_bytes(32, 'big') + s.to_bytes(32, 'big'))


def api(key, path, parameters=None):
    query = '?' + urllib.parse.urlencode(parameters) if parameters else ''
    request = urllib.request.Request('https://api.appstoreconnect.apple.com/v1/' + path + query,
                                     headers={'Authorization': 'Bearer ' + token(key)})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        details = json.loads(error.read()).get('errors', [])
        raise RuntimeError('App Store Connect: ' + '; '.join(
            str(item.get('code', '')) + ': ' + str(item.get('detail', '')) for item in details)) from None


def key_file(directory):
    key_id = os.environ['KEY_ID']
    if not re.fullmatch(r'[A-Z0-9]+', key_id):
        raise ValueError('Invalid API Key ID')
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    key = directory / ('AuthKey_' + key_id + '.p8')
    key.write_text(os.environ['KEY_P8'])
    key.chmod(0o600)
    return key


def check_app(key):
    app_id = os.environ['APP_STORE_APP_ID']
    if not app_id.isdigit():
        raise ValueError('APP_STORE_APP_ID must be numeric')
    app = api(key, 'apps/' + app_id)['data']
    if app['attributes']['bundleId'] != os.environ['IOS_BUNDLE_ID']:
        raise ValueError('App Store app does not match IOS_BUNDLE_ID')
    print('Verified API access to app ' + app_id + ' (' + app['attributes']['bundleId'] + ')')


def wait_for_build(key, output):
    deadline = time.monotonic() + 1800
    while time.monotonic() < deadline:
        result = api(key, 'builds', {'filter[app]': os.environ['APP_STORE_APP_ID'],
                                   'filter[version]': os.environ['IOS_BUILD'],
                                   'filter[preReleaseVersion.version]': os.environ['VERSION'],
                                   'include': 'preReleaseVersion', 'limit': '10'})
        builds = result['data']
        if builds:
            build = builds[0]
            state = build['attributes']['processingState']
            print('Apple build processing: ' + state, flush=True)
            output.write_text(json.dumps(result, indent=2) + '\n')
            if state == 'VALID':
                print('Build is processed and valid in App Store Connect: ' + build['id'])
                return
            if state in ('FAILED', 'INVALID'):
                raise RuntimeError('Apple rejected the build during processing; inspect App Store Connect')
        else:
            print('Waiting for the uploaded build to appear in App Store Connect', flush=True)
        time.sleep(30)
    raise RuntimeError('Timed out waiting for Apple processing; upload receipt alone is not a successful validation')


def smoke(output, source):
    """A clearly labelled deployment fixture, using the real app ID and real Godot device template."""
    stage = output / 'project'
    stage.mkdir(parents=True, exist_ok=False)
    import shutil
    shutil.copy2(source / 'art/ui/app_icon.png', stage / 'icon.png')
    (stage / 'project.godot').write_text('''config_version=5
[application]
config/name="Curse of Strahd"
config/icon="res://icon.png"
run/main_scene="res://main.tscn"
run/max_fps=30
[display]
window/size/viewport_width=844
window/size/viewport_height=390
window/stretch/mode="canvas_items"
window/handheld/orientation=0
[rendering]
renderer/rendering_method="mobile"
renderer/rendering_method.mobile="mobile"
textures/vram_compression/import_etc2_astc=true
''')
    (stage / 'main.tscn').write_text('''[gd_scene format=3]
[node name="DeploymentCheck" type="Control"]
layout_mode=3
anchors_preset=15
anchor_right=1.0
anchor_bottom=1.0
[node name="Label" type="Label" parent="."]
anchors_preset=15
anchor_right=1.0
anchor_bottom=1.0
text="Curse of Strahd — deployment check\nSigning and TestFlight verification build.\nThe game is not included in this build."
horizontal_alignment=1
vertical_alignment=1
autowrap_mode=2
''')
    options = {'application/app_store_team_id': os.environ['IOS_TEAM_ID'],
               'application/bundle_identifier': os.environ['IOS_BUNDLE_ID'],
               'application/short_version': os.environ['VERSION'],
               'application/version': os.environ['IOS_BUILD'],
               'icons/icon_1024x1024': 'res://icon.png',
               'application/code_sign_identity_release': os.environ['IOS_SIGNING_IDENTITY'],
               'application/provisioning_profile_specifier_release': os.environ['IOS_PROVISIONING_UUID'],
               'application/min_ios_version': '16.0'}
    preset = '''[preset.0]
name="iOS"
platform="iOS"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter=""
[preset.0.options]
application/export_project_only=true
application/targeted_device_family=2
architectures/arm64=true
'''
    preset += ''.join(key + '=' + json.dumps(value) + '\n' for key, value in options.items())
    (stage / 'export_presets.cfg').write_text(preset)
    xcode = output / 'xcode'
    xcode.mkdir()
    subprocess.run([os.environ['GODOT'], '--headless', '--editor', '--path', str(stage), '--import'], check=True)
    subprocess.run([os.environ['GODOT'], '--headless', '--path', str(stage), '--export-release', 'iOS',
                    str(xcode / 'CurseOfStrahd.xcodeproj')], check=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['smoke', 'check-app', 'wait'])
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--source', type=Path)
    args = parser.parse_args()
    if args.action == 'smoke':
        smoke(args.output, args.source)
    else:
        key = key_file(Path(os.environ['RUNNER_TEMP']) / 'ios-signing/private_keys')
        if args.action == 'check-app':
            check_app(key)
        else:
            wait_for_build(key, args.output / 'app-store-build.json')
