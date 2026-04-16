part of 'prediction_repository.dart';

extension PredictionRepoH2HEncounters on PredictionRepository {


  /// Loads head-to-head encounters between two teams.
  ///
  /// Returns recent matches from the supported prediction fixtures catalog where one team
  /// is home and the other is away (and vice versa). No dedicated H2H table
  /// exists — we query finished fixtures for the two team slugs.
  Future<List<Map<String, dynamic>>> loadH2hEncounters({
    required String homeTeamSlug,
    required String awayTeamSlug,
    int limit = 10,
  }) async {
    return _cachedRawListQuery(
      cacheKey: _cacheKey('h2h', <Object?>[homeTeamSlug, awayTeamSlug, limit]),
      ttl: _detailCacheTtl,
      description: 'loadH2h($homeTeamSlug vs $awayTeamSlug)',
      request: () async {
        // Match A vs B OR B vs A in finished fixtures.
        final rows = List<Map<String, dynamic>>.from(
          await _client
              .from(_fixturesCatalog)
              .select()
              .eq('status', 'finished')
              .or(
                'and(home_team_slug.eq.$homeTeamSlug,away_team_slug.eq.$awayTeamSlug),'
                'and(home_team_slug.eq.$awayTeamSlug,away_team_slug.eq.$homeTeamSlug)',
              )
              .order('kickoff_at', ascending: false)
              .limit(limit),
        );
        return rows;
      },
    );
  }


}
