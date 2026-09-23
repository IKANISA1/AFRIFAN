part of 'prediction_repository.dart';

extension PredictionRepoPredictions on PredictionRepository {
  Future<PredictionMatchCenter?> loadMatchCenter(String fixtureId) async {
    final cacheKey = _cacheKey('match_center', <Object?>[fixtureId]);
    final result = await SafeRpc.call(
      'prediction_get_match_center',
      params: <String, dynamic>{'p_fixture_id': fixtureId},
      tag: _tag,
    );

    if (!result.isSuccess || result.data is! Map) {
      return _readCachedObject(cacheKey, PredictionMatchCenter.fromJson);
    }

    final row = Map<String, dynamic>.from(result.data as Map);
    if (row.isEmpty) {
      return null;
    }

    await HiveCacheService.putJson(cacheKey, row, ttl: _detailCacheTtl);
    return PredictionMatchCenter.fromJson(row);
  }

  Future<PredictionPlaceResult> cancelPrediction(String predictionId) async {
    final result = await SafeRpc.call(
      'prediction_cancel',
      params: <String, dynamic>{'p_prediction_id': predictionId},
      tag: _tag,
      maxAttempts: 1,
    );

    if (!result.isSuccess || result.data is! Map) {
      return PredictionPlaceResult(
        status: 'error',
        message: result.error ?? 'Failed to cancel prediction.',
      );
    }

    await _clearUserCaches();

    return PredictionPlaceResult.fromJson(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  Future<List<UserPrediction>> loadActivePredictions({
    int limit = 50,
    int offset = 0,
  }) async {
    final cacheKey = _cacheKey('active_predictions', <Object?>[
      _client.auth.currentUser?.id ?? 'anonymous',
      limit,
      offset,
    ]);
    final result = await SafeRpc.call(
      'prediction_get_active',
      params: <String, dynamic>{'p_limit': limit, 'p_offset': offset},
      tag: _tag,
    );

    if (!result.isSuccess) {
      return _readCachedList(cacheKey, UserPrediction.fromJson);
    }

    final data = result.data;
    if (data is List) {
      final rows = data
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      await HiveCacheService.putJson(cacheKey, rows, ttl: _userCacheTtl);
      return rows.map(UserPrediction.fromJson).toList(growable: false);
    }

    return _readCachedList(cacheKey, UserPrediction.fromJson);
  }

  Future<List<UserPrediction>> loadPredictionHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    final cacheKey = _cacheKey('prediction_history', <Object?>[
      _client.auth.currentUser?.id ?? 'anonymous',
      limit,
      offset,
    ]);
    final result = await SafeRpc.call(
      'prediction_get_history',
      params: <String, dynamic>{'p_limit': limit, 'p_offset': offset},
      tag: _tag,
    );

    if (!result.isSuccess) {
      return _readCachedList(cacheKey, UserPrediction.fromJson);
    }

    final data = result.data;
    if (data is List) {
      final rows = data
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      await HiveCacheService.putJson(cacheKey, rows, ttl: _userCacheTtl);
      return rows.map(UserPrediction.fromJson).toList(growable: false);
    }

    return _readCachedList(cacheKey, UserPrediction.fromJson);
  }
}
