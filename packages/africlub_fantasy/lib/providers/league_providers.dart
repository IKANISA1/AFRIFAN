import 'package:africlub_fantasy/models/entry_gameweek_score.dart';
import 'package:africlub_fantasy/models/fantasy_league.dart';
import 'package:africlub_fantasy/repositories/league_repository.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef LeagueTableRequest = ({String leagueId, String gameweekId});
typedef GlobalLeaderboardRequest = ({String competitionId, String? gameweekId});

final leagueRepositoryProvider = Provider<LeagueRepository>((ref) {
  return LeagueRepository(ref.watch(supabaseClientProvider));
});

final globalLeaderboardProvider =
    FutureProvider.family<List<EntryGameweekScore>, GlobalLeaderboardRequest>((
      ref,
      request,
    ) {
      return ref
          .watch(leagueRepositoryProvider)
          .getGlobalLeaderboard(
            competitionId: request.competitionId,
            gameweekId: request.gameweekId,
          );
    });

final myLeaguesProvider = FutureProvider.family<List<FantasyLeague>, String>((
  ref,
  competitionId,
) {
  return ref.watch(leagueRepositoryProvider).getMyLeagues(competitionId);
});

final leagueTableProvider =
    FutureProvider.family<List<EntryGameweekScore>, LeagueTableRequest>((
      ref,
      request,
    ) {
      return ref
          .watch(leagueRepositoryProvider)
          .getLeagueTable(
            leagueId: request.leagueId,
            gameweekId: request.gameweekId,
          );
    });
