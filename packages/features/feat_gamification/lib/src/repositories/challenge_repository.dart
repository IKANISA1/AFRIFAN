import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_network/core_network.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/challenge_models.dart';

class ChallengeRepository {
  ChallengeRepository({
    required SupabaseClient client,
    StoreReleasePolicy? storeReleasePolicy,
  }) : _client = client,
       _storeReleasePolicy =
           storeReleasePolicy ??
           StoreReleasePolicy.forCurrentBuild(const PlatformConfigSnapshot());

  final SupabaseClient _client;
  final StoreReleasePolicy _storeReleasePolicy;
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
    if (!_storeReleasePolicy.allowsStakedCompetitions) {
      return const <Challenge>[];
    }
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
        .map((row) => Map<String, dynamic>.from(row))
        .map(_sanitizeChallenge)
        .map(Challenge.fromJson)
        .toList(growable: false);
  }

  Future<List<Challenge>> loadMyChallenges({
    List<String>? statuses,
    String sort = 'ending_soon',
    int limit = 20,
    int offset = 0,
  }) async {
    if (!_storeReleasePolicy.allowsStakedCompetitions) {
      return const <Challenge>[];
    }
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
        .map((row) => Map<String, dynamic>.from(row))
        .map(_sanitizeChallenge)
        .map(Challenge.fromJson)
        .toList(growable: false);
  }

  Future<ChallengeDetailPayload?> loadChallengeDetail(
    String challengeId,
  ) async {
    if (!_storeReleasePolicy.allowsStakedCompetitions) {
      return null;
    }
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
      _sanitizeChallengeDetail(Map<String, dynamic>.from(result.data as Map)),
    );
  }

  Future<ChallengeMutationResult> createChallenge({
    required String matchId,
    required int homeScore,
    required int awayScore,
    required int stakeFet,
  }) async {
    _requireStakedCompetitionAuthorization();
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
      _sanitizeChallengeMutation(Map<String, dynamic>.from(result.data as Map)),
    );
  }

  Future<ChallengeMutationResult> joinChallenge({
    required String challengeId,
    required int homeScore,
    required int awayScore,
  }) async {
    _requireStakedCompetitionAuthorization();
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
      _sanitizeChallengeMutation(Map<String, dynamic>.from(result.data as Map)),
    );
  }

  Future<ChallengeMutationResult> cancelChallenge(String challengeId) async {
    _requireStakedCompetitionAuthorization();
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
      _sanitizeChallengeMutation(Map<String, dynamic>.from(result.data as Map)),
    );
  }

  Map<String, dynamic> _sanitizeChallenge(Map<String, dynamic> row) {
    if (_storeReleasePolicy.allowsCrossUserText) {
      return row;
    }

    final creatorUserId = row['creator_user_id']?.toString();
    final rawCreator = row['creator'];
    final creator = rawCreator is Map
        ? Map<String, dynamic>.from(rawCreator)
        : null;
    final creatorId = creator?['id']?.toString() ?? creatorUserId;
    final creatorLabel = _storeReleasePolicy.publicSupporterLabel(
      displayName:
          row['creator_name']?.toString() ??
          creator?['display_name']?.toString(),
      publicUserId: creator?['public_user_id']?.toString(),
      userId: creatorId,
    );
    final rawEntry = row['my_entry'];

    return <String, dynamic>{
      ...row,
      'creator_name': creatorLabel,
      if (creator != null)
        'creator': <String, dynamic>{...creator, 'display_name': creatorLabel},
      if (rawEntry is Map)
        'my_entry': _sanitizeChallengeEntry(
          Map<String, dynamic>.from(rawEntry),
        ),
    };
  }

  Map<String, dynamic> _sanitizeChallengeEntry(Map<String, dynamic> row) {
    if (_storeReleasePolicy.allowsCrossUserText) {
      return row;
    }
    final rawUser = row['user'];
    final user = rawUser is Map ? Map<String, dynamic>.from(rawUser) : null;
    final userId = row['user_id']?.toString() ?? user?['id']?.toString();
    final label = _storeReleasePolicy.publicSupporterLabel(
      displayName:
          row['user_name']?.toString() ?? user?['display_name']?.toString(),
      publicUserId: user?['public_user_id']?.toString(),
      userId: userId,
    );
    return <String, dynamic>{
      ...row,
      'user_name': label,
      if (user != null)
        'user': <String, dynamic>{...user, 'display_name': label},
    };
  }

  Map<String, dynamic> _sanitizeChallengeDetail(Map<String, dynamic> row) {
    if (_storeReleasePolicy.allowsCrossUserText) {
      return row;
    }
    final rawChallenge = row['challenge'];
    final rawEntries = row['entries'];
    return <String, dynamic>{
      ...row,
      if (rawChallenge is Map)
        'challenge': _sanitizeChallenge(
          Map<String, dynamic>.from(rawChallenge),
        ),
      if (rawEntries is List)
        'entries': rawEntries
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .map(_sanitizeChallengeEntry)
            .toList(growable: false),
    };
  }

  Map<String, dynamic> _sanitizeChallengeMutation(Map<String, dynamic> row) {
    if (_storeReleasePolicy.allowsCrossUserText) {
      return row;
    }
    final rawChallenge = row['challenge'];
    return <String, dynamic>{
      ...row,
      if (rawChallenge is Map)
        'challenge': _sanitizeChallenge(
          Map<String, dynamic>.from(rawChallenge),
        ),
    };
  }

  void _requireStakedCompetitionAuthorization() {
    if (!_storeReleasePolicy.allowsStakedCompetitions) {
      throw UnsupportedError(
        'Stake-based challenges are unavailable in this store release.',
      );
    }
  }
}
