part of 'prediction_repository.dart';

extension PredictionRepoCompetitions on PredictionRepository {


  Future<List<CompetitionCatalogItem>> loadCompetitionCatalog() async {
    return _cachedListQuery(
      cacheKey: _cacheKey('competition_catalog'),
      ttl: _catalogCacheTtl,
      description: 'loadCompetitionCatalog',
      request: () async {
        final rows = List<Map<String, dynamic>>.from(
          await _client
              .from(_competitionsCatalog)
              .select()
              .eq('is_supported', true)
              .eq('is_active', true)
              .order('support_sort_order', ascending: true),
        );

        return rows;
      },
      decoder: CompetitionCatalogItem.fromJson,
    );
  }

  Future<CompetitionCatalogItem?> loadCompetition(
    String competitionSlug,
  ) async {
    return _cachedObjectQuery(
      cacheKey: _cacheKey('competition', <Object?>[competitionSlug]),
      ttl: _catalogCacheTtl,
      description: 'loadCompetition($competitionSlug)',
      request: () async {
        final row = await _client
            .from(_competitionsCatalog)
            .select()
            .eq('is_supported', true)
            .eq('slug', competitionSlug)
            .maybeSingle();

        return row == null ? null : Map<String, dynamic>.from(row);
      },
      decoder: CompetitionCatalogItem.fromJson,
    );
  }

  Future<List<LeagueStandingEntry>> loadStandings({
    required String competitionSlug,
    int limit = 32,
  }) async {
    return _cachedListQuery(
      cacheKey: _cacheKey('standings', <Object?>[competitionSlug, limit]),
      ttl: _detailCacheTtl,
      description: 'loadStandings($competitionSlug)',
      request: () async {
        final rows = List<Map<String, dynamic>>.from(
          await _client
              .from('football_standings_catalog')
              .select()
              .eq('competition_slug', competitionSlug)
              .order('position', ascending: true)
              .limit(limit),
        );

        return rows;
      },
      decoder: LeagueStandingEntry.fromJson,
    );
  }

  Future<TeamCatalogEntry?> loadTeam(String teamSlug) async {
    return _cachedObjectQuery(
      cacheKey: _cacheKey('team', <Object?>[teamSlug]),
      ttl: _catalogCacheTtl,
      description: 'loadTeam($teamSlug)',
      request: () async {
        final row = await _client
            .from('football_teams_catalog')
            .select()
            .eq('slug', teamSlug)
            .maybeSingle();

        return row == null ? null : Map<String, dynamic>.from(row);
      },
      decoder: TeamCatalogEntry.fromJson,
    );
  }

  Future<List<TeamRosterPlayer>> loadTeamRoster(
    String teamSlug, {
    int limit = 40,
  }) async {
    return _cachedListQuery(
      cacheKey: _cacheKey('team_roster', <Object?>[teamSlug, limit]),
      ttl: _catalogCacheTtl,
      description: 'loadTeamRoster($teamSlug)',
      request: () async {
        final rows = List<Map<String, dynamic>>.from(
          await _client
              .from('football_roster_catalog')
              .select()
              .eq('team_slug', teamSlug)
              .eq('is_active', true)
              .order('squad_number', ascending: true)
              .limit(limit),
        );

        return rows;
      },
      decoder: TeamRosterPlayer.fromJson,
    );
  }

  Future<List<FixtureSummary>> loadTeamFixtures(
    String teamSlug, {
    String? status,
    int limit = 10,
  }) async {
    return _cachedListQuery(
      cacheKey: _cacheKey('team_fixtures', <Object?>[teamSlug, status, limit]),
      ttl: _fixturesCacheTtl,
      description: 'loadTeamFixtures($teamSlug)',
      request: () async {
        var query = _client
            .from(_fixturesCatalog)
            .select()
            .or('home_team_slug.eq.$teamSlug,away_team_slug.eq.$teamSlug');

        if (status != null && status.trim().isNotEmpty) {
          query = query.eq('status', status);
        }

        final rows = List<Map<String, dynamic>>.from(
          await query.order('kickoff_at', ascending: true).limit(limit),
        );

        return rows;
      },
      decoder: FixtureSummary.fromJson,
    );
  }


}
