enum PredictionStatus { pending, won, lost, cancelled, void_ }

enum MarketGroup {
  matchResult,
  goals,
  scorers,
  specials,
  outright,
  matchBetting,
  handicap,
  goalscorer,
  matchProps,
  corners,
  cards,
  playerProps,
  matchEvents,
  inPlay,
  combo,
}

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
    required this.marketCategory,
    required this.betType,
    required this.difficultyTier,
    required this.defaultFetValue,
    required this.baseFet,
    required this.description,
    required this.outcomeTemplate,
    required this.sortOrder,
    required this.leagueAvailability,
  });

  final String id;
  final String slug;
  final String name;
  final String shortName;
  final MarketGroup marketGroup;
  final String marketCategory;
  final String betType;
  final DifficultyTier difficultyTier;
  final int defaultFetValue;
  final int baseFet;
  final String description;
  final List<MarketOutcomeOption> outcomeTemplate;
  final int sortOrder;
  final List<String> leagueAvailability;

  factory PredictionMarket.fromJson(Map<String, dynamic> json) {
    return PredictionMarket(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      shortName: json['short_name']?.toString() ?? '',
      marketGroup: _parseMarketGroup(json['market_group']?.toString()),
      marketCategory: json['market_category']?.toString() ?? '',
      betType: json['bet_type']?.toString() ?? '',
      difficultyTier: _parseDifficulty(json['difficulty_tier']?.toString()),
      defaultFetValue: (json['default_fet_value'] as num?)?.toInt() ?? 100,
      baseFet: (json['base_fet'] as num?)?.toInt() ?? 0,
      description: json['description']?.toString() ?? '',
      outcomeTemplate: _parseOutcomeList(json['outcome_template']),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      leagueAvailability: _parseStringList(json['league_availability']),
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
    required this.marketCategory,
    required this.betType,
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
  final String marketCategory;
  final String betType;
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
      marketCategory: json['market_category']?.toString() ?? '',
      betType: json['bet_type']?.toString() ?? '',
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
  const MarketOutcomeOption({
    required this.key,
    required this.label,
    this.odds = 1.0,
  });

  final String key;
  final String label;
  final double odds;

  factory MarketOutcomeOption.fromJson(Map<String, dynamic> json) {
    return MarketOutcomeOption(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      odds: (json['odds'] as num?)?.toDouble() ?? 1.0,
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
    this.odds = 1.0,
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
  final double odds;
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
      odds: (json['odds'] as num?)?.toDouble() ?? 1.0,
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

  bool get isSuccess =>
      status == 'placed' ||
      status == 'updated' ||
      status == 'created' ||
      status == 'submitted';
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
    this.odds = 1.0,
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
  final double odds;
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
      odds: (json['odds'] as num?)?.toDouble() ?? 1.0,
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

class JackpotRoundFixture {
  const JackpotRoundFixture({
    required this.fixtureMarketId,
    required this.fixtureId,
    required this.competitionName,
    required this.competitionSlug,
    required this.homeTeamName,
    required this.homeTeamShortName,
    required this.awayTeamName,
    required this.awayTeamShortName,
    required this.status,
    required this.marketName,
    required this.marketShortName,
    required this.outcomes,
    this.kickoffAt,
  });

  final String fixtureMarketId;
  final String fixtureId;
  final String competitionName;
  final String competitionSlug;
  final String homeTeamName;
  final String homeTeamShortName;
  final String awayTeamName;
  final String awayTeamShortName;
  final DateTime? kickoffAt;
  final String status;
  final String marketName;
  final String marketShortName;
  final List<MarketOutcomeOption> outcomes;

  String get fixtureLabel =>
      '${homeTeamShortName.toUpperCase()} vs ${awayTeamShortName.toUpperCase()}';

  factory JackpotRoundFixture.fromJson(Map<String, dynamic> json) {
    return JackpotRoundFixture(
      fixtureMarketId: json['fixture_market_id']?.toString() ?? '',
      fixtureId: json['fixture_id']?.toString() ?? '',
      competitionName: json['competition_name']?.toString() ?? '',
      competitionSlug: json['competition_slug']?.toString() ?? '',
      homeTeamName: json['home_team_name']?.toString() ?? '',
      homeTeamShortName: json['home_team_short_name']?.toString() ?? '',
      awayTeamName: json['away_team_name']?.toString() ?? '',
      awayTeamShortName: json['away_team_short_name']?.toString() ?? '',
      kickoffAt: DateTime.tryParse(json['kickoff_at']?.toString() ?? ''),
      status: json['status']?.toString() ?? 'scheduled',
      marketName: json['market_name']?.toString() ?? '',
      marketShortName: json['market_short_name']?.toString() ?? '',
      outcomes: _parseOutcomeList(json['outcomes']),
    );
  }
}

class PredictionJackpotRound {
  const PredictionJackpotRound({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.status,
    required this.prizePoolFet,
    required this.maxLegs,
    required this.maxEntriesPerUser,
    required this.userEntryCount,
    required this.bonusEntryCount,
    required this.remainingEntries,
    required this.canEnter,
    required this.fixtures,
    this.clubId,
    this.opensAt,
    this.entryDeadlineAt,
    this.kickoffWindowStartAt,
    this.kickoffWindowEndAt,
  });

  final String id;
  final int? clubId;
  final String slug;
  final String title;
  final String description;
  final String status;
  final DateTime? opensAt;
  final DateTime? entryDeadlineAt;
  final DateTime? kickoffWindowStartAt;
  final DateTime? kickoffWindowEndAt;
  final int prizePoolFet;
  final int maxLegs;
  final int maxEntriesPerUser;
  final int userEntryCount;
  final int bonusEntryCount;
  final int remainingEntries;
  final bool canEnter;
  final List<JackpotRoundFixture> fixtures;

  factory PredictionJackpotRound.fromJson(Map<String, dynamic> json) {
    final rawFixtures = json['fixtures'];
    return PredictionJackpotRound(
      id: json['id']?.toString() ?? '',
      clubId: int.tryParse(json['club_id']?.toString() ?? ''),
      slug: json['slug']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'draft',
      opensAt: DateTime.tryParse(json['opens_at']?.toString() ?? ''),
      entryDeadlineAt: DateTime.tryParse(
        json['entry_deadline_at']?.toString() ?? '',
      ),
      kickoffWindowStartAt: DateTime.tryParse(
        json['kickoff_window_start_at']?.toString() ?? '',
      ),
      kickoffWindowEndAt: DateTime.tryParse(
        json['kickoff_window_end_at']?.toString() ?? '',
      ),
      prizePoolFet: (json['prize_pool_fet'] as num?)?.toInt() ?? 0,
      maxLegs: (json['max_legs'] as num?)?.toInt() ?? 0,
      maxEntriesPerUser: (json['max_entries_per_user'] as num?)?.toInt() ?? 1,
      userEntryCount: (json['user_entry_count'] as num?)?.toInt() ?? 0,
      bonusEntryCount: (json['bonus_entry_count'] as num?)?.toInt() ?? 0,
      remainingEntries: (json['remaining_entries'] as num?)?.toInt() ?? 0,
      canEnter: json['can_enter'] == true,
      fixtures: rawFixtures is List
          ? rawFixtures
                .whereType<Map>()
                .map(
                  (row) => JackpotRoundFixture.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList(growable: false)
          : const <JackpotRoundFixture>[],
    );
  }
}

class FriendChallengeSummary {
  const FriendChallengeSummary({
    required this.id,
    required this.status,
    required this.fixtureId,
    required this.fixtureMarketId,
    required this.competitionName,
    required this.homeTeamName,
    required this.awayTeamName,
    required this.marketName,
    required this.marketShortName,
    required this.challengerUserId,
    required this.challengerDisplayName,
    required this.challengerOutcome,
    required this.opponentUserId,
    required this.opponentDisplayName,
    required this.isChallenger,
    this.kickoffAt,
    this.opponentOutcome,
    this.winnerUserId,
    this.challengeNote,
  });

  final String id;
  final String status;
  final String fixtureId;
  final String fixtureMarketId;
  final String competitionName;
  final String homeTeamName;
  final String awayTeamName;
  final DateTime? kickoffAt;
  final String marketName;
  final String marketShortName;
  final String challengerUserId;
  final String challengerDisplayName;
  final String challengerOutcome;
  final String opponentUserId;
  final String opponentDisplayName;
  final String? opponentOutcome;
  final String? winnerUserId;
  final String? challengeNote;
  final bool isChallenger;

  factory FriendChallengeSummary.fromJson(Map<String, dynamic> json) {
    return FriendChallengeSummary(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      fixtureId: json['fixture_id']?.toString() ?? '',
      fixtureMarketId: json['fixture_market_id']?.toString() ?? '',
      competitionName: json['competition_name']?.toString() ?? '',
      homeTeamName: json['home_team_name']?.toString() ?? '',
      awayTeamName: json['away_team_name']?.toString() ?? '',
      kickoffAt: DateTime.tryParse(json['kickoff_at']?.toString() ?? ''),
      marketName: json['market_name']?.toString() ?? '',
      marketShortName: json['market_short_name']?.toString() ?? '',
      challengerUserId: json['challenger_user_id']?.toString() ?? '',
      challengerDisplayName:
          json['challenger_display_name']?.toString() ?? 'Supporter',
      challengerOutcome: json['challenger_outcome']?.toString() ?? '',
      opponentUserId: json['opponent_user_id']?.toString() ?? '',
      opponentDisplayName:
          json['opponent_display_name']?.toString() ?? 'Supporter',
      opponentOutcome: json['opponent_outcome']?.toString(),
      winnerUserId: json['winner_user_id']?.toString(),
      challengeNote: json['challenge_note']?.toString(),
      isChallenger: json['is_challenger'] == true,
    );
  }
}

class MatchCenterStat {
  const MatchCenterStat({
    required this.label,
    required this.leftValue,
    required this.rightValue,
    required this.leftDisplay,
    required this.rightDisplay,
  });

  final String label;
  final double leftValue;
  final double rightValue;
  final String leftDisplay;
  final String rightDisplay;

  factory MatchCenterStat.fromJson(Map<String, dynamic> json) {
    return MatchCenterStat(
      label: json['label']?.toString() ?? '',
      leftValue: (json['left_value'] as num?)?.toDouble() ?? 0,
      rightValue: (json['right_value'] as num?)?.toDouble() ?? 0,
      leftDisplay: json['left_display']?.toString() ?? '',
      rightDisplay: json['right_display']?.toString() ?? '',
    );
  }
}

class MatchCenterEncounter {
  const MatchCenterEncounter({
    required this.homeTeam,
    required this.awayTeam,
    required this.homeScore,
    required this.awayScore,
    this.date,
    this.competition,
  });

  final String homeTeam;
  final String awayTeam;
  final int homeScore;
  final int awayScore;
  final String? date;
  final String? competition;

  factory MatchCenterEncounter.fromJson(Map<String, dynamic> json) {
    return MatchCenterEncounter(
      homeTeam: json['home_team']?.toString() ?? '',
      awayTeam: json['away_team']?.toString() ?? '',
      homeScore: (json['home_score'] as num?)?.toInt() ?? 0,
      awayScore: (json['away_score'] as num?)?.toInt() ?? 0,
      date: json['date']?.toString(),
      competition: json['competition']?.toString(),
    );
  }
}

class MatchCenterLineupPlayer {
  const MatchCenterLineupPlayer({
    required this.name,
    this.number,
    this.position,
    this.isStarter = true,
    this.role = 'starter',
  });

  final String name;
  final int? number;
  final String? position;
  final bool isStarter;
  final String role;

  factory MatchCenterLineupPlayer.fromJson(Map<String, dynamic> json) {
    return MatchCenterLineupPlayer(
      name: json['name']?.toString() ?? 'Unknown',
      number: (json['number'] as num?)?.toInt(),
      position: json['position']?.toString(),
      isStarter: json['is_starter'] != false,
      role: json['role']?.toString() ?? 'starter',
    );
  }
}

class MatchCenterLineup {
  const MatchCenterLineup({
    required this.isConfirmed,
    required this.source,
    required this.starters,
    required this.substitutes,
    this.formation,
    this.coachName,
  });

  final String? formation;
  final String? coachName;
  final bool isConfirmed;
  final String source;
  final List<MatchCenterLineupPlayer> starters;
  final List<MatchCenterLineupPlayer> substitutes;

  factory MatchCenterLineup.fromJson(Map<String, dynamic> json) {
    List<MatchCenterLineupPlayer> parsePlayers(Object? raw) {
      if (raw is! List) {
        return const <MatchCenterLineupPlayer>[];
      }
      return raw
          .whereType<Map>()
          .map(
            (row) => MatchCenterLineupPlayer.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(growable: false);
    }

    return MatchCenterLineup(
      formation: json['formation']?.toString(),
      coachName: json['coach_name']?.toString(),
      isConfirmed: json['is_confirmed'] == true,
      source: json['source']?.toString() ?? 'manual',
      starters: parsePlayers(json['starters']),
      substitutes: parsePlayers(json['substitutes']),
    );
  }
}

class PredictionMatchCenter {
  const PredictionMatchCenter({
    required this.fixtureId,
    required this.stats,
    required this.h2h,
    required this.events,
    required this.homeLineup,
    required this.awayLineup,
  });

  final String fixtureId;
  final List<MatchCenterStat> stats;
  final List<MatchCenterEncounter> h2h;
  final List<Map<String, dynamic>> events;
  final MatchCenterLineup homeLineup;
  final MatchCenterLineup awayLineup;

  factory PredictionMatchCenter.fromJson(Map<String, dynamic> json) {
    final lineups = json['lineups'];
    final lineupsMap = lineups is Map ? Map<String, dynamic>.from(lineups) : {};

    List<T> parseList<T>(
      Object? raw,
      T Function(Map<String, dynamic>) decoder,
    ) {
      if (raw is! List) {
        return <T>[];
      }
      return raw
          .whereType<Map>()
          .map((row) => decoder(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    }

    return PredictionMatchCenter(
      fixtureId: json['fixture_id']?.toString() ?? '',
      stats: parseList(json['stats'], MatchCenterStat.fromJson),
      h2h: parseList(json['h2h'], MatchCenterEncounter.fromJson),
      events: parseList(
        json['events'],
        (row) => Map<String, dynamic>.from(row),
      ),
      homeLineup: MatchCenterLineup.fromJson(
        lineupsMap['home'] is Map<String, dynamic>
            ? lineupsMap['home'] as Map<String, dynamic>
            : lineupsMap['home'] is Map
            ? Map<String, dynamic>.from(lineupsMap['home'] as Map)
            : const <String, dynamic>{},
      ),
      awayLineup: MatchCenterLineup.fromJson(
        lineupsMap['away'] is Map<String, dynamic>
            ? lineupsMap['away'] as Map<String, dynamic>
            : lineupsMap['away'] is Map
            ? Map<String, dynamic>.from(lineupsMap['away'] as Map)
            : const <String, dynamic>{},
      ),
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
    this.homeTeamLogoUrl,
    this.awayTeamLogoUrl,
    this.competitionLogoUrl,
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

  /// API-Football CDN logo URLs (hotlinked)
  final String? homeTeamLogoUrl;
  final String? awayTeamLogoUrl;
  final String? competitionLogoUrl;

  bool get isScheduled => status == 'scheduled';
  bool get isLive => status == 'live';
  bool get isFinished => status == 'finished';
  bool get isPredictable => isScheduled;

  String get fixtureLabel =>
      '${homeTeamShort.toUpperCase()} vs ${awayTeamShort.toUpperCase()}';

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
      homeTeamLogoUrl: json['home_team_logo_url']?.toString(),
      awayTeamLogoUrl: json['away_team_logo_url']?.toString(),
      competitionLogoUrl: json['competition_logo_url']?.toString(),
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
    'outright' => MarketGroup.outright,
    'match_betting' => MarketGroup.matchBetting,
    'handicap' => MarketGroup.handicap,
    'goalscorer' => MarketGroup.goalscorer,
    'match_props' => MarketGroup.matchProps,
    'corners' => MarketGroup.corners,
    'cards' => MarketGroup.cards,
    'player_props' => MarketGroup.playerProps,
    'match_events' => MarketGroup.matchEvents,
    'in_play' => MarketGroup.inPlay,
    'combo' => MarketGroup.combo,
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

List<String> _parseStringList(Object? raw) {
  if (raw is List) {
    return raw.map((e) => e?.toString() ?? '').toList(growable: false);
  }
  return const <String>[];
}
