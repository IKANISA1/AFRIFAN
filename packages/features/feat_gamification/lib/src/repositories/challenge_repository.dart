import 'package:core_network/core_network.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/challenge_models.dart';

class ChallengeRepository {
  ChallengeRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;
  late final ClubScopeResolver _scopeResolver = ClubScopeResolver(
    client: _client,
  );

  static const _tag = 'ChallengeRepo';

  Future<List<Challenge>> loadChallenges({
    List<String>? statuses,
    String sort = 'ending_soon',
    int limit = 20,
    int offset = 0,
    bool onlyJoined = false,
  }) async {
    final scope = await _scopeResolver.requireResolved();
    if (scope.clubId == null) {
      return const <Challenge>[];
    }

    final result = await SafeRpc.call(
      'prediction_get_challenge_feed',
      params: <String, dynamic>{
        'p_club_id': scope.clubId,
        'p_statuses': statuses,
        'p_sort': sort,
        'p_limit': limit,
        'p_offset': offset,
        'p_only_joined': onlyJoined,
      },
      tag: _tag,
    );

    if (!result.isSuccess || result.data is! List) {
      return const <Challenge>[];
    }

    return (result.data as List)
        .whereType<Map>()
        .map((row) => Challenge.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<List<Challenge>> loadMyChallenges({
    List<String>? statuses,
    String sort = 'ending_soon',
    int limit = 20,
    int offset = 0,
  }) async {
    final scope = await _scopeResolver.requireResolved();
    if (scope.clubId == null) {
      return const <Challenge>[];
    }

    final result = await SafeRpc.call(
      'prediction_get_my_challenges',
      params: <String, dynamic>{
        'p_club_id': scope.clubId,
        'p_statuses': statuses,
        'p_sort': sort,
        'p_limit': limit,
        'p_offset': offset,
      },
      tag: _tag,
    );

    if (!result.isSuccess || result.data is! List) {
      return const <Challenge>[];
    }

    return (result.data as List)
        .whereType<Map>()
        .map((row) => Challenge.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<ChallengeDetailPayload?> loadChallengeDetail(
    String challengeId,
  ) async {
    final scope = await _scopeResolver.requireResolved();
    if (scope.clubId == null) {
      return null;
    }

    final result = await SafeRpc.call(
      'prediction_get_challenge_detail',
      params: <String, dynamic>{
        'p_challenge_id': challengeId,
        'p_club_id': scope.clubId,
      },
      tag: _tag,
    );

    if (!result.isSuccess || result.data is! Map) {
      return null;
    }

    return ChallengeDetailPayload.fromJson(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  Future<ChallengeMutationResult> createChallenge({
    required String matchId,
    required int homeScore,
    required int awayScore,
    required int stakeFet,
  }) async {
    final scope = await _scopeResolver.requireResolved();

    final result = await SafeRpc.call(
      'prediction_challenge_create',
      params: <String, dynamic>{
        'p_match_id': matchId,
        'p_home_score': homeScore,
        'p_away_score': awayScore,
        'p_stake_fet': stakeFet,
        'p_club_id': scope.clubId,
      },
      tag: _tag,
      maxAttempts: 1,
    );

    if (!result.isSuccess || result.data is! Map) {
      return const ChallengeMutationResult(status: 'error');
    }

    return ChallengeMutationResult.fromJson(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  Future<ChallengeMutationResult> joinChallenge({
    required String challengeId,
    required int homeScore,
    required int awayScore,
  }) async {
    final result = await SafeRpc.call(
      'prediction_challenge_join',
      params: <String, dynamic>{
        'p_challenge_id': challengeId,
        'p_home_score': homeScore,
        'p_away_score': awayScore,
      },
      tag: _tag,
      maxAttempts: 1,
    );

    if (!result.isSuccess || result.data is! Map) {
      return const ChallengeMutationResult(status: 'error');
    }

    return ChallengeMutationResult.fromJson(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  Future<ChallengeMutationResult> cancelChallenge(String challengeId) async {
    final result = await SafeRpc.call(
      'prediction_challenge_cancel',
      params: <String, dynamic>{'p_challenge_id': challengeId},
      tag: _tag,
      maxAttempts: 1,
    );

    if (!result.isSuccess || result.data is! Map) {
      return const ChallengeMutationResult(status: 'error');
    }

    return ChallengeMutationResult.fromJson(
      Map<String, dynamic>.from(result.data as Map),
    );
  }
}
