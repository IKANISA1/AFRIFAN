import 'package:africlub_fantasy/models/competition.dart';
import 'package:africlub_fantasy/models/fantasy_notification_topic.dart';
import 'package:africlub_fantasy/models/gameweek.dart';
import 'package:africlub_fantasy/models/world_cup_bracket_match.dart';
import 'package:africlub_fantasy/repositories/competition_repository.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final competitionRepositoryProvider = Provider<CompetitionRepository>((ref) {
  return CompetitionRepository(ref.watch(supabaseClientProvider));
});

final activeCompetitionsProvider = FutureProvider<List<Competition>>((ref) {
  return ref.watch(competitionRepositoryProvider).getActiveCompetitions();
});

final competitionProvider = FutureProvider.family<Competition, String>((
  ref,
  slug,
) {
  return ref.watch(competitionRepositoryProvider).getCompetition(slug);
});

final currentGameweekProvider = FutureProvider.family<Gameweek?, String>((
  ref,
  competitionId,
) {
  return ref
      .watch(competitionRepositoryProvider)
      .getCurrentGameweek(competitionId);
});

final allGameweeksProvider = FutureProvider.family<List<Gameweek>, String>((
  ref,
  competitionId,
) {
  return ref
      .watch(competitionRepositoryProvider)
      .getAllGameweeks(competitionId);
});

final worldCupStandingsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) {
  return ref.watch(competitionRepositoryProvider).getWCStandings();
});

final worldCupBracketProvider =
    FutureProvider.family<List<WorldCupBracketMatch>, String>((
      ref,
      competitionId,
    ) {
      return ref
          .watch(competitionRepositoryProvider)
          .getCompetitionBracket(competitionId);
    });

final fantasyNotificationTopicsProvider =
    FutureProvider<List<FantasyNotificationTopic>>((ref) {
      return ref.watch(competitionRepositoryProvider).getNotificationTopics();
    });

final fantasyNotificationTopicProvider =
    FutureProvider.family<FantasyNotificationTopic?, String>((
      ref,
      competitionId,
    ) async {
      final topics = await ref.watch(fantasyNotificationTopicsProvider.future);
      for (final topic in topics) {
        if (topic.competitionId == competitionId) {
          return topic;
        }
      }
      return null;
    });
