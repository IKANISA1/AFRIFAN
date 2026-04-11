import 'package:africlub_fantasy/core/exceptions.dart';
import 'package:africlub_fantasy/models/entry_gameweek_score.dart';
import 'package:africlub_fantasy/models/fantasy_entry.dart';
import 'package:africlub_fantasy/models/fantasy_league.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeagueRepository {
  LeagueRepository(this._client);

  final SupabaseClient _client;

  Future<List<EntryGameweekScore>> getGlobalLeaderboard({
    required String competitionId,
    String? gameweekId,
    int limit = 100,
  }) async {
    try {
      final entries = await _client
          .schema('fantasy')
          .from('public_entry_summaries')
          .select()
          .eq('competition_id', competitionId)
          .order('overall_rank', ascending: true)
          .limit(limit);

      final entryList = (entries as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);

      Map<String, Map<String, dynamic>> scoreByEntry =
          <String, Map<String, dynamic>>{};
      if (gameweekId != null && entryList.isNotEmpty) {
        final scores = await _client
            .schema('fantasy')
            .from('entry_gameweek_scores')
            .select()
            .eq('gameweek_id', gameweekId)
            .inFilter('entry_id', entryList.map((row) => row['id']).toList());
        scoreByEntry = {
          for (final row in scores as List<dynamic>)
            row['entry_id'] as String: Map<String, dynamic>.from(row),
        };
      }

      return entryList
          .map((row) {
            final score = scoreByEntry[row['id']] ?? const <String, dynamic>{};
            return EntryGameweekScore.fromJson(<String, dynamic>{
              'id': score['id'] ?? row['id'],
              'entry_id': row['id'],
              'gameweek_id': score['gameweek_id'] ?? gameweekId ?? '',
              'points': score['points'] ?? 0,
              'rank': score['rank'],
              'team_name': row['team_name'],
              'manager_name': row['manager_name'],
              'overall_points': row['overall_points'],
              'overall_rank': row['overall_rank'],
            });
          })
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw FantasyException.data(error.message);
    }
  }

  Future<List<FantasyLeague>> getMyLeagues(String competitionId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const <FantasyLeague>[];

    try {
      final entries = await _client
          .schema('fantasy')
          .from('fantasy_entries')
          .select('id')
          .eq('competition_id', competitionId)
          .eq('user_id', userId);
      final entryIds = (entries as List<dynamic>)
          .map((row) => row['id'] as String)
          .toList(growable: false);
      if (entryIds.isEmpty) return const <FantasyLeague>[];

      final memberships = await _client
          .schema('fantasy')
          .from('league_memberships')
          .select('league:leagues(*)')
          .inFilter('entry_id', entryIds);

      return (memberships as List<dynamic>)
          .map((row) => row['league'])
          .whereType<Map<String, dynamic>>()
          .map(FantasyLeague.fromJson)
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw FantasyException.data(error.message);
    }
  }

  Future<List<EntryGameweekScore>> getLeagueTable({
    required String leagueId,
    required String gameweekId,
  }) async {
    try {
      final memberships = await _client
          .schema('fantasy')
          .from('league_memberships')
          .select('entry_id')
          .eq('league_id', leagueId);
      final entryIds = (memberships as List<dynamic>)
          .map((row) => row['entry_id'] as String)
          .toList(growable: false);
      if (entryIds.isEmpty) return const <EntryGameweekScore>[];

      final entries = await _client
          .schema('fantasy')
          .from('public_entry_summaries')
          .select()
          .inFilter('id', entryIds);
      final entryMap = {
        for (final row in entries as List<dynamic>)
          row['id'] as String: Map<String, dynamic>.from(row),
      };

      final scores = await _client
          .schema('fantasy')
          .from('entry_gameweek_scores')
          .select()
          .eq('gameweek_id', gameweekId)
          .inFilter('entry_id', entryIds)
          .order('rank');

      return (scores as List<dynamic>)
          .map((row) {
            final json = Map<String, dynamic>.from(row);
            final summary =
                entryMap[row['entry_id']] ?? const <String, dynamic>{};
            json['team_name'] = summary['team_name'];
            json['manager_name'] = summary['manager_name'];
            json['overall_points'] = summary['overall_points'];
            json['overall_rank'] = summary['overall_rank'];
            return EntryGameweekScore.fromJson(json);
          })
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw FantasyException.data(error.message);
    }
  }

  Future<FantasyLeague> createLeague({
    required String competitionId,
    required String name,
    required bool isPublic,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw FantasyException.auth(
        'You need to sign in before creating leagues.',
      );
    }

    try {
      final result = await _client
          .schema('fantasy')
          .from('leagues')
          .insert(<String, dynamic>{
            'competition_id': competitionId,
            'name': name,
            'created_by': userId,
            'is_public': isPublic,
          })
          .select()
          .single();
      return FantasyLeague.fromJson(Map<String, dynamic>.from(result));
    } on PostgrestException catch (error) {
      throw FantasyException.validation(error.message);
    }
  }

  Future<void> joinLeague({
    required String leagueCode,
    required FantasyEntry entry,
  }) async {
    try {
      final league = await _client
          .schema('fantasy')
          .from('leagues')
          .select('id')
          .eq('code', leagueCode.toUpperCase())
          .single();

      await _client.schema('fantasy').from('league_memberships').insert(
        <String, dynamic>{'league_id': league['id'], 'entry_id': entry.id},
      );
    } on PostgrestException catch (error) {
      throw FantasyException.validation(error.message);
    }
  }
}
