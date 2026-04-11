import 'package:freezed_annotation/freezed_annotation.dart';

part 'competition.freezed.dart';
part 'competition.g.dart';

enum CompetitionType {
  @JsonValue('season_long')
  seasonLong,
  @JsonValue('tournament')
  tournament,
}

enum CompetitionStatus {
  @JsonValue('draft')
  draft,
  @JsonValue('active')
  active,
  @JsonValue('finished')
  finished,
}

@freezed
class Competition with _$Competition {
  const factory Competition({
    required String id,
    required String slug,
    required String name,
    @JsonKey(name: 'short_name') required String shortName,
    @JsonKey(name: 'competition_type') required CompetitionType competitionType,
    required String season,
    @JsonKey(name: 'logo_url') String? logoUrl,
    @JsonKey(name: 'primary_color') @Default('#1A7A4E') String primaryColor,
    @JsonKey(name: 'scoring_rules') required Map<String, dynamic> scoringRules,
    @JsonKey(name: 'squad_config') required Map<String, dynamic> squadConfig,
    @JsonKey(name: 'chip_config') required Map<String, dynamic> chipConfig,
    @JsonKey(name: 'transfer_config')
    required Map<String, dynamic> transferConfig,
    required CompetitionStatus status,
    @JsonKey(name: 'start_date') required DateTime startDate,
    @JsonKey(name: 'end_date') required DateTime endDate,
    @JsonKey(name: 'external_league_id') int? externalLeagueId,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _Competition;

  factory Competition.fromJson(Map<String, dynamic> json) =>
      _$CompetitionFromJson(json);
}
