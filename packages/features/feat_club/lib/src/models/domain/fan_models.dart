import 'package:core_utils/core_utils.dart' as jh;
import 'package:equatable/equatable.dart';

const Object _unset = Object();

/// Universal fan membership — white-label, club-agnostic.
class FanMembership extends Equatable {
  const FanMembership({
    this.id = '',
    required this.userId,
    required this.partnerId,
    this.displayName = 'Fan',
    required this.tier,
    required this.points,
    required this.chapter,
    required this.membershipNumber,
    required this.joinedAt,
    this.expiresAt,
    this.renewedAt,
  });

  final String id;
  final String userId;
  final String partnerId;
  final String displayName;
  final jh.FanTier tier;
  final int points;
  final String chapter;
  final String membershipNumber;
  final DateTime joinedAt;
  final DateTime? expiresAt;
  final DateTime? renewedAt;

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  int get nextTierPoints => switch (tier) {
        jh.FanTier.fan => 1000,
        jh.FanTier.bronze => 2000,
        jh.FanTier.gold => 5000,
        jh.FanTier.platinum => points,
      };

  int get pointsToNextTier => switch (tier) {
        jh.FanTier.platinum => 0,
        _ => (nextTierPoints - points).clamp(0, nextTierPoints),
      };

  double get progressToNextTier {
    if (tier == jh.FanTier.platinum) return 1;
    final floor = tier.minPoints;
    final span = nextTierPoints - floor;
    if (span <= 0) return 1;
    return ((points - floor) / span).clamp(0, 1).toDouble();
  }

  factory FanMembership.fromJson(Map<String, dynamic> json) {
    final points = jh.asInt(json['points']);
    final tier = json['tier'] == null
        ? jh.FanTierX.fromPoints(points)
        : jh.FanTierX.fromValue(json['tier']?.toString());

    return FanMembership(
      id: jh.asStringOrNull(json['id']) ?? '',
      userId: jh.asStringOrNull(json['user_id']) ?? '',
      partnerId: jh.asStringOrNull(json['partner_id']) ?? '',
      displayName: jh.asStringOrNull(json['display_name']) ?? 'Fan',
      tier: tier,
      points: points,
      chapter: jh.asStringOrNull(json['chapter']) ?? 'Main',
      membershipNumber: jh.asStringOrNull(json['membership_number']) ?? '',
      joinedAt: jh.parseDateTime(json['joined_at']) ?? DateTime.now(),
      expiresAt: jh.parseDateTime(json['expires_at']),
      renewedAt: jh.parseDateTime(json['renewed_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'partner_id': partnerId,
        'display_name': displayName,
        'tier': tier.value,
        'points': points,
        'chapter': chapter,
        'membership_number': membershipNumber,
        'joined_at': joinedAt.toIso8601String(),
        if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
        if (renewedAt != null) 'renewed_at': renewedAt!.toIso8601String(),
      };

  FanMembership copyWith({
    String? id,
    String? userId,
    String? partnerId,
    String? displayName,
    jh.FanTier? tier,
    int? points,
    String? chapter,
    String? membershipNumber,
    DateTime? joinedAt,
    Object? expiresAt = _unset,
    Object? renewedAt = _unset,
  }) {
    return FanMembership(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      partnerId: partnerId ?? this.partnerId,
      displayName: displayName ?? this.displayName,
      tier: tier ?? this.tier,
      points: points ?? this.points,
      chapter: chapter ?? this.chapter,
      membershipNumber: membershipNumber ?? this.membershipNumber,
      joinedAt: joinedAt ?? this.joinedAt,
      expiresAt: identical(expiresAt, _unset)
          ? this.expiresAt
          : expiresAt as DateTime?,
      renewedAt: identical(renewedAt, _unset)
          ? this.renewedAt
          : renewedAt as DateTime?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        partnerId,
        displayName,
        tier,
        points,
        chapter,
        membershipNumber,
        joinedAt,
        expiresAt,
        renewedAt,
      ];
}

class FanClub extends Equatable {
  const FanClub({
    required this.id,
    required this.partnerId,
    required this.name,
    required this.region,
    required this.description,
    required this.memberCount,
    required this.eventCount,
    required this.rating,
    this.bannerImageUrl,
  });

  final String id;
  final String partnerId;
  final String name;
  final String region;
  final String description;
  final int memberCount;
  final int eventCount;
  final double rating;
  final String? bannerImageUrl;

  factory FanClub.fromJson(Map<String, dynamic> json) {
    return FanClub(
      id: jh.asStringOrNull(json['id']) ?? '',
      partnerId: jh.asStringOrNull(json['partner_id']) ?? '',
      name: jh.asStringOrNull(json['name']) ?? '',
      region: jh.asStringOrNull(json['region']) ?? '',
      description: jh.asStringOrNull(json['description']) ?? '',
      memberCount: jh.asInt(json['member_count']),
      eventCount: jh.asInt(json['event_count']),
      rating: jh.asDouble(json['rating']),
      bannerImageUrl: jh.asStringOrNull(json['banner_image_url']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'partner_id': partnerId,
        'name': name,
        'region': region,
        'description': description,
        'member_count': memberCount,
        'event_count': eventCount,
        'rating': rating,
        'banner_image_url': bannerImageUrl,
      };

  @override
  List<Object?> get props => [id, partnerId, name, region];
}
