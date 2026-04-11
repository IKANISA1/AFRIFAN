import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/fantasy_models.dart';

abstract class FantasyRepository {
  Future<List<FantasyCompetitionSummary>> loadCompetitions();
  Future<FantasyCompetitionSummary?> loadCompetitionBySlug(String slug);
  Future<FantasyCompetitionSummary?> loadFeaturedCompetition();
  Future<List<FantasyLeaderboardRow>> loadLeaderboard(
    String competitionSlug, {
    int limit = 20,
  });
  Future<String?> createEntry({
    required String competitionSlug,
    required String teamName,
  });
  Future<FantasyEntryContext?> loadCompetitionContext(String competitionSlug);
  Future<List<FantasyPlayerPoolItem>> loadPlayerPool(String competitionSlug);
  Future<List<FantasySquadSelection>> loadSquad({
    required String entryId,
    String? gameweekId,
  });
  Future<int?> saveSquadSelections({
    required String entryId,
    required String gameweekId,
    required List<FantasySquadSelection> selections,
  });
}

class SupabaseFantasyRepository implements FantasyRepository {
  SupabaseFantasyRepository({required this.client});

  final SupabaseClient client;

  @override
  Future<List<FantasyCompetitionSummary>> loadCompetitions() async {
    try {
      final competitionRows = List<Map<String, dynamic>>.from(
        await client
            .from('fantasy_competitions')
            .select()
            .order('start_at', ascending: true),
      );
      if (competitionRows.isEmpty) {
        return const <FantasyCompetitionSummary>[];
      }

      final clubId = _currentClubId();
      final enablementsByCompetitionId = <String, Map<String, dynamic>>{};
      final enteredCompetitionIds = <String>{};

      if (clubId != null) {
        try {
          final enablementRows = List<Map<String, dynamic>>.from(
            await client
                .from('fantasy_competition_enablements')
                .select()
                .eq('club_id', clubId),
          );
          for (final row in enablementRows) {
            final competitionId = row['competition_id']?.toString();
            if (competitionId != null && competitionId.isNotEmpty) {
              enablementsByCompetitionId[competitionId] = row;
            }
          }
        } catch (error) {
          if (!_isMissingRelation(error, 'fantasy_competition_enablements')) {
            rethrow;
          }
        }
      }

      if (client.auth.currentUser != null) {
        try {
          final entryRows = List<Map<String, dynamic>>.from(
            await client.rpc('fantasy_get_my_entries'),
          );
          for (final row in entryRows) {
            final competitionId = row['competition_id']?.toString();
            if (competitionId != null && competitionId.isNotEmpty) {
              enteredCompetitionIds.add(competitionId);
            }
          }
        } catch (_) {
          // Keep the hub usable even if the entry RPC is missing.
        }
      }

      final competitions = competitionRows
          .map((row) {
            final competitionId = row['id']?.toString() ?? '';
            return _mapCompetition(
              row,
              enablement: enablementsByCompetitionId[competitionId],
              hasEntry: enteredCompetitionIds.contains(competitionId),
            );
          })
          .where(
            (competition) => competition.isVisible || competition.isFeatured,
          )
          .toList(growable: false);

      return competitions;
    } catch (error) {
      if (_isMissingRelation(error, 'fantasy_competitions')) {
        return const <FantasyCompetitionSummary>[];
      }
      return const <FantasyCompetitionSummary>[];
    }
  }

  @override
  Future<FantasyCompetitionSummary?> loadCompetitionBySlug(String slug) async {
    final competitions = await loadCompetitions();
    for (final competition in competitions) {
      if (competition.slug == slug) {
        return competition;
      }
    }
    return null;
  }

  @override
  Future<FantasyCompetitionSummary?> loadFeaturedCompetition() async {
    final competitions = await loadCompetitions();
    for (final competition in competitions) {
      if (competition.isFeatured) {
        return competition;
      }
    }
    return competitions.isEmpty ? null : competitions.first;
  }

  @override
  Future<List<FantasyLeaderboardRow>> loadLeaderboard(
    String competitionSlug, {
    int limit = 20,
  }) async {
    try {
      if (competitionSlug.trim().isEmpty) {
        return const <FantasyLeaderboardRow>[];
      }

      final entryRows = List<Map<String, dynamic>>.from(
        await client.rpc(
          'fantasy_get_leaderboard',
          params: {'p_competition_slug': competitionSlug, 'p_limit': limit},
        ),
      );
      if (entryRows.isEmpty) {
        return const <FantasyLeaderboardRow>[];
      }

      return entryRows
          .asMap()
          .entries
          .map((entry) {
            final row = entry.value;
            final rank =
                (row['overall_rank'] as num?)?.toInt() ?? entry.key + 1;
            final managerName = row['manager_name']?.toString().trim() ?? '';
            final teamName = (row['team_name']?.toString().trim() ?? '').isEmpty
                ? (managerName.isEmpty ? 'Manager $rank' : managerName)
                : row['team_name'].toString().trim();
            return FantasyLeaderboardRow(
              rank: rank,
              teamName: teamName,
              points: (row['total_points'] as num?)?.toInt() ?? 0,
              isCurrentUser: row['is_current_user'] == true,
            );
          })
          .toList(growable: false);
    } catch (_) {
      return const <FantasyLeaderboardRow>[];
    }
  }

