enum PredictionStatus { pending, won, lost, cancelled, void_ }

enum MarketGroup { matchResult, goals, scorers, specials }

enum DifficultyTier { entry, mid, hard, advanced }

class PredictionDashboard {
  const PredictionDashboard({
    required this.totalPredictions,
    required this.settledCount,
    required this.wonCount,
    required this.lostCount,
    required this.activeCount,
    required this.totalFetEarned,
    required this.currentStreak,
    required this.winRate,
    this.streakType,
  });

  final int totalPredictions;
  final int settledCount;
  final int wonCount;
  final int lostCount;
  final int activeCount;
  final int totalFetEarned;
  final int currentStreak;
  final double winRate;
  final String? streakType;

  factory PredictionDashboard.fromJson(Map<String, dynamic> json) {
    final wonCount = (json['total_won'] as num?)?.toInt() ?? 0;
    final lostCount = (json['total_lost'] as num?)?.toInt() ?? 0;
    return PredictionDashboard(
      totalPredictions: (json['total_predictions'] as num?)?.toInt() ?? 0,
      settledCount: wonCount + lostCount,
      wonCount: wonCount,
      lostCount: lostCount,
      activeCount: (json['total_pending'] as num?)?.toInt() ?? 0,
      totalFetEarned: (json['total_fet_earned'] as num?)?.toInt() ?? 0,
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      winRate: (json['win_rate'] as num?)?.toDouble() ?? 0,
      streakType: json['streak_type']?.toString(),
    );
  }

  /// Returns an empty dashboard for error/loading fallback.
  factory PredictionDashboard.empty() => const PredictionDashboard(
    totalPredictions: 0,
    settledCount: 0,
    wonCount: 0,
    lostCount: 0,
    activeCount: 0,
    totalFetEarned: 0,
    currentStreak: 0,
    winRate: 0,
  );
}

class PredictionLeaderboardEntry {
  const PredictionLeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.wins,
    required this.totalSettled,
    required this.totalFetEarned,
    required this.winRate,
    this.trend,
  });

  final int rank;
  final String userId;
  final String displayName;
  final int wins;
  final int totalSettled;
  final int totalFetEarned;
  final double winRate;

  /// Trend indicator: 'up', 'down', or 'same'. Null if unavailable.
  final String? trend;

  factory PredictionLeaderboardEntry.fromJson(
    Map<String, dynamic> json, {
    required int rank,
  }) {
    return PredictionLeaderboardEntry(
      rank: rank,
      userId: json['user_id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? 'Supporter',
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      totalSettled: (json['total_settled'] as num?)?.toInt() ?? 0,
      totalFetEarned: (json['total_fet_earned'] as num?)?.toInt() ?? 0,
      winRate: (json['win_rate'] as num?)?.toDouble() ?? 0,
      trend: json['trend']?.toString(),
    );
  }
}

class PredictionMarket {
  const PredictionMarket({
    required this.id,
    required this.slug,
    required this.name,
    required this.shortName,
    required this.marketGroup,
    required this.difficultyTier,
    required this.defaultFetValue,
    required this.description,
    required this.outcomeTemplate,
    required this.sortOrder,
  });

  final String id;
  final String slug;
  final String name;
  final String shortName;
  final MarketGroup marketGroup;
  final DifficultyTier difficultyTier;
  final int defaultFetValue;
  final String description;
  final List<MarketOutcomeOption> outcomeTemplate;
  final int sortOrder;

