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
    versions = api.call('apps/' + app_id + '/appStoreVersions',
        {'filter[platform]': 'IOS', 'limit': 200})['data']
    # Connect creates an initial draft as 1.0; build marketing versions use 1.0.0.
    labels = {version, version[:-2]} if version.endswith('.0') else {version}
    result = {'app': app, 'allVersions': versions,
              'versions': [v for v in versions if v['attributes']['versionString'] in labels]}
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


def payload(kind, attributes, relationships=None, identity=None):
    item = {'type': kind, 'attributes': attributes}
    if identity:
        item['id'] = identity
    if relationships:
        item['relationships'] = {key: {'data': {'type': value[0], 'id': value[1]}}
                                 for key, value in relationships.items()}
    return {'data': item}


def validate_manifest(path, version):
    import hashlib
    data = json.loads(path.read_text())
    if data['version'] != version or data['locale'] != 'en-US':
        raise ValueError('Manifest must match the requested version and en-US localization')
    if not 1 <= len(data['description']) <= 4000 or len(data.get('promotionalText', '')) > 170:
        raise ValueError('Description or promotional text exceeds Apple limits')
    seen = set()
    for item in data['assets']:
        file = (path.parent / item['file']).resolve()
        if path.parent.resolve() not in file.parents or not file.is_file():
            raise ValueError('Asset must be a file inside the manifest directory')
        if item['file'] in seen:
            raise ValueError('Duplicate manifest asset')
        seen.add(item['file'])
        if hashlib.sha256(file.read_bytes()).hexdigest() != item['sha256']:
            raise ValueError('Asset hash differs from reviewed file: ' + item['file'])
        if item['kind'] not in ['image', 'video'] or not item['groups']:
            raise ValueError('Invalid asset kind or missing placement groups')
    return data


def spec_for(item, refdata, file):
    placement_type = 'APP_SCREENSHOT' if item['kind'] == 'image' else 'APP_PREVIEW'
    kind = next(x for x in refdata['placementTypes'] if x['placementTypeId'] == placement_type)
    specs = refdata['imageSpecs'] if item['kind'] == 'image' else refdata['videoSpecs']
    matches = [s for s in specs if s['dimensions']['minWidth'] == item['width']
               and s['dimensions']['maxWidth'] == item['width']
               and s['dimensions']['minHeight'] == item['height']
               and s['dimensions']['maxHeight'] == item['height']
               and file.suffix.lower() in s['fileExtensions']
               and file.stat().st_size <= s['maxFileSize']]
    if item['kind'] == 'video':
        def seconds(value):
            match = re.fullmatch(r'PT([0-9.]+)S', value)
            if not match:
                raise ValueError('Unsupported duration specification: ' + value)
            return float(match[1])
        matches = [s for s in matches if seconds(s['duration']['min']) <= item['duration'] <= seconds(s['duration']['max'])
                   and any(f['minFps'] <= item['fps'] <= f['maxFps'] for f in s['frameRates'])
                   and (not s.get('audioRequired') or item.get('has_audio'))]
    for group in item['groups']:
        allowed = next((x['specs'] for x in kind['specMappings'] if x['placementGroupId'] == group), [])
        if not any(s['specId'] in allowed for s in matches):
            raise ValueError('Asset does not match live Apple specifications for ' + group)
    return {s['specId'] for s in matches}


def all_data(api, path, parameters=None):
    result = []
    for _ in range(100):
        page = api.call(path, parameters)
        result.extend(page['data'])
        link = page.get('links', {}).get('next')
        if not link:
            return result
        parsed = urllib.parse.urlparse(link)
        if parsed.scheme != 'https' or parsed.netloc != 'api.appstoreconnect.apple.com' or not parsed.path.startswith('/v1/'):
            raise ValueError('Untrusted pagination URL')
        path = parsed.path[4:]
        parameters = dict(urllib.parse.parse_qsl(parsed.query))
    raise RuntimeError('Listing pagination exceeded safety limit')


def upload_parts(file, operations):
    total = file.stat().st_size
    spans = sorted((o['offset'], o['length']) for o in operations)
    position = 0
    for start, length in spans:
        if start != position or length <= 0:
            raise ValueError('Upload operations must cover file exactly without overlap')
        position += length
    if position != total:
        raise ValueError('Upload operations do not cover the reviewed file')
    with file.open('rb') as source:
        for operation in operations:
            parsed = urllib.parse.urlparse(operation['url'])
            if parsed.scheme != 'https' or not (parsed.hostname or '').endswith('.apple.com') or operation['method'] != 'PUT':
                raise ValueError('Unexpected asset upload destination or method')
            headers = {x['name']: x['value'] for x in operation['requestHeaders']}
            if any(x.lower() == 'authorization' for x in headers):
                raise ValueError('Asset uploads must not carry API authorization')
            source.seek(operation['offset'])
            request = urllib.request.Request(operation['url'], data=source.read(operation['length']),
                                             headers=headers, method='PUT')
            with urllib.request.urlopen(request, timeout=120) as response:
                response.read()


