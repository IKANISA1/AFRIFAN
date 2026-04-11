import 'package:freezed_annotation/freezed_annotation.dart';

import 'fantasy_player.dart';

part 'squad_selection.freezed.dart';
part 'squad_selection.g.dart';

@freezed
class SquadSelection with _$SquadSelection {
  const factory SquadSelection({
    required String id,
    @JsonKey(name: 'entry_id') required String entryId,
    @JsonKey(name: 'gameweek_id') required String gameweekId,
    @JsonKey(name: 'player_id') required int playerId,
    required PlayerPosition position,
    @JsonKey(name: 'is_starter') @Default(true) bool isStarter,
    @JsonKey(name: 'bench_order') int? benchOrder,
    @JsonKey(name: 'is_captain') @Default(false) bool isCaptain,
    @JsonKey(name: 'is_vice_captain') @Default(false) bool isViceCaptain,
    @JsonKey(name: 'purchase_price') required int purchasePrice,
    @Default(1) int multiplier,
    FantasyPlayer? player,
  }) = _SquadSelection;

  factory SquadSelection.fromJson(Map<String, dynamic> json) =>
      _$SquadSelectionFromJson(json);
}

extension SquadSelectionX on SquadSelection {
  bool get isBench => !isStarter;
}
