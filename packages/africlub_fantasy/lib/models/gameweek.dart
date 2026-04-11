import 'package:freezed_annotation/freezed_annotation.dart';

part 'gameweek.freezed.dart';
part 'gameweek.g.dart';

enum GameweekStatus {
  @JsonValue('upcoming')
  upcoming,
  @JsonValue('live')
  live,
  @JsonValue('scoring')
  scoring,
  @JsonValue('finished')
  finished,
}

@freezed
class Gameweek with _$Gameweek {
  const factory Gameweek({
    required String id,
    @JsonKey(name: 'competition_id') required String competitionId,
    required int number,
    required String name,
    @JsonKey(name: 'deadline_at') required DateTime deadlineAt,
    @JsonKey(name: 'start_at') required DateTime startAt,
    @JsonKey(name: 'end_at') required DateTime endAt,
    required GameweekStatus status,
    @JsonKey(name: 'is_double_gw') @Default(false) bool isDoubleGw,
    @JsonKey(name: 'average_score') int? averageScore,
    @JsonKey(name: 'highest_score') int? highestScore,
    @JsonKey(name: 'most_captained_player_id') int? mostCaptainedPlayerId,
  }) = _Gameweek;

  factory Gameweek.fromJson(Map<String, dynamic> json) =>
      _$GameweekFromJson(json);
}
