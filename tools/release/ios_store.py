#!/usr/bin/env python3
"""Inspect and maintain the authorized iOS product page using existing CI credentials.

Credentials stay in a temporary directory; reports omit signed upload operations.
This tool never submits review, releases an app, changes pricing, or invites testers.
"""
import argparse
import json
import os
from pathlib import Path
import re
import tempfile
import urllib.error
import urllib.parse
import urllib.request

from ios_deploy import key_file, token


class StoreAPI:
    def __init__(self, key):
        self.key = key

    def call(self, path, parameters=None, method='GET', data=None):
        if not re.fullmatch(r'[A-Za-z0-9_/-]+', path) or '..' in path:
            raise ValueError('Expected a relative App Store Connect resource path')
        query = '?' + urllib.parse.urlencode(parameters) if parameters else ''
        request = urllib.request.Request('https://api.appstoreconnect.apple.com/v1/' + path + query,
            data=json.dumps(data).encode() if data is not None else None, method=method,
            headers={'Authorization': 'Bearer ' + token(self.key), 'Content-Type': 'application/json'})
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                body = response.read()
                return json.loads(body) if body else {}
        except urllib.error.HTTPError as error:
            details = json.loads(error.read()).get('errors', [])
            raise RuntimeError('App Store Connect ' + str(error.code) + ': ' + '; '.join(
                item.get('code', '') + ': ' + item.get('detail', '') for item in details)) from None


def sanitized(value):
    if isinstance(value, dict):
        return {k: sanitized(v) for k, v in value.items() if k != 'uploadOperations'}
    if isinstance(value, list):
        return [sanitized(v) for v in value]
    return value


def inspect(api, app_id, version):
    app = api.call('apps/' + app_id)['data']
    if app['attributes']['bundleId'] != 'app.curseofstrahd.game':
        raise ValueError('Unexpected app Bundle ID')
    result = {'app': app, 'versions': api.call('apps/' + app_id + '/appStoreVersions',
        {'filter[platform]': 'IOS', 'filter[versionString]': version, 'limit': 20})['data']}
    for item in result['versions']:
        item['localizations'] = api.call('appStoreVersions/' + item['id'] + '/appStoreVersionLocalizations')['data']
        for loc in item['localizations']:
            loc['placements'] = api.call('appStoreVersionLocalizations/' + loc['id'] + '/placements',
                {'include': 'image,video', 'sort': 'placementGroupPosition', 'limit': 200})
    result['library'] = api.call('apps/' + app_id + '/assetLibrary')['data']
    result['referenceData'] = api.call('appAssetLibraryRefData')['data']
    result['builds'] = api.call('builds', {'filter[app]': app_id,
        'filter[preReleaseVersion.version]': version, 'sort': '-uploadedDate', 'limit': 5})['data']
    for build in result['builds']:
        build['icons'] = api.call('builds/' + build['id'] + '/icons')['data']
    return sanitized(result)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['inspect'])
    parser.add_argument('--version', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    app_id = os.environ['APP_STORE_APP_ID']
    if not app_id.isdigit() or not re.fullmatch(r'\d+\.\d+\.\d+', args.version):
        raise ValueError('Invalid app or version')
    args.output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='ios-store-key-', dir=os.environ.get('RUNNER_TEMP')) as private:
        api = StoreAPI(key_file(Path(private)))
        result = inspect(api, app_id, args.version)
        (args.output / 'listing.json').write_text(json.dumps(result, indent=2) + '\n')
        print('Verified app ' + app_id + '; ' + str(len(result['versions'])) + ' matching iOS versions')
        print('Saved listing, asset specifications and build icon metadata; no changes made.')


if __name__ == '__main__':
    main()
