import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Fetch a single config value by key.
  Future<String?> getValue(String key, {bool forceRefresh = false}) async {
    if (!forceRefresh && _cache.containsKey(key)) {
      return _cache[key];
    }
    if (forceRefresh) {
      _cache.remove(key);
    }

    final rows = await _client
        .from('app_config')
        .select('value')
        .eq('key', key)
        .limit(1);

    if (rows.isNotEmpty) {
      final value = rows.first['value']?.toString();
      if (value != null) {
        _cache[key] = value;
        return value;
      }
    }

    return null;
  }

  /// Fetch all config entries.
  Future<Map<String, String>> getAll() async {
    final rows = await _client.from('app_config').select();
    final result = <String, String>{};

    for (final row in rows) {
      final key = row['key']?.toString();
      final value = row['value']?.toString();
      if (key != null && value != null) {
        result[key] = value;
      }
    }

    _cache.addAll(result);
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
