import 'package:africlub_fantasy/core/exceptions.dart';
import 'package:africlub_fantasy/models/fantasy_player.dart';
import 'package:africlub_fantasy/models/player_gameweek_stats.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlayerRepository {
  PlayerRepository(this._client);

  final SupabaseClient _client;

  Future<List<FantasyPlayer>> getCompetitionPlayers(
    String competitionId,
  ) async {
    try {
      final result = await _client.rpc(
        'fantasy_get_player_pool_by_competition_id',
        params: <String, dynamic>{'p_competition_id': competitionId},
      );

      return (result as List<dynamic>)
          .map(
            (row) => FantasyPlayer.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw FantasyException.data(error.message);
    }
  }

  Future<FantasyPlayer?> getPlayer(String competitionId, int playerId) async {
    try {
      final result = await _client.rpc(
        'fantasy_get_player_by_competition_id',
        params: <String, dynamic>{
          'p_competition_id': competitionId,
          'p_player_id': playerId,
        },
      );
      final rows = result as List<dynamic>;
      if (rows.isEmpty) return null;
      return FantasyPlayer.fromJson(Map<String, dynamic>.from(rows.first));
    } on PostgrestException catch (error) {
      throw FantasyException.data(error.message);
    }
  }

  Future<List<PlayerGameweekStats>> getPlayerStatsHistory(
    int playerId, {
    int limit = 6,
  }) async {
    try {
      final result = await _client
          .schema('fantasy')
          .from('player_gameweek_stats')
          .select()
          .eq('player_id', playerId)
          .order('last_synced_at', ascending: false)
          .limit(limit);
      return (result as List<dynamic>)
          .map(
            (row) =>
                PlayerGameweekStats.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw FantasyException.data(error.message);
    }
  }
}
