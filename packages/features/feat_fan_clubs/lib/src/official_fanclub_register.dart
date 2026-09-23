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

List<Map<String, dynamic>> officialFanclubRegister() {
  return _officialFanclubs.map(normalizeFanclubRow).toList(growable: false);
}

String fanclubMemberLabel(Map<String, dynamic> club) {
  return club['member_count_label']?.toString() ??
      ((club['member_count'] as num?)?.toInt() ?? 0).toString();
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

Map<String, dynamic> _fanclub(
  String slug,
  String name,
  String province,
  String district,
  String status,
  String note,
  int sortOrder,
) {
  return <String, dynamic>{
    'id': slug,
    'slug': slug,
    'name': name,
    'official_name': name,
    'chapter_type': province == 'Diaspora'
        ? 'diaspora'
        : province == 'Nationwide'
        ? 'nationwide'
        : 'district',
    'status': status,
    'approval_status': 'approved',
    'visibility': 'public',
    'active': true,
    'country': province == 'Diaspora' ? 'Diaspora' : 'Rwanda',
    'province': province,
    'district': district,
    'member_count_public': 'Pending official confirmation',
    'show_member_count': false,
    'activities': note,
    'impact_summary': note,
    'community_activity': note,
    'matchday_travel': note,
    'source_label': 'User-provided Rayon Sports fanclub register',
    'verification_status': 'user_provided_operational_dataset',
    'sort_order': sortOrder,
  };
}

final _officialFanclubs = <Map<String, dynamic>>[
  _fanclub(
    'gikundiro-forever-nyarugenge',
    'Gikundiro Forever',
    'Kigali City',
    'Nyarugenge',
    'registered_fan_club',
    'Operates its main office here with high financial impact.',
    1,
  ),
  _fanclub(
    'dyna-nyarugenge',
    'DYNA',
    'Kigali City',
    'Nyarugenge',
    'registered_fan_club',
    'Nyarugenge registered fan club in the central Kigali supporter base.',
    2,
  ),
  _fanclub(
    'the-blue-sky-gasabo',
    'The Blue Sky',
    'Kigali City',
    'Gasabo',
    'registered_fan_club',
    'Urban youth and digital networks dominate this demographic.',
    3,
  ),
  _fanclub(
    'smart-blue-gasabo',
    'Smart Blue',
    'Kigali City',
    'Gasabo',
    'registered_fan_club',
    'Urban youth and digital networks dominate this demographic.',
    4,
  ),
  _fanclub(
    'new-vision-gasabo',
    'New Vision',
    'Kigali City',
    'Gasabo',
    'registered_fan_club',
    'Urban youth and digital networks dominate this demographic.',
    5,
  ),
  _fanclub(
    'march-generation-kicukiro',
    "March' Generation",
    'Kigali City',
    'Kicukiro',
    'registered_fan_club',
    'Hosts corporate professionals and coordinates Player of the Month awards.',
    6,
  ),
  _fanclub(
    'winning-team-kicukiro',
    'Winning Team',
    'Kigali City',
    'Kicukiro',
    'registered_fan_club',
    'Hosts corporate professionals and coordinates Player of the Month awards.',
    7,
  ),
  _fanclub(
    'isaro-fan-club-muhanga',
    'Isaro Fan Club',
    'Southern Province',
    'Muhanga',
    'registered_fan_club',
    'Highly active collection pipeline for the Southern province.',
    8,
  ),
  _fanclub(
    'ruhango-fan-club-ruhango',
    'Ruhango Fan Club',
    'Southern Province',
    'Ruhango',
    'registered_fan_club',
    'Regular monthly contributions verified by central fan leadership.',
    9,
  ),
  _fanclub(
    'gikundiro-ku-ivuko-nyanza',
    'Gikundiro ku Ivuko Nyanza',
    'Southern Province',
    'Nyanza',
    'registered_fan_club',
    'The historical home base of the club; preserves long-standing heritage connections.',
    10,
  ),
  _fanclub(
    'gikundiro-iwacu-nyamagabe',
    'Gikundiro Iwacu Nyamagabe',
    'Southern Province',
    'Nyamagabe',
    'registered_fan_club',
    'Active regional branch coordinating match-day logistics.',
    11,
  ),
  _fanclub(
    'gikundiro-huko-huye-fan-club',
    'Gikundiro Huko Huye Fan Club',
    'Southern Province',
    'Huye',
    'proposed_branch',
    'Proposing a dedicated branch to compete directly with rival local teams.',
    12,
  ),
  _fanclub(
    'kamonyi-amizero-fan-club',
    'Kamonyi Amizero Fan Club',
    'Southern Province',
    'Kamonyi',
    'registered_fan_club',
    'Strategic entry point connecting Kigali to the Southern fan base.',
    13,
  ),
  _fanclub(
    'gisagara-intwari-fan-club',
    'Gisagara Intwari Fan Club',
    'Southern Province',
    'Gisagara',
    'mobilization_branch',
    'Potential rural talent identification and fan mobilization branch.',
    14,
  ),
  _fanclub(
    'nyaruguru-ishema-fan-club',
    'Nyaruguru Ishema Fan Club',
    'Southern Province',
    'Nyaruguru',
    'regional_stream',
    'Border district currently relying on generic southern fan streams.',
    15,
  ),
  _fanclub(
    'rubavu-fan-club',
    'Rubavu Fan Club',
    'Western Province',
    'Rubavu',
    'registered_fan_club',
    'Strong match-day mobilization around Lake Kivu area.',
    16,
  ),
  _fanclub(
    'kivu-blue-fan-club-rubavu',
    'Kivu Blue Fan Club',
    'Western Province',
    'Rubavu',
    'registered_fan_club',
    'Strong match-day mobilization around Lake Kivu area.',
    17,
  ),
  _fanclub(
    'kivu-blue-fan-club-karongi',
    'Kivu Blue Fan Club',
    'Western Province',
    'Karongi',
    'regional_chapter',
    'Shares regional representation with Rubavu fans.',
    18,
  ),
  _fanclub(
    'kinyaga-fan-club-nyamasheke',
    'Kinyaga Fan Club',
    'Western Province',
    'Nyamasheke',
    'registered_fan_club',
    'Covers the Nyamasheke-Rusizi alignment for Western travel.',
    19,
  ),
  _fanclub(
    'rusizi-bugarama-fanclub',
    'Rusizi Bugarama Fanclub',
    'Western Province',
    'Rusizi',
    'leadership_cleanup',
    'Under leadership cleanup due to temporary operational gaps.',
    20,
  ),
  _fanclub(
    'nyabihu-inkuba-fan-club',
    'Nyabihu Inkuba Fan Club',
    'Western Province',
    'Nyabihu',
    'mobilization_branch',
    'High altitude fans currently absorbed by Musanze networks.',
    21,
  ),
  _fanclub(
    'rutsiro-gikundiro-alliance',
    'Rutsiro Gikundiro Alliance',
    'Western Province',
    'Rutsiro',
    'unmapped_district',
    'Unmapped district requiring direct mobilization.',
    22,
  ),
  _fanclub(
    'ngororero-isibo-fan-club',
    'Ngororero Isibo Fan Club',
    'Western Province',
    'Ngororero',
    'grassroots_branch',
    'Grassroots area requiring localized shortcode access training.',
    23,
  ),
  _fanclub(
    'ibirunga-fan-club-musanze',
    'Ibirunga Fan Club',
    'Northern Province',
    'Musanze',
    'registered_fan_club',
    'Highly active powerhouse; finances senior squad hosting when traveling North.',
    24,
  ),
  _fanclub(
    'gicumbi-cy-abarayon',
    "Gicumbi cy'Abarayon",
    'Northern Province',
    'Gicumbi',
    'operational_audit',
    'Under operational audit to clear membership reporting delays.',
    25,
  ),
  _fanclub(
    'burera-ubumwe-fan-club',
    'Burera Ubumwe Fan Club',
    'Northern Province',
    'Burera',
    'registration_drive',
    'Border demographic requiring targeted registration drives.',
    26,
  ),
  _fanclub(
    'rulindo-umucyo-fan-club',
    'Rulindo Umucyo Fan Club',
    'Northern Province',
    'Rulindo',
    'committee_mapping',
    'Requires localized committee mapping to capture local transit fans.',
    27,
  ),
  _fanclub(
    'gakenke-imbaga-fan-club',
    'Gakenke Imbaga Fan Club',
    'Northern Province',
    'Gakenke',
    'charter_required',
    'Receives CSR outreach from Gikundiro Forever but needs its own charter.',
    28,
  ),
  _fanclub(
    'inyambo-nyagatare-fan-club',
    'Inyambo / Nyagatare Fan Club',
    'Eastern Province',
    'Nyagatare',
    'registered_fan_club',
    'Active border-district pillar leading Eastern mobilization.',
    29,
  ),
  _fanclub(
    'gisaka-fan-club-ngoma',
    'Gisaka Fan Club',
    'Eastern Province',
    'Ngoma',
    'regional_cluster',
    'Consolidated cluster fan club covering Ngoma and Kirehe.',
    30,
  ),
  _fanclub(
    'gisaka-fan-club-kirehe',
    'Gisaka Fan Club',
    'Eastern Province',
    'Kirehe',
    'regional_cluster',
    'Coordinated under the unified Gisaka regional banner.',
    31,
  ),
  _fanclub(
    'kiramuruzi-umucyo-fan-club',
    'Kiramuruzi Umucyo Fan Club',
    'Eastern Province',
    'Gatsibo',
    'registered_fan_club',
    'Newly fast-tracked and fully registered under the 2025 reforms.',
    32,
  ),
  _fanclub(
    'kayonza-ikaze-fan-club',
    'Kayonza Ikaze Fan Club',
    'Eastern Province',
    'Kayonza',
    'office_pending',
    'Major intersection hub currently lacking a distinct standalone office.',
    33,
  ),
  _fanclub(
    'rwamagana-umuseke-fan-club',
    'Rwamagana Umuseke Fan Club',
    'Eastern Province',
    'Rwamagana',
    'institutional_recognition_pending',
    'Provincial capital requiring standalone institutional recognition.',
    34,
  ),
  _fanclub(
    'bugesera-imena-fan-club',
    'Bugesera Imena Fan Club',
    'Eastern Province',
    'Bugesera',
    'charter_required',
    'Rapidly growing area that needs a formal localized charter.',
    35,
  ),
  _fanclub(
    'ururembo-fan-club-diaspora',
    'Ururembo Fan Club',
    'Diaspora',
    'Global/Diaspora',
    'registered_diaspora_fan_club',
    'International crowdfunding arm across Europe and North America.',
    36,
  ),
  _fanclub(
    'rayon-sports-super-fans',
    'Rayon Sports Super Fans',
    'Nationwide',
    'Nationwide',
    'registered_national_fan_club',
    'Core stadium crowd-pullers and official match animators.',
    37,
  ),
  _fanclub(
    'rayon-sports-special',
    'Rayon Sports Special',
    'Nationwide',
    'Nationwide',
    'registered_national_fan_club',
    'Elite corporate figures funding instant transfer window bonuses.',
    38,
  ),
  _fanclub(
    'gikundiro-senior-fan-club',
    'Gikundiro Senior Fan Club',
    'Nationwide',
    'Nationwide',
    'registered_national_fan_club',
    'Long-time veteran supporter opinion leaders.',
    39,
  ),
  _fanclub(
    'dream-unity-fan-club',
    'Dream Unity Fan Club',
    'Nationwide',
    'Nationwide',
    'registered_national_fan_club',
    'Community development-oriented young professionals.',
    40,
  ),
  _fanclub(
    'the-blue-family-fan-club',
    'The Blue Family Fan Club',
    'Nationwide',
    'Nationwide',
    'registered_national_fan_club',
    'Cross-generational family supporter wing.',
    41,
  ),
  _fanclub(
    'gikundiro-lovers-fan-club',
    'Gikundiro Lovers Fan Club',
    'Nationwide',
    'Nationwide',
    'registered_national_fan_club',
    'Female-led supporter networking and charity wing.',
    42,
  ),
];
