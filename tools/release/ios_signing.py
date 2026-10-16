#!/usr/bin/env python3
"""Ephemeral manual iOS signing on GitHub-hosted macOS runners; never prints credentials."""
import argparse
import base64
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import secrets
import shutil
import subprocess

WWDR_SHA256 = 'dcf21878c77f4198e4b4614f03d696d89c66c66008d4244e1b99161aac91601f'


def run(args):
    result = subprocess.run(args, capture_output=True)
    if result.returncode:
        raise RuntimeError(f"{Path(args[0]).name} {args[1]} failed (exit {result.returncode}); check signing configuration")
    return result.stdout


def validate_profile(profile, bundle, method, now=None):
    now = now or dt.datetime.now(dt.timezone.utc)
    expires = profile['ExpirationDate'].replace(tzinfo=dt.timezone.utc)
    if expires <= now:
        raise ValueError('iOS provisioning profile has expired')
    team = profile['TeamIdentifier'][0]
    entitlements = profile['Entitlements']
    app = entitlements.get('application-identifier', '')
    # The App ID prefix can differ from the Team ID on older accounts.
    if app.split('.', 1)[-1] != bundle or '*' in app:
        raise ValueError('Use an explicit provisioning profile matching IOS_BUNDLE_ID')
    if entitlements.get('com.apple.developer.team-identifier') != team:
        raise ValueError('Provisioning team and entitlement disagree')
    if profile.get('ProvisionsAllDevices'):
        raise ValueError('Enterprise profiles are not supported by this workflow')
    actual = 'development' if entitlements.get('get-task-allow', False) else (
        'ad-hoc' if profile.get('ProvisionedDevices') else 'app-store')
    if actual != method:
        raise ValueError(f'Profile is {actual}; requested {method}')
    uuid = profile['UUID']
    if not re.fullmatch(r'[A-Fa-f0-9-]{36}', uuid) or not re.fullmatch(r'[A-Z0-9]{10}', team):
        raise ValueError('Invalid profile UUID or team identifier')
    return team, uuid


