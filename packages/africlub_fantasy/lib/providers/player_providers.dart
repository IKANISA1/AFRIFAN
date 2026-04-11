import 'package:africlub_fantasy/models/fantasy_player.dart';
import 'package:africlub_fantasy/models/player_gameweek_stats.dart';
import 'package:africlub_fantasy/repositories/player_repository.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef PlayerRequest = ({String competitionId, int playerId});

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return PlayerRepository(ref.watch(supabaseClientProvider));
});

final competitionPlayersProvider =
    FutureProvider.family<List<FantasyPlayer>, String>((ref, competitionId) {
      return ref
          .watch(playerRepositoryProvider)
          .getCompetitionPlayers(competitionId);
    });

final playerProvider = FutureProvider.family<FantasyPlayer?, PlayerRequest>((
  ref,
  request,
) {
  return ref
      .watch(playerRepositoryProvider)
      .getPlayer(request.competitionId, request.playerId);
});

final playerHistoryProvider =
    FutureProvider.family<List<PlayerGameweekStats>, int>((ref, playerId) {
      return ref
          .watch(playerRepositoryProvider)
          .getPlayerStatsHistory(playerId);
    });
