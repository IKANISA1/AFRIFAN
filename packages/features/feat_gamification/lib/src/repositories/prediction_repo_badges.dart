part of 'prediction_repository.dart';

extension PredictionRepoBadges on PredictionRepository {
  Future<List<PredictionBadge>> loadUserBadges() async {
    final cacheKey = _cacheKey('user_badges', <Object?>[
      _client.auth.currentUser?.id ?? 'anonymous',
    ]);
    final result = await SafeRpc.call('prediction_get_user_badges', tag: _tag);

    if (!result.isSuccess) {
      return _readCachedList(cacheKey, PredictionBadge.fromJson);
    }

    final data = result.data;
    if (data is! List) {
      return _readCachedList(cacheKey, PredictionBadge.fromJson);
    }

    final rows = data
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
    await HiveCacheService.putJson(cacheKey, rows, ttl: _userCacheTtl);

    return rows.map(PredictionBadge.fromJson).toList(growable: false);
  }
}
