class FantasyNotificationTopic {
  const FantasyNotificationTopic({
    required this.competitionId,
    required this.slug,
    required this.topic,
    required this.enabled,
    required this.deadlineAlerts,
    required this.gameplayAlerts,
    required this.leagueAlerts,
  });

  factory FantasyNotificationTopic.fromJson(Map<String, dynamic> json) {
    return FantasyNotificationTopic(
      competitionId: json['competition_id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      topic: json['topic']?.toString() ?? '',
      enabled: _asBool(json['enabled'], fallback: true),
      deadlineAlerts: _asBool(json['deadline_alerts'], fallback: true),
      gameplayAlerts: _asBool(json['gameplay_alerts'], fallback: true),
      leagueAlerts: _asBool(json['league_alerts'], fallback: true),
    );
  }

  final String competitionId;
  final String slug;
  final String topic;
  final bool enabled;
  final bool deadlineAlerts;
  final bool gameplayAlerts;
  final bool leagueAlerts;

  FantasyNotificationTopic copyWith({
    bool? enabled,
    bool? deadlineAlerts,
    bool? gameplayAlerts,
    bool? leagueAlerts,
  }) {
    return FantasyNotificationTopic(
      competitionId: competitionId,
      slug: slug,
      topic: topic,
      enabled: enabled ?? this.enabled,
      deadlineAlerts: deadlineAlerts ?? this.deadlineAlerts,
      gameplayAlerts: gameplayAlerts ?? this.gameplayAlerts,
      leagueAlerts: leagueAlerts ?? this.leagueAlerts,
    );
  }
}

bool _asBool(Object? value, {required bool fallback}) {
  if (value is bool) {
    return value;
  }
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return fallback;
  }
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}
