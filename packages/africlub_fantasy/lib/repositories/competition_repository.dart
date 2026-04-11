import 'package:africlub_fantasy/core/exceptions.dart';
import 'package:africlub_fantasy/models/competition.dart';
import 'package:africlub_fantasy/models/gameweek.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CompetitionRepository {
  CompetitionRepository(this._client);

  final SupabaseClient _client;

  Future<List<Competition>> getActiveCompetitions() async {
    try {
      final result = await _client.rpc('fantasy_get_mobile_competitions');
      return (result as List<dynamic>)
          .map((row) => Competition.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw FantasyException.data(error.message);
    }
  }

  Future<Competition> getCompetition(String slug) async {
    try {
      final result = await _client.rpc(
        'fantasy_get_mobile_competition',
        params: <String, dynamic>{'p_slug': slug},
      );
      return Competition.fromJson(Map<String, dynamic>.from(result));
    } on PostgrestException catch (error) {
      throw FantasyException.data(error.message);
    }
  }

  Future<Gameweek?> getCurrentGameweek(String competitionId) async {
    try {
      final result = await _client
          .schema('fantasy')
          .from('gameweeks')
          .select()
          .eq('competition_id', competitionId)
          .inFilter('status', <String>['live', 'scoring', 'upcoming'])
          .order('number')
          .limit(1)
          .maybeSingle();
      if (result == null) return null;
      return Gameweek.fromJson(Map<String, dynamic>.from(result));
    } on PostgrestException catch (error) {
      throw FantasyException.data(error.message);
    }
  }

  Future<List<Gameweek>> getAllGameweeks(String competitionId) async {
    try {
      final result = await _client
          .schema('fantasy')
          .from('gameweeks')
          .select()
          .eq('competition_id', competitionId)
          .order('number');
      return (result as List<dynamic>)
          .map((row) => Gameweek.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw FantasyException.data(error.message);
    }
  }

  Future<List<Map<String, dynamic>>> getWCStandings() async {
    try {
      final result = await _client
          .from('standings')
          .select()
          .ilike('league', '%World Cup%')
          .eq('is_active', true)
          .order('position');
      return (result as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    } on PostgrestException {
      return const <Map<String, dynamic>>[];
    }
  }
}
