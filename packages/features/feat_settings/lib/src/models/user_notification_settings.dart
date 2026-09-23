class UserNotificationSettings {
  const UserNotificationSettings({
    required this.userId,
    required this.clubId,
    required this.pushEnabled,
    required this.allowAll,
    required this.matchAlerts,
    required this.contributionReceipts,
    required this.fetMilestones,
    required this.teamNews,
    required this.challenges,
    required this.groupChat,
    this.updatedAt,
  });

  final String userId;
  final String clubId;
  final bool pushEnabled;
  final bool allowAll;
  final bool matchAlerts;
  final bool contributionReceipts;
  final bool fetMilestones;
  final bool teamNews;
  final bool challenges;
  final bool groupChat;
  final String? updatedAt;

  factory UserNotificationSettings.defaults({
    required String userId,
    required String clubId,
  }) {
    return UserNotificationSettings(
      userId: userId,
      clubId: clubId,
      pushEnabled: false,
      allowAll: false,
      matchAlerts: true,
      contributionReceipts: true,
      fetMilestones: true,
      teamNews: false,
      challenges: true,
      groupChat: false,
      updatedAt: null,
    );
  }

  factory UserNotificationSettings.fromJson(Map<String, dynamic> json) {
    return UserNotificationSettings(
      userId: _asString(json['user_id']),
      clubId: _asString(json['club_id']),
      pushEnabled: _asBool(json['push_enabled']),
      allowAll: _asBool(json['allow_all']),
      matchAlerts: _asBool(json['match_alerts'], fallback: true),
      contributionReceipts: _asBool(
        json['contribution_receipts'],
        fallback: true,
      ),
      fetMilestones: _asBool(json['fet_milestones'], fallback: true),
      teamNews: _asBool(json['team_news']),
      challenges: _asBool(json['challenges'], fallback: true),
      groupChat: _asBool(json['group_chat']),
      updatedAt: _asNullableString(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    final normalizedClubId = int.tryParse(clubId);
    return <String, dynamic>{
      'user_id': userId,
      if (normalizedClubId != null) 'club_id': normalizedClubId,
      'push_enabled': pushEnabled,
      'allow_all': allowAll,
      'match_alerts': matchAlerts,
      'contribution_receipts': contributionReceipts,
      'fet_milestones': fetMilestones,
      'team_news': teamNews,
      'challenges': challenges,
      'group_chat': groupChat,
    };
  }

  UserNotificationSettings copyWith({
    String? userId,
    String? clubId,
    bool? pushEnabled,
    bool? allowAll,
    bool? matchAlerts,
    bool? contributionReceipts,
    bool? fetMilestones,
    bool? teamNews,
    bool? challenges,
    bool? groupChat,
    String? updatedAt,
  }) {
    return UserNotificationSettings(
      userId: userId ?? this.userId,
      clubId: clubId ?? this.clubId,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      allowAll: allowAll ?? this.allowAll,
      matchAlerts: matchAlerts ?? this.matchAlerts,
      contributionReceipts: contributionReceipts ?? this.contributionReceipts,
      fetMilestones: fetMilestones ?? this.fetMilestones,
      teamNews: teamNews ?? this.teamNews,
      challenges: challenges ?? this.challenges,
      groupChat: groupChat ?? this.groupChat,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String? _asNullableString(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return fallback;
}
