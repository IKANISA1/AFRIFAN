import 'package:freezed_annotation/freezed_annotation.dart';

part 'fantasy_player.freezed.dart';
part 'fantasy_player.g.dart';

enum PlayerPosition {
  @JsonValue('GK')
  gk,
  @JsonValue('DEF')
  def,
  @JsonValue('MID')
  mid,
  @JsonValue('FWD')
  fwd,
}

@freezed
class FantasyPlayer with _$FantasyPlayer {
  const factory FantasyPlayer({
    @JsonKey(name: 'external_id') required int externalId,
    required String name,
    @JsonKey(name: 'short_name') required String shortName,
    @JsonKey(name: 'photo_url') String? photoUrl,
    required PlayerPosition position,
    @JsonKey(name: 'team_id') required int teamId,
    @JsonKey(name: 'team_name') required String teamName,
    @JsonKey(name: 'team_short') required String teamShort,
    @JsonKey(name: 'team_logo_url') String? teamLogoUrl,
    @Default(0) int price,
    @JsonKey(name: 'price_change') @Default(0) int priceChange,
    @JsonKey(name: 'ownership_percent') @Default(0.0) double ownershipPercent,
    @JsonKey(name: 'form_points') @Default(0) int formPoints,
    @JsonKey(name: 'total_points') @Default(0) int totalPoints,
    @JsonKey(name: 'recent_points') @Default(<int>[]) List<int> recentPoints,
    @JsonKey(name: 'fixture_difficulty')
    @Default(<Map<String, dynamic>>[])
    List<Map<String, dynamic>> fixtureDifficulty,
    @Default(false) bool isInjured,
    @Default(false) bool isDoubtful,
  }) = _FantasyPlayer;

  factory FantasyPlayer.fromJson(Map<String, dynamic> json) =>
      _$FantasyPlayerFromJson(json);
}

extension FantasyPlayerX on FantasyPlayer {
  String get priceDisplay => '£${(price / 10).toStringAsFixed(1)}M';
  String get positionLabel => position.name.toUpperCase();
}
