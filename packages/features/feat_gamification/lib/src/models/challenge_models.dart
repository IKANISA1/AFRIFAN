import 'prediction_models.dart';

enum ChallengeStatus { open, locked, settled, void_, cancelled }

enum ChallengeEntryStatus { active, winner, loser, refunded, cancelled }

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
  });

  final String id;
  final String matchId;
  final String creatorUserId;
  final int stakeFet;
  final ChallengeStatus status;
  final DateTime lockAt;
  final DateTime? settledAt;
  final DateTime? cancelledAt;
  final String? voidReason;
  final int totalParticipants;
  final int totalPoolFet;
  final int winnerCount;
  final int loserCount;
  final int payoutPerWinnerFet;
  final int? officialHomeScore;
  final int? officialAwayScore;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined fields for UI convenience
  final String? creatorName;
  final String? creatorAvatar;
  final FixtureSummary? fixture;

  bool get isOpen => status == ChallengeStatus.open && lockAt.isAfter(DateTime.now());
  bool get isLocked => status == ChallengeStatus.locked || (status == ChallengeStatus.open && lockAt.isBefore(DateTime.now()));
  bool get isSettled => status == ChallengeStatus.settled;
  bool get isVoid => status == ChallengeStatus.void_;

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id']?.toString() ?? '',
      matchId: json['match_id']?.toString() ?? '',
      creatorUserId: json['creator_user_id']?.toString() ?? '',
      stakeFet: (json['stake_fet'] as num?)?.toInt() ?? 0,
      status: _parseStatus(json['status']?.toString()),
      lockAt: DateTime.tryParse(json['lock_at']?.toString() ?? '') ?? DateTime.now(),
      settledAt: DateTime.tryParse(json['settled_at']?.toString() ?? ''),
      cancelledAt: DateTime.tryParse(json['cancelled_at']?.toString() ?? ''),
      voidReason: json['void_reason']?.toString(),
      totalParticipants: (json['total_participants'] as num?)?.toInt() ?? 1,
      totalPoolFet: (json['total_pool_fet'] as num?)?.toInt() ?? 0,
      winnerCount: (json['winner_count'] as num?)?.toInt() ?? 0,
      loserCount: (json['loser_count'] as num?)?.toInt() ?? 0,
      payoutPerWinnerFet: (json['payout_per_winner_fet'] as num?)?.toInt() ?? 0,
      officialHomeScore: (json['official_home_score'] as num?)?.toInt(),
      officialAwayScore: (json['official_away_score'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      creatorName: json['creator_name']?.toString(),
      creatorAvatar: json['creator_avatar']?.toString(),
      fixture: json['fixture'] != null ? FixtureSummary.fromJson(Map<String, dynamic>.from(json['fixture'] as Map)) : null,
    );
  }

  static ChallengeStatus _parseStatus(String? value) {
    return switch (value?.toLowerCase()) {
      'open' => ChallengeStatus.open,
      'locked' => ChallengeStatus.locked,
      'settled' => ChallengeStatus.settled,
      'void' => ChallengeStatus.void_,
      'cancelled' => ChallengeStatus.cancelled,
      _ => ChallengeStatus.open,
    };
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

  bool get isWinner => status == ChallengeEntryStatus.winner;
  bool get isLoser => status == ChallengeEntryStatus.loser;
  bool get isRefunded => status == ChallengeEntryStatus.refunded;

  factory ChallengeEntry.fromJson(Map<String, dynamic> json) {
    return ChallengeEntry(
      id: json['id']?.toString() ?? '',
      challengeId: json['challenge_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      predictedHomeScore: (json['predicted_home_score'] as num?)?.toInt() ?? 0,
      predictedAwayScore: (json['predicted_away_score'] as num?)?.toInt() ?? 0,
      stakeFet: (json['stake_fet'] as num?)?.toInt() ?? 0,
      status: _parseStatus(json['status']?.toString()),
      payoutFet: (json['payout_fet'] as num?)?.toInt() ?? 0,
      joinedAt: DateTime.tryParse(json['joined_at']?.toString() ?? ''),
      settledAt: DateTime.tryParse(json['settled_at']?.toString() ?? ''),
      userName: json['user_name']?.toString(),
      userAvatar: json['user_avatar']?.toString(),
    );
  }

  static ChallengeEntryStatus _parseStatus(String? value) {
    return switch (value?.toLowerCase()) {
      'active' => ChallengeEntryStatus.active,
      'winner' => ChallengeEntryStatus.winner,
      'loser' => ChallengeEntryStatus.loser,
      'refunded' => ChallengeEntryStatus.refunded,
      'cancelled' => ChallengeEntryStatus.cancelled,
      _ => ChallengeEntryStatus.active,
    };
  }
}