def save_report(output, name, value):
    (output / name).write_text(json.dumps(sanitized(value), indent=2) + '\n')


def wait_asset(api, collection, asset, seconds=900):
    import time
    deadline = time.monotonic() + seconds
    while True:
        attrs = asset['attributes']
        state = attrs['state']
        ready = state in ['COMPLETE', 'PREPARE_FOR_SUBMISSION', 'APPROVED']
        if not ready and state not in ['UPLOAD_COMPLETE', 'UPLOADING', 'PROCESSING']:
            return asset
        # The live API can report COMPLETE before it publishes the transcoded
        # video, specification and poster. Wait for those processed resources too.
        poster = attrs.get('previewFrameImage') or {}
        poster_state = (poster.get('state') or {}).get('state')
        if poster_state == 'FAILED':
            raise RuntimeError('Apple preview frame processing failed: ' + asset['id'])
        video_ready = collection != 'appAssetLibraryVideos' or (
            attrs.get('videoAsset') and poster_state == 'COMPLETE' and poster.get('image'))
        if ready and attrs.get('specId') and video_ready:
            return asset
        if time.monotonic() >= deadline:
            raise TimeoutError('Apple asset processing timed out: ' + asset['id'] + ' (' + state + ')')
        time.sleep(10)
        asset = api.call(collection + '/' + asset['id'])['data']


def order_placements(api, locale_id, receipts):
    groups = {}
    for receipt in receipts:
        for placement in receipt['placements']:
            groups.setdefault(placement['attributes']['placementGroup'], []).append(placement['id'])
    for group, wanted in groups.items():
        path = 'appStoreVersionLocalizations/' + locale_id + '/placements'
        parameters = {'filter[placementGroup]': group, 'sort': 'placementGroupPosition', 'limit': 200}
        existing = [p['id'] for p in all_data(api, path, parameters)]
        ordered = wanted + [identity for identity in existing if identity not in wanted]
        if existing != ordered:
            request = payload('appAssetLibraryPlacementOrderingRequests', {'placementGroup': group},
                              {'appStoreVersionLocalization': ('appStoreVersionLocalizations', locale_id)})
            request['data']['relationships']['orderedPlacements'] = {'data': [
                {'type': 'appAssetLibraryPlacements', 'id': identity} for identity in ordered]}
            api.call('appAssetLibraryPlacementOrderingRequests', method='POST', data=request)
        actual = [p['id'] for p in all_data(api, path, parameters)]
        if actual != ordered:
            raise RuntimeError('Apple listing order does not match the reviewed media order: ' + group)
    return groups


