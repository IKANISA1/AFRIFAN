class LeagueH2HFixture {
  const LeagueH2HFixture({
    required this.id,
    required this.leagueId,
    required this.gameweekId,
    required this.gameweekNumber,
    required this.gameweekName,
    required this.roundNumber,
    required this.homeEntryId,
    required this.homeTeamName,
    required this.awayEntryId,
    required this.awayTeamName,
    this.homePoints,
    this.awayPoints,
    this.winnerEntryId,
    required this.status,
  });

  factory LeagueH2HFixture.fromJson(Map<String, dynamic> json) {
    return LeagueH2HFixture(
      id: json['id']?.toString() ?? '',
      leagueId: json['league_id']?.toString() ?? '',
      gameweekId: json['gameweek_id']?.toString() ?? '',
      gameweekNumber: _asInt(json['gameweek_number']),
      gameweekName: json['gameweek_name']?.toString() ?? 'Gameweek',
      roundNumber: _asInt(json['round_number']),
      homeEntryId: json['home_entry_id']?.toString() ?? '',
      homeTeamName: json['home_team_name']?.toString() ?? 'Home',
      awayEntryId: json['away_entry_id']?.toString() ?? '',
      awayTeamName: json['away_team_name']?.toString() ?? 'Away',
      homePoints: _asNullableInt(json['home_points']),
      awayPoints: _asNullableInt(json['away_points']),
      winnerEntryId: json['winner_entry_id']?.toString(),
      status: json['status']?.toString() ?? 'upcoming',
    );
  }

  final String id;
  final String leagueId;
  final String gameweekId;
  final int gameweekNumber;
  final String gameweekName;
  final int roundNumber;
  final String homeEntryId;
  final String homeTeamName;
  final String awayEntryId;
  final String awayTeamName;
  final int? homePoints;
  final int? awayPoints;
  final String? winnerEntryId;
  final String status;

  bool get isFinished => status == 'finished';
  bool get isLive => status == 'live' || status == 'scoring';
  bool involvesEntry(String entryId) =>
      homeEntryId == entryId || awayEntryId == entryId;

  String scoreLabel() {
    final home = homePoints?.toString() ?? '-';
    final away = awayPoints?.toString() ?? '-';
    return '$home - $away';
  }
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _asNullableInt(Object? value) {
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
