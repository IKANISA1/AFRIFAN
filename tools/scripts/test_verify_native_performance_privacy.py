"""Mutation regressions over copies of the actual ten native host files."""
import contextlib
import io
import json
from pathlib import Path
import re
import shutil
import tempfile
import unittest

import verify_native_performance_privacy as verifier


class NativePerformancePrivacyTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix='africlub-performance-controls-')
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.scopes = verifier.declared_scopes(verifier.ROOT)
        self.sources = {}
        for club in self.scopes:
            for platform, relative in [('android', 'android/app/src/main/AndroidManifest.xml'),
                                       ('ios', 'ios/Runner/Info.plist')]:
                source = verifier.ROOT / 'apps' / club / relative
                destination = self.root / source.relative_to(verifier.ROOT)
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, destination)
                self.sources[club, platform] = (destination, destination.read_bytes())
        scope = Path('docs/release/full_stack_qa_plan.md')
        (self.root / scope).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(verifier.ROOT / scope, self.root / scope)

    def rejected(self, code=None):
        with self.assertRaises(verifier.NativeControlError) as caught:
            verifier.verify_native_controls(self.root, self.scopes)
        report = caught.exception.report
        self.assertFalse(report['configurationVerified'])
        self.assertEqual(len(report['targets']), 10)
        if code:
            self.assertIn(code, [error['code'] for error in report['errors']])
        self.assertFalse(report['hostedJobsExecuted'])
        self.assertFalse(report['releaseAccepted'])
        return report

    def test_actual_ten_host_files_have_permanent_controls(self):
        report = verifier.verify_native_controls(self.root, self.scopes)
        self.assertTrue(report['configurationVerified'])
        self.assertEqual(len(report['targets']), 10)
        self.assertEqual(len(report['sourceInputs']), 10)
        self.assertTrue(all(target['permanentCollectionDeactivated'] for target in report['targets']))
        self.assertTrue(all(len(source['sha256']) == 64 for source in report['sourceInputs']))

    def test_each_host_missing_file_is_rejected(self):
        for key, (path, data) in self.sources.items():
            with self.subTest(host=key):
                path.unlink()
                self.rejected('missing_or_unsafe_source')
                path.write_bytes(data)

    def test_each_host_missing_or_renamed_control_is_rejected(self):
        for key, (path, data) in self.sources.items():
            with self.subTest(host=key):
                path.write_text(data.decode().replace(verifier.CONTROL, 'unreviewed_control'))
                self.rejected('missing_android_control' if key[1] == 'android' else 'missing_ios_control')
                path.write_bytes(data)

    def test_duplicate_controls_rejected_on_every_host(self):
        for key, (path, data) in self.sources.items():
            text = data.decode()
            if key[1] == 'android':
                duplicate = f'<meta-data android:name="{verifier.CONTROL}" android:value="true" />'
                text = text.replace('</application>', duplicate + '</application>', 1)
            else:
                text = text.replace('<dict>', f'<dict><key>{verifier.CONTROL}</key><true/>', 1)
            with self.subTest(host=key):
                path.write_text(text)
                self.rejected('duplicate_android_control' if key[1] == 'android' else 'duplicate_ios_key')
                path.write_bytes(data)

    def test_android_control_must_be_literal_true_for_every_club(self):
        for club in self.scopes:
            path, data = self.sources[club, 'android']
            for value in ['false', 'TRUE', '1', '${collectionDeactivated}', '@bool/performance_disabled']:
                with self.subTest(club=club, value=value):
                    text = data.decode().replace(f'android:name="{verifier.CONTROL}"\n            android:value="true"',
                                                 f'android:name="{verifier.CONTROL}"\n            android:value="{value}"')
                    self.assertNotEqual(text, data.decode())
                    path.write_text(text)
                    self.rejected('android_control_not_literal_true')
                    path.write_bytes(data)

    def test_android_resource_or_activity_control_cannot_replace_application_control(self):
        for club in self.scopes:
            path, data = self.sources[club, 'android']
            text = data.decode()
            metadata = re.search(r'<meta-data\s+android:name="' + verifier.CONTROL + r'"[^>]*/>', text).group()
            for fault in ['resource', 'activity']:
                with self.subTest(club=club, fault=fault):
                    changed = text.replace(metadata, metadata.replace('android:value="true"', 'android:resource="@bool/disabled"')) if fault == 'resource' else text.replace(metadata, '').replace('</activity>', metadata + '</activity>', 1)
                    path.write_text(changed)
                    self.rejected('android_control_not_literal_true' if fault == 'resource' else 'misplaced_android_control')
                    path.write_bytes(data)

    def test_ios_control_must_be_boolean_true_for_every_club(self):
        for club in self.scopes:
            path, data = self.sources[club, 'ios']
            for value in ['<false/>', '<string>true</string>', '<integer>1</integer>', '<true>private_payload</true>']:
                with self.subTest(club=club, value=value):
                    path.write_text(data.decode().replace(f'<key>{verifier.CONTROL}</key>\n\t<true/>',
                                                         f'<key>{verifier.CONTROL}</key>\n\t{value}'))
                    self.rejected('ios_control_not_boolean_true')
                    path.write_bytes(data)

    def test_android_build_type_and_flavor_overrides_cannot_remove_or_replace_controls(self):
        for club in self.scopes:
            for source_set in ['debug', 'profile', 'release', 'privateFlavor']:
                path = self.root / 'apps' / club / 'android/app/src' / source_set / 'AndroidManifest.xml'
                path.parent.mkdir(parents=True, exist_ok=True)
                for metadata in [f'<meta-data android:name="{verifier.CONTROL}" android:value="false"/>',
                                 f'<meta-data android:name="{verifier.CONTROL}" tools:node="remove"/>',
                                 '<meta-data tools:node="removeAll"/>',
                                 f'<meta-data android:name="{verifier.CONTROL}" android:value="true"/>']:
                    with self.subTest(club=club, source_set=source_set, metadata=metadata):
                        path.write_text(f'<manifest xmlns:android="http://schemas.android.com/apk/res/android" xmlns:tools="http://schemas.android.com/tools"><application>{metadata}</application></manifest>')
                        self.rejected()
                for node in ['replace', 'remove', 'removeAll']:
                    with self.subTest(club=club, source_set=source_set, application=node):
                        path.write_text(f'<manifest xmlns:tools="http://schemas.android.com/tools"><application tools:node="{node}"/></manifest>')
                        self.rejected('contradictory_android_override')
                path.unlink()

    def test_benign_android_override_is_inventoried_without_changing_control(self):
        path = self.root / 'apps/rayon_sports/android/app/src/debug/AndroidManifest.xml'
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><uses-permission android:name="android.permission.INTERNET"/></manifest>')
        report = verifier.verify_native_controls(self.root, self.scopes)
        self.assertTrue(report['configurationVerified'])
        self.assertEqual(len(report['sourceInputs']), 11)

    def test_malformed_xml_plist_and_unsafe_host_sources_fail_closed(self):
        for key, (path, data) in self.sources.items():
            with self.subTest(host=key):
                path.write_text('<private_invalid_source>')
                report = self.rejected()
                self.assertNotIn('private_invalid_source', json.dumps(report))
                path.unlink()
                outside = self.root / 'private-outside-source'
                outside.write_bytes(data)
                path.symlink_to(outside)
                self.rejected('missing_or_unsafe_source')
                path.unlink()
                path.write_bytes(data)

    def test_scope_drift_and_duplicate_declared_club_are_rejected(self):
        for scopes in [dict(list(self.scopes.items())[:-1]), {**self.scopes, 'foreign': '99'}]:
            with self.assertRaises(ValueError):
                verifier.verify_native_controls(self.root, scopes)
        scope = self.root / 'docs/release/full_stack_qa_plan.md'
        text = scope.read_text()
        scope.write_text(text.replace('| as_vita |', '| rayon_sports |'))
        with self.assertRaises(ValueError):
            verifier.declared_scopes(self.root)

    def test_cli_writes_source_bound_finite_report_and_nonzero_failure(self):
        report_path = self.root / 'report.json'
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(verifier.main(['--root', str(self.root), '--report', str(report_path)]), 0)
        result = json.loads(report_path.read_text())
        self.assertEqual(len(result['targets']), 10)
        self.assertEqual(len(result['sourceInputs']), 11)
        path, data = self.sources['nkana', 'ios']
        path.write_text(data.decode().replace(verifier.CONTROL, 'private_configuration_value'))
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(verifier.main(['--root', str(self.root), '--report', str(report_path)]), 1)
        self.assertNotIn('private_configuration_value', report_path.read_text())


if __name__ == '__main__':
    unittest.main()
