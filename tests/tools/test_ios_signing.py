"""Reject mismatched signing material before an expensive full-content import."""
import datetime as dt
import importlib.util
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location('ios_signing', Path(__file__).resolve().parents[2] / 'tools/release/ios_signing.py')
signing = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(signing)


class SigningTests(unittest.TestCase):
    def setUp(self):
        self.now = dt.datetime(2026, 1, 1, tzinfo=dt.timezone.utc)
        self.profile = {'UUID': '12345678-1234-1234-1234-123456789ABC',
                        'ExpirationDate': dt.datetime(2027, 1, 1), 'TeamIdentifier': ['ABCDEFGHIJ'],
                        'Entitlements': {'application-identifier': 'OLDPREFIX.app.example.game',
                                         'com.apple.developer.team-identifier': 'ABCDEFGHIJ'}}

    def validate(self, method='app-store'):
        return signing.validate_profile(self.profile, 'app.example.game', method, self.now)

    def test_explicit_app_id_can_have_a_legacy_prefix(self):
        self.assertEqual(self.validate()[0], 'ABCDEFGHIJ')

    def test_expired_profile_is_rejected(self):
        self.profile['ExpirationDate'] = dt.datetime(2025, 1, 1)
        with self.assertRaisesRegex(ValueError, 'expired'):
            self.validate()

    def test_wildcard_and_wrong_app_are_rejected(self):
        for app in ['ABCDEFGHIJ.*', 'ABCDEFGHIJ.app.other.game']:
            self.profile['Entitlements']['application-identifier'] = app
            with self.assertRaisesRegex(ValueError, 'explicit'):
                self.validate()

    def test_profile_method_must_match_dispatch(self):
        self.profile['ProvisionedDevices'] = ['test-device']
        with self.assertRaisesRegex(ValueError, 'ad-hoc'):
            self.validate()
        self.validate('ad-hoc')
        self.profile['Entitlements']['get-task-allow'] = True
        self.validate('development')
        with self.assertRaisesRegex(ValueError, 'development'):
            self.validate('ad-hoc')

    def test_enterprise_or_mismatched_team_is_rejected(self):
        self.profile['ProvisionsAllDevices'] = True
        with self.assertRaisesRegex(ValueError, 'Enterprise'):
            self.validate()
        del self.profile['ProvisionsAllDevices']
        self.profile['Entitlements']['com.apple.developer.team-identifier'] = 'OTHERTEAM1'
        with self.assertRaisesRegex(ValueError, 'disagree'):
            self.validate()


if __name__ == '__main__':
    unittest.main()
