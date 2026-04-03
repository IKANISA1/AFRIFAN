import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/user_notification_settings.dart';
import 'models/user_privacy_settings.dart';

class SettingsRepository {
  SettingsRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  Future<UserPrivacySettings> getPrivacySettings({
    required String userId,
    required String clubId,
  }) async {
    final row = await _client
        .from('user_privacy_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (row != null) {
      return UserPrivacySettings.fromJson(Map<String, dynamic>.from(row));
    }

    return updatePrivacySettings(
      UserPrivacySettings.defaults(userId: userId, clubId: clubId),
    );
  }

  Future<UserPrivacySettings> updatePrivacySettings(
    UserPrivacySettings settings,
  ) async {
    await _client
        .from('user_privacy_settings')
        .upsert(settings.toJson(), onConflict: 'user_id');

    final row = await _client
        .from('user_privacy_settings')
        .select()
        .eq('user_id', settings.userId)
        .maybeSingle();

    if (row == null) {
      throw StateError('Privacy settings were not returned after saving.');
    }

    return UserPrivacySettings.fromJson(Map<String, dynamic>.from(row));
  }

  Future<UserNotificationSettings> getNotificationSettings({
    required String userId,
    required String clubId,
  }) async {
    final row = await _client
        .from('user_notification_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (row != null) {
      return UserNotificationSettings.fromJson(Map<String, dynamic>.from(row));
    }

    return updateNotificationSettings(
      UserNotificationSettings.defaults(userId: userId, clubId: clubId),
    );
  }

  Future<UserNotificationSettings> updateNotificationSettings(
    UserNotificationSettings settings,
  ) async {
    await _client
        .from('user_notification_settings')
        .upsert(settings.toJson(), onConflict: 'user_id');

    final row = await _client
        .from('user_notification_settings')
        .select()
        .eq('user_id', settings.userId)
        .maybeSingle();

    if (row == null) {
      throw StateError('Notification settings were not returned after saving.');
    }

    return UserNotificationSettings.fromJson(Map<String, dynamic>.from(row));
  }
}
