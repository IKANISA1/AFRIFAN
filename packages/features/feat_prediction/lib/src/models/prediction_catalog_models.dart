class CompetitionCatalogItem {
  const CompetitionCatalogItem({
    required this.id,
    required this.slug,
    required this.name,
    required this.shortName,
    required this.competitionKind,
    required this.region,
    required this.countryCode,
    required this.countryName,
    required this.organizer,
    required this.gender,
    required this.formatNotes,
    required this.isActive,
  });

  final String id;
  final String slug;
  final String name;
  final String shortName;
  final String competitionKind;
  final String region;
  final String? countryCode;
  final String? countryName;
  final String? organizer;
  final String? gender;
  final String? formatNotes;
  final bool isActive;

  factory CompetitionCatalogItem.fromJson(Map<String, dynamic> json) {
    return CompetitionCatalogItem(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      shortName: json['short_name']?.toString() ?? '',
      competitionKind: json['competition_kind']?.toString() ?? '',
      region: json['region']?.toString() ?? '',
      countryCode: _nullableString(json['country_code']),
      countryName: _nullableString(json['country_name']),
      organizer: _nullableString(json['organizer']),
      gender: _nullableString(json['gender']),
      formatNotes: _nullableString(json['format_notes']),
      isActive: json['is_active'] != false,
    );
  }
}

class LeagueStandingEntry {
  const LeagueStandingEntry({
    required this.id,
    required this.competitionSlug,
    required this.competitionName,
    required this.seasonSlug,
    required this.seasonLabel,
    required this.teamId,
    required this.teamSlug,
    required this.teamName,
    required this.teamShortName,
    required this.position,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
    required this.points,
    required this.form,
    this.stageName,
    this.groupName,
    this.notes,
  });

  final String id;
  final String competitionSlug;
  final String competitionName;
  final String seasonSlug;
  final String seasonLabel;
  final String teamId;
  final String teamSlug;
  final String teamName;
  final String teamShortName;
  final int position;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;
  final int points;
  final String? form;
  final String? stageName;
  final String? groupName;
  final String? notes;

  List<String> get formTokens {
    final raw = form?.trim() ?? '';
    if (raw.isEmpty) {
      return const <String>[];
    }
    if (raw.contains(',')) {
      return raw
          .split(',')
          .map((token) => token.trim().toUpperCase())
          .where((token) => token.isNotEmpty)
          .toList(growable: false);
    }
    return raw
        .split('')
        .map((token) => token.trim().toUpperCase())
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
  }

  factory LeagueStandingEntry.fromJson(Map<String, dynamic> json) {
    return LeagueStandingEntry(
      id: json['id']?.toString() ?? '',
      competitionSlug: json['competition_slug']?.toString() ?? '',
      competitionName: json['competition_name']?.toString() ?? '',
      seasonSlug: json['season_slug']?.toString() ?? '',
      seasonLabel: json['season_label']?.toString() ?? '',
      teamId: json['team_id']?.toString() ?? '',
      teamSlug: json['team_slug']?.toString() ?? '',
      teamName: json['team_name']?.toString() ?? '',
      teamShortName: json['team_short_name']?.toString() ?? '',
      stageName: _nullableString(json['stage_name']),
      groupName: _nullableString(json['group_name']),
      position: (json['position'] as num?)?.toInt() ?? 0,
      played: (json['played'] as num?)?.toInt() ?? 0,
      won: (json['won'] as num?)?.toInt() ?? 0,
      drawn: (json['drawn'] as num?)?.toInt() ?? 0,
      lost: (json['lost'] as num?)?.toInt() ?? 0,
      goalsFor: (json['goals_for'] as num?)?.toInt() ?? 0,
      goalsAgainst: (json['goals_against'] as num?)?.toInt() ?? 0,
      goalDifference: (json['goal_difference'] as num?)?.toInt() ?? 0,
      points: (json['points'] as num?)?.toInt() ?? 0,
      form: _nullableString(json['form']),
      notes: _nullableString(json['notes']),
    );
  }
}

class TeamCatalogEntry {
  const TeamCatalogEntry({
    required this.id,
    required this.slug,
    required this.name,
    required this.shortName,
    required this.teamType,
    required this.countryCode,
    required this.countryName,
    required this.city,
    required this.foundedYear,
    required this.crestUrl,
    required this.sourceClubSlug,
    required this.sourceClubName,
    required this.isActive,
  });

  final String id;
  final String slug;
  final String name;
  final String shortName;
  final String? teamType;
  final String? countryCode;
  final String? countryName;
  final String? city;
  final int? foundedYear;
  final String? crestUrl;
  final String? sourceClubSlug;
  final String? sourceClubName;
  final bool isActive;

  factory TeamCatalogEntry.fromJson(Map<String, dynamic> json) {
    return TeamCatalogEntry(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      shortName: json['short_name']?.toString() ?? '',
      teamType: _nullableString(json['team_type']),
      countryCode: _nullableString(json['country_code']),
      countryName: _nullableString(json['country_name']),
      city: _nullableString(json['city']),
      foundedYear: (json['founded_year'] as num?)?.toInt(),
      crestUrl: _nullableString(json['crest_url']),
      sourceClubSlug: _nullableString(json['source_club_slug']),
      sourceClubName: _nullableString(json['source_club_name']),
      isActive: json['is_active'] != false,
    );
  }
}

