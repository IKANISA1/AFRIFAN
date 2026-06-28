import 'dart:convert';
import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/platform_feature_config.dart';

class FeatureConfigRepository {
  FeatureConfigRepository();

  static const _cacheKeyPrefix = 'africlub_platform_config';
  static const _legacyCacheKey = 'africlub_platform_config';
  static const _tag = 'FeatureConfigRepo';

  Future<PlatformConfigSnapshot> loadConfig({
    required int clubId,
    String channel = 'mobile',
  }) async {
    // 1. Try to fetch from network
    final result = await SafeRpc.call(
      'get_platform_config',
      params: {'p_channel': channel, 'p_club_id': clubId},
      tag: _tag,
    );

    if (result.isSuccess) {
      final snapshot = PlatformConfigSnapshot.fromJson(
        Map<String, dynamic>.from(result.requireData as Map),
      );
      // Cache success
      await _cacheConfig(clubId: clubId, channel: channel, snapshot: snapshot);
      return snapshot;
    }

    // 2. Network failed, try cache
    final cached = await _loadCachedConfig(clubId: clubId, channel: channel);
    if (cached != null) {
      AfriLogger.info(
        _tag,
        'Returning cached platform config for club=$clubId channel=$channel',
      );
      return cached;
    }

    // 3. Last resort, return empty
    AfriLogger.warn(_tag, 'Config unavailable, returning empty snapshot');
    return PlatformConfigSnapshot.empty;
  }

  Future<PlatformConfigSnapshot?> loadCachedConfig({
    required int clubId,
    String channel = 'mobile',
  }) {
    return _loadCachedConfig(clubId: clubId, channel: channel);
  }

  Future<void> _cacheConfig({
    required int clubId,
    required String channel,
    required PlatformConfigSnapshot snapshot,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey(clubId: clubId, channel: channel),
        jsonEncode(snapshot.toJson()),
      );
    } catch (e) {
      AfriLogger.warn(_tag, 'Failed to cache platform config: $e');
    }
  }

  Future<PlatformConfigSnapshot?> _loadCachedConfig({
    required int clubId,
    required String channel,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw =
          prefs.getString(_cacheKey(clubId: clubId, channel: channel)) ??
          prefs.getString(_legacyCacheKey);
      if (raw == null) return null;
      return PlatformConfigSnapshot.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      AfriLogger.warn(_tag, 'Failed to load cached platform config: $e');
      return null;
    }
  }

  String _cacheKey({required int clubId, required String channel}) =>
      '$_cacheKeyPrefix:$clubId:$channel';
}
