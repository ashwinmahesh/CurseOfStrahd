"""Exercise API identity checks, processing failures, and actual ES256 JWT signatures."""
import base64
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('ios_deploy', Path(__file__).resolve().parents[2] / 'tools/release/ios_deploy.py')
deploy = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(deploy)


class DeployTests(unittest.TestCase):
    def test_wrong_bundle_is_rejected_before_upload(self):
        with patch.dict(os.environ, APP_STORE_APP_ID='123', IOS_BUNDLE_ID='app.example.game'), patch.object(
                deploy, 'api', return_value={'data': {'attributes': {'bundleId': 'app.other.game'}}}):
            with self.assertRaisesRegex(ValueError, 'does not match'):
                deploy.check_app(None)

    def test_processing_requires_valid_and_fails_on_invalid(self):
        with tempfile.TemporaryDirectory() as folder, patch.dict(
                os.environ, APP_STORE_APP_ID='123', IOS_BUILD='1.1', VERSION='1.0.0'), patch.object(deploy.time, 'sleep'):
            output = Path(folder) / 'build.json'
            waiting = {'data': []}
            valid = {'data': [{'id': 'build-1', 'attributes': {'processingState': 'VALID'}}]}
            with patch.object(deploy, 'api', side_effect=[waiting, valid]):
                deploy.wait_for_build(None, output)
            self.assertEqual(json.loads(output.read_text()), valid)
            invalid = {'data': [{'id': 'build-2', 'attributes': {'processingState': 'INVALID'}}]}
            with patch.object(deploy, 'api', return_value=invalid):
                with self.assertRaisesRegex(RuntimeError, 'rejected'):
                    deploy.wait_for_build(None, output)

    @unittest.skipUnless(shutil.which('openssl'), 'OpenSSL required')
    def test_jwt_signature_verifies_with_openssl(self):
        with tempfile.TemporaryDirectory() as folder, patch.dict(os.environ, KEY_ID='TESTKEY123', ISSUER_ID='test-issuer'):
            key = Path(folder) / 'key.pem'
            public = Path(folder) / 'public.pem'
            subprocess.run(['openssl', 'ecparam', '-name', 'prime256v1', '-genkey', '-noout', '-out', str(key)], check=True)
            subprocess.run(['openssl', 'pkey', '-in', str(key), '-pubout', '-out', str(public)], check=True)
            jwt = deploy.token(key)
            header, payload, raw = jwt.split('.')
            claims = json.loads(base64.urlsafe_b64decode(payload + '=='))
            self.assertEqual(claims['aud'], 'appstoreconnect-v1')
            signature = base64.urlsafe_b64decode(raw + '==')
            self.assertEqual(len(signature), 64)
            integers = []
            for half in (signature[:32], signature[32:]):
                value = half.lstrip(b'\0') or b'\0'
                if value[0] & 128:
                    value = b'\0' + value
                integers.append(b'\x02' + bytes([len(value)]) + value)
            body = b''.join(integers)
            der = Path(folder) / 'signature.der'
            der.write_bytes(b'\x30' + bytes([len(body)]) + body)
            result = subprocess.run(['openssl', 'dgst', '-sha256', '-verify', str(public), '-signature', str(der)],
                                    input=(header + '.' + payload).encode(), capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
