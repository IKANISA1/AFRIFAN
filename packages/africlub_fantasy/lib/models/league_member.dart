class LeagueMember {
  const LeagueMember({
    required this.entryId,
    required this.teamName,
    required this.overallPoints,
    this.overallRank,
    this.joinedAt,
  });

  factory LeagueMember.fromJson(Map<String, dynamic> json) {
    return LeagueMember(
      entryId: json['entry_id']?.toString() ?? '',
      teamName: json['team_name']?.toString() ?? 'Fantasy Team',
      overallPoints: _asLeagueInt(json['overall_points']),
      overallRank: _asLeagueNullableInt(json['overall_rank']),
      joinedAt: _asDateTime(json['joined_at']),
    );
  }

  final String entryId;
  final String teamName;
  final int overallPoints;
  final int? overallRank;
  final DateTime? joinedAt;
}

int _asLeagueInt(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _asLeagueNullableInt(Object? value) {
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

DateTime? _asDateTime(Object? value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}
