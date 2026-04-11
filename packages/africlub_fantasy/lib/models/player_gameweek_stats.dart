import 'package:freezed_annotation/freezed_annotation.dart';

part 'player_gameweek_stats.freezed.dart';
part 'player_gameweek_stats.g.dart';

@freezed
class PlayerGameweekStats with _$PlayerGameweekStats {
  const factory PlayerGameweekStats({
    required String id,
    @JsonKey(name: 'player_id') required int playerId,
    @JsonKey(name: 'gameweek_id') required String gameweekId,
    @JsonKey(name: 'minutes_played') @Default(0) int minutesPlayed,
    @Default(0) int goals,
    @Default(0) int assists,
    @JsonKey(name: 'clean_sheet') @Default(false) bool cleanSheet,
    @JsonKey(name: 'goals_conceded') @Default(0) int goalsConceded,
    @JsonKey(name: 'yellow_cards') @Default(0) int yellowCards,
    @JsonKey(name: 'red_cards') @Default(0) int redCards,
    @JsonKey(name: 'penalties_saved') @Default(0) int penaltiesSaved,
    @JsonKey(name: 'penalties_missed') @Default(0) int penaltiesMissed,
    @JsonKey(name: 'own_goals') @Default(0) int ownGoals,
    @Default(0) int saves,
    @JsonKey(name: 'bps_score') @Default(0) int bpsScore,
    @JsonKey(name: 'bonus_points') @Default(0) int bonusPoints,
    @JsonKey(name: 'defensive_contributions')
    @Default(0)
    int defensiveContributions,
    @JsonKey(name: 'stage_advanced') @Default(false) bool stageAdvanced,
    @JsonKey(name: 'raw_points') @Default(0) int rawPoints,
    @JsonKey(name: 'last_synced_at') DateTime? lastSyncedAt,
  }) = _PlayerGameweekStats;

  factory PlayerGameweekStats.fromJson(Map<String, dynamic> json) =>
      _$PlayerGameweekStatsFromJson(json);
}
