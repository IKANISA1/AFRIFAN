import 'package:core_network/core_network.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/challenge_models.dart';

class ChallengeRepository {
  ChallengeRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;
  static const _tag = 'ChallengeRepo';

  Future<List<Challenge>> loadChallenges({
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    final result = await SafeRpc.query<List<Challenge>>(
      () async {
        var query = _client.from('prediction_challenges').select('''
              *,
              fixture:match_id (
                id,
                home_team_name,
                home_team_short_name,
                away_team_name,
                away_team_short_name,
                kickoff_at,
                venue_name,
                status,
                home_score,
                away_score,
                competition_name
              ),
              creator:creator_user_id (
                display_name,
                full_name,
                avatar_url
              )
            ''');

        if (status != null) {
          query = query.eq('status', status);
        }

        final rows = await query
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);

        return rows.map((row) {
          final creator = row['creator'] as Map<String, dynamic>?;
          return Challenge.fromJson({
            ...row,
            'creator_name': creator?['display_name'] ?? creator?['full_name'],
            'creator_avatar': creator?['avatar_url'],
          });
        }).toList();
      },
      tag: _tag,
      description: 'Load challenges',
    );
    return result.requireData;
  }

  Future<Challenge?> loadChallengeDetail(String challengeId) async {
    final result = await SafeRpc.query<Challenge?>(
      () async {
        final row = await _client
            .from('prediction_challenges')
            .select('''
              *,
              fixture:match_id (*),
              creator:creator_user_id (display_name, full_name, avatar_url)
            ''')
            .eq('id', challengeId)
            .maybeSingle();

        if (row == null) return null;

        final creator = row['creator'] as Map<String, dynamic>?;
        return Challenge.fromJson({
          ...row,
          'creator_name': creator?['display_name'] ?? creator?['full_name'],
          'creator_avatar': creator?['avatar_url'],
        });
      },
      tag: _tag,
      description: 'Load challenge detail',
    );
    return result.requireData;
  }

  Future<List<ChallengeEntry>> loadChallengeEntries(String challengeId) async {
    final result = await SafeRpc.query<List<ChallengeEntry>>(
      () async {
        final rows = await _client
            .from('prediction_challenge_entries')
            .select('*, user:user_id(display_name, full_name, avatar_url)')
            .eq('challenge_id', challengeId)
            .order('joined_at', ascending: true);

        return rows.map((row) {
          final user = row['user'] as Map<String, dynamic>?;
          return ChallengeEntry.fromJson({
            ...row,
            'user_name': user?['display_name'] ?? user?['full_name'],
            'user_avatar': user?['avatar_url'],
          });
        }).toList();
      },
      tag: _tag,
      description: 'Load challenge entries',
    );
    return result.requireData;
  }

  Future<ChallengeEntry?> loadUserEntry(String challengeId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final result = await SafeRpc.query<ChallengeEntry?>(
      () async {
        final row = await _client
            .from('prediction_challenge_entries')
            .select()
            .eq('challenge_id', challengeId)
            .eq('user_id', userId)
            .maybeSingle();

        return row != null ? ChallengeEntry.fromJson(row) : null;
      },
      tag: _tag,
      description: 'Load user entry',
    );
    return result.requireData;
  }

  Future<bool> createChallenge({
    required String matchId,
    required int homeScore,
    required int awayScore,
    required int stakeFet,
  }) async {
    final result = await SafeRpc.call(
      'prediction_challenge_create',
      params: {
        'p_match_id': matchId,
        'p_home_score': homeScore,
        'p_away_score': awayScore,
        'p_stake_fet': stakeFet,
      },
      tag: _tag,
    );
    return result.isSuccess;
  }

  Future<bool> joinChallenge({
    required String challengeId,
    required int homeScore,
    required int awayScore,
  }) async {
    final result = await SafeRpc.call(
      'prediction_challenge_join',
      params: {
        'p_challenge_id': challengeId,
        'p_home_score': homeScore,
        'p_away_score': awayScore,
      },
      tag: _tag,
    );
    return result.isSuccess;
  }

  Future<bool> cancelChallenge(String challengeId) async {
    final result = await SafeRpc.call(
      'prediction_challenge_cancel',
      params: {'p_challenge_id': challengeId},
      tag: _tag,
    );
    return result.isSuccess;
  }
}
