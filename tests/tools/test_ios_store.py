import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools/release'))
import ios_store


class StoreTests(unittest.TestCase):
    def test_uploaded_asset_waits_for_apple_processing(self):
        from unittest.mock import Mock
        api = Mock()
        ready = {'id': 'video-1', 'attributes': {'state': 'PREPARE_FOR_SUBMISSION'}}
        api.call.return_value = {'data': ready}
        with patch('time.sleep'):
            actual = ios_store.wait_asset(api, 'appAssetLibraryVideos',
                {'id': 'video-1', 'attributes': {'state': 'UPLOAD_COMPLETE'}})
        self.assertEqual(actual, ready)
        api.call.assert_called_once_with('appAssetLibraryVideos/video-1')

    def test_ordering_keeps_existing_placements_and_verifies_new_sequence(self):
        from unittest.mock import Mock
        api = Mock()
        api.call.side_effect = [
            {'data': [{'id': 'older'}, {'id': 'second'}, {'id': 'first'}]}, {},
            {'data': [{'id': 'first'}, {'id': 'second'}, {'id': 'older'}]}]
        receipts = [{'placements': [{'id': i, 'attributes': {'placementGroup': 'phone'}}]}
                    for i in ['first', 'second']]
        ios_store.order_placements(api, 'locale', receipts)
        request = api.call.call_args_list[1].kwargs['data']
        order = request['data']['relationships']['orderedPlacements']['data']
        self.assertEqual([p['id'] for p in order], ['first', 'second', 'older'])

    def test_reports_never_preserve_signed_upload_urls(self):
        report = {'data': [{'attributes': {'uploadOperations': [{'url': 'secret'}], 'state': 'UPLOADING'}}]}
        self.assertNotIn('secret', json.dumps(ios_store.sanitized(report)))
        self.assertEqual(ios_store.sanitized(report)['data'][0]['attributes']['state'], 'UPLOADING')

    def test_inspection_includes_equivalent_initial_draft_version(self):
        from unittest.mock import Mock
        api = Mock()
        def call(path, parameters=None):
            if path == 'apps/1':
                return {'data': {'id': '1', 'attributes': {'bundleId': 'app.curseofstrahd.game'}}}
            if path == 'apps/1/appStoreVersions':
                self.assertNotIn('filter[versionString]', parameters)
                return {'data': [{'id': 'draft', 'attributes': {'versionString': '1.0'}},
                                 {'id': 'unrelated', 'attributes': {'versionString': '2.0'}}]}
            return {'data': []}
        api.call.side_effect = call
        result = ios_store.inspect(api, '1', '1.0.0')
        self.assertEqual([v['id'] for v in result['versions']], ['draft'])
        self.assertEqual(len(result['allVersions']), 2)

    def test_api_rejects_other_hosts_and_parent_paths(self):
        api = ios_store.StoreAPI(Path('unused'))
        for path in ['https://example.com/apps', '../apps/1', 'apps/1?token=bad']:
            with self.subTest(path=path), self.assertRaises(ValueError):
                api.call(path)

    def test_manifest_rejects_modified_files_and_path_escape(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            asset = base / 'shot.jpg'
            asset.write_bytes(b'actual reviewed screenshot')
            item = {'file': 'shot.jpg', 'kind': 'image', 'groups': ['phone'],
                    'sha256': hashlib.sha256(asset.read_bytes()).hexdigest()}
            data = {'version': '1.0.0', 'locale': 'en-US', 'description': 'A game.', 'assets': [item]}
            manifest = base / 'listing.json'
            manifest.write_text(json.dumps(data))
            self.assertEqual(ios_store.validate_manifest(manifest, '1.0.0')['assets'][0], item)
            asset.write_bytes(b'changed')
            with self.assertRaises(ValueError):
                ios_store.validate_manifest(manifest, '1.0.0')
            item['file'] = '../outside.jpg'
            manifest.write_text(json.dumps(data))
            with self.assertRaises(ValueError):
                ios_store.validate_manifest(manifest, '1.0.0')

    def test_upload_requires_complete_nonoverlapping_ranges(self):
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / 'file.jpg'
            file.write_bytes(b'1234')
            for spans in [[(0, 2)], [(0, 3), (2, 1)], [(1, 3)]]:
                with self.subTest(spans=spans), self.assertRaises(ValueError):
                    ios_store.upload_parts(file, [{'offset': x, 'length': y} for x, y in spans])

    def test_upload_rejects_non_apple_destination_without_transmitting(self):
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / 'file.jpg'
            file.write_bytes(b'1234')
            with patch('urllib.request.urlopen') as send, self.assertRaises(ValueError):
                ios_store.upload_parts(file, [{'offset': 0, 'length': 4, 'method': 'PUT',
                    'url': 'https://apple.com.example.org/upload', 'requestHeaders': []}])
            send.assert_not_called()

    def test_video_uses_live_dimensions_duration_frame_rate_and_audio_requirements(self):
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / 'preview.mp4'
            file.write_bytes(b'video')
            ref = {'placementTypes': [{'placementTypeId': 'APP_PREVIEW', 'specMappings': [
                {'placementGroupId': 'live-phone', 'specs': ['live-spec']}]}], 'videoSpecs': [
                {'specId': 'live-spec', 'dimensions': {'minWidth': 1920, 'maxWidth': 1920, 'minHeight': 886, 'maxHeight': 886},
                 'fileExtensions': ['.mp4'], 'maxFileSize': 1000, 'duration': {'min': 'PT15S', 'max': 'PT30S'},
                 'frameRates': [{'minFps': 23, 'maxFps': 30}], 'audioRequired': True}]}
            item = {'kind': 'video', 'groups': ['live-phone'], 'width': 1920, 'height': 886, 'duration': 29, 'fps': 30, 'has_audio': True}
            self.assertEqual(ios_store.spec_for(item, ref, file), {'live-spec'})
            for change in [{'duration': 89}, {'fps': 60}, {'has_audio': False}, {'width': 1080}, {'groups': ['unknown']}]:
                with self.subTest(change=change), self.assertRaises(ValueError):
                    ios_store.spec_for(dict(item, **change), ref, file)


if __name__ == '__main__':
    unittest.main()
