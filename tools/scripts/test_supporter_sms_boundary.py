import pathlib
import tempfile
import unittest
from validate_supporter_sms_boundary import APPS, manifest_violations, validate, strip_comments

HEADER = '<manifest xmlns:android="http://schemas.android.com/apk/res/android" xmlns:tools="http://schemas.android.com/tools">'

class SupporterPrivacyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        self.write('pubspec.yaml', 'workspace:\n' + ''.join('  - apps/' + app + '\n' for app in APPS) +
                   '  - packages/features/shared\nmelos:\n  scripts: {}\n')
        for app in APPS:
            self.write(f'apps/{app}/pubspec.yaml', f'name: {app}\ndependencies:\n  flutter:\n    sdk: flutter\n')
            self.write(f'apps/{app}/lib/main.dart', 'void main() {}')
            self.write(f'apps/{app}/android/app/src/main/AndroidManifest.xml', HEADER +
                       '<uses-permission android:name="android.permission.INTERNET"/></manifest>')
        self.write('packages/features/shared/pubspec.yaml', 'name: shared\ndependencies:\n  flutter:\n    sdk: flutter\n')
        self.write('packages/features/shared/lib/shared.dart', 'const enabled = true;')
    def write(self, relative, value):
        file = self.root / relative; file.parent.mkdir(parents=True, exist_ok=True); file.write_text(value); return file
    def manifest(self, body, app='nkana'):
        return self.write(f'apps/{app}/android/app/src/main/AndroidManifest.xml', HEADER + body + '</manifest>')
    def test_all_five_clean(self): self.assertTrue(validate(self.root)['passed'])
    def test_non_reference_club_permission(self):
        self.manifest('<uses-permission android:name="android.permission.READ_SMS"/>', 'costa_do_sol')
        self.assertFalse(validate(self.root)['passed'])
    def test_permission_removal_is_not_active_access(self):
        self.manifest('<uses-permission android:name="android.permission.READ_SMS" tools:node="remove"/>')
        self.assertTrue(validate(self.root)['passed'])
    def test_sdk23_permission(self):
        self.manifest('<uses-permission-sdk-23 android:name="android.permission.RECEIVE_SMS"/>')
        self.assertFalse(validate(self.root)['passed'])
    def test_receiver(self):
        self.manifest('<application><receiver android:name="SmsReceiver"/></application>')
        self.assertFalse(validate(self.root)['passed'])
    def test_shared_runtime_collector(self):
        self.write('packages/features/shared/lib/shared.dart', 'void x() { SmsManager(); }')
        self.assertFalse(validate(self.root)['passed'])
    def test_runtime_dependency(self):
        self.write('packages/features/shared/pubspec.yaml', 'name: shared\ndependencies:\n  telephony: 1.0.0\n')
        self.assertFalse(validate(self.root)['passed'])
    def test_development_dependency_not_shipped(self):
        self.write('packages/features/shared/pubspec.yaml', 'name: shared\ndev_dependencies:\n  telephony: 1.0.0\n')
        self.assertTrue(validate(self.root)['passed'])
    def test_comment_is_not_runtime(self):
        self.write('packages/features/shared/lib/shared.dart', '// SmsManager\n/* nested /* querySms */ comment */ const ok = true;')
        self.assertTrue(validate(self.root)['passed'])
    def test_sms_uri_string_is_detected(self):
        self.write('packages/features/shared/lib/shared.dart', "const inbox = 'content://sms/inbox';")
        self.assertFalse(validate(self.root)['passed'])
    def test_ordinary_https_string_survives_comment_parsing(self):
        self.assertIn('https://club.invalid', strip_comments("const url = 'https://club.invalid'; // discarded"))
    def test_missing_app_fails(self):
        (self.root/'apps/vitalo/android/app/src/main/AndroidManifest.xml').unlink()
        self.assertFalse(validate(self.root)['passed'])
    def test_extra_workspace_app_fails(self):
        file=self.root/'pubspec.yaml'; file.write_text(file.read_text().replace('melos:', '  - apps/retired\nmelos:'))
        self.assertFalse(validate(self.root)['passed'])
    def test_backend_gateway_is_not_scanned(self):
        self.write('supabase/functions/sms-ingest/index.ts', 'SmsManager();')
        self.assertTrue(validate(self.root)['passed'])
    def test_merged_manifests_are_required_per_club(self):
        self.assertFalse(validate(self.root, self.root/'merged')['passed'])
        for app in APPS:self.write(f'merged/{app}/AndroidManifest.xml', HEADER+'</manifest>')
        report=validate(self.root,self.root/'merged'); self.assertTrue(report['passed']); self.assertEqual(report['mergedManifestsChecked'],5)
    def test_invalid_xml_fails(self):
        self.write('apps/as_vita/android/app/src/main/AndroidManifest.xml','<manifest')
        self.assertFalse(validate(self.root)['passed'])

if __name__ == '__main__': unittest.main()
