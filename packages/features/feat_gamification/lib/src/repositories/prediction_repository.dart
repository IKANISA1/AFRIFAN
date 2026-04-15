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
  static const _fixturesCacheTtl = Duration(minutes: 5);
  static const _detailCacheTtl = Duration(minutes: 5);
  static const _catalogCacheTtl = Duration(hours: 6);
  static const _userCacheTtl = Duration(minutes: 2);
  static const _communityCacheTtl = Duration(minutes: 5);
  static const _fixturesCatalog = 'prediction_supported_fixtures_catalog';
  static const _competitionsCatalog =
      'prediction_supported_competitions_catalog';

  // ── Fixtures ──────────────────────────────────────────────────────────

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

  // ── Markets ───────────────────────────────────────────────────────────

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

    await _clearUserCaches();

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
      await _clearUserCaches();
      return PredictionPlaceResult.fromJson(Map<String, dynamic>.from(data));
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

  // ── Competitions ──────────────────────────────────────────────────────

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

  // ── Community Picks ─────────────────────────────────────────────────

  Future<List<CommunityPick>> loadCommunityPicks(String fixtureMarketId) async {
    return _cachedListQuery(
      cacheKey: _cacheKey('community_market', <Object?>[fixtureMarketId]),
      ttl: _communityCacheTtl,
      description: 'loadCommunityPicks($fixtureMarketId)',
      request: () async {
        final rows = List<Map<String, dynamic>>.from(
          await _client
              .from('prediction_fixture_community')
              .select()
              .eq('fixture_market_id', fixtureMarketId)
              .order('pick_percentage', ascending: false),
        );

        return rows;
      },
      decoder: CommunityPick.fromJson,
    );
  }

  Future<List<CommunityPick>> loadFixtureCommunityPicks(
    String fixtureId,
  ) async {
    return _cachedListQuery(
      cacheKey: _cacheKey('community_fixture', <Object?>[fixtureId]),
      ttl: _communityCacheTtl,
      description: 'loadFixtureCommunityPicks($fixtureId)',
      request: () async {
        final rows = List<Map<String, dynamic>>.from(
          await _client
              .from('prediction_fixture_community')
              .select()
              .eq('fixture_id', fixtureId)
              .order('pick_percentage', ascending: false),
        );

        return rows;
      },
      decoder: CommunityPick.fromJson,
    );
  }

  // ── H2H Encounters ────────────────────────────────────────────────────

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

  // ── Lineups ────────────────────────────────────────────────────────────

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

  // ── Profile ────────────────────────────────────────────────────────────

  /// Updates the current user's profile (display_name, club_id, etc.)
  /// for onboarding and privacy settings.
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    final result = await SafeRpc.query<void>(
      () async {
        await _client.from('profiles').update(updates).eq('id', userId);
      },
      tag: _tag,
      description: 'updateProfile',
      maxAttempts: 2,
    );

    return result.isSuccess;
  }

  /// Returns the current authenticated user ID, or null.
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Whether the current user is authenticated.
  bool get isAuthenticated => _client.auth.currentUser != null;

  // ── Badges ──────────────────────────────────────────────────────────

  Future<List<PredictionBadge>> loadUserBadges() async {
    final cacheKey = _cacheKey('user_badges', <Object?>[
      _client.auth.currentUser?.id ?? 'anonymous',
    ]);
    final result = await SafeRpc.call('prediction_get_user_badges', tag: _tag);

    if (!result.isSuccess) {
      return _readCachedList(cacheKey, PredictionBadge.fromJson);
    }

    final data = result.data;
    if (data is! List) {
      return _readCachedList(cacheKey, PredictionBadge.fromJson);
    }

    final rows = data
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
    await HiveCacheService.putJson(cacheKey, rows, ttl: _userCacheTtl);

    return rows.map(PredictionBadge.fromJson).toList(growable: false);
  }

  // ── Notifications ───────────────────────────────────────────────────

  Future<List<PredictionNotification>> loadNotifications({
    int limit = 50,
  }) async {
    return _cachedListQuery(
      cacheKey: _cacheKey('notifications', <Object?>[
        _client.auth.currentUser?.id ?? 'anonymous',
        limit,
      ]),
      ttl: _userCacheTtl,
      description: 'loadNotifications',
      request: () async {
        final rows = List<Map<String, dynamic>>.from(
          await _client
              .from('prediction_notifications_feed')
              .select()
              .order('created_at', ascending: false)
              .limit(limit),
        );

        return rows;
      },
      decoder: PredictionNotification.fromJson,
    );
  }

  // ── Calendar-based Fixture Loading ──────────────────────────────────

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

  Future<void> _clearUserCaches() async {
    final userId = _client.auth.currentUser?.id ?? 'anonymous';
    await Future.wait(<Future<void>>[
      HiveCacheService.remove(_cacheKey('user_stats', <Object?>[userId])),
      HiveCacheService.remove(
        _cacheKey('active_predictions', <Object?>[userId, 50, 0]),
      ),
      HiveCacheService.remove(
        _cacheKey('prediction_history', <Object?>[userId, 50, 0]),
      ),
      HiveCacheService.remove(_cacheKey('user_badges', <Object?>[userId])),
      HiveCacheService.remove(
        _cacheKey('notifications', <Object?>[userId, 50]),
      ),
    ]);
  }

  Future<List<T>> _cachedListQuery<T>({
    required String cacheKey,
    required Duration ttl,
    required String description,
    required Future<List<Map<String, dynamic>>> Function() request,
    required T Function(Map<String, dynamic> row) decoder,
  }) async {
    final result = await SafeRpc.query<List<Map<String, dynamic>>>(
      request,
      tag: _tag,
      description: description,
      maxAttempts: 3,
    );
    if (result.isSuccess) {
      final rows = result.requireData;
      await HiveCacheService.putJson(cacheKey, rows, ttl: ttl);
      return rows.map(decoder).toList(growable: false);
    }
    return _readCachedList(cacheKey, decoder);
  }

  Future<List<Map<String, dynamic>>> _cachedRawListQuery({
    required String cacheKey,
    required Duration ttl,
    required String description,
    required Future<List<Map<String, dynamic>>> Function() request,
  }) async {
    final result = await SafeRpc.query<List<Map<String, dynamic>>>(
      request,
      tag: _tag,
      description: description,
      maxAttempts: 3,
    );
    if (result.isSuccess) {
      final rows = result.requireData;
      await HiveCacheService.putJson(cacheKey, rows, ttl: ttl);
      return rows;
    }
    return _readCachedRawList(cacheKey);
  }

  Future<T?> _cachedObjectQuery<T>({
    required String cacheKey,
    required Duration ttl,
    required String description,
    required Future<Map<String, dynamic>?> Function() request,
    required T Function(Map<String, dynamic> row) decoder,
  }) async {
    final result = await SafeRpc.query<Map<String, dynamic>?>(
      request,
      tag: _tag,
      description: description,
      maxAttempts: 3,
    );
    if (result.isSuccess) {
      final row = result.data;
      if (row == null) {
        await HiveCacheService.remove(cacheKey);
        return null;
      }
      await HiveCacheService.putJson(cacheKey, row, ttl: ttl);
      return decoder(row);
    }
    return _readCachedObject(cacheKey, decoder);
  }

  List<T> _readCachedList<T>(
    String cacheKey,
    T Function(Map<String, dynamic> row) decoder,
  ) {
    final cached = HiveCacheService.getJson<List<dynamic>>(
      cacheKey,
      allowExpired: true,
    );
    if (cached == null) {
      return <T>[];
    }
    return cached
        .whereType<Map>()
        .map((row) => decoder(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _readCachedRawList(String cacheKey) {
    final cached = HiveCacheService.getJson<List<dynamic>>(
      cacheKey,
      allowExpired: true,
    );
    if (cached == null) {
      return const <Map<String, dynamic>>[];
    }
    return cached
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  T? _readCachedObject<T>(
    String cacheKey,
    T Function(Map<String, dynamic> row) decoder,
  ) {
    final cached = HiveCacheService.getJson<dynamic>(
      cacheKey,
      allowExpired: true,
    );
    if (cached is! Map) {
      return null;
    }
    return decoder(Map<String, dynamic>.from(cached));
  }

  String _cacheKey(
    String section, [
    Iterable<Object?> parts = const <Object?>[],
  ]) {
    final normalized = <String>[
      'prediction',
      section,
      ...parts.map(_normalizeCachePart),
    ];
    return normalized.join(':');
  }

  String _normalizeCachePart(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return 'all';
    }
    return raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  }
}
