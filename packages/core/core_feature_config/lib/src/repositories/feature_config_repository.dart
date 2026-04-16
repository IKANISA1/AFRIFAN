import 'dart:convert';
import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/platform_feature_config.dart';

class FeatureConfigRepository {
  FeatureConfigRepository();

  static const _cacheKey = 'africlub_platform_config';
  static const _tag = 'FeatureConfigRepo';

  Future<PlatformConfigSnapshot> loadConfig({
    required int clubId,
    String channel = 'mobile',
  }) async {
    // 1. Try to fetch from network
    final result = await SafeRpc.call(
      'get_platform_config',
      params: {
        'p_channel': channel,
        'p_club_id': clubId,
      },
      tag: _tag,
    );

    if (result.isSuccess) {
      final snapshot = PlatformConfigSnapshot.fromJson(
        Map<String, dynamic>.from(result.requireData as Map),
      );
      // Cache success
      await _cacheConfig(snapshot);
      return snapshot;
    }

    // 2. Network failed, try cache
    final cached = await _loadCachedConfig();
    if (cached != null) {
      AfriLogger.info(_tag, 'Returning cached platform config');
      return cached;
    }

    // 3. Last resort, return empty
    AfriLogger.warn(_tag, 'No config available, returning empty snapshot');
    return PlatformConfigSnapshot.empty;
  }

  Future<void> _cacheConfig(PlatformConfigSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(snapshot.toJson()));
    } catch (e) {
      AfriLogger.warn(_tag, 'Failed to cache platform config: $e');
    }
  }

  Future<PlatformConfigSnapshot?> _loadCachedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      return PlatformConfigSnapshot.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      AfriLogger.warn(_tag, 'Failed to load cached platform config: $e');
      return null;
    }
  }
}
