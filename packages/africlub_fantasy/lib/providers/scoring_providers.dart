import 'package:africlub_fantasy/models/entry_gameweek_score.dart';
import 'package:africlub_fantasy/repositories/scoring_repository.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef EntryGameweekRequest = ({String entryId, String gameweekId});

final scoringRepositoryProvider = Provider<ScoringRepository>((ref) {
  return ScoringRepository(ref.watch(supabaseClientProvider));
});

final latestEntryScoreProvider =
    FutureProvider.family<EntryGameweekScore?, String>((ref, entryId) {
      return ref.watch(scoringRepositoryProvider).getLatestEntryScore(entryId);
    });

final gameweekScoreProvider =
    FutureProvider.family<EntryGameweekScore?, EntryGameweekRequest>((
      ref,
      request,
    ) {
      return ref
          .watch(scoringRepositoryProvider)
          .getGameweekScore(request.entryId, request.gameweekId);
    });
