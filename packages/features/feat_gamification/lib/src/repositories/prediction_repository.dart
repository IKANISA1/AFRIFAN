import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/fanzone_models.dart';
import '../models/prediction_models.dart';

class PredictionRepository {
  PredictionRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  Future<List<FixtureSummary>> loadFixtures({
    String? competitionSlug,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    var filter = _client.from('football_fixtures_catalog').select();

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

    final rows = List<Map<String, dynamic>>.from(await query);
    return rows.map(FixtureSummary.fromJson).toList(growable: false);
  }

  Future<FixtureSummary?> loadFixture(String fixtureId) async {
    final row = await _client
        .from('football_fixtures_catalog')
        .select()
        .eq('id', fixtureId)
        .maybeSingle();

    if (row == null) return null;
    return FixtureSummary.fromJson(row);
  }

  Future<List<FixtureMarket>> loadFixtureMarkets(String fixtureId) async {
    final response = await _client.rpc(
      'prediction_get_fixture_markets',
      params: <String, dynamic>{'p_fixture_id': fixtureId},
    );

    if (response is List) {
      return response
          .whereType<Map>()
          .map((row) => FixtureMarket.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    }

    return const <FixtureMarket>[];
  }

  Future<List<PredictionMarket>> loadMarketCatalog() async {
    final rows = List<Map<String, dynamic>>.from(
      await _client
          .from('prediction_markets_catalog')
          .select()
          .order('sort_order', ascending: true),
    );

    return rows.map(PredictionMarket.fromJson).toList(growable: false);
  }

  Future<PredictionDetail?> loadPredictionDetail(String predictionId) async {
    final response = await _client.rpc(
      'prediction_get_detail',
      params: <String, dynamic>{'p_prediction_id': predictionId},
    );

    if (response is! Map) {
      return null;
    }

    final detail = Map<String, dynamic>.from(response);
    if (detail.isEmpty) {
      return null;
    }

    return PredictionDetail.fromJson(detail);
  }

  Future<PredictionDashboard> loadUserStats() async {
    final response = await _client.rpc('prediction_get_user_stats');
    return PredictionDashboard.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<List<PredictionLeaderboardEntry>> loadLeaderboard({
    int limit = 20,
  }) async {
    final rows = List<Map<String, dynamic>>.from(
      await _client.from('prediction_leaderboard').select().limit(limit),
    );

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

  Future<PredictionPlaceResult> placePrediction({
    required String fixtureMarketId,
    required String selectedOutcome,
  }) async {
    final response = await _client.rpc(
      'prediction_place',
      params: <String, dynamic>{
        'p_fixture_market_id': fixtureMarketId,
        'p_selected_outcome': selectedOutcome,
      },
    );

    return PredictionPlaceResult.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<PredictionPlaceResult> placeAcca(
    List<Map<String, String>> selections,
  ) async {
    final response = await _client.rpc(
      'prediction_place_acca',
      params: <String, dynamic>{'p_selections': selections},
    );

    if (response is Map) {
      return PredictionPlaceResult.fromJson(
        Map<String, dynamic>.from(response),
      );
    }

    return const PredictionPlaceResult(
      status: 'error',
      message: 'Unexpected response from server.',
    );
  }

  Future<PredictionPlaceResult> cancelPrediction(String predictionId) async {
    final response = await _client.rpc(
      'prediction_cancel',
      params: <String, dynamic>{'p_prediction_id': predictionId},
    );

    return PredictionPlaceResult.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<List<UserPrediction>> loadActivePredictions({
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _client.rpc(
      'prediction_get_active',
      params: <String, dynamic>{'p_limit': limit, 'p_offset': offset},
    );

    if (response is List) {
      return response
          .whereType<Map>()
          .map((row) => UserPrediction.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    }

    return const <UserPrediction>[];
  }

  Future<List<UserPrediction>> loadPredictionHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _client.rpc(
      'prediction_get_history',
      params: <String, dynamic>{'p_limit': limit, 'p_offset': offset},
    );

    if (response is List) {
      return response
          .whereType<Map>()
          .map((row) => UserPrediction.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    }

    return const <UserPrediction>[];
  }

  Future<List<Map<String, dynamic>>> loadCompetitions() async {
    final rows = List<Map<String, dynamic>>.from(
      await _client
          .from('football_competitions_catalog')
          .select('id, slug, name, short_name, region, country_code')
          .eq('is_active', true)
          .order('name', ascending: true),
    );

    return rows;
  }

  Future<List<CompetitionCatalogItem>> loadCompetitionCatalog() async {
    final rows = List<Map<String, dynamic>>.from(
      await _client
          .from('football_competitions_catalog')
          .select()
          .eq('is_active', true)
          .order('name', ascending: true),
    );

    return rows.map(CompetitionCatalogItem.fromJson).toList(growable: false);
  }

  Future<CompetitionCatalogItem?> loadCompetition(
    String competitionSlug,
  ) async {
    final row = await _client
        .from('football_competitions_catalog')
        .select()
        .eq('slug', competitionSlug)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return CompetitionCatalogItem.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<LeagueStandingEntry>> loadStandings({
    required String competitionSlug,
    int limit = 32,
  }) async {
    final rows = List<Map<String, dynamic>>.from(
      await _client
          .from('football_standings_catalog')
          .select()
          .eq('competition_slug', competitionSlug)
          .order('position', ascending: true)
          .limit(limit),
    );

    return rows.map(LeagueStandingEntry.fromJson).toList(growable: false);
  }

  Future<TeamCatalogEntry?> loadTeam(String teamSlug) async {
    final row = await _client
        .from('football_teams_catalog')
        .select()
        .eq('slug', teamSlug)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return TeamCatalogEntry.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<TeamRosterPlayer>> loadTeamRoster(
    String teamSlug, {
    int limit = 40,
  }) async {
    final rows = List<Map<String, dynamic>>.from(
      await _client
          .from('football_roster_catalog')
          .select()
          .eq('team_slug', teamSlug)
          .eq('is_active', true)
          .order('squad_number', ascending: true)
          .limit(limit),
    );

    return rows.map(TeamRosterPlayer.fromJson).toList(growable: false);
  }

  Future<List<FixtureSummary>> loadTeamFixtures(
    String teamSlug, {
    String? status,
    int limit = 10,
  }) async {
    var query = _client
        .from('football_fixtures_catalog')
        .select()
        .or('home_team_slug.eq.$teamSlug,away_team_slug.eq.$teamSlug');

    if (status != null && status.trim().isNotEmpty) {
      query = query.eq('status', status);
    }

    final rows = List<Map<String, dynamic>>.from(
      await query.order('kickoff_at', ascending: true).limit(limit),
    );

    return rows.map(FixtureSummary.fromJson).toList(growable: false);
  }

  Future<List<CommunityPick>> loadCommunityPicks(String fixtureMarketId) async {
    final rows = List<Map<String, dynamic>>.from(
      await _client
          .from('prediction_fixture_community')
          .select()
          .eq('fixture_market_id', fixtureMarketId)
          .order('pick_percentage', ascending: false),
    );

    return rows.map(CommunityPick.fromJson).toList(growable: false);
  }

  Future<List<CommunityPick>> loadFixtureCommunityPicks(
    String fixtureId,
  ) async {
    final rows = List<Map<String, dynamic>>.from(
      await _client
          .from('prediction_fixture_community')
          .select()
          .eq('fixture_id', fixtureId)
          .order('pick_percentage', ascending: false),
    );

    return rows.map(CommunityPick.fromJson).toList(growable: false);
  }

  Future<List<PredictionBadge>> loadUserBadges() async {
    final response = await _client.rpc('prediction_get_user_badges');
    if (response is! List) {
      return const <PredictionBadge>[];
    }

    return response
        .whereType<Map>()
        .map((row) => PredictionBadge.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<List<PredictionNotification>> loadNotifications({
    int limit = 50,
  }) async {
    final rows = List<Map<String, dynamic>>.from(
      await _client
          .from('prediction_notifications_feed')
          .select()
          .order('created_at', ascending: false)
          .limit(limit),
    );

    return rows.map(PredictionNotification.fromJson).toList(growable: false);
  }
}
