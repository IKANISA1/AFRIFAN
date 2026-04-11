import 'package:freezed_annotation/freezed_annotation.dart';

part 'entry_gameweek_score.freezed.dart';
part 'entry_gameweek_score.g.dart';

@freezed
class EntryGameweekScore with _$EntryGameweekScore {
  const factory EntryGameweekScore({
    required String id,
    @JsonKey(name: 'entry_id') required String entryId,
    @JsonKey(name: 'gameweek_id') required String gameweekId,
    @Default(0) int points,
    @JsonKey(name: 'transfers_made') @Default(0) int transfersMade,
    @JsonKey(name: 'transfer_cost') @Default(0) int transferCost,
    @JsonKey(name: 'chip_played') String? chipPlayed,
    int? rank,
    double? percentile,
    @JsonKey(name: 'calculated_at') DateTime? calculatedAt,
    @JsonKey(name: 'team_name') String? teamName,
    @JsonKey(name: 'manager_name') String? managerName,
    @JsonKey(name: 'overall_points') int? overallPoints,
    @JsonKey(name: 'overall_rank') int? overallRank,
    @JsonKey(name: 'rank_movement') int? rankMovement,
  }) = _EntryGameweekScore;

  factory EntryGameweekScore.fromJson(Map<String, dynamic> json) =>
      _$EntryGameweekScoreFromJson(json);
}
