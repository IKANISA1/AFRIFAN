part of 'prediction_repository.dart';

extension PredictionRepoCalendarbasedFixtureLoading on PredictionRepository {


  /// Loads fixtures for a specific date range via the `fixtures_calendar` RPC.
  Future<List<FixtureSummary>> loadFixturesByDate({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? competitionSlug,
    String? status,
    int limit = 200,
  }) async {
    final fromStr =
        '${dateFrom.year}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}';
    final toStr =
        '${dateTo.year}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}';

    final cacheKey = _cacheKey('cal_fixtures', <Object?>[
      fromStr,
      toStr,
      competitionSlug,
      status,
      limit,
    ]);

    final result = await SafeRpc.call(
      'fixtures_calendar',
      params: <String, dynamic>{
        'p_date_from': fromStr,
        'p_date_to': toStr,
        if (competitionSlug != null) 'p_competition_slug': competitionSlug,
        if (status != null) 'p_status': status,
        'p_limit': limit,
      },
      tag: _tag,
    );

    if (result.isSuccess && result.data is List) {
      final rows = (result.data as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      await HiveCacheService.putJson(cacheKey, rows, ttl: _fixturesCacheTtl);
      return rows.map(FixtureSummary.fromJson).toList(growable: false);
    }

    return _readCachedList(cacheKey, FixtureSummary.fromJson);
  }

  /// Returns a summary of fixture counts per date for calendar indicators.
  Future<List<FixtureDateSummary>> loadFixtureDateSummary({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? competitionSlug,
  }) async {
    final fromStr =
        '${dateFrom.year}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}';
    final toStr =
        '${dateTo.year}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}';

    final cacheKey = _cacheKey('cal_summary', <Object?>[
      fromStr,
      toStr,
      competitionSlug,
    ]);

    final result = await SafeRpc.call(
      'fixtures_date_summary',
      params: <String, dynamic>{
        'p_date_from': fromStr,
        'p_date_to': toStr,
        if (competitionSlug != null) 'p_competition_slug': competitionSlug,
      },
      tag: _tag,
    );

    if (result.isSuccess && result.data is List) {
      final rows = (result.data as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      await HiveCacheService.putJson(cacheKey, rows, ttl: _fixturesCacheTtl);
      return rows.map(FixtureDateSummary.fromJson).toList(growable: false);
    }

    return _readCachedList(cacheKey, FixtureDateSummary.fromJson);
  }

}
