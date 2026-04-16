part of 'prediction_repository.dart';

extension PredictionRepoMarkets on PredictionRepository {


  Future<List<FixtureMarket>> loadFixtureMarkets(String fixtureId) async {
    final cacheKey = _cacheKey('fixture_markets', <Object?>[fixtureId]);
    final result = await SafeRpc.call(
      'prediction_get_fixture_markets',
      params: <String, dynamic>{'p_fixture_id': fixtureId},
      tag: _tag,
    );

    if (!result.isSuccess) {
      return _readCachedList(cacheKey, FixtureMarket.fromJson);
    }

    final data = result.data;
    if (data is List) {
      final rows = data
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      await HiveCacheService.putJson(cacheKey, rows, ttl: _detailCacheTtl);
      return rows.map(FixtureMarket.fromJson).toList(growable: false);
    }

    return _readCachedList(cacheKey, FixtureMarket.fromJson);
  }

  Future<List<PredictionMarket>> loadMarketCatalog() async {
    return _cachedListQuery(
      cacheKey: _cacheKey('market_catalog'),
      ttl: _catalogCacheTtl,
      description: 'loadMarketCatalog',
      request: () async {
        final rows = List<Map<String, dynamic>>.from(
          await _client
              .from('prediction_markets_catalog')
              .select()
              .order('sort_order', ascending: true),
        );
        return rows;
      },
      decoder: PredictionMarket.fromJson,
    );
  }

  Future<PredictionDetail?> loadPredictionDetail(String predictionId) async {
    final cacheKey = _cacheKey('prediction_detail', <Object?>[predictionId]);
    final result = await SafeRpc.call(
      'prediction_get_detail',
      params: <String, dynamic>{'p_prediction_id': predictionId},
      tag: _tag,
    );

    if (!result.isSuccess) {
      return _readCachedObject(cacheKey, PredictionDetail.fromJson);
    }

    final data = result.data;
    if (data is! Map) return null;
    if (data.isEmpty) return null;

    final row = Map<String, dynamic>.from(data);
    await HiveCacheService.putJson(cacheKey, row, ttl: _detailCacheTtl);
    return PredictionDetail.fromJson(row);
  }

  Future<PredictionDashboard> loadUserStats() async {
    final cacheKey = _cacheKey('user_stats', <Object?>[
      _client.auth.currentUser?.id ?? 'anonymous',
    ]);
    final result = await SafeRpc.call('prediction_get_user_stats', tag: _tag);

    if (!result.isSuccess || result.data is! Map) {
      return _readCachedObject(cacheKey, PredictionDashboard.fromJson) ??
          const PredictionDashboard(
            totalPredictions: 0,
            settledCount: 0,
            wonCount: 0,
            lostCount: 0,
            activeCount: 0,
            totalFetEarned: 0,
            currentStreak: 0,
            winRate: 0,
          );
    }

    final row = Map<String, dynamic>.from(result.data as Map);
    await HiveCacheService.putJson(cacheKey, row, ttl: _userCacheTtl);
    return PredictionDashboard.fromJson(row);
  }

  Future<List<PredictionLeaderboardEntry>> loadLeaderboard({
    int limit = 20,
    String? scope,
    String? period,
  }) async {
    final cacheKey = _cacheKey('leaderboard', <Object?>[limit, scope, period]);
    final result = await SafeRpc.query<List<Map<String, dynamic>>>(
      () async {
        var query = _client.from('prediction_leaderboard').select();
        if (scope != null && scope.isNotEmpty) {
          query = query.eq('scope', scope);
        }
        return List<Map<String, dynamic>>.from(await query.limit(limit));
      },
      tag: _tag,
      description: 'loadLeaderboard(scope=$scope, period=$period)',
      maxAttempts: 3,
    );

    final rows = result.isSuccess
        ? result.requireData
        : _readCachedRawList(cacheKey);
    if (rows.isEmpty) {
      return const <PredictionLeaderboardEntry>[];
    }
    if (result.isSuccess) {
      await HiveCacheService.putJson(cacheKey, rows, ttl: _userCacheTtl);
    }
    return rows
        .asMap()
        .entries
        .map(
          (entry) => PredictionLeaderboardEntry.fromJson(
            entry.value,
            rank: entry.key + 1,
          ),
        )
        .toList(growable: false);
  }


}
