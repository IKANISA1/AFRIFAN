import 'package:supabase_flutter/supabase_flutter.dart';

import 'club_scope.dart';

/// Centralized key constants for the `app_config` table.
abstract final class AppConfigKeys {
  // BioPay
  static const biopayEnabled = 'feature_biopay_enabled';
  static const biopayMatchThreshold = 'biopay_match_threshold';
  static const biopayCacheTtlHours = 'biopay_cache_ttl_hours';
  static const biopayStableFrames = 'biopay_stable_frames';

  // Feature flags
  static const featureFlagsPrefix = 'feature_';
  static const killSwitchPrefix = 'kill_';

  // Payment
  static const defaultPaymentMethod = 'default_payment_method';

  // Support
  static const supportWhatsApp = 'support_whatsapp';
  static const supportEmail = 'support_email';
}

/// Fetches key-value config from the `app_config` Supabase table.
///
/// Used for feature flags, BioPay thresholds, and runtime configuration
/// without requiring an app update.
class AppConfigRepository {
  AppConfigRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;
  final Map<String, String> _cache = {};
  late final ClubScopeResolver _scopeResolver = ClubScopeResolver(
    client: _client,
  );

  bool _isMissingRelation(Object error, String relation) {
    if (error is! PostgrestException) {
      return false;
    }
    final message = error.message.toLowerCase();
    return message.contains(relation.toLowerCase()) &&
        message.contains('does not exist');
  }

  String _cacheKey(String key, int? clubId) {
    return clubId == null ? key : '$clubId::$key';
  }

  Future<String?> _getConfigValueFromTable(
    String table,
    String key, {
    int? clubId,
  }) async {
    try {
      var query = _client.from(table).select('value').eq('key', key);
      if (clubId != null) {
        query = query.eq('club_id', clubId);
      }
      final rows = await query.limit(1);
      if (rows.isEmpty) {
        return null;
      }
      return rows.first['value']?.toString();
    } on PostgrestException catch (error) {
      if (_isMissingRelation(error, table)) {
        return null;
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _getRowsFromTable(
    String table, {
    int? clubId,
  }) async {
    try {
      var query = _client.from(table).select();
      if (clubId != null) {
        query = query.eq('club_id', clubId);
      }
      final rows = await query;
      return List<Map<String, dynamic>>.from(rows);
    } on PostgrestException catch (error) {
      if (_isMissingRelation(error, table)) {
        return const <Map<String, dynamic>>[];
      }
      rethrow;
    }
  }

  /// Fetch a single config value by key.
  Future<String?> getValue(String key, {bool forceRefresh = false}) async {
    final clubId = _scopeResolver.currentClubId;
    final scopedCacheKey = _cacheKey(key, clubId);

    if (!forceRefresh && _cache.containsKey(scopedCacheKey)) {
      return _cache[scopedCacheKey];
    }
    if (forceRefresh) {
      _cache.remove(scopedCacheKey);
    }

    final clubValue = clubId == null
        ? null
        : await _getConfigValueFromTable(
            'club_app_config',
            key,
            clubId: clubId,
          );
    if (clubValue != null) {
      _cache[scopedCacheKey] = clubValue;
      return clubValue;
    }

    final globalValue = await _getConfigValueFromTable('app_config', key);
    if (globalValue != null) {
      _cache[scopedCacheKey] = globalValue;
      return globalValue;
    }

    return null;
  }

  /// Fetch all config entries.
  Future<Map<String, String>> getAll() async {
    final result = <String, String>{};
    final clubId = _scopeResolver.currentClubId;

    final globalRows = await _getRowsFromTable('app_config');
    for (final row in globalRows) {
      final key = row['key']?.toString();
      final value = row['value']?.toString();
      if (key != null && value != null) {
        result[key] = value;
      }
    }

    final clubRows = clubId == null
        ? const <Map<String, dynamic>>[]
        : await _getRowsFromTable('club_app_config', clubId: clubId);

    for (final row in clubRows) {
      final key = row['key']?.toString();
      final value = row['value']?.toString();
      if (key != null && value != null) {
        result[key] = value;
      }
    }

    _cache
      ..clear()
      ..addAll({
        for (final entry in result.entries)
          _cacheKey(entry.key, clubId): entry.value,
      });
    return result;
  }

  /// Check if a feature flag is enabled.
  Future<bool> isFeatureEnabled(String featureKey) async {
    final value = await getValue(
      '${AppConfigKeys.featureFlagsPrefix}$featureKey',
    );
    if (value == null) return true; // Default: enabled
    return value.toLowerCase() == 'true' || value == '1';
  }

  /// Check if a kill switch is active.
  Future<bool> isKillSwitchActive(String switchKey) async {
    final value = await getValue('${AppConfigKeys.killSwitchPrefix}$switchKey');
    if (value == null) return false; // Default: not killed
    return value.toLowerCase() == 'true' || value == '1';
  }

  /// Clear the in-memory cache.
  void clearCache() => _cache.clear();
}
