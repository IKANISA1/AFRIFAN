import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/user_notification_settings.dart';
import 'models/user_privacy_settings.dart';

class SettingsConflictException implements Exception {
  const SettingsConflictException(this.resource);

  final String resource;

  @override
  String toString() =>
      '$resource changed on another device. The latest version must be reviewed before saving again.';
}

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
    final row = await _writePrivacySettings(settings);

    if (row == null) {
      throw const SettingsConflictException('Privacy settings');
    }

    return UserPrivacySettings.fromJson(Map<String, dynamic>.from(row));
  }

  Future<Map<String, dynamic>?> _writePrivacySettings(
    UserPrivacySettings settings,
  ) async {
    final expectedUpdatedAt = settings.updatedAt;
    if (expectedUpdatedAt == null) {
      try {
        return await _client
            .from('user_privacy_settings')
            .insert(settings.toJson())
            .select()
            .maybeSingle();
      } on PostgrestException catch (error) {
        if (error.code == '23505') {
          throw const SettingsConflictException('Privacy settings');
        }
        rethrow;
      }
    }

    return _client
        .from('user_privacy_settings')
        .update(settings.toJson())
        .eq('user_id', settings.userId)
        .eq('updated_at', expectedUpdatedAt)
        .select()
        .maybeSingle();
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
    final row = await _writeNotificationSettings(settings);

    if (row == null) {
      throw const SettingsConflictException('Notification settings');
    }

    return UserNotificationSettings.fromJson(Map<String, dynamic>.from(row));
  }

  Future<Map<String, dynamic>?> _writeNotificationSettings(
    UserNotificationSettings settings,
  ) async {
    final expectedUpdatedAt = settings.updatedAt;
    if (expectedUpdatedAt == null) {
      try {
        return await _client
            .from('user_notification_settings')
            .insert(settings.toJson())
            .select()
            .maybeSingle();
      } on PostgrestException catch (error) {
        if (error.code == '23505') {
          throw const SettingsConflictException('Notification settings');
        }
        rethrow;
      }
    }

    return _client
        .from('user_notification_settings')
        .update(settings.toJson())
        .eq('user_id', settings.userId)
        .eq('updated_at', expectedUpdatedAt)
        .select()
        .maybeSingle();
  }
}