  factory PredictionMarket.fromJson(Map<String, dynamic> json) {
    return PredictionMarket(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      shortName: json['short_name']?.toString() ?? '',
      marketGroup: _parseMarketGroup(json['market_group']?.toString()),
      difficultyTier: _parseDifficulty(json['difficulty_tier']?.toString()),
      defaultFetValue: (json['default_fet_value'] as num?)?.toInt() ?? 100,
      description: json['description']?.toString() ?? '',
      outcomeTemplate: _parseOutcomeList(json['outcome_template']),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class FixtureMarket {
  const FixtureMarket({
    required this.fixtureMarketId,
    required this.marketId,
    required this.marketSlug,
    required this.marketName,
    required this.marketShortName,
    required this.marketGroup,
    required this.difficultyTier,
    required this.description,
    required this.fetValue,
    required this.outcomes,
    required this.isLocked,
    this.userPrediction,
  });

  final String fixtureMarketId;
  final String marketId;
  final String marketSlug;
  final String marketName;
  final String marketShortName;
  final MarketGroup marketGroup;
  final DifficultyTier difficultyTier;
  final String description;
  final int fetValue;
  final List<MarketOutcomeOption> outcomes;
  final bool isLocked;
  final UserPredictionSummary? userPrediction;

  factory FixtureMarket.fromJson(Map<String, dynamic> json) {
    final userPred = json['user_prediction'];
    return FixtureMarket(
      fixtureMarketId: json['fixture_market_id']?.toString() ?? '',
      marketId: json['market_id']?.toString() ?? '',
      marketSlug: json['market_slug']?.toString() ?? '',
      marketName: json['market_name']?.toString() ?? '',
      marketShortName: json['market_short_name']?.toString() ?? '',
      marketGroup: _parseMarketGroup(json['market_group']?.toString()),
      difficultyTier: _parseDifficulty(json['difficulty_tier']?.toString()),
      description: json['description']?.toString() ?? '',
      fetValue: (json['fet_value'] as num?)?.toInt() ?? 100,
      outcomes: _parseOutcomeList(json['outcomes']),
      isLocked: json['is_locked'] == true,
      userPrediction: userPred is Map<String, dynamic>
          ? UserPredictionSummary.fromJson(userPred)
          : null,
    );
  }
}

class UserPredictionSummary {
  const UserPredictionSummary({
    required this.predictionId,
    required this.selectedOutcome,
    required this.status,
  });

  final String predictionId;
  final String selectedOutcome;
  final PredictionStatus status;

  factory UserPredictionSummary.fromJson(Map<String, dynamic> json) {
    return UserPredictionSummary(
      predictionId: json['prediction_id']?.toString() ?? '',
      selectedOutcome: json['selected_outcome']?.toString() ?? '',
      status: _parseStatus(json['status']?.toString()),
    );
  }
}

class MarketOutcomeOption {
  const MarketOutcomeOption({required this.key, required this.label});

  final String key;
  final String label;

  factory MarketOutcomeOption.fromJson(Map<String, dynamic> json) {
    return MarketOutcomeOption(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }
}

class UserPrediction {
  const UserPrediction({
    required this.id,
    required this.fixtureId,
    required this.marketSlug,
    required this.marketName,
    required this.marketGroup,
    required this.homeTeam,
    required this.homeTeamShort,
    required this.awayTeam,
    required this.awayTeamShort,
    required this.kickoffAt,
    required this.fixtureStatus,
    required this.competitionName,
    required this.selectedOutcome,
    required this.status,
    required this.fetPotential,
    required this.fetEarned,
    required this.placedAt,
    this.settledAt,
    this.homeScore,
    this.awayScore,
    this.slipId,
  });

  final String id;
  final String fixtureId;
  final String marketSlug;
  final String marketName;
  final MarketGroup marketGroup;
  final String homeTeam;
  final String homeTeamShort;
  final String awayTeam;
  final String awayTeamShort;
  final DateTime? kickoffAt;
  final String fixtureStatus;
  final String competitionName;
  final String selectedOutcome;
  final PredictionStatus status;
  final int fetPotential;
  final int fetEarned;
  final DateTime? placedAt;
  final DateTime? settledAt;
  final int? homeScore;
  final int? awayScore;
  final String? slipId;

  factory UserPrediction.fromJson(Map<String, dynamic> json) {
    return UserPrediction(
      id: json['id']?.toString() ?? '',
      fixtureId: json['fixture_id']?.toString() ?? '',
      marketSlug: json['market_slug']?.toString() ?? '',
      marketName: json['market_name']?.toString() ?? '',
      marketGroup: _parseMarketGroup(json['market_group']?.toString()),
      homeTeam: json['home_team']?.toString() ?? '',
      homeTeamShort: json['home_team_short']?.toString() ?? '',
      awayTeam: json['away_team']?.toString() ?? '',
      awayTeamShort: json['away_team_short']?.toString() ?? '',
      kickoffAt: DateTime.tryParse(json['kickoff_at']?.toString() ?? ''),
      fixtureStatus: json['fixture_status']?.toString() ?? 'scheduled',
      competitionName: json['competition_name']?.toString() ?? '',
      selectedOutcome: json['selected_outcome']?.toString() ?? '',
      status: _parseStatus(json['status']?.toString()),
      fetPotential: (json['fet_potential'] as num?)?.toInt() ?? 0,
      fetEarned: (json['fet_earned'] as num?)?.toInt() ?? 0,
      placedAt: DateTime.tryParse(json['placed_at']?.toString() ?? ''),
      settledAt: DateTime.tryParse(json['settled_at']?.toString() ?? ''),
      homeScore: (json['home_score'] as num?)?.toInt(),
      awayScore: (json['away_score'] as num?)?.toInt(),
      slipId: json['slip_id']?.toString(),
    );
  }

  bool get isPending => status == PredictionStatus.pending;
  bool get isWon => status == PredictionStatus.won;
  bool get isLost => status == PredictionStatus.lost;
  bool get isSettled => isWon || isLost;
}

class PredictionPlaceResult {
  const PredictionPlaceResult({
    required this.status,
    this.predictionId = '',
    this.selectedOutcome = '',
    this.fetPotential = 0,
    required this.message,
    this.slipId,
  });

  final String status;
  final String predictionId;
  final String selectedOutcome;
  final int fetPotential;
  final String message;
  final String? slipId;

  bool get isSuccess => status == 'placed' || status == 'updated';
  bool get isError => status == 'error';

  factory PredictionPlaceResult.fromJson(Map<String, dynamic> json) {
    return PredictionPlaceResult(
      status: json['status']?.toString() ?? 'error',
      predictionId: json['prediction_id']?.toString() ?? '',
      selectedOutcome: json['selected_outcome']?.toString() ?? '',
      fetPotential: (json['fet_potential'] as num?)?.toInt() ?? 0,
      message: json['message']?.toString() ?? '',
      slipId: json['slip_id']?.toString(),
    );
  }
}

class PredictionDetail {
  const PredictionDetail({
    required this.id,
    required this.fixtureId,
    required this.marketSlug,
    required this.marketName,
    required this.marketShortName,
    required this.marketGroup,
    required this.difficultyTier,
    required this.competitionName,
    required this.homeTeam,
    required this.homeTeamShort,
    required this.awayTeam,
    required this.awayTeamShort,
    required this.selectedOutcome,
    required this.status,
    required this.fetPotential,
    required this.fetEarned,
    this.slipId,
    this.venueName,
    this.kickoffAt,
    this.fixtureStatus = 'scheduled',
    this.homeScore,
    this.awayScore,
    this.correctOutcome,
    this.placedAt,
    this.settledAt,
  });

  final String id;
  final String fixtureId;
  final String marketSlug;
  final String marketName;
  final String marketShortName;
  final MarketGroup marketGroup;
  final DifficultyTier difficultyTier;
  final String competitionName;
  final String homeTeam;
  final String homeTeamShort;
  final String awayTeam;
  final String awayTeamShort;
  final String selectedOutcome;
  final PredictionStatus status;
  final int fetPotential;
  final int fetEarned;
  final String? slipId;
  final String? venueName;
  final DateTime? kickoffAt;
  final String fixtureStatus;
  final int? homeScore;
  final int? awayScore;
  final String? correctOutcome;
  final DateTime? placedAt;
  final DateTime? settledAt;

  bool get isPending => status == PredictionStatus.pending;
  bool get isWon => status == PredictionStatus.won;
  bool get isLost => status == PredictionStatus.lost;
  bool get isSettled => isWon || isLost || status == PredictionStatus.void_;
  bool get hasScoreline => homeScore != null && awayScore != null;

  factory PredictionDetail.fromJson(Map<String, dynamic> json) {
    return PredictionDetail(
      id: json['id']?.toString() ?? '',
      fixtureId: json['fixture_id']?.toString() ?? '',
      marketSlug: json['market_slug']?.toString() ?? '',
      marketName: json['market_name']?.toString() ?? '',
      marketShortName: json['market_short_name']?.toString() ?? '',
      marketGroup: _parseMarketGroup(json['market_group']?.toString()),
      difficultyTier: _parseDifficulty(json['difficulty_tier']?.toString()),
      competitionName: json['competition_name']?.toString() ?? '',
      homeTeam: json['home_team']?.toString() ?? '',
      homeTeamShort: json['home_team_short']?.toString() ?? '',
      awayTeam: json['away_team']?.toString() ?? '',
      awayTeamShort: json['away_team_short']?.toString() ?? '',
      selectedOutcome: json['selected_outcome']?.toString() ?? '',
      status: _parseStatus(json['status']?.toString()),
      fetPotential: (json['fet_potential'] as num?)?.toInt() ?? 0,
      fetEarned: (json['fet_earned'] as num?)?.toInt() ?? 0,
      slipId: json['slip_id']?.toString(),
      venueName: json['venue_name']?.toString(),
      kickoffAt: DateTime.tryParse(json['kickoff_at']?.toString() ?? ''),
      fixtureStatus: json['fixture_status']?.toString() ?? 'scheduled',
      homeScore: (json['home_score'] as num?)?.toInt(),
      awayScore: (json['away_score'] as num?)?.toInt(),
      correctOutcome: json['correct_outcome']?.toString(),
      placedAt: DateTime.tryParse(json['placed_at']?.toString() ?? ''),
      settledAt: DateTime.tryParse(json['settled_at']?.toString() ?? ''),
    );
  }
}

class FixtureSummary {
  const FixtureSummary({
    required this.id,
    required this.competitionSlug,
    required this.competitionName,
    required this.seasonLabel,
    required this.matchday,
    this.homeTeamSlug = '',
    required this.homeTeamName,
    required this.homeTeamShort,
    this.awayTeamSlug = '',
    required this.awayTeamName,
    required this.awayTeamShort,
    required this.kickoffAt,
    required this.venueName,
    required this.status,
    this.homeScore,
    this.awayScore,
  });

  final String id;
  final String competitionSlug;
  final String competitionName;
  final String seasonLabel;
  final int? matchday;
  final String homeTeamSlug;
  final String homeTeamName;
  final String homeTeamShort;
  final String awayTeamSlug;
  final String awayTeamName;
  final String awayTeamShort;
  final DateTime? kickoffAt;
  final String? venueName;
  final String status;
  final int? homeScore;
  final int? awayScore;

  bool get isScheduled => status == 'scheduled';
  bool get isLive => status == 'live';
  bool get isFinished => status == 'finished';
  bool get isPredictable => isScheduled;

  String get fixtureLabel =>
      '${homeTeamName.toUpperCase()} vs ${awayTeamName.toUpperCase()}';

  factory FixtureSummary.fromJson(Map<String, dynamic> json) {
    return FixtureSummary(
      id: json['id']?.toString() ?? '',
      competitionSlug: json['competition_slug']?.toString() ?? '',
      competitionName: json['competition_name']?.toString() ?? '',
      seasonLabel: json['season_label']?.toString() ?? '',
      matchday: (json['matchday'] as num?)?.toInt(),
      homeTeamSlug: json['home_team_slug']?.toString() ?? '',
      homeTeamName: json['home_team_name']?.toString() ?? '',
      homeTeamShort: json['home_team_short_name']?.toString() ?? '',
      awayTeamSlug: json['away_team_slug']?.toString() ?? '',
      awayTeamName: json['away_team_name']?.toString() ?? '',
      awayTeamShort: json['away_team_short_name']?.toString() ?? '',
      kickoffAt: DateTime.tryParse(json['kickoff_at']?.toString() ?? ''),
      venueName: json['venue_name']?.toString(),
      status: json['status']?.toString() ?? 'scheduled',
      homeScore: (json['home_score'] as num?)?.toInt(),
      awayScore: (json['away_score'] as num?)?.toInt(),
    );
  }
}

PredictionStatus _parseStatus(String? value) {
  return switch (value?.toLowerCase()) {
    'won' => PredictionStatus.won,
    'lost' => PredictionStatus.lost,
    'cancelled' => PredictionStatus.cancelled,
    'void' => PredictionStatus.void_,
    _ => PredictionStatus.pending,
  };
}

MarketGroup _parseMarketGroup(String? value) {
  return switch (value?.toLowerCase()) {
    'goals' => MarketGroup.goals,
    'scorers' => MarketGroup.scorers,
    'specials' => MarketGroup.specials,
    _ => MarketGroup.matchResult,
  };
}

DifficultyTier _parseDifficulty(String? value) {
  return switch (value?.toLowerCase()) {
    'mid' => DifficultyTier.mid,
    'hard' => DifficultyTier.hard,
    'advanced' => DifficultyTier.advanced,
    _ => DifficultyTier.entry,
  };
}

List<MarketOutcomeOption> _parseOutcomeList(Object? raw) {
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map(
          (row) => MarketOutcomeOption.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }
  return const <MarketOutcomeOption>[];
}