def install(directory, bundle, method):
    required = ['IOS_SIGNING_P12', 'IOS_PROVISIONING_PROFILE', 'APPLE_TEAM_ID']
    missing = [key for key in required if not os.environ.get(key)]
    if missing:
        raise ValueError('Missing GitHub secrets: ' + ', '.join(missing))
    if not re.fullmatch(r'[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+', bundle):
        raise ValueError('Set IOS_BUNDLE_ID to the registered explicit app identifier')
    directory.mkdir(mode=0o700, parents=True, exist_ok=False)
    os.chmod(directory, 0o700)
    p12 = directory / 'identity.p12'
    mobile = directory / 'profile.mobileprovision'
    p12.write_bytes(base64.b64decode(os.environ['IOS_SIGNING_P12'], validate=True))
    mobile.write_bytes(base64.b64decode(os.environ['IOS_PROVISIONING_PROFILE'], validate=True))
    profile = plistlib.loads(run(['security', 'cms', '-D', '-i', str(mobile)]))
    team, uuid = validate_profile(profile, bundle, method)
    if team != os.environ['APPLE_TEAM_ID']:
        raise ValueError('Provisioning profile does not match APPLE_TEAM_ID')
    keychain = directory / 'signing.keychain-db'
    password = secrets.token_urlsafe(32)
    old = run(['security', 'list-keychains', '-d', 'user']).decode()
    previous = re.findall(r'"([^"\n]+)"', old)
    # Record cleanup locations before making any persistent runner changes.
    paths = [Path.home() / 'Library/MobileDevice/Provisioning Profiles' / (uuid + '.mobileprovision'),
             Path.home() / 'Library/Developer/Xcode/UserData/Provisioning Profiles' / (uuid + '.mobileprovision')]
    if any(p.exists() for p in paths):
        raise ValueError('Profile already installed; use a clean hosted runner')
    (directory / 'cleanup.json').write_text(json.dumps({'keychains': previous, 'profiles': [str(p) for p in paths]}))
    run(['security', 'create-keychain', '-p', password, str(keychain)])
    run(['security', 'set-keychain-settings', '-lut', '21600', str(keychain)])
    run(['security', 'unlock-keychain', '-p', password, str(keychain)])
    run(['security', 'import', str(p12), '-k', str(keychain), '-P', os.environ.get('IOS_SIGNING_P12_PASSWORD', ''),
         '-T', '/usr/bin/codesign', '-T', '/usr/bin/security'])
    # Apple Distribution chains to WWDR G3. Import the pinned intermediate into this keychain only.
    import urllib.request
    intermediate = urllib.request.urlopen('https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer', timeout=60).read()
    if hashlib.sha256(intermediate).hexdigest() != WWDR_SHA256:
        raise ValueError('Unexpected Apple WWDR G3 certificate checksum')
    ca = directory / 'wwdr.cer'
    ca.write_bytes(intermediate)
    run(['security', 'import', str(ca), '-k', str(keychain)])
    run(['security', 'set-key-partition-list', '-S', 'apple-tool:,apple:,codesign:', '-s', '-k', password, str(keychain)])
    run(['security', 'list-keychains', '-d', 'user', '-s', str(keychain), *previous])
    identities = run(['security', 'find-identity', '-v', '-p', 'codesigning', str(keychain)]).decode()
    allowed = {hashlib.sha1(cert).hexdigest().upper() for cert in profile['DeveloperCertificates']}
    found = re.findall(r'\b([A-F0-9]{40})\s+"(?:Apple Distribution|Apple Development|iPhone Distribution|iPhone Developer)[^"\n]*"', identities)
    identity = next((value for value in found if value in allowed), None)
    if not identity:
        raise ValueError('No valid iOS signing identity with a private key matches the provisioning profile')
    for path in paths:
        path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(mobile, path)
    options = {'method': {'app-store': 'app-store-connect', 'ad-hoc': 'release-testing', 'development': 'debugging'}[method],
               'teamID': team, 'signingStyle': 'manual', 'signingCertificate': identity,
               'provisioningProfiles': {bundle: uuid}, 'destination': 'export',
               'manageAppVersionAndBuildNumber': False, 'uploadSymbols': True}
    (directory / 'ExportOptions.plist').write_bytes(plistlib.dumps(options))
    values = {'IOS_TEAM_ID': team, 'IOS_PROVISIONING_UUID': uuid, 'IOS_SIGNING_IDENTITY': identity,
              'IOS_KEYCHAIN': str(keychain)}
    with Path(os.environ['GITHUB_ENV']).open('a') as stream:
        for key, value in values.items():
            stream.write(f'{key}={value}\n')
    p12.unlink()
    print('Validated and installed matching iOS identity and provisioning profile.')


def cleanup(directory):
    state = directory / 'cleanup.json'
    if state.exists():
        data = json.loads(state.read_text())
        subprocess.run(['security', 'list-keychains', '-d', 'user', '-s', *data['keychains']], capture_output=True)
        subprocess.run(['security', 'delete-keychain', str(directory / 'signing.keychain-db')], capture_output=True)
        for path in data['profiles']:
            Path(path).unlink(missing_ok=True)
    if directory.exists():
        shutil.rmtree(directory)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['install', 'cleanup'])
    parser.add_argument('--directory', required=True, type=Path)
    parser.add_argument('--method', choices=['app-store', 'ad-hoc', 'development'], default='app-store')
    parser.add_argument('--bundle', default=os.environ.get('IOS_BUNDLE_ID', ''))
    args = parser.parse_args()
    try:
        if args.action == 'cleanup':
            cleanup(args.directory)
        else:
            install(args.directory, args.bundle, args.method)
    except (ValueError, RuntimeError, KeyError, OSError) as error:
        print(f'iOS signing: {error}')
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
