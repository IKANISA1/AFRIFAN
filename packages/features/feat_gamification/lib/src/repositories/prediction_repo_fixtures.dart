part of 'prediction_repository.dart';

extension PredictionRepoFixtures on PredictionRepository {
  Future<List<FixtureSummary>> loadFixtures({
    String? competitionSlug,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    final cacheKey = _cacheKey('fixtures', <Object?>[
      competitionSlug,
      status,
      limit,
      offset,
    ]);
    return _cachedListQuery(
      cacheKey: cacheKey,
      ttl: _fixturesCacheTtl,
      description: 'loadFixtures(status=$status)',
      request: () async {
        var filter = _client.from(_fixturesCatalog).select();

        if (status != null && status.trim().isNotEmpty) {
          filter = filter.eq('status', status);
        }

        if (competitionSlug != null && competitionSlug.isNotEmpty) {
          filter = filter.eq('competition_slug', competitionSlug);
        }

        var query = filter.order('kickoff_at', ascending: true);
        if (offset > 0) {
          query = query.range(offset, offset + limit - 1);
        } else {
          query = query.limit(limit);
        }

        return List<Map<String, dynamic>>.from(await query);
      },
      decoder: FixtureSummary.fromJson,
    );
  }

  Future<FixtureSummary?> loadFixture(String fixtureId) async {
    return _cachedObjectQuery(
      cacheKey: _cacheKey('fixture', <Object?>[fixtureId]),
      ttl: _detailCacheTtl,
      description: 'loadFixture($fixtureId)',
      request: () async {
        final row = await _client
            .from(_fixturesCatalog)
            .select()
            .eq('id', fixtureId)
            .maybeSingle();

        return row == null ? null : Map<String, dynamic>.from(row);
      },
      decoder: FixtureSummary.fromJson,
    );
  }
}
