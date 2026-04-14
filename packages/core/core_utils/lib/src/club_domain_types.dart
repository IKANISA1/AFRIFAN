import 'package:core_utils/core_utils.dart' as jh;
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
// Fan Tier — Gamification levels
// ═══════════════════════════════════════════════════════════════

enum FanTier { fan, bronze, gold, platinum }

extension FanTierX on FanTier {
  static FanTier fromValue(String? value) {
    return switch ((value ?? '').toLowerCase()) {
      'fan' || 'blue' => FanTier.fan,
      'bronze' || 'silver' => FanTier.bronze,
      'gold' => FanTier.gold,
      'platinum' => FanTier.platinum,
      _ => FanTier.fan,
    };
  }

  static FanTier fromPoints(int points) {
    if (points >= 5000) return FanTier.platinum;
    if (points >= 2000) return FanTier.gold;
    if (points >= 1000) return FanTier.bronze;
    return FanTier.fan;
  }

  String get value => switch (this) {
    FanTier.fan => 'fan',
    FanTier.bronze => 'bronze',
    FanTier.gold => 'gold',
    FanTier.platinum => 'platinum',
  };

  String get label => switch (this) {
    FanTier.fan => 'Fan',
    FanTier.bronze => 'Bronze',
    FanTier.gold => 'Gold',
    FanTier.platinum => 'Platinum',
  };

  IconData get icon => switch (this) {
    FanTier.fan => Icons.sports_soccer_rounded,
    FanTier.bronze => Icons.workspace_premium_rounded,
    FanTier.gold => Icons.emoji_events_rounded,
    FanTier.platinum => Icons.diamond_rounded,
  };

  int get minPoints => switch (this) {
    FanTier.fan => 0,
    FanTier.bronze => 1000,
    FanTier.gold => 2000,
    FanTier.platinum => 5000,
  };

  double get membershipDiscount => switch (this) {
    FanTier.fan => 0,
    FanTier.bronze => 5,
    FanTier.gold => 10,
    FanTier.platinum => 15,
  };
}

// ═══════════════════════════════════════════════════════════════
// Order / Ticket / Seat statuses
// ═══════════════════════════════════════════════════════════════

enum OrderStatus { pending, confirmed, processing, completed, cancelled }

extension OrderStatusX on OrderStatus {
  static OrderStatus fromValue(String? value) {
    return switch ((value ?? '').toLowerCase()) {
      'confirmed' => OrderStatus.confirmed,
      'processing' => OrderStatus.processing,
      'completed' => OrderStatus.completed,
      'cancelled' => OrderStatus.cancelled,
      _ => OrderStatus.pending,
    };
  }

  String get value => name;
  String get label => '${name[0].toUpperCase()}${name.substring(1)}';
}

enum TicketStatus { active, used, expired, cancelled }

extension TicketStatusX on TicketStatus {
  static TicketStatus fromValue(String? value) {
    return switch ((value ?? '').toLowerCase()) {
      'used' => TicketStatus.used,
      'expired' => TicketStatus.expired,
      'cancelled' => TicketStatus.cancelled,
      _ => TicketStatus.active,
    };
  }

  String get value => name;
}

enum SeatType { general, vip }

extension SeatTypeX on SeatType {
  static SeatType fromValue(String? value) {
    return switch ((value ?? '').toLowerCase()) {
      'vip' => SeatType.vip,
      _ => SeatType.general,
    };
  }

  String get value => name;
  String get label => switch (this) {
    SeatType.general => 'General',
    SeatType.vip => 'VIP',
  };
}

enum ProductCategory { jersey, scarf, cap, accessory, collectible, other }

extension ProductCategoryX on ProductCategory {
  static ProductCategory fromValue(String? value) {
    return switch ((value ?? '').toLowerCase()) {
      'jersey' => ProductCategory.jersey,
      'scarf' => ProductCategory.scarf,
      'cap' => ProductCategory.cap,
      'accessory' => ProductCategory.accessory,
      'collectible' => ProductCategory.collectible,
      _ => ProductCategory.other,
    };
  }

  String get value => name;
  String get label => '${name[0].toUpperCase()}${name.substring(1)}';
}

// ═══════════════════════════════════════════════════════════════
// FET Event Types — Gamification engine
// ═══════════════════════════════════════════════════════════════

enum XpEventType {
  dailyOpen,
  matchAttendance,
  contribution,
  createGroup,
  inviteFriends,
  shopPurchase,
  completeProfile,
  weekStreak,
  monthStreak,
}

extension XpEventTypeX on XpEventType {
  int get xpReward => switch (this) {
    XpEventType.dailyOpen => 10,
    XpEventType.matchAttendance => 500,
    XpEventType.contribution => 50,
    XpEventType.createGroup => 200,
    XpEventType.inviteFriends => 150,
    XpEventType.shopPurchase => 100,
    XpEventType.completeProfile => 300,
    XpEventType.weekStreak => 250,
    XpEventType.monthStreak => 1000,
  };

  String get label => switch (this) {
    XpEventType.dailyOpen => 'Daily Check-In',
    XpEventType.matchAttendance => 'Match Attendance',
    XpEventType.contribution => 'Make Contribution',
    XpEventType.createGroup => 'Create Circle',
    XpEventType.inviteFriends => 'Invite 3 Friends',
    XpEventType.shopPurchase => 'Shop Purchase',
    XpEventType.completeProfile => 'Complete Profile',
    XpEventType.weekStreak => '7-Day Streak',
    XpEventType.monthStreak => '30-Day Streak',
  };