def apply_listing(api, app_id, version, manifest, output):
    metadata = validate_manifest(manifest, version)
    before = inspect(api, app_id, version)
    save_report(output, 'before.json', before)
    refdata = before['referenceData'][0]['attributes']
    for item in metadata['assets']:
        spec_for(item, refdata, manifest.parent / item['file'])
    versions = before['versions']
    if len(versions) > 1:
        raise ValueError('Ambiguous matching app version')
    if versions:
        current = versions[0]
        if current['attributes']['appStoreState'] not in ['PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED', 'INVALID_BINARY']:
            raise ValueError('App Store version is not editable')
    else:
        current = api.call('appStoreVersions', method='POST', data=payload('appStoreVersions',
            {'platform': 'IOS', 'versionString': version, 'releaseType': 'MANUAL'}, {'app': ('apps', app_id)}))['data']
    if current['attributes']['versionString'] != version:
        current = api.call('appStoreVersions/' + current['id'], method='PATCH',
            data=payload('appStoreVersions', {'versionString': version}, identity=current['id']))['data']
    locales = all_data(api, 'appStoreVersions/' + current['id'] + '/appStoreVersionLocalizations')
    locale = next((x for x in locales if x['attributes']['locale'] == metadata['locale']), None)
    fields = {key: metadata[key] for key in ['description', 'promotionalText', 'marketingUrl', 'supportUrl'] if key in metadata}
    if locale:
        locale = api.call('appStoreVersionLocalizations/' + locale['id'], method='PATCH',
            data=payload('appStoreVersionLocalizations', fields, identity=locale['id']))['data']
    else:
        locale = api.call('appStoreVersionLocalizations', method='POST', data=payload('appStoreVersionLocalizations',
            dict(fields, locale=metadata['locale']), {'appStoreVersion': ('appStoreVersions', current['id'])}))['data']
    save_report(output, 'localization.json', locale)
    library_id = before['library']['id']
    receipts = []
    for item in metadata['assets']:
        video = item['kind'] == 'video'
        collection = 'appAssetLibraryVideos' if video else 'appAssetLibraryImages'
        relation = 'videos' if video else 'images'
        file = manifest.parent / item['file']
        name = file.stem + '-' + item['sha256'][:12] + file.suffix
        existing = all_data(api, 'appAssetLibraries/' + library_id + '/' + relation, {'limit': 200})
        asset = next((x for x in existing if x['attributes']['fileName'] == name), None)
        if not asset:
            attrs = {'fileName': name, 'fileSize': file.stat().st_size,
                     'category': 'APP_SCREENSHOTS_AND_PREVIEWS', 'referenceName': item['title'] + ' ' + item['sha256'][:12]}
            if video:
                attrs['previewFrameTimeCode'] = item.get('poster_timecode', '00:00:05:00')
            asset = api.call(collection, method='POST', data=payload(collection, attrs,
                {'assetLibrary': ('appAssetLibraries', library_id)}))['data']
        if asset['attributes']['fileSize'] != file.stat().st_size:
            raise ValueError('Existing asset differs from reviewed file')
        if asset['attributes']['state'] == 'AWAITING_UPLOAD':
            asset = api.call(collection + '/' + asset['id'])['data']
            upload_parts(file, asset['attributes']['uploadOperations'])
            asset = api.call(collection + '/' + asset['id'], method='PATCH',
                data=payload(collection, {'uploaded': True}, identity=asset['id']))['data']
        record = {'file': item['file'], 'sha256': item['sha256'], 'asset': sanitized(asset), 'placements': []}
        receipts.append(record)
        save_report(output, 'receipts.json', receipts)
        asset = wait_asset(api, collection, asset)
        record['asset'] = sanitized(asset)
        save_report(output, 'receipts.json', receipts)
        if asset['attributes']['state'] not in ['COMPLETE', 'PREPARE_FOR_SUBMISSION', 'APPROVED']:
            raise RuntimeError('Asset not ready: ' + file.name + ' (' + asset['attributes']['state'] + ') ' + json.dumps(asset['attributes'].get('stateDetails')))
        if asset['attributes']['specId'] not in spec_for(item, refdata, file):
            raise ValueError('Apple processed asset at an unexpected specification')
        placement_type = 'APP_PREVIEW' if video else 'APP_SCREENSHOT'
        for group in item['groups']:
            placements = all_data(api, 'appStoreVersionLocalizations/' + locale['id'] + '/placements',
                {'filter[placementType]': placement_type, 'filter[placementGroup]': group, 'include': 'image,video', 'limit': 200})
            key = 'video' if video else 'image'
            placement = next((p for p in placements if p.get('relationships', {}).get(key, {}).get('data', {}).get('id') == asset['id']), None)
            if not placement:
                placement = api.call('appAssetLibraryPlacements', method='POST', data=payload('appAssetLibraryPlacements',
                    {'placementType': placement_type, 'placementGroup': group},
                    {key: (collection, asset['id']), 'appStoreVersionLocalization': ('appStoreVersionLocalizations', locale['id'])}))['data']
            record['placements'].append(sanitized(placement))
            save_report(output, 'receipts.json', receipts)
        print('Processed and placed ' + file.name, flush=True)
    save_report(output, 'ordering.json', order_placements(api, locale['id'], receipts))
    build_number = metadata.get('build_number')
    if build_number:
        builds = api.call('builds', {'filter[app]': app_id, 'filter[version]': build_number,
            'filter[preReleaseVersion.version]': version})['data']
        ready = [b for b in builds if b['attributes']['processingState'] == 'VALID']
        if len(ready) == 1:
            api.call('appStoreVersions/' + current['id'] + '/relationships/build', method='PATCH',
                     data={'data': {'type': 'builds', 'id': ready[0]['id']}})
            save_report(output, 'selected-build.json', ready[0])
        else:
            save_report(output, 'pending-build.json', {'build_number': build_number, 'status': 'Awaiting Apple VALID'})
    after = inspect(api, app_id, version)
    save_report(output, 'listing.json', after)
    actual = next(l for v in after['versions'] for l in v['localizations'] if l['id'] == locale['id'])
    if any(actual['attributes'].get(k) != v for k, v in fields.items()):
        raise RuntimeError('Saved listing copy does not match requested metadata')
    placed_ids = {x['id'] for x in actual['placements']['data']}
    expected = {p['id'] for r in receipts for p in r['placements']}
    if not expected.issubset(placed_ids):
        raise RuntimeError('Not every requested media placement is visible in the listing')
    print('Verified saved description and ' + str(len(expected)) + ' media placements. No review submission or public release.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['inspect', 'apply'])
    parser.add_argument('--version', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--manifest', type=Path)
    args = parser.parse_args()
    app_id = os.environ['APP_STORE_APP_ID']
    if not app_id.isdigit() or not re.fullmatch(r'\d+\.\d+\.\d+', args.version):
        raise ValueError('Invalid app or version')
    args.output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='ios-store-key-', dir=os.environ.get('RUNNER_TEMP')) as private:
        api = StoreAPI(key_file(Path(private)))
        if args.action == 'apply':
            if args.manifest is None:
                raise ValueError('Apply requires a reviewed manifest')
            apply_listing(api, app_id, args.version, args.manifest.resolve(), args.output)
            return
        result = inspect(api, app_id, args.version)
        (args.output / 'listing.json').write_text(json.dumps(result, indent=2) + '\n')
        print('Verified app ' + app_id + '; ' + str(len(result['versions'])) + ' matching iOS versions')
        print('Saved listing, asset specifications and build icon metadata; no changes made.')


if __name__ == '__main__':
    main()
