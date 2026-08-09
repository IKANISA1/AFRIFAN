import 'package:supabase_flutter/supabase_flutter.dart';

import 'club_scope.dart';

/// Centralized key constants for the `app_config` table.
abstract final class AppConfigKeys {
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
/// Used for feature flags and runtime configuration
/// without requiring an app update.
class AppConfigRepository {
  AppConfigRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;
  final Map<String, String> _cache = {};
  late final ClubScopeResolver _scopeResolver = ClubScopeResolver(
    client: _client,
  );

  String _cacheKey(String key, int? clubId) {
    return clubId == null ? key : '$clubId::$key';
  }

  Future<List<Map<String, dynamic>>> _loadRuntimeRows({String? key}) async {
    final response = await _client.rpc(
      'get_runtime_app_config',
      params: <String, dynamic>{'p_key': key},
    );
    if (response is! List) {
      return const <Map<String, dynamic>>[];
    }
    return response
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
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

    final rows = await _loadRuntimeRows(key: key);
    String? resolvedValue;
    for (final row in rows) {
      final value = row['value']?.toString();
      if (value == null) continue;
      if (row['scope'] == 'club' && clubId != null) {
        resolvedValue = value;
        break;
      }
      resolvedValue ??= value;
    }
    if (resolvedValue != null) {
      _cache[scopedCacheKey] = resolvedValue;
    }
    return resolvedValue;
  }

  /// Fetch all config entries.
  Future<Map<String, String>> getAll() async {
    final result = <String, String>{};
    final clubId = _scopeResolver.currentClubId;

    final rows = await _loadRuntimeRows();
    for (final row in rows) {
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
