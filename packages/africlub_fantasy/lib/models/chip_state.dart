import 'package:freezed_annotation/freezed_annotation.dart';

part 'chip_state.freezed.dart';
part 'chip_state.g.dart';

enum ChipType {
  @JsonValue('wildcard')
  wildcard,
  @JsonValue('free_hit')
  freeHit,
  @JsonValue('triple_captain')
  tripleCaptain,
  @JsonValue('bench_boost')
  benchBoost,
}

@freezed
class ChipState with _$ChipState {
  const factory ChipState({
    required ChipType chip,
    @Default(false) bool isAvailable,
    @Default(false) bool isActivated,
    @Default(false) bool isConsumed,
    String? description,
    @JsonKey(name: 'projected_points') @Default(0) int projectedPoints,
    @JsonKey(name: 'gameweek_id') String? gameweekId,
  }) = _ChipState;

  factory ChipState.fromJson(Map<String, dynamic> json) =>
      _$ChipStateFromJson(json);
}