  @override
  Future<String?> createEntry({
    required String competitionSlug,
    required String teamName,
  }) async {
    final currentUser = client.auth.currentUser;
    if (currentUser == null) {
      return null;
    }

    try {
      final entryId = await client.rpc(
        'fantasy_create_entry',
        params: {
          'p_competition_slug': competitionSlug,
          'p_team_name': teamName.trim(),
        },
      );
      return entryId?.toString();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<FantasyEntryContext?> loadCompetitionContext(
    String competitionSlug,
  ) async {
    try {
      final rows = List<Map<String, dynamic>>.from(
        await client.rpc(
          'fantasy_get_competition_context',
          params: {'p_competition_slug': competitionSlug},
        ),
      );
      if (rows.isEmpty) {
        return null;
      }

      final row = rows.first;
      final gameweekId = row['gameweek_id']?.toString();
      final gameweekNumber = (row['gameweek_number'] as num?)?.toInt();
      final gameweekName = row['gameweek_name']?.toString() ?? '';
      final gameweekStatus = row['gameweek_status']?.toString() ?? '';

      return FantasyEntryContext(
        competitionId: row['competition_id']?.toString() ?? '',
        competitionSlug: row['competition_slug']?.toString() ?? competitionSlug,
        competitionName:
            row['competition_name']?.toString() ?? 'Fantasy competition',
        competitionMode: fantasyCompetitionModeFromRaw(
          row['competition_type']?.toString(),
        ),
        competitionStatus: fantasyCompetitionStatusFromRaw(
          row['competition_status']?.toString(),
        ),
        squadConfig: _mapJsonObject(row['squad_config']),
        transferConfig: _mapJsonObject(row['transfer_config']),
        gameweek:
            gameweekId == null ||
                gameweekId.isEmpty ||
                gameweekNumber == null ||
                gameweekName.isEmpty
            ? null
            : FantasyGameweekSummary(
                id: gameweekId,
                number: gameweekNumber,
                name: gameweekName,
                status: gameweekStatus,
                deadlineAt: DateTime.tryParse(
                  row['gameweek_deadline_at']?.toString() ?? '',
                ),
              ),
        entryId: row['entry_id']?.toString(),
        teamName: row['team_name']?.toString(),
        bankBalance: (row['bank_balance'] as num?)?.toInt() ?? 0,
        teamValue: (row['team_value'] as num?)?.toInt() ?? 0,
        overallPoints: (row['overall_points'] as num?)?.toInt() ?? 0,
        overallRank: (row['overall_rank'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<FantasyPlayerPoolItem>> loadPlayerPool(
    String competitionSlug,
  ) async {
    try {
      final rows = List<Map<String, dynamic>>.from(
        await client.rpc(
          'fantasy_get_player_pool',
          params: {'p_competition_slug': competitionSlug},
        ),
      );

      return rows
          .map(
            (row) => FantasyPlayerPoolItem(
              playerId: (row['player_id'] as num?)?.toInt() ?? 0,
              name: row['name']?.toString() ?? 'Player',
              shortName: row['short_name']?.toString() ?? '',
              position: fantasyPlayerPositionFromRaw(
                row['player_position']?.toString() ??
                    row['position']?.toString(),
              ),
              teamId: (row['team_id'] as num?)?.toInt() ?? 0,
              teamName: row['team_name']?.toString() ?? 'Club',
              teamShort: row['team_short']?.toString() ?? '',
              price: (row['price'] as num?)?.toInt() ?? 0,
              photoUrl: row['photo_url']?.toString(),
              teamLogoUrl: row['team_logo_url']?.toString(),
              nationality: row['nationality']?.toString(),
              priceChange: (row['price_change'] as num?)?.toInt() ?? 0,
              ownershipPercent:
                  (row['ownership_percent'] as num?)?.toDouble() ?? 0,
            ),
          )
          .where((player) => player.playerId != 0)
          .toList(growable: false);
    } catch (_) {
      return const <FantasyPlayerPoolItem>[];
    }
  }

  @override
  Future<List<FantasySquadSelection>> loadSquad({
    required String entryId,
    String? gameweekId,
  }) async {
    try {
      final rows = List<Map<String, dynamic>>.from(
        await client.rpc(
          'fantasy_get_squad',
          params: {'p_entry_id': entryId, 'p_gameweek_id': gameweekId},
        ),
      );

      return rows
          .map(
            (row) => FantasySquadSelection(
              selectionId: row['selection_id']?.toString(),
              gameweekId: row['gameweek_id']?.toString(),
              playerId: (row['player_id'] as num?)?.toInt() ?? 0,
              name: row['name']?.toString() ?? 'Player',
              shortName: row['short_name']?.toString() ?? '',
              position: fantasyPlayerPositionFromRaw(
                row['player_position']?.toString() ??
                    row['position']?.toString(),
              ),
              teamName: row['team_name']?.toString() ?? 'Club',
              teamShort: row['team_short']?.toString() ?? '',
              purchasePrice: (row['purchase_price'] as num?)?.toInt() ?? 0,
              isStarter: row['is_starter'] == true,
              benchOrder: (row['bench_order'] as num?)?.toInt(),
              isCaptain: row['is_captain'] == true,
              isViceCaptain: row['is_vice_captain'] == true,
              multiplier: (row['multiplier'] as num?)?.toInt() ?? 1,
              photoUrl: row['photo_url']?.toString(),
              teamLogoUrl: row['team_logo_url']?.toString(),
            ),
          )
          .where((selection) => selection.playerId != 0)
          .toList(growable: false);
    } catch (_) {
      return const <FantasySquadSelection>[];
    }
  }

  @override
  Future<int?> saveSquadSelections({
    required String entryId,
    required String gameweekId,
    required List<FantasySquadSelection> selections,
  }) async {
    if (entryId.trim().isEmpty ||
        gameweekId.trim().isEmpty ||
        selections.isEmpty) {
      return null;
    }

    try {
      final savedCount = await client.rpc(
        'fantasy_save_squad_selections',
        params: {
          'p_entry_id': entryId,
          'p_gameweek_id': gameweekId,
          'p_selections': selections
              .map((selection) => selection.toRpcPayload())
              .toList(growable: false),
        },
      );
      return (savedCount as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  FantasyCompetitionSummary _mapCompetition(
    Map<String, dynamic> row, {
    Map<String, dynamic>? enablement,
    required bool hasEntry,
  }) {
    final mode = fantasyCompetitionModeFromRaw(
      row['competition_mode']?.toString() ??
          row['competition_type']?.toString(),
    );
    final status = fantasyCompetitionStatusFromRaw(row['status']?.toString());

    final opensAt = DateTime.tryParse(
      enablement?['entry_window_opens_at']?.toString() ?? '',
    );
    final closesAt = DateTime.tryParse(
      enablement?['entry_window_closes_at']?.toString() ?? '',
    );
    final now = DateTime.now();
    final isEntryWindowOpen =
        opensAt == null ||
        opensAt.isBefore(now) ||
        opensAt.isAtSameMomentAs(now);
    final isEntryWindowClosed =
        closesAt != null &&
        closesAt.isBefore(now) &&
        !closesAt.isAtSameMomentAs(now);

    return FantasyCompetitionSummary(
      id: row['id']?.toString() ?? row['slug']?.toString() ?? '',
      slug: row['slug']?.toString() ?? '',
      name: row['name']?.toString() ?? 'Fantasy competition',
      season: row['season']?.toString() ?? '2026',
      description:
          row['description']?.toString() ??
          (mode == FantasyCompetitionMode.tournament
              ? 'Tournament-mode fantasy with stage pressure, live scoring, and knockout momentum.'
              : 'Season-long fantasy built around transfers, captains, and weekly score swings.'),
      mode: mode,
      status: status,
      provider: row['provider']?.toString(),
      promoTitle: enablement?['promo_title']?.toString(),
      promoBody: enablement?['promo_body']?.toString(),
      entryWindowOpensAt: opensAt,
      entryWindowClosesAt: closesAt,
      isVisible: enablement?['is_visible'] == false ? false : true,
      isFeatured: enablement?['is_featured'] == true,
      isPlayable:
          enablement?['is_playable'] == true ||
          status == FantasyCompetitionStatus.playable,
      entryWindowOpen: isEntryWindowOpen && !isEntryWindowClosed,
      hasEntry: hasEntry,
      activeEntries: (row['active_entries'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> _mapJsonObject(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const <String, dynamic>{};
  }

  int? _currentClubId() {
    final user = client.auth.currentUser;
    final rawValue =
        user?.appMetadata['club_id'] ??
        user?.userMetadata?['club_id'] ??
        user?.appMetadata['clubId'] ??
        user?.userMetadata?['clubId'];
    if (rawValue is int) return rawValue;
    if (rawValue is num) return rawValue.toInt();
    if (rawValue == null) return null;
    return int.tryParse(rawValue.toString().trim());
  }

  bool _isMissingRelation(Object error, String relation) {
    if (error is! PostgrestException) {
      return false;
    }
    final message = error.message.toLowerCase();
    return message.contains(relation.toLowerCase()) &&
        message.contains('does not exist');
  }
}
