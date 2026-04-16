part of 'prediction_repository.dart';

extension PredictionRepoLineups on PredictionRepository {


  /// Loads fixture lineups from `football_roster_catalog` for both teams.
  ///
  /// No dedicated lineups table exists per fixture; we return the current
  /// active roster for both teams as a proxy. When lineups become available
  /// via an external data provider, swap this for a dedicated table query.
  Future<Map<String, List<Map<String, dynamic>>>> loadFixtureLineups({
    required String homeTeamSlug,
    required String awayTeamSlug,
  }) async {
    final homeRoster = await _cachedRawListQuery(
      cacheKey: _cacheKey('lineup_home', <Object?>[homeTeamSlug]),
      ttl: _catalogCacheTtl,
      description: 'loadLineupHome($homeTeamSlug)',
      request: () async {
        return List<Map<String, dynamic>>.from(
          await _client
              .from('football_roster_catalog')
              .select()
              .eq('team_slug', homeTeamSlug)
              .eq('is_active', true)
              .order('squad_number', ascending: true)
              .limit(25),
        );
      },
    );

    final awayRoster = await _cachedRawListQuery(
      cacheKey: _cacheKey('lineup_away', <Object?>[awayTeamSlug]),
      ttl: _catalogCacheTtl,
      description: 'loadLineupAway($awayTeamSlug)',
      request: () async {
        return List<Map<String, dynamic>>.from(
          await _client
              .from('football_roster_catalog')
              .select()
              .eq('team_slug', awayTeamSlug)
              .eq('is_active', true)
              .order('squad_number', ascending: true)
              .limit(25),
        );
      },
    );

    return <String, List<Map<String, dynamic>>>{
      'home': homeRoster,
      'away': awayRoster,
    };
  }


}
