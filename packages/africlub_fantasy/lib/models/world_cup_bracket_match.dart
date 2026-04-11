class WorldCupBracketMatch {
  const WorldCupBracketMatch({
    required this.stage,
    required this.stageOrder,
    required this.label,
    required this.fixtureId,
    this.externalFixtureId,
    this.kickoffAt,
    required this.statusShort,
    this.roundLabel,
    required this.homeTeamName,
    required this.awayTeamName,
    this.homeGoals,
    this.awayGoals,
  });

  factory WorldCupBracketMatch.fromJson(Map<String, dynamic> json) {
    return WorldCupBracketMatch(
      stage: json['stage']?.toString() ?? 'Groups',
      stageOrder: _asBracketInt(json['stage_order'], fallback: 99),
      label: json['label']?.toString() ?? 'Fixture',
      fixtureId: json['fixture_id']?.toString() ?? '',
      externalFixtureId: _asBracketNullableInt(json['external_fixture_id']),
      kickoffAt: _asBracketDateTime(json['kickoff_at']),
      statusShort: json['status_short']?.toString() ?? 'NS',
      roundLabel: json['round_label']?.toString(),
      homeTeamName: json['home_team_name']?.toString() ?? 'TBD',
      awayTeamName: json['away_team_name']?.toString() ?? 'TBD',
      homeGoals: _asBracketNullableInt(json['home_goals']),
      awayGoals: _asBracketNullableInt(json['away_goals']),
    );
  }

  final String stage;
  final int stageOrder;
  final String label;
  final String fixtureId;
  final int? externalFixtureId;
  final DateTime? kickoffAt;
  final String statusShort;
  final String? roundLabel;
  final String homeTeamName;
  final String awayTeamName;
  final int? homeGoals;
  final int? awayGoals;

  bool get isLive => const {'1H', 'HT', '2H', 'ET', 'P'}.contains(statusShort);
  bool get isFinished => const {'FT', 'AET', 'PEN'}.contains(statusShort);
  String get scoreLabel => '${homeGoals ?? '-'} - ${awayGoals ?? '-'}';
}

int _asBracketInt(Object? value, {required int fallback}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _asBracketNullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString());
}

DateTime? _asBracketDateTime(Object? value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}
