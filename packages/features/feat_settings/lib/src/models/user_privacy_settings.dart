class UserPrivacySettings {
  const UserPrivacySettings({
    required this.userId,
    required this.clubId,
    required this.groupVisibility,
    required this.analyticsEnabled,
    required this.biometricLoginEnabled,
    required this.showActivityStatus,
    this.updatedAt,
  });

  final String userId;
  final String clubId;
  final String groupVisibility;
  final bool analyticsEnabled;
  final bool biometricLoginEnabled;
  final bool showActivityStatus;
  final String? updatedAt;

  static const List<String> visibilityOptions = <String>[
    'public',
    'members',
    'private',
  ];

  factory UserPrivacySettings.defaults({
    required String userId,
    required String clubId,
  }) {
    return UserPrivacySettings(
      userId: userId,
      clubId: clubId,
      groupVisibility: 'members',
      analyticsEnabled: false,
      biometricLoginEnabled: true,
      showActivityStatus: true,
      updatedAt: null,
    );
  }

  factory UserPrivacySettings.fromJson(Map<String, dynamic> json) {
    return UserPrivacySettings(
      userId: _asString(json['user_id']),
      clubId: _asString(json['club_id']),
      groupVisibility: _normalizeVisibility(json['group_visibility']),
      analyticsEnabled: _asBool(json['analytics_enabled'], fallback: false),
      biometricLoginEnabled: _asBool(
        json['biometric_login_enabled'],
        fallback: true,
      ),
      showActivityStatus: _asBool(json['show_activity_status'], fallback: true),
      updatedAt: _asNullableString(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    final normalizedClubId = int.tryParse(clubId);
    return <String, dynamic>{
      'user_id': userId,
      if (normalizedClubId != null) 'club_id': normalizedClubId,
      'group_visibility': _normalizeVisibility(groupVisibility),
      'analytics_enabled': analyticsEnabled,
      'biometric_login_enabled': biometricLoginEnabled,
      'show_activity_status': showActivityStatus,
    };
  }

  UserPrivacySettings copyWith({
    String? userId,
    String? clubId,
    String? groupVisibility,
    bool? analyticsEnabled,
    bool? biometricLoginEnabled,
    bool? showActivityStatus,
    String? updatedAt,
  }) {
    return UserPrivacySettings(
      userId: userId ?? this.userId,
      clubId: clubId ?? this.clubId,
      groupVisibility: groupVisibility == null
          ? this.groupVisibility
          : _normalizeVisibility(groupVisibility),
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      biometricLoginEnabled:
          biometricLoginEnabled ?? this.biometricLoginEnabled,
      showActivityStatus: showActivityStatus ?? this.showActivityStatus,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

String _normalizeVisibility(dynamic value) {
  final candidate = value?.toString().trim().toLowerCase() ?? 'members';
  return UserPrivacySettings.visibilityOptions.contains(candidate)
      ? candidate
      : 'members';
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
