import 'package:feat_settings/src/models/user_privacy_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserPrivacySettings', () {
    test('defaults SMS autoread consent to disabled', () {
      final settings = UserPrivacySettings.defaults(
        userId: 'user-1',
        clubId: '1',
      );

      expect(settings.momoSmsAutoreadEnabled, isFalse);
      expect(settings.analyticsEnabled, isFalse);
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

    test(
      'fromJson falls back to disabled when analytics consent is absent',
      () {
        final settings = UserPrivacySettings.fromJson(const <String, dynamic>{
          'user_id': 'user-1',
          'club_id': 1,
          'group_visibility': 'members',
        });

        expect(settings.analyticsEnabled, isFalse);
      },
    );

    test('preserves the concurrency token without writing it', () {
      final settings = UserPrivacySettings.fromJson(const <String, dynamic>{
        'user_id': 'user-1',
        'club_id': 1,
        'updated_at': '2026-07-24T10:00:00Z',
      });

      expect(settings.updatedAt, '2026-07-24T10:00:00Z');
      expect(
        settings.copyWith(analyticsEnabled: true).updatedAt,
        settings.updatedAt,
      );
      expect(settings.toJson().containsKey('updated_at'), isFalse);
    });
  });
}
