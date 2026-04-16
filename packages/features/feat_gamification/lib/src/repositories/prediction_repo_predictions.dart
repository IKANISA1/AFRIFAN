part of 'prediction_repository.dart';

extension PredictionRepoPredictions on PredictionRepository {


  Future<PredictionPlaceResult> placePrediction({
    required String fixtureMarketId,
    required String selectedOutcome,
    String? idempotencyKey,
  }) async {
    final result = await SafeRpc.call(
      'prediction_place',
      params: <String, dynamic>{
        'p_fixture_market_id': fixtureMarketId,
        'p_selected_outcome': selectedOutcome,
        if (idempotencyKey != null) 'p_idempotency_key': idempotencyKey,
      },
      tag: _tag,
      maxAttempts: 1, // Don't retry writes to prevent duplicates.
    );

    if (!result.isSuccess || result.data is! Map) {
      return PredictionPlaceResult(
        status: 'error',
        message: result.error ?? 'Failed to place prediction.',
      );
    }

    await _clearUserCaches();

    return PredictionPlaceResult.fromJson(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  Future<PredictionPlaceResult> placeAcca(
    List<Map<String, String>> selections, {
    String? idempotencyKey,
  }) async {
    final result = await SafeRpc.call(
      'prediction_place_acca',
      params: <String, dynamic>{
        'p_selections': selections,
        if (idempotencyKey != null) 'p_idempotency_key': idempotencyKey,
      },
      tag: _tag,
      maxAttempts: 1,
    );

    if (!result.isSuccess) {
      return PredictionPlaceResult(
        status: 'error',
        message: result.error ?? 'Unexpected response from server.',
      );
    }

    final data = result.data;
    if (data is Map) {
      await _clearUserCaches();
      return PredictionPlaceResult.fromJson(Map<String, dynamic>.from(data));
    }

    return const PredictionPlaceResult(
      status: 'error',
      message: 'Unexpected response from server.',
    );
  }

  Future<PredictionJackpotRound?> loadActiveJackpotRound() async {
    final cacheKey = _cacheKey('jackpot_round', <Object?>[
      _client.auth.currentUser?.id ?? 'anonymous',
    ]);
    final result = await SafeRpc.call(
      'prediction_get_active_jackpot_round',
      tag: _tag,
    );

    if (!result.isSuccess || result.data is! Map) {
      return _readCachedObject(cacheKey, PredictionJackpotRound.fromJson);
    }

    final row = Map<String, dynamic>.from(result.data as Map);
    if (row.isEmpty) {
      return null;
    }

    await HiveCacheService.putJson(cacheKey, row, ttl: _detailCacheTtl);
    return PredictionJackpotRound.fromJson(row);
  }

  Future<PredictionPlaceResult> placeJackpotEntry({
    required String roundId,
    required List<Map<String, String>> selections,
    String? idempotencyKey,
  }) async {
    final result = await SafeRpc.call(
      'prediction_place_jackpot_entry',
      params: <String, dynamic>{
        'p_round_id': roundId,
        'p_selections': selections,
        'p_idempotency_key': idempotencyKey,
      },
      tag: _tag,
      maxAttempts: 1,
    );

    if (!result.isSuccess || result.data is! Map) {
      return PredictionPlaceResult(
        status: 'error',
        message: result.error ?? 'Unexpected response from server.',
      );
    }

    await _clearUserCaches();
    await HiveCacheService.remove(
      _cacheKey('jackpot_round', <Object?>[
        _client.auth.currentUser?.id ?? 'anonymous',
      ]),
    );

    return PredictionPlaceResult.fromJson(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  Future<PredictionPlaceResult> createFriendChallenge({
    required String opponentUserId,
    required String fixtureMarketId,
    required String selectedOutcome,
    String? message,
  }) async {
    final result = await SafeRpc.call(
      'prediction_create_friend_challenge',
      params: <String, dynamic>{
        'p_opponent_user_id': opponentUserId,
        'p_fixture_market_id': fixtureMarketId,
        'p_selected_outcome': selectedOutcome,
        'p_message': message,
      },
      tag: _tag,
      maxAttempts: 1,
    );

    if (!result.isSuccess || result.data is! Map) {
      return PredictionPlaceResult(
        status: 'error',
        message: result.error ?? 'Could not create the challenge.',
      );
    }

    return PredictionPlaceResult.fromJson(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

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
