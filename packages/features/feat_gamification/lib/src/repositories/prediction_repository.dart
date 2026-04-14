import 'package:core_network/core_network.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/fanzone_models.dart';
import '../models/prediction_models.dart';

/// Single source of truth for all prediction data operations.
///
/// Uses [SafeRpc] internally for timeout, retry, and error normalization
/// while keeping the same external API (returns unwrapped data, throws on
/// unrecoverable errors). This means all 20+ consumer screens work unchanged.
class PredictionRepository {
  PredictionRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  static const _tag = 'PredictionRepo';

  // ── Fixtures ──────────────────────────────────────────────────────────

  Future<List<FixtureSummary>> loadFixtures({
    String? competitionSlug,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    final result = await SafeRpc.query(
      () async {
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
      },
      tag: _tag,
      description: 'loadFixtures(status=$status)',
    );

    return result.isSuccess
        ? result.requireData
        : const <FixtureSummary>[];
  }

  Future<FixtureSummary?> loadFixture(String fixtureId) async {
    final result = await SafeRpc.query(
      () async {
        final row = await _client
            .from('football_fixtures_catalog')
            .select()
            .eq('id', fixtureId)
            .maybeSingle();

        if (row == null) return null;
        return FixtureSummary.fromJson(row);
      },
      tag: _tag,
      description: 'loadFixture($fixtureId)',
    );

    return result.isSuccess ? result.data : null;
  }

  // ── Markets ───────────────────────────────────────────────────────────

  Future<List<FixtureMarket>> loadFixtureMarkets(String fixtureId) async {
    final result = await SafeRpc.call(
      'prediction_get_fixture_markets',
      params: <String, dynamic>{'p_fixture_id': fixtureId},
      tag: _tag,
    );

    if (!result.isSuccess) return const <FixtureMarket>[];

    final data = result.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map(
            (row) =>
                FixtureMarket.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    }

    return const <FixtureMarket>[];
  }

  Future<List<PredictionMarket>> loadMarketCatalog() async {
    final result = await SafeRpc.query(
      () async {
        final rows = List<Map<String, dynamic>>.from(
          await _client
              .from('prediction_markets_catalog')
              .select()
              .order('sort_order', ascending: true),
        );
        return rows.map(PredictionMarket.fromJson).toList(growable: false);
      },
      tag: _tag,
      description: 'loadMarketCatalog',
    );

    return result.isSuccess
        ? result.requireData
        : const <PredictionMarket>[];
  }

  Future<PredictionDetail?> loadPredictionDetail(String predictionId) async {
    final result = await SafeRpc.call(
      'prediction_get_detail',
      params: <String, dynamic>{'p_prediction_id': predictionId},
      tag: _tag,
    );

    if (!result.isSuccess) return null;

    final data = result.data;
    if (data is! Map) return null;
    if (data.isEmpty) return null;

    return PredictionDetail.fromJson(Map<String, dynamic>.from(data));
  }

  Future<PredictionDashboard> loadUserStats() async {
    final result = await SafeRpc.call(
      'prediction_get_user_stats',
      tag: _tag,
    );

    if (!result.isSuccess || result.data is! Map) {
      return const PredictionDashboard(
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

    return PredictionDashboard.fromJson(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  Future<List<PredictionLeaderboardEntry>> loadLeaderboard({
    int limit = 20,
  }) async {
    final result = await SafeRpc.query(
      () async {
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
      },
      tag: _tag,
      description: 'loadLeaderboard',
    );

    return result.isSuccess
        ? result.requireData
        : const <PredictionLeaderboardEntry>[];
  }

  // ── Predictions ───────────────────────────────────────────────────────

  Future<PredictionPlaceResult> placePrediction({
    required String fixtureMarketId,
    required String selectedOutcome,
  }) async {
    final result = await SafeRpc.call(
      'prediction_place',
      params: <String, dynamic>{
        'p_fixture_market_id': fixtureMarketId,
        'p_selected_outcome': selectedOutcome,
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

    return PredictionPlaceResult.fromJson(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  Future<PredictionPlaceResult> placeAcca(
    List<Map<String, String>> selections,
  ) async {
    final result = await SafeRpc.call(
      'prediction_place_acca',
      params: <String, dynamic>{'p_selections': selections},
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
      return PredictionPlaceResult.fromJson(
        Map<String, dynamic>.from(data),
      );
    }

    return const PredictionPlaceResult(
      status: 'error',
      message: 'Unexpected response from server.',
    );
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

    return PredictionPlaceResult.fromJson(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  Future<List<UserPrediction>> loadActivePredictions({
    int limit = 50,
    int offset = 0,
  }) async {
    final result = await SafeRpc.call(
      'prediction_get_active',
      params: <String, dynamic>{'p_limit': limit, 'p_offset': offset},
      tag: _tag,
    );

    if (!result.isSuccess) return const <UserPrediction>[];

    final data = result.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map(
            (row) =>
                UserPrediction.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    }

    return const <UserPrediction>[];
  }

  Future<List<UserPrediction>> loadPredictionHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    final result = await SafeRpc.call(
      'prediction_get_history',
      params: <String, dynamic>{'p_limit': limit, 'p_offset': offset},
      tag: _tag,
    );

    if (!result.isSuccess) return const <UserPrediction>[];

    final data = result.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map(
            (row) =>
                UserPrediction.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    }

    return const <UserPrediction>[];
  }

  // ── Competitions ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> loadCompetitions() async {
    final result = await SafeRpc.query(
      () async {
        return List<Map<String, dynamic>>.from(
          await _client
              .from('football_competitions_catalog')
              .select('id, slug, name, short_name, region, country_code')
              .eq('is_active', true)
              .order('name', ascending: true),
        );
      },
      tag: _tag,
      description: 'loadCompetitions',
    );

    return result.isSuccess
        ? result.requireData
        : const <Map<String, dynamic>>[];
  }

  Future<List<CompetitionCatalogItem>> loadCompetitionCatalog() async {
    final result = await SafeRpc.query(
      () async {
        final rows = List<Map<String, dynamic>>.from(
          await _client
              .from('football_competitions_catalog')
              .select()
              .eq('is_active', true)
              .order('name', ascending: true),
        );

        return rows
            .map(CompetitionCatalogItem.fromJson)
            .toList(growable: false);
      },
      tag: _tag,
      description: 'loadCompetitionCatalog',
    );

    return result.isSuccess
        ? result.requireData
        : const <CompetitionCatalogItem>[];
  }

  Future<CompetitionCatalogItem?> loadCompetition(
    String competitionSlug,
  ) async {
    final result = await SafeRpc.query(
      () async {
        final row = await _client
            .from('football_competitions_catalog')
            .select()
            .eq('slug', competitionSlug)
            .maybeSingle();

        if (row == null) return null;
        return CompetitionCatalogItem.fromJson(Map<String, dynamic>.from(row));
      },
      tag: _tag,
      description: 'loadCompetition($competitionSlug)',
    );

    return result.isSuccess ? result.data : null;
  }

  Future<List<LeagueStandingEntry>> loadStandings({
    required String competitionSlug,
    int limit = 32,
  }) async {
    final result = await SafeRpc.query(
      () async {
        final rows = List<Map<String, dynamic>>.from(
          await _client
              .from('football_standings_catalog')
              .select()
              .eq('competition_slug', competitionSlug)
              .order('position', ascending: true)
              .limit(limit),
        );

        return rows
            .map(LeagueStandingEntry.fromJson)
            .toList(growable: false);
      },
      tag: _tag,
      description: 'loadStandings($competitionSlug)',
    );

    return result.isSuccess
        ? result.requireData
        : const <LeagueStandingEntry>[];
  }

  Future<TeamCatalogEntry?> loadTeam(String teamSlug) async {
    final result = await SafeRpc.query(
      () async {
        final row = await _client
            .from('football_teams_catalog')
            .select()
            .eq('slug', teamSlug)
            .maybeSingle();

        if (row == null) return null;
        return TeamCatalogEntry.fromJson(Map<String, dynamic>.from(row));
      },
      tag: _tag,
      description: 'loadTeam($teamSlug)',
    );

    return result.isSuccess ? result.data : null;
  }

  Future<List<TeamRosterPlayer>> loadTeamRoster(
    String teamSlug, {
    int limit = 40,
  }) async {
    final result = await SafeRpc.query(
      () async {
        final rows = List<Map<String, dynamic>>.from(
          await _client
              .from('football_roster_catalog')
              .select()
              .eq('team_slug', teamSlug)
              .eq('is_active', true)
              .order('squad_number', ascending: true)
              .limit(limit),
        );

        return rows
            .map(TeamRosterPlayer.fromJson)
            .toList(growable: false);
      },
      tag: _tag,
      description: 'loadTeamRoster($teamSlug)',
    );

    return result.isSuccess
        ? result.requireData
        : const <TeamRosterPlayer>[];
  }

  Future<List<FixtureSummary>> loadTeamFixtures(
    String teamSlug, {
    String? status,
    int limit = 10,
  }) async {
    final result = await SafeRpc.query(
      () async {
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
      },
      tag: _tag,
      description: 'loadTeamFixtures($teamSlug)',
    );

    return result.isSuccess
        ? result.requireData
        : const <FixtureSummary>[];
  }

  // ── Community Picks ─────────────────────────────────────────────────

  Future<List<CommunityPick>> loadCommunityPicks(
    String fixtureMarketId,
  ) async {
    final result = await SafeRpc.query(
      () async {
        final rows = List<Map<String, dynamic>>.from(
          await _client
              .from('prediction_fixture_community')
              .select()
              .eq('fixture_market_id', fixtureMarketId)
              .order('pick_percentage', ascending: false),
        );

        return rows.map(CommunityPick.fromJson).toList(growable: false);
      },
      tag: _tag,
      description: 'loadCommunityPicks($fixtureMarketId)',
    );

    return result.isSuccess
        ? result.requireData
        : const <CommunityPick>[];
  }

  Future<List<CommunityPick>> loadFixtureCommunityPicks(
    String fixtureId,
  ) async {
    final result = await SafeRpc.query(
      () async {
        final rows = List<Map<String, dynamic>>.from(
          await _client
              .from('prediction_fixture_community')
              .select()
              .eq('fixture_id', fixtureId)
              .order('pick_percentage', ascending: false),
        );

        return rows.map(CommunityPick.fromJson).toList(growable: false);
      },
      tag: _tag,
      description: 'loadFixtureCommunityPicks($fixtureId)',
    );

    return result.isSuccess
        ? result.requireData
        : const <CommunityPick>[];
  }

  // ── Badges ──────────────────────────────────────────────────────────

  Future<List<PredictionBadge>> loadUserBadges() async {
    final result = await SafeRpc.call(
      'prediction_get_user_badges',
      tag: _tag,
    );

    if (!result.isSuccess) return const <PredictionBadge>[];

    final data = result.data;
    if (data is! List) return const <PredictionBadge>[];

    return data
        .whereType<Map>()
        .map(
          (row) =>
              PredictionBadge.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  // ── Notifications ───────────────────────────────────────────────────

  Future<List<PredictionNotification>> loadNotifications({
    int limit = 50,
  }) async {
    final result = await SafeRpc.query(
      () async {
        final rows = List<Map<String, dynamic>>.from(
          await _client
              .from('prediction_notifications_feed')
              .select()
              .order('created_at', ascending: false)
              .limit(limit),
        );

        return rows
            .map(PredictionNotification.fromJson)
            .toList(growable: false);
      },
      tag: _tag,
      description: 'loadNotifications',
    );

    return result.isSuccess
        ? result.requireData
        : const <PredictionNotification>[];
  }
}
