import 'prediction_models.dart';

enum ChallengeStatus { open, locked, settled, void_, cancelled }

enum ChallengeEntryStatus { active, winner, loser, refunded, cancelled }

class ChallengeUser {
  const ChallengeUser({
    required this.id,
    required this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;

  factory ChallengeUser.fromJson(Map<String, dynamic> json) {
    return ChallengeUser(
      id: json['id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? 'Supporter',
      avatarUrl: json['avatar_url']?.toString(),
    );
  }
}

class ChallengeScorePrediction {
  const ChallengeScorePrediction({
    required this.homeScore,
    required this.awayScore,
    this.joinedAt,
  });

  final int homeScore;
  final int awayScore;
  final DateTime? joinedAt;

  factory ChallengeScorePrediction.fromJson(Map<String, dynamic> json) {
    return ChallengeScorePrediction(
      homeScore: (json['home_score'] as num?)?.toInt() ?? 0,
      awayScore: (json['away_score'] as num?)?.toInt() ?? 0,
      joinedAt: DateTime.tryParse(json['joined_at']?.toString() ?? ''),
    );
  }
}

class ChallengePermissions {
  const ChallengePermissions({
    this.hasJoined = false,
    this.isCreator = false,
    this.canJoin = false,
    this.canCancel = false,
    this.canRetrySettlement = false,
  });

  final bool hasJoined;
  final bool isCreator;
  final bool canJoin;
  final bool canCancel;
  final bool canRetrySettlement;

  factory ChallengePermissions.fromJson(Map<String, dynamic> json) {
    return ChallengePermissions(
      hasJoined: json['has_joined'] == true,
      isCreator: json['is_creator'] == true,
      canJoin: json['can_join'] == true,
      canCancel: json['can_cancel'] == true,
      canRetrySettlement: json['can_retry_settlement'] == true,
    );
  }
}

class ChallengeSettlementSummary {
  const ChallengeSettlementSummary({
    required this.challengeId,
    required this.matchId,
    required this.winnersCount,
    required this.losersCount,
    required this.totalPoolFet,
    required this.losersPoolFet,
    required this.payoutPerWinnerFet,
    required this.settlementMode,
    this.officialHomeScore,
    this.officialAwayScore,
    this.executedAt,
    this.metadata = const <String, dynamic>{},
  });

  final String challengeId;
  final String matchId;
  final int? officialHomeScore;
  final int? officialAwayScore;
  final int winnersCount;
  final int losersCount;
  final int totalPoolFet;
  final int losersPoolFet;
  final int payoutPerWinnerFet;
  final String settlementMode;
  final DateTime? executedAt;
  final Map<String, dynamic> metadata;

  factory ChallengeSettlementSummary.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'];
    return ChallengeSettlementSummary(
      challengeId: json['challenge_id']?.toString() ?? '',
      matchId: json['match_id']?.toString() ?? '',
      officialHomeScore: (json['official_home_score'] as num?)?.toInt(),
      officialAwayScore: (json['official_away_score'] as num?)?.toInt(),
      winnersCount: (json['winners_count'] as num?)?.toInt() ?? 0,
      losersCount: (json['losers_count'] as num?)?.toInt() ?? 0,
      totalPoolFet: (json['total_pool_fet'] as num?)?.toInt() ?? 0,
      losersPoolFet: (json['losers_pool_fet'] as num?)?.toInt() ?? 0,
      payoutPerWinnerFet: (json['payout_per_winner_fet'] as num?)?.toInt() ?? 0,
      settlementMode: json['settlement_mode']?.toString() ?? '',
      executedAt: DateTime.tryParse(json['executed_at']?.toString() ?? ''),
      metadata: rawMetadata is Map<String, dynamic>
          ? rawMetadata
          : rawMetadata is Map
          ? Map<String, dynamic>.from(rawMetadata)
          : const <String, dynamic>{},
    );
  }
}

class ChallengeEntry {
  const ChallengeEntry({
    required this.id,
    required this.challengeId,
    required this.userId,
    required this.predictedHomeScore,
    required this.predictedAwayScore,
    required this.stakeFet,
    required this.status,
    required this.payoutFet,
    this.joinedAt,
    this.settledAt,
    this.userName,
    this.userAvatar,
    this.user,
  });

  final String id;
  final String challengeId;
  final String userId;
  final int predictedHomeScore;
  final int predictedAwayScore;
  final int stakeFet;
  final ChallengeEntryStatus status;
  final int payoutFet;
  final DateTime? joinedAt;
  final DateTime? settledAt;
  final String? userName;
  final String? userAvatar;
  final ChallengeUser? user;

  bool get isWinner => status == ChallengeEntryStatus.winner;
  bool get isLoser => status == ChallengeEntryStatus.loser;
  bool get isRefunded => status == ChallengeEntryStatus.refunded;

  String get displayName => userName ?? user?.displayName ?? 'Supporter';

  factory ChallengeEntry.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    return ChallengeEntry(
      id: json['id']?.toString() ?? '',
      challengeId: json['challenge_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      predictedHomeScore: (json['predicted_home_score'] as num?)?.toInt() ?? 0,
      predictedAwayScore: (json['predicted_away_score'] as num?)?.toInt() ?? 0,
      stakeFet: (json['stake_fet'] as num?)?.toInt() ?? 0,
      status: _parseEntryStatus(json['status']?.toString()),
      payoutFet: (json['payout_fet'] as num?)?.toInt() ?? 0,
      joinedAt: DateTime.tryParse(json['joined_at']?.toString() ?? ''),
      settledAt: DateTime.tryParse(json['settled_at']?.toString() ?? ''),
      userName: json['user_name']?.toString(),
      userAvatar: json['user_avatar']?.toString(),
      user: rawUser is Map<String, dynamic>
          ? ChallengeUser.fromJson(rawUser)
          : rawUser is Map
          ? ChallengeUser.fromJson(Map<String, dynamic>.from(rawUser))
          : null,
    );
  }

  static ChallengeEntryStatus _parseEntryStatus(String? value) {
    return switch (value?.toLowerCase()) {
      'winner' => ChallengeEntryStatus.winner,
      'loser' => ChallengeEntryStatus.loser,
      'refunded' => ChallengeEntryStatus.refunded,
      'cancelled' => ChallengeEntryStatus.cancelled,
      _ => ChallengeEntryStatus.active,
    };
  }
}

class Challenge {
  const Challenge({
    required this.id,
    required this.matchId,
    required this.creatorUserId,
    required this.stakeFet,
    required this.status,
    required this.lockAt,
    required this.totalParticipants,
    required this.totalPoolFet,
    required this.clubId,
    this.currencyCode = 'FET',
    this.settledAt,
    this.cancelledAt,
    this.voidReason,
    this.winnerCount = 0,
    this.loserCount = 0,
    this.payoutPerWinnerFet = 0,
    this.officialHomeScore,
    this.officialAwayScore,
    this.createdAt,
    this.updatedAt,
    this.creatorName,
    this.creatorAvatar,
    this.fixture,
    this.creator,
    this.creatorPrediction,
    this.myEntry,
    this.permissions = const ChallengePermissions(),
    this.settlement,
    this.admin = const <String, dynamic>{},
  });

  final String id;
  final String matchId;
  final String creatorUserId;
  final int stakeFet;
  final ChallengeStatus status;
  final DateTime lockAt;
  final int totalParticipants;
  final int totalPoolFet;
  final int clubId;
  final String currencyCode;
  final DateTime? settledAt;
  final DateTime? cancelledAt;
  final String? voidReason;
  final int winnerCount;
  final int loserCount;
  final int payoutPerWinnerFet;
  final int? officialHomeScore;
  final int? officialAwayScore;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? creatorName;
  final String? creatorAvatar;
  final FixtureSummary? fixture;
  final ChallengeUser? creator;
  final ChallengeScorePrediction? creatorPrediction;
  final ChallengeEntry? myEntry;
  final ChallengePermissions permissions;
  final ChallengeSettlementSummary? settlement;
  final Map<String, dynamic> admin;

  bool get isOpen =>
      status == ChallengeStatus.open && lockAt.isAfter(DateTime.now());
  bool get isLocked =>
      status == ChallengeStatus.locked ||
      (status == ChallengeStatus.open && lockAt.isBefore(DateTime.now()));
  bool get isSettled => status == ChallengeStatus.settled;
  bool get isVoid => status == ChallengeStatus.void_;
  bool get isCancelled => status == ChallengeStatus.cancelled;

  String get creatorDisplayName =>
      creatorName ?? creator?.displayName ?? 'Supporter';
  String? get creatorAvatarUrl =>
      creatorAvatar?.isNotEmpty == true ? creatorAvatar : creator?.avatarUrl;
  bool get hasJoined => permissions.hasJoined || myEntry != null;
  bool get canJoin => permissions.canJoin;
  bool get canCancel => permissions.canCancel;
  bool get isCreator => permissions.isCreator;
  bool get canRetrySettlement => permissions.canRetrySettlement;
  Duration get timeUntilLock => lockAt.difference(DateTime.now());

  factory Challenge.fromJson(Map<String, dynamic> json) {
    final rawFixture = json['fixture'];
    final rawCreator = json['creator'];
    final rawCreatorPrediction = json['creator_prediction'];
    final rawMyEntry = json['my_entry'];
    final rawPermissions = json['permissions'];
    final rawSettlement = json['settlement'];
    final rawAdmin = json['admin'];

    return Challenge(
      id: json['id']?.toString() ?? '',
      clubId: (json['club_id'] as num?)?.toInt() ?? 0,
      matchId: json['match_id']?.toString() ?? '',
      creatorUserId: json['creator_user_id']?.toString() ?? '',
      stakeFet: (json['stake_fet'] as num?)?.toInt() ?? 0,
      currencyCode: json['currency_code']?.toString() ?? 'FET',
      status: _parseStatus(json['status']?.toString()),
      lockAt: DateTime.tryParse(json['lock_at']?.toString() ?? '') ??
          DateTime.now(),
      settledAt: DateTime.tryParse(json['settled_at']?.toString() ?? ''),
      cancelledAt: DateTime.tryParse(json['cancelled_at']?.toString() ?? ''),
      voidReason: json['void_reason']?.toString(),
      totalParticipants: (json['total_participants'] as num?)?.toInt() ?? 1,
      totalPoolFet: (json['total_pool_fet'] as num?)?.toInt() ?? 0,
      winnerCount: (json['winner_count'] as num?)?.toInt() ?? 0,
      loserCount: (json['loser_count'] as num?)?.toInt() ?? 0,
      payoutPerWinnerFet:
          (json['payout_per_winner_fet'] as num?)?.toInt() ?? 0,
      officialHomeScore: (json['official_home_score'] as num?)?.toInt(),
      officialAwayScore: (json['official_away_score'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      creatorName: json['creator_name']?.toString(),
      creatorAvatar: json['creator_avatar']?.toString(),
      fixture: rawFixture is Map<String, dynamic>
          ? FixtureSummary.fromJson(rawFixture)
          : rawFixture is Map
          ? FixtureSummary.fromJson(Map<String, dynamic>.from(rawFixture))
          : null,
      creator: rawCreator is Map<String, dynamic>
          ? ChallengeUser.fromJson(rawCreator)
          : rawCreator is Map
          ? ChallengeUser.fromJson(Map<String, dynamic>.from(rawCreator))
          : null,
      creatorPrediction: rawCreatorPrediction is Map<String, dynamic>
          ? ChallengeScorePrediction.fromJson(rawCreatorPrediction)
          : rawCreatorPrediction is Map
          ? ChallengeScorePrediction.fromJson(
              Map<String, dynamic>.from(rawCreatorPrediction),
            )
          : null,
      myEntry: rawMyEntry is Map<String, dynamic>
          ? ChallengeEntry.fromJson(rawMyEntry)
          : rawMyEntry is Map
          ? ChallengeEntry.fromJson(Map<String, dynamic>.from(rawMyEntry))
          : null,
      permissions: rawPermissions is Map<String, dynamic>
          ? ChallengePermissions.fromJson(rawPermissions)
          : rawPermissions is Map
          ? ChallengePermissions.fromJson(
              Map<String, dynamic>.from(rawPermissions),
            )
          : const ChallengePermissions(),
      settlement: rawSettlement is Map<String, dynamic>
          ? ChallengeSettlementSummary.fromJson(rawSettlement)
          : rawSettlement is Map
          ? ChallengeSettlementSummary.fromJson(
              Map<String, dynamic>.from(rawSettlement),
            )
          : null,
      admin: rawAdmin is Map<String, dynamic>
          ? rawAdmin
          : rawAdmin is Map
          ? Map<String, dynamic>.from(rawAdmin)
          : const <String, dynamic>{},
    );
  }

  static ChallengeStatus _parseStatus(String? value) {
    return switch (value?.toLowerCase()) {
      'locked' => ChallengeStatus.locked,
      'settled' => ChallengeStatus.settled,
      'void' => ChallengeStatus.void_,
      'cancelled' => ChallengeStatus.cancelled,
      _ => ChallengeStatus.open,
    };
  }
}

class ChallengeDetailPayload {
  const ChallengeDetailPayload({
    required this.challenge,
    required this.entries,
  });

  final Challenge challenge;
  final List<ChallengeEntry> entries;

  ChallengeEntry? get userEntry => challenge.myEntry;
  ChallengeSettlementSummary? get settlement => challenge.settlement;

  factory ChallengeDetailPayload.fromJson(Map<String, dynamic> json) {
    final rawChallenge = json['challenge'];
    final rawEntries = json['entries'];
    return ChallengeDetailPayload(
      challenge: rawChallenge is Map<String, dynamic>
          ? Challenge.fromJson(rawChallenge)
          : Challenge.fromJson(
              rawChallenge is Map
                  ? Map<String, dynamic>.from(rawChallenge)
                  : const <String, dynamic>{},
            ),
      entries: rawEntries is List
          ? rawEntries
                .whereType<Map>()
                .map((row) => ChallengeEntry.fromJson(
                      Map<String, dynamic>.from(row),
                    ))
                .toList(growable: false)
          : const <ChallengeEntry>[],
    );
  }
}

class ChallengeMutationResult {
  const ChallengeMutationResult({
    required this.status,
    this.challenge,
  });

  final String status;
  final Challenge? challenge;

  bool get isSuccess => switch (status) {
        'created' ||
        'joined' ||
        'cancelled' ||
        'already_joined' ||
        'already_processed' =>
          true,
        _ => false,
      };

  factory ChallengeMutationResult.fromJson(Map<String, dynamic> json) {
    final rawChallenge = json['challenge'];
    return ChallengeMutationResult(
      status: json['status']?.toString() ?? 'error',
      challenge: rawChallenge is Map<String, dynamic>
          ? Challenge.fromJson(rawChallenge)
          : rawChallenge is Map
          ? Challenge.fromJson(Map<String, dynamic>.from(rawChallenge))
          : null,
    );
  }
}
