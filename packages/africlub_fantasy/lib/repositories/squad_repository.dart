import 'package:africlub_fantasy/core/exceptions.dart';
import 'package:africlub_fantasy/models/chip_state.dart';
import 'package:africlub_fantasy/models/fantasy_entry.dart';
import 'package:africlub_fantasy/models/fantasy_gameweek_state.dart';
import 'package:africlub_fantasy/models/squad_selection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SquadRepository {
  SquadRepository(this._client);

  final SupabaseClient _client;

  Future<FantasyEntry?> getMyEntry(String competitionId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final result = await _client
          .schema('fantasy')
          .from('fantasy_entries')
          .select()
          .eq('competition_id', competitionId)
          .eq('user_id', userId)
          .maybeSingle();
      if (result == null) return null;
      return FantasyEntry.fromJson(Map<String, dynamic>.from(result));
    } on PostgrestException catch (error) {
      throw FantasyException.data(error.message);
    }
  }

  Future<FantasyEntry> createEntry({
    required String competitionSlug,
    required String teamName,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw FantasyException.auth(
        'You need to sign in before entering fantasy.',
      );
    }

    try {
      final entryId = await _client.rpc(
        'fantasy_create_entry',
        params: <String, dynamic>{
          'p_competition_slug': competitionSlug,
          'p_team_name': teamName,
        },
      );
      final result = await _client
          .schema('fantasy')
          .from('fantasy_entries')
          .select()
          .eq('id', entryId)
          .single();
      return FantasyEntry.fromJson(Map<String, dynamic>.from(result));
    } on PostgrestException catch (error) {
      throw FantasyException.data(error.message);
    }
  }

  Future<List<SquadSelection>> getSquadForGameweek(
    String entryId,
    String gameweekId,
  ) async {
    try {
      final result = await _client.rpc(
        'fantasy_get_squad',
        params: <String, dynamic>{
          'p_entry_id': entryId,
          'p_gameweek_id': gameweekId,
        },
      );
      return (result as List<dynamic>)
          .map((row) {
            final json = Map<String, dynamic>.from(row);
            return SquadSelection.fromJson(<String, dynamic>{
              'id': json['selection_id'],
              'entry_id': entryId,
              'gameweek_id': json['gameweek_id'] ?? gameweekId,
              'player_id': json['player_id'],
              'position': json['player_position'],
              'is_starter': json['is_starter'],
              'bench_order': json['bench_order'],
              'is_captain': json['is_captain'],
              'is_vice_captain': json['is_vice_captain'],
              'purchase_price': json['purchase_price'],
              'multiplier': json['multiplier'],
              'player': <String, dynamic>{
                'external_id': json['player_id'],
                'name': json['name'],
                'short_name': json['short_name'],
                'photo_url': json['photo_url'],
                'position': json['player_position'],
                'team_id': json['team_id'] ?? 0,
                'team_name': json['team_name'],
                'team_short': json['team_short'],
                'team_logo_url': json['team_logo_url'],
                'price': json['purchase_price'],
              },
            });
          })
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw FantasyException.data(error.message);
    }
  }

  Future<void> saveSquad({
    required String entryId,
    required String gameweekId,
    required List<Map<String, dynamic>> selections,
  }) async {
    try {
      await _client.rpc(
        'fantasy_save_squad_selections',
        params: <String, dynamic>{
          'p_entry_id': entryId,
          'p_gameweek_id': gameweekId,
          'p_selections': selections,
        },
      );
    } on PostgrestException catch (error) {
      throw FantasyException.validation(error.message);
    }
  }

  Future<FantasyGameweekState> getEntryGameweekState({
    required String entryId,
    required String gameweekId,
  }) async {
    try {
      final result = await _client.rpc(
        'fantasy_get_entry_gameweek_state',
        params: <String, dynamic>{
          'p_entry_id': entryId,
          'p_gameweek_id': gameweekId,
        },
      );
      final rows = result as List<dynamic>;
      return FantasyGameweekState.fromJson(
        Map<String, dynamic>.from(rows.first),
      );
    } on PostgrestException catch (error) {
      throw FantasyException.data(error.message);
    }
  }

  Future<List<ChipState>> getChipStates({
    required String entryId,
    required String gameweekId,
  }) async {
    try {
      final result = await _client.rpc(
        'fantasy_get_chip_statuses',
        params: <String, dynamic>{
          'p_entry_id': entryId,
          'p_gameweek_id': gameweekId,
        },
      );
      return (result as List<dynamic>)
          .map((row) => ChipState.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw FantasyException.data(error.message);
    }
  }

  Future<void> activateChip({
    required String entryId,
    required String gameweekId,
    required ChipType chip,
  }) async {
    try {
      await _client.rpc(
        'fantasy_activate_chip',
        params: <String, dynamic>{
          'p_entry_id': entryId,
          'p_gameweek_id': gameweekId,
          'p_chip': _chipRpcValue(chip),
        },
      );
    } on PostgrestException catch (error) {
      throw FantasyException.validation(error.message);
    }
  }

  String _chipRpcValue(ChipType chip) {
    return switch (chip) {
      ChipType.wildcard => 'wildcard',
      ChipType.freeHit => 'free_hit',
      ChipType.tripleCaptain => 'triple_captain',
      ChipType.benchBoost => 'bench_boost',
    };
  }

  Future<FantasyGameweekState> makeTransfer({
    required String entryId,
    required String gameweekId,
    required int playerOutId,
    required int playerInId,
  }) async {
    try {
      final result = await _client.rpc(
        'fantasy_make_transfer',
        params: <String, dynamic>{
          'p_entry_id': entryId,
          'p_gameweek_id': gameweekId,
          'p_player_out_id': playerOutId,
          'p_player_in_id': playerInId,
        },
      );
      final rows = result as List<dynamic>;
      return FantasyGameweekState.fromJson(<String, dynamic>{
        'entry_id': entryId,
        'gameweek_id': gameweekId,
        ...Map<String, dynamic>.from(rows.first),
      });
    } on PostgrestException catch (error) {
      throw FantasyException.validation(error.message);
    }
  }
}
