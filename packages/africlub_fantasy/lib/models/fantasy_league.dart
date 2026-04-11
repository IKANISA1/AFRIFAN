import 'package:freezed_annotation/freezed_annotation.dart';

part 'fantasy_league.freezed.dart';
part 'fantasy_league.g.dart';

enum FantasyLeagueType {
  @JsonValue('classic')
  classic,
  @JsonValue('head_to_head')
  headToHead,
}

@freezed
class FantasyLeague with _$FantasyLeague {
  const factory FantasyLeague({
    required String id,
    @JsonKey(name: 'competition_id') required String competitionId,
    required String name,
    required String code,
    required FantasyLeagueType type,
    @JsonKey(name: 'created_by') required String createdBy,
    @JsonKey(name: 'max_entries') @Default(50) int maxEntries,
    @JsonKey(name: 'is_public') @Default(false) bool isPublic,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'member_count') @Default(0) int memberCount,
  }) = _FantasyLeague;

  factory FantasyLeague.fromJson(Map<String, dynamic> json) =>
      _$FantasyLeagueFromJson(json);
}
