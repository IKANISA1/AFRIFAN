import 'package:feat_settings/src/models/user_notification_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification settings retain but do not submit concurrency token', () {
    final settings = UserNotificationSettings.fromJson(const <String, dynamic>{
      'user_id': 'user-1',
      'club_id': 1,
      'updated_at': '2026-07-24T10:00:00Z',
    });

    expect(settings.updatedAt, '2026-07-24T10:00:00Z');
    expect(settings.copyWith(pushEnabled: true).updatedAt, settings.updatedAt);
    expect(settings.toJson().containsKey('updated_at'), isFalse);
  });
}
