import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_network/core_network.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/football_models.dart';
import '../models/prediction_models.dart';

part 'prediction_repo_fixtures.dart';
part 'prediction_repo_markets.dart';
part 'prediction_repo_predictions.dart';
part 'prediction_repo_competitions.dart';
part 'prediction_repo_community_picks.dart';
part 'prediction_repo_h2h_encounters.dart';
part 'prediction_repo_lineups.dart';
part 'prediction_repo_profile.dart';
part 'prediction_repo_badges.dart';
part 'prediction_repo_notifications.dart';
part 'prediction_repo_calendar_based_fixture_loading.dart';

const _tag = 'PredictionRepo';
const _fixturesCacheTtl = Duration(minutes: 5);
const _detailCacheTtl = Duration(minutes: 5);
const _catalogCacheTtl = Duration(hours: 6);
const _userCacheTtl = Duration(minutes: 2);
const _communityCacheTtl = Duration(minutes: 5);
const _fixturesCatalog = 'prediction_supported_fixtures_catalog';
const _competitionsCatalog = 'prediction_supported_competitions_catalog';

/// Single source of truth for all prediction data operations.
///
/// Uses [SafeRpc] internally for timeout, retry, and error normalization
/// while keeping the same external API (returns unwrapped data, throws on
/// unrecoverable errors). This means all 20+ consumer screens work unchanged.
class PredictionRepository {
  PredictionRepository({
    required SupabaseClient client,
    StoreReleasePolicy? storeReleasePolicy,
  }) : _client = client,
       _storeReleasePolicy =
           storeReleasePolicy ??
           StoreReleasePolicy.forCurrentBuild(const PlatformConfigSnapshot());

  final SupabaseClient _client;
  final StoreReleasePolicy _storeReleasePolicy;

  Map<String, dynamic> _sanitizeLeaderboardIdentity(Map<String, dynamic> row) {
    if (_storeReleasePolicy.allowsCrossUserText) {
      return row;
    }
    return <String, dynamic>{
      ...row,
      'display_name': _storeReleasePolicy.publicSupporterLabel(
        displayName: row['display_name']?.toString(),
        publicUserId: row['public_user_id']?.toString(),
        userId: row['user_id']?.toString(),
      ),
    };
  }

  Future<void> _clearUserCaches() async {
    final userId = _client.auth.currentUser?.id ?? 'anonymous';
    await Future.wait(<Future<void>>[
      HiveCacheService.remove(_cacheKey('user_stats', <Object?>[userId])),
      HiveCacheService.remove(
        _cacheKey('active_predictions', <Object?>[userId, 50, 0]),
      ),
      HiveCacheService.remove(
        _cacheKey('prediction_history', <Object?>[userId, 50, 0]),
      ),
      HiveCacheService.remove(_cacheKey('user_badges', <Object?>[userId])),
      HiveCacheService.remove(
        _cacheKey('notifications', <Object?>[userId, 50]),
      ),
    ]);
  }

  Future<List<T>> _cachedListQuery<T>({
    required String cacheKey,
    required Duration ttl,
    required String description,
    required Future<List<Map<String, dynamic>>> Function() request,
    required T Function(Map<String, dynamic> row) decoder,
  }) async {
    final result = await SafeRpc.query<List<Map<String, dynamic>>>(
      request,
      tag: _tag,
      description: description,
      maxAttempts: 3,
    );
    if (result.isSuccess) {
      final rows = result.requireData;
      await HiveCacheService.putJson(cacheKey, rows, ttl: ttl);
      return rows.map(decoder).toList(growable: false);
    }
    return _readCachedList(cacheKey, decoder);
  }

  Future<List<Map<String, dynamic>>> _cachedRawListQuery({
    required String cacheKey,
    required Duration ttl,
    required String description,
    required Future<List<Map<String, dynamic>>> Function() request,
  }) async {
    final result = await SafeRpc.query<List<Map<String, dynamic>>>(
      request,
      tag: _tag,
      description: description,
      maxAttempts: 3,
    );
    if (result.isSuccess) {
      final rows = result.requireData;
      await HiveCacheService.putJson(cacheKey, rows, ttl: ttl);
      return rows;
    }
    return _readCachedRawList(cacheKey);
  }

  Future<T?> _cachedObjectQuery<T>({
    required String cacheKey,
    required Duration ttl,
    required String description,
    required Future<Map<String, dynamic>?> Function() request,
    required T Function(Map<String, dynamic> row) decoder,
  }) async {
    final result = await SafeRpc.query<Map<String, dynamic>?>(
      request,
      tag: _tag,
      description: description,
      maxAttempts: 3,
    );
    if (result.isSuccess) {
      final row = result.data;
      if (row == null) {
        await HiveCacheService.remove(cacheKey);
        return null;
      }
      await HiveCacheService.putJson(cacheKey, row, ttl: ttl);
      return decoder(row);
    }
    return _readCachedObject(cacheKey, decoder);
  }

  List<T> _readCachedList<T>(
    String cacheKey,
    T Function(Map<String, dynamic> row) decoder,
  ) {
    final cached = HiveCacheService.getJson<List<dynamic>>(
      cacheKey,
      allowExpired: true,
    );
    if (cached == null) {
      return <T>[];
    }
    return cached
        .whereType<Map>()
        .map((row) => decoder(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _readCachedRawList(String cacheKey) {
    final cached = HiveCacheService.getJson<List<dynamic>>(
      cacheKey,
      allowExpired: true,
    );
    if (cached == null) {
      return const <Map<String, dynamic>>[];
    }
    return cached
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  T? _readCachedObject<T>(
    String cacheKey,
    T Function(Map<String, dynamic> row) decoder,
  ) {
    final cached = HiveCacheService.getJson<dynamic>(
      cacheKey,
      allowExpired: true,
    );
    if (cached is! Map) {
      return null;
    }
    return decoder(Map<String, dynamic>.from(cached));
  }

  String _cacheKey(
    String section, [
    Iterable<Object?> parts = const <Object?>[],
  ]) {
    final normalized = <String>[
      'prediction',
      section,
      ...parts.map(_normalizeCachePart),
    ];
    return normalized.join(':');
  }

  String _normalizeCachePart(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return 'all';
    }
    return raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  }
}
