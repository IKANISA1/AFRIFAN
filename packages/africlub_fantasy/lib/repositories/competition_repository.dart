import 'package:africlub_fantasy/core/exceptions.dart';
import 'package:africlub_fantasy/models/competition.dart';
import 'package:africlub_fantasy/models/fantasy_notification_topic.dart';
import 'package:africlub_fantasy/models/gameweek.dart';
import 'package:africlub_fantasy/models/world_cup_bracket_match.dart';
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

  Future<List<WorldCupBracketMatch>> getCompetitionBracket(
    String competitionId,
  ) async {
    try {
      final result = await _client.rpc(
        'fantasy_get_competition_bracket',
        params: <String, dynamic>{'p_competition_id': competitionId},
      );
      return (result as List<dynamic>)
          .map(
            (row) =>
                WorldCupBracketMatch.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw FantasyException.data(error.message);
    }
  }

  Future<List<FantasyNotificationTopic>> getNotificationTopics() async {
    try {
      final result = await _client.rpc('fantasy_get_notification_topics');
      return (result as List<dynamic>)
          .map(
            (row) => FantasyNotificationTopic.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw FantasyException.data(error.message);
    }
  }

  Future<FantasyNotificationTopic> updateNotificationTopic({
    required String competitionId,
    required bool enabled,
    required bool deadlineAlerts,
    required bool gameplayAlerts,
    required bool leagueAlerts,
  }) async {
    try {
      final result = await _client.rpc(
        'fantasy_update_notification_preference',
        params: <String, dynamic>{
          'p_competition_id': competitionId,
          'p_topic_enabled': enabled,
          'p_deadline_alerts': deadlineAlerts,
          'p_gameplay_alerts': gameplayAlerts,
          'p_league_alerts': leagueAlerts,
        },
      );
      return FantasyNotificationTopic.fromJson(
        Map<String, dynamic>.from(result),
      );
    } on PostgrestException catch (error) {
      throw FantasyException.validation(error.message);
    }
  }
}
