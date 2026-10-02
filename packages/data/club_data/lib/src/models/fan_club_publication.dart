Map<String, dynamic> normalizeFanclubRow(Map<String, dynamic> row) {
  final isOfficialRegister =
      row.containsKey('approval_status') ||
      row.containsKey('member_count_public');
  if (!isOfficialRegister) {
    final memberCount = (row['member_count'] as num?)?.toInt() ?? 0;
    return <String, dynamic>{
      ...row,
      'region': _firstText(<Object?>[row['region']]) ?? 'Unknown',
      'description':
          _firstText(<Object?>[row['description']]) ??
          'Official supporter FanClubs.',
      'member_count': memberCount,
      'member_count_label': memberCount.toString(),
      'status_label': (row['is_active'] as bool? ?? true)
          ? 'ACTIVE'
          : 'PENDING REVIEW',
      'source_label': row['source_label']?.toString(),
      'is_official': row['is_official'] as bool? ?? false,
      'is_active': row['is_active'] as bool? ?? true,
    };
  }

  final memberCount = (row['member_count'] as num?)?.toInt() ?? 0;
  final memberCountLabel =
      _firstText(<Object?>[row['member_count_public']]) ??
      (memberCount > 0 ? memberCount.toString() : 'Pending confirmation');
  final status = _statusLabel(row['status']?.toString());
  final province = _firstText(<Object?>[row['province'], row['country']]);
  final district = _firstText(<Object?>[row['district'], row['city']]);
  final region = district == null
      ? province ?? 'Unknown'
      : province == null
      ? district
      : '$province / $district';

  return <String, dynamic>{
    'id': row['id']?.toString() ?? row['slug']?.toString() ?? row['name'],
    'slug': row['slug']?.toString(),
    'name':
        _firstText(<Object?>[row['name'], row['official_name']]) ?? 'Fanclub',
    'official_name': row['official_name']?.toString(),
    'region': region,
    'province': province,
    'district': district,
    'description':
        _firstText(<Object?>[
          row['activities'],
          row['impact_summary'],
          row['community_activity'],
          row['metadata'] is Map
              ? (row['metadata'] as Map)['operationalNote']
              : null,
        ]) ??
        'Official Rayon Sports supporter FanClubs.',
    'member_count': memberCount,
    'member_count_label': memberCountLabel,
    'status_label': status,
    'chapter_type': row['chapter_type']?.toString(),
    'accepting_members': row['accepting_members'] as bool? ?? true,
    'is_active': row['active'] as bool? ?? row['is_active'] as bool? ?? true,
    'is_official':
        row['approval_status']?.toString() == 'approved' ||
        row['verification_status']?.toString().isNotEmpty == true,
    'source_label': row['source_label']?.toString(),
    'verification_status': row['verification_status']?.toString(),
    'meeting_location_public': row['meeting_location_public']?.toString(),
    'matchday_travel': row['matchday_travel']?.toString(),
    'community_activity': row['community_activity']?.toString(),
  };
}

String _statusLabel(String? rawStatus) {
  final value = (rawStatus ?? '').trim().toLowerCase();
  return switch (value) {
    'registered_fan_club' ||
    'registered_national_fan_club' ||
    'registered_diaspora_fan_club' => 'Registered',
    'proposed_branch' => 'Proposed',
    'mobilization_branch' => 'Mobilizing',
    'regional_stream' || 'regional_cluster' || 'regional_chapter' => 'Regional',
    'leadership_cleanup' => 'Review',
    'operational_audit' => 'Audit',
    'registration_drive' => 'Registration',
    'committee_mapping' => 'Mapping',
    'charter_required' => 'Charter',
    'office_pending' => 'Office pending',
    'institutional_recognition_pending' => 'Recognition',
    _ => 'Approved',
  };
}

String? _firstText(List<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }
  }
  return null;
}