class TeamRosterPlayer {
  const TeamRosterPlayer({
    required this.id,
    required this.seasonSlug,
    required this.seasonLabel,
    required this.teamSlug,
    required this.teamName,
    required this.teamShortName,
    required this.playerId,
    required this.playerSlug,
    required this.playerName,
    required this.playerShortName,
    required this.position,
    this.squadNumber,
    this.joinedOn,
    this.leftOn,
    this.isActive = true,
  });

  final String id;
  final String seasonSlug;
  final String seasonLabel;
  final String teamSlug;
  final String teamName;
  final String teamShortName;
  final String playerId;
  final String playerSlug;
  final String playerName;
  final String playerShortName;
  final String? position;
  final int? squadNumber;
  final DateTime? joinedOn;
  final DateTime? leftOn;
  final bool isActive;

  factory TeamRosterPlayer.fromJson(Map<String, dynamic> json) {
    return TeamRosterPlayer(
      id: json['id']?.toString() ?? '',
      seasonSlug: json['season_slug']?.toString() ?? '',
      seasonLabel: json['season_label']?.toString() ?? '',
      teamSlug: json['team_slug']?.toString() ?? '',
      teamName: json['team_name']?.toString() ?? '',
      teamShortName: json['team_short_name']?.toString() ?? '',
      playerId: json['player_id']?.toString() ?? '',
      playerSlug: json['player_slug']?.toString() ?? '',
      playerName: json['player_name']?.toString() ?? '',
      playerShortName: json['player_short_name']?.toString() ?? '',
      position: _nullableString(json['position']),
      squadNumber: (json['squad_number'] as num?)?.toInt(),
      joinedOn: DateTime.tryParse(json['joined_on']?.toString() ?? ''),
      leftOn: DateTime.tryParse(json['left_on']?.toString() ?? ''),
      isActive: json['is_active'] != false,
    );
  }
}

class CommunityPick {
  const CommunityPick({
    required this.fixtureId,
    required this.fixtureMarketId,
    required this.marketName,
    required this.marketShortName,
    required this.selectedOutcome,
    required this.pickCount,
    required this.pickPercentage,
  });

  final String fixtureId;
  final String fixtureMarketId;
  final String marketName;
  final String marketShortName;
  final String selectedOutcome;
  final int pickCount;
  final double pickPercentage;

  String get outcome => selectedOutcome;
  double get percentage => pickPercentage;

  factory CommunityPick.fromJson(Map<String, dynamic> json) {
    return CommunityPick(
      fixtureId: json['fixture_id']?.toString() ?? '',
      fixtureMarketId: json['fixture_market_id']?.toString() ?? '',
      marketName: json['market_name']?.toString() ?? '',
      marketShortName: json['market_short_name']?.toString() ?? '',
      selectedOutcome: json['selected_outcome']?.toString() ?? '',
      pickCount: (json['pick_count'] as num?)?.toInt() ?? 0,
      pickPercentage: (json['pick_percentage'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PredictionBadge {
  const PredictionBadge({
    required this.badgeSlug,
    required this.badgeName,
    required this.badgeDescription,
    required this.thresholdWins,
    this.earnedAt,
  });

  final String badgeSlug;
  final String badgeName;
  final String badgeDescription;
  final int thresholdWins;
  final DateTime? earnedAt;

  factory PredictionBadge.fromJson(Map<String, dynamic> json) {
    return PredictionBadge(
      badgeSlug: json['badge_slug']?.toString() ?? '',
      badgeName: json['badge_name']?.toString() ?? '',
      badgeDescription: json['badge_description']?.toString() ?? '',
      thresholdWins: (json['threshold_wins'] as num?)?.toInt() ?? 0,
      earnedAt: DateTime.tryParse(json['earned_at']?.toString() ?? ''),
    );
  }
}

class PredictionNotification {
  const PredictionNotification({
    required this.id,
    required this.notificationType,
    required this.title,
    required this.body,
    required this.payload,
    required this.createdAt,
    required this.isSent,
    this.sentAt,
  });

  final String id;
  final String notificationType;
  final String title;
  final String body;
  final Map<String, dynamic> payload;
  final DateTime? createdAt;
  final bool isSent;
  final DateTime? sentAt;

  String? get route {
    final value = payload['route']?.toString().trim() ?? '';
    return value.isEmpty ? null : value;
  }

  String? get predictionId {
    final value = payload['prediction_id']?.toString().trim() ?? '';
    return value.isEmpty ? null : value;
  }

  String? get fixtureId {
    final value = payload['fixture_id']?.toString().trim() ?? '';
    return value.isEmpty ? null : value;
  }

  int get earned {
    return (payload['earned'] as num?)?.toInt() ?? 0;
  }

  factory PredictionNotification.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    return PredictionNotification(
      id: json['id']?.toString() ?? '',
      notificationType: json['notification_type']?.toString() ?? 'settlement',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      payload: rawPayload is Map<String, dynamic>
          ? rawPayload
          : rawPayload is Map
          ? Map<String, dynamic>.from(rawPayload)
          : const <String, dynamic>{},
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      isSent: json['is_sent'] == true,
      sentAt: DateTime.tryParse(json['sent_at']?.toString() ?? ''),
    );
  }
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
