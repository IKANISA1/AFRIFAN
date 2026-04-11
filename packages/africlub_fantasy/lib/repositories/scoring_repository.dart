import 'package:africlub_fantasy/core/exceptions.dart';
import 'package:africlub_fantasy/models/entry_gameweek_score.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScoringRepository {
  ScoringRepository(this._client);

  final SupabaseClient _client;

  Future<EntryGameweekScore?> getGameweekScore(
    String entryId,
    String gameweekId,
  ) async {
    try {
      final result = await _client
          .schema('fantasy')
          .from('entry_gameweek_scores')
          .select()
          .eq('entry_id', entryId)
          .eq('gameweek_id', gameweekId)
          .maybeSingle();
      if (result == null) return null;
      return EntryGameweekScore.fromJson(Map<String, dynamic>.from(result));
    } on PostgrestException catch (error) {
      throw FantasyException.data(error.message);
    }
  }

  Future<EntryGameweekScore?> getLatestEntryScore(String entryId) async {
    try {
      final result = await _client
          .schema('fantasy')
          .from('entry_gameweek_scores')
          .select()
          .eq('entry_id', entryId)
          .order('calculated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (result == null) return null;
      return EntryGameweekScore.fromJson(Map<String, dynamic>.from(result));
    } on PostgrestException catch (error) {
      throw FantasyException.data(error.message);
    }
  }

  Future<List<EntryGameweekScore>> getLeagueScores({
    required String gameweekId,
    required List<String> entryIds,
  }) async {
    if (entryIds.isEmpty) return const <EntryGameweekScore>[];

    try {
      final result = await _client
          .schema('fantasy')
          .from('entry_gameweek_scores')
          .select()
          .eq('gameweek_id', gameweekId)
          .inFilter('entry_id', entryIds)
          .order('rank');
      return (result as List<dynamic>)
          .map(
            (row) =>
                EntryGameweekScore.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw FantasyException.data(error.message);
    }
  }
}
