import 'package:feat_settings/src/models/user_privacy_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserPrivacySettings', () {
    test('defaults SMS autoread consent to disabled', () {
      final settings = UserPrivacySettings.defaults(userId: 'user-1', clubId: '1');

      expect(settings.momoSmsAutoreadEnabled, isFalse);
    });

    test('fromJson falls back to disabled when SMS consent is absent', () {
      final settings = UserPrivacySettings.fromJson(const <String, dynamic>{
        'user_id': 'user-1',
        'club_id': 1,
        'group_visibility': 'members',
        'analytics_enabled': true,
        'biometric_login_enabled': true,
        'show_activity_status': true,
      });

      expect(settings.momoSmsAutoreadEnabled, isFalse);
    });
  });
}