  IconData get icon => switch (this) {
    XpEventType.dailyOpen => Icons.today_rounded,
    XpEventType.matchAttendance => Icons.stadium_rounded,
    XpEventType.contribution => Icons.volunteer_activism_rounded,
    XpEventType.createGroup => Icons.groups_rounded,
    XpEventType.inviteFriends => Icons.campaign_rounded,
    XpEventType.shopPurchase => Icons.shopping_bag_rounded,
    XpEventType.completeProfile => Icons.check_circle_rounded,
    XpEventType.weekStreak => Icons.local_fire_department_rounded,
    XpEventType.monthStreak => Icons.diamond_rounded,
  };

  String get frequency => switch (this) {
    XpEventType.dailyOpen => 'Once per day',
    XpEventType.matchAttendance => 'Per match',
    XpEventType.contribution => 'Per transaction',
    XpEventType.createGroup => 'Per creation',
    XpEventType.inviteFriends => 'Per 3 invites',
    XpEventType.shopPurchase => 'Per purchase',
    XpEventType.completeProfile => 'One-time',
    XpEventType.weekStreak => 'Per week',
    XpEventType.monthStreak => 'Per month',
  };

  String get eventKey => switch (this) {
    XpEventType.dailyOpen => 'daily_open',
    XpEventType.matchAttendance => 'match_attendance',
    XpEventType.contribution => 'contribution',
    XpEventType.createGroup => 'create_group',
    XpEventType.inviteFriends => 'invite_friends',
    XpEventType.shopPurchase => 'shop_purchase',
    XpEventType.completeProfile => 'complete_profile',
    XpEventType.weekStreak => 'week_streak',
    XpEventType.monthStreak => 'month_streak',
  };

  static XpEventType? fromKey(String key) {
    for (final type in XpEventType.values) {
      if (type.eventKey == key) return type;
    }
    return null;
  }
}

/// A single FET event log entry.
class XpEvent extends Equatable {
  const XpEvent({
    required this.id,
    required this.userId,
    required this.eventType,
    required this.xpAwarded,
    required this.eventAt,
    this.metadata,
  });

  final String id;
  final String userId;
  final XpEventType eventType;
  final int xpAwarded;
  final DateTime eventAt;
  final Map<String, Object?>? metadata;

  factory XpEvent.fromJson(Map<String, dynamic> json) {
    return XpEvent(
      id: jh.asStringOrNull(json['id']) ?? '',
      userId: jh.asStringOrNull(json['user_id']) ?? '',
      eventType:
          XpEventTypeX.fromKey(jh.asStringOrNull(json['event_type']) ?? '') ??
          XpEventType.dailyOpen,
      xpAwarded: jh.asInt(json['xp_awarded']),
      eventAt: jh.parseDateTime(json['event_at']) ?? DateTime.now(),
      metadata: jh.asMapOrNull(json['metadata']),
    );
  }

  @override
  List<Object?> get props => [id, userId, eventType, xpAwarded, eventAt];
}

// ═══════════════════════════════════════════════════════════════
// Contribution Group Types & Privacy
// ═══════════════════════════════════════════════════════════════

enum ContributionGroupType { club, community, savings, fanCircle }

extension ContributionGroupTypeX on ContributionGroupType {
  static ContributionGroupType fromValue(String? value) {
    return switch ((value ?? '').toLowerCase()) {
      'club' => ContributionGroupType.club,
      'community' => ContributionGroupType.community,
      'savings' => ContributionGroupType.savings,
      'fan_circle' || 'fancircle' => ContributionGroupType.fanCircle,
      _ => ContributionGroupType.community,
    };
  }

  String get value => switch (this) {
    ContributionGroupType.club => 'club',
    ContributionGroupType.community => 'community',
    ContributionGroupType.savings => 'savings',
    ContributionGroupType.fanCircle => 'fan_circle',
  };

  String get label => switch (this) {
    ContributionGroupType.club => 'Club Project',
    ContributionGroupType.community => 'Community Circle',
    ContributionGroupType.savings => 'Public Savings',
    ContributionGroupType.fanCircle => 'Fan Circle',
  };
}

enum GroupPrivacy { public, friends, private_ }

extension GroupPrivacyX on GroupPrivacy {
  static GroupPrivacy fromValue(String? value) {
    return switch ((value ?? '').toLowerCase()) {
      'public' => GroupPrivacy.public,
      'friends' => GroupPrivacy.friends,
      'private' => GroupPrivacy.private_,
      _ => GroupPrivacy.public,
    };
  }

  String get value => switch (this) {
    GroupPrivacy.public => 'public',
    GroupPrivacy.friends => 'friends',
    GroupPrivacy.private_ => 'private',
  };
}

// ═══════════════════════════════════════════════════════════════
// Payment Status — RB-4 Verification Integrity
// ═══════════════════════════════════════════════════════════════

enum PaymentStatus { pendingVerification, verified, failed }

extension PaymentStatusX on PaymentStatus {
  static PaymentStatus fromValue(String? value) {
    return switch ((value ?? '').toLowerCase()) {
      'verified' => PaymentStatus.verified,
      'failed' => PaymentStatus.failed,
      'pending_verification' => PaymentStatus.pendingVerification,
      _ => PaymentStatus.verified, // Default backward compatibility
    };
  }

  String get value => switch (this) {
    PaymentStatus.pendingVerification => 'pending_verification',
    PaymentStatus.verified => 'verified',
    PaymentStatus.failed => 'failed',
  };

  String get label => switch (this) {
    PaymentStatus.pendingVerification => 'Pending Verification',
    PaymentStatus.verified => 'Verified',
    PaymentStatus.failed => 'Failed',
  };
}
