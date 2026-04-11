import 'package:africlub_fantasy/models/entry_gameweek_score.dart';
import 'package:africlub_fantasy/models/player_gameweek_stats.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final liveEntryScoreProvider =
    StreamProvider.family<EntryGameweekScore?, String>((ref, entryId) {
      final client = ref.watch(supabaseClientProvider);

      return client
          .schema('fantasy')
          .from('entry_gameweek_scores')
          .stream(primaryKey: <String>['id'])
          .eq('entry_id', entryId)
          .order('calculated_at', ascending: false)
          .map((rows) {
            if (rows.isEmpty) return null;
            return EntryGameweekScore.fromJson(
              Map<String, dynamic>.from(rows.first),
            );
          });
    });

final livePlayerStatsProvider =
    StreamProvider.family<List<PlayerGameweekStats>, String>((ref, gameweekId) {
      final client = ref.watch(supabaseClientProvider);

      return client
          .schema('fantasy')
          .from('player_gameweek_stats')
          .stream(primaryKey: <String>['id'])
          .eq('gameweek_id', gameweekId)
          .map(
            (rows) => rows
                .map(
                  (row) => PlayerGameweekStats.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList(growable: false),
          );
    });

final deadlineCountdownProvider = StreamProvider.family<Duration, DateTime>((
  ref,
  deadline,
) {
  return Stream<Duration>.periodic(const Duration(seconds: 1), (_) {
    final now = DateTime.now().toUtc();
    final diff = deadline.toUtc().difference(now);
    return diff.isNegative ? Duration.zero : diff;
  });
});
