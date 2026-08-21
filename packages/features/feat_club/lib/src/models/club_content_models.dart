import 'package:equatable/equatable.dart';

String _stringValue(Object? value) => value?.toString().trim() ?? '';

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_stringValue(value)) ?? 0;
}

DateTime? _dateValue(Object? value) {
  if (value is DateTime) return value;
  return DateTime.tryParse(_stringValue(value));
}

/// Official, club-scoped identity projected into the consumer Club hub.
class ClubOverview extends Equatable {
  const ClubOverview({
    required this.id,
    required this.name,
    required this.country,
    required this.league,
    required this.slug,
    required this.nickname,
    this.logoUrl,
  });

  final int id;
  final String name;
  final String country;
  final String league;
  final String slug;
  final String nickname;
  final String? logoUrl;

  factory ClubOverview.fromJson(Map<String, dynamic> json) {
    final logo = _stringValue(json['official_logo_url']);
    return ClubOverview(
      id: _intValue(json['id']),
      name: _stringValue(json['club_name']),
      country: _stringValue(json['country_name']),
      league: _stringValue(json['league']),
      slug: _stringValue(json['club_slug']),
      nickname: _stringValue(json['nickname_brand_identity']),
      logoUrl: logo.isEmpty ? null : logo,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    country,
    league,
    slug,
    nickname,
    logoUrl,
  ];
}

class ClubNewsItem extends Equatable {
  const ClubNewsItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.category,
    required this.author,
    required this.publishedAt,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final String body;
  final String category;
  final String author;
  final DateTime? publishedAt;
  final String? imageUrl;

  factory ClubNewsItem.fromJson(Map<String, dynamic> json) {
    final image = _stringValue(json['image_url']);
    return ClubNewsItem(
      id: _stringValue(json['id']),
      title: _stringValue(json['title']),
      subtitle: _stringValue(json['subtitle']),
      body: _stringValue(json['body']),
      category: _stringValue(json['category']),
      author: _stringValue(json['author_name']),
      publishedAt: _dateValue(json['published_at']),
      imageUrl: image.isEmpty ? null : image,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    title,
    subtitle,
    body,
    category,
    author,
    publishedAt,
    imageUrl,
  ];
}

class ClubSquadMember extends Equatable {
  const ClubSquadMember({
    required this.id,
    required this.name,
    required this.position,
    required this.shirtNumber,
    required this.nationality,
    required this.bio,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String position;
  final int shirtNumber;
  final String nationality;
  final String bio;
  final String? imageUrl;

  factory ClubSquadMember.fromJson(Map<String, dynamic> json) {
    final image = _stringValue(json['image_url'] ?? json['photo_url']);
    return ClubSquadMember(
      id: _stringValue(json['id']),
      name: _stringValue(json['name']),
      position: _stringValue(json['position']),
      shirtNumber: _intValue(json['shirt_number'] ?? json['number']),
      nationality: _stringValue(json['nationality']),
      bio: _stringValue(json['bio']),
      imageUrl: image.isEmpty ? null : image,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    position,
    shirtNumber,
    nationality,
    bio,
    imageUrl,
  ];
}

class ClubFixtureItem extends Equatable {
  const ClubFixtureItem({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.competition,
    required this.venue,
    required this.matchDate,
    required this.kickoffTime,
    required this.status,
    required this.homeScore,
    required this.awayScore,
    required this.isOnSale,
  });

  final String id;
  final String homeTeam;
  final String awayTeam;
  final String competition;
  final String venue;
  final DateTime? matchDate;
  final String kickoffTime;
  final String status;
  final int homeScore;
  final int awayScore;
  final bool isOnSale;

  bool get isCompleted {
    final normalized = status.toLowerCase();
    return normalized == 'completed' ||
        normalized == 'finished' ||
        normalized == 'full_time' ||
        normalized == 'ft';
  }

  factory ClubFixtureItem.fromJson(Map<String, dynamic> json) {
    return ClubFixtureItem(
      id: _stringValue(json['id']),
      homeTeam: _stringValue(json['home_team']),
      awayTeam: _stringValue(json['away_team']),
      competition: _stringValue(json['competition']),
      venue: _stringValue(json['venue']),
      matchDate: _dateValue(json['match_date']),
      kickoffTime: _stringValue(json['kickoff_time']),
      status: _stringValue(json['match_status'] ?? json['status']),
      homeScore: _intValue(json['home_score']),
      awayScore: _intValue(json['away_score']),
      isOnSale: json['is_on_sale'] == true,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    homeTeam,
    awayTeam,
    competition,
    venue,
    matchDate,
    kickoffTime,
    status,
    homeScore,
    awayScore,
    isOnSale,
  ];
}

class ClubStandingItem extends Equatable {
  const ClubStandingItem({
    required this.id,
    required this.position,
    required this.clubName,
    required this.played,
    required this.goalDifference,
    required this.points,
    required this.clubSlug,
  });

  final String id;
  final int position;
  final String clubName;
  final int played;
  final int goalDifference;
  final int points;
  final String clubSlug;

  factory ClubStandingItem.fromJson(Map<String, dynamic> json) {
    return ClubStandingItem(
      id: _stringValue(json['id']),
      position: _intValue(json['position']),
      clubName: _stringValue(json['club_name'] ?? json['team_name']),
      played: _intValue(json['played'] ?? json['matches_played']),
      goalDifference: _intValue(
        json['goal_difference'] ?? json['goal_diff'] ?? json['gd'],
      ),
      points: _intValue(json['points'] ?? json['pts']),
      clubSlug: _stringValue(json['club_slug']),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    position,
    clubName,
    played,
    goalDifference,
    points,
    clubSlug,
  ];
}

class ClubHistoryItem extends Equatable {
  const ClubHistoryItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.sortOrder,
  });

  final String id;
  final String title;
  final String subtitle;
  final String body;
  final int sortOrder;

  factory ClubHistoryItem.fromJson(Map<String, dynamic> json) {
    return ClubHistoryItem(
      id: _stringValue(json['id']),
      title: _stringValue(json['title']),
      subtitle: _stringValue(json['subtitle']),
      body: _stringValue(json['body']),
      sortOrder: _intValue(json['sort_order']),
    );
  }

  @override
  List<Object?> get props => <Object?>[id, title, subtitle, body, sortOrder];
}

class ClubProjectItem extends Equatable {
  const ClubProjectItem({
    required this.id,
    required this.name,
    required this.description,
    required this.currentTotal,
    required this.targetAmount,
    required this.memberCount,
  });

  final String id;
  final String name;
  final String description;
  final int currentTotal;
  final int targetAmount;
  final int memberCount;

  double get progress {
    if (targetAmount <= 0) return 0;
    return (currentTotal / targetAmount).clamp(0, 1).toDouble();
  }

  factory ClubProjectItem.fromJson(Map<String, dynamic> json) {
    return ClubProjectItem(
      id: _stringValue(json['id']),
      name: _stringValue(json['name']),
      description: _stringValue(json['description']),
      currentTotal: _intValue(json['current_total']),
      targetAmount: _intValue(json['target_amount']),
      memberCount: _intValue(json['member_count']),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    description,
    currentTotal,
    targetAmount,
    memberCount,
  ];
}
