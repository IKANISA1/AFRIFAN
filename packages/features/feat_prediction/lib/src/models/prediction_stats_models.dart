// Prediction stats and leaderboard models.

/// User's prediction statistics.
class PredictionStats {
  const PredictionStats({
    required this.totalPredictions,
    required this.totalWon,
    required this.totalLost,
    required this.totalPending,
    required this.totalFetEarned,
    required this.winRate,
    required this.currentStreak,
    this.streakType,
  });

  final int totalPredictions;
  final int totalWon;
  final int totalLost;
  final int totalPending;
  final int totalFetEarned;
  final double winRate;
  final int currentStreak;
  final String? streakType;

  bool get hasHistory => totalPredictions > 0;
  bool get isOnWinStreak => streakType == 'won' && currentStreak >= 2;
  bool get isOnLoseStreak => streakType == 'lost' && currentStreak >= 3;

  factory PredictionStats.empty() => const PredictionStats(
    totalPredictions: 0,
    totalWon: 0,
    totalLost: 0,
    totalPending: 0,
    totalFetEarned: 0,
    winRate: 0,
    currentStreak: 0,
  );

  factory PredictionStats.fromJson(Map<String, dynamic> json) {
    return PredictionStats(
      totalPredictions: (json['total_predictions'] as num?)?.toInt() ?? 0,
      totalWon: (json['total_won'] as num?)?.toInt() ?? 0,
      totalLost: (json['total_lost'] as num?)?.toInt() ?? 0,
      totalPending: (json['total_pending'] as num?)?.toInt() ?? 0,
      totalFetEarned: (json['total_fet_earned'] as num?)?.toInt() ?? 0,
      winRate: (json['win_rate'] as num?)?.toDouble() ?? 0,
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      streakType: json['streak_type']?.toString(),
    );
  }
}

/// Single row in the prediction leaderboard.
class PredictionLeaderboardRow {
  const PredictionLeaderboardRow({
    required this.userId,
    required this.displayName,
    required this.wins,
    required this.totalSettled,
    required this.totalFetEarned,
    required this.winRate,
  });

  final String userId;
  final String displayName;
  final int wins;
  final int totalSettled;
  final int totalFetEarned;
  final double winRate;

  factory PredictionLeaderboardRow.fromJson(Map<String, dynamic> json) {
    return PredictionLeaderboardRow(
      userId: json['user_id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? 'Supporter',
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      totalSettled: (json['total_settled'] as num?)?.toInt() ?? 0,
      totalFetEarned: (json['total_fet_earned'] as num?)?.toInt() ?? 0,
      winRate: (json['win_rate'] as num?)?.toDouble() ?? 0,
    );
  }
}
