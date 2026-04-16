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

enum FetEventType {
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

extension FetEventTypeX on FetEventType {
  int get fetReward => switch (this) {
    FetEventType.dailyOpen => 10,
    FetEventType.matchAttendance => 500,
    FetEventType.contribution => 50,
    FetEventType.createGroup => 200,
    FetEventType.inviteFriends => 150,
    FetEventType.shopPurchase => 100,
    FetEventType.completeProfile => 300,
    FetEventType.weekStreak => 250,
    FetEventType.monthStreak => 1000,
  };

  String get label => switch (this) {
    FetEventType.dailyOpen => 'Daily Check-In',
    FetEventType.matchAttendance => 'Match Attendance',
    FetEventType.contribution => 'Make Contribution',
    FetEventType.createGroup => 'Create Group',
    FetEventType.inviteFriends => 'Invite 3 Friends',
    FetEventType.shopPurchase => 'Shop Purchase',
    FetEventType.completeProfile => 'Complete Profile',
    FetEventType.weekStreak => '7-Day Streak',
    FetEventType.monthStreak => '30-Day Streak',
  };

  IconData get icon => switch (this) {
    FetEventType.dailyOpen => Icons.today_rounded,
    FetEventType.matchAttendance => Icons.stadium_rounded,
    FetEventType.contribution => Icons.volunteer_activism_rounded,
    FetEventType.createGroup => Icons.groups_rounded,
    FetEventType.inviteFriends => Icons.campaign_rounded,
    FetEventType.shopPurchase => Icons.shopping_bag_rounded,
    FetEventType.completeProfile => Icons.check_circle_rounded,
    FetEventType.weekStreak => Icons.local_fire_department_rounded,
    FetEventType.monthStreak => Icons.diamond_rounded,
  };

  String get frequency => switch (this) {
    FetEventType.dailyOpen => 'Once per day',
    FetEventType.matchAttendance => 'Per match',
    FetEventType.contribution => 'Per transaction',
    FetEventType.createGroup => 'Per creation',
    FetEventType.inviteFriends => 'Per 3 invites',
    FetEventType.shopPurchase => 'Per purchase',
    FetEventType.completeProfile => 'One-time',
    FetEventType.weekStreak => 'Per week',
    FetEventType.monthStreak => 'Per month',
  };

  String get eventKey => switch (this) {
    FetEventType.dailyOpen => 'daily_open',
    FetEventType.matchAttendance => 'match_attendance',
    FetEventType.contribution => 'contribution',
    FetEventType.createGroup => 'create_group',
    FetEventType.inviteFriends => 'invite_friends',
    FetEventType.shopPurchase => 'shop_purchase',
    FetEventType.completeProfile => 'complete_profile',
    FetEventType.weekStreak => 'week_streak',
    FetEventType.monthStreak => 'month_streak',
  };

  static FetEventType? fromKey(String key) {
    for (final type in FetEventType.values) {
      if (type.eventKey == key) return type;
    }
    return null;
  }
}

/// A single FET event log entry.
class FetEvent extends Equatable {
  const FetEvent({
    required this.id,
    required this.userId,
    required this.eventType,
    required this.fetAwarded,
    required this.eventAt,
    this.metadata,
  });

  final String id;
  final String userId;
  final FetEventType eventType;
  final int fetAwarded;
  final DateTime eventAt;
  final Map<String, Object?>? metadata;

  factory FetEvent.fromJson(Map<String, dynamic> json) {
    return FetEvent(
      id: jh.asStringOrNull(json['id']) ?? '',
      userId: jh.asStringOrNull(json['user_id']) ?? '',
      eventType:
          FetEventTypeX.fromKey(jh.asStringOrNull(json['event_type']) ?? '') ??
          FetEventType.dailyOpen,
      fetAwarded: jh.asInt(json['fet_awarded']),
      eventAt: jh.parseDateTime(json['event_at']) ?? DateTime.now(),
      metadata: jh.asMapOrNull(json['metadata']),
    );
  }

  @override
  List<Object?> get props => [id, userId, eventType, fetAwarded, eventAt];
}

// ═══════════════════════════════════════════════════════════════
// Contribution Group Types & Privacy
// ═══════════════════════════════════════════════════════════════

enum ContributionGroupType { club, community, savings, fanGroup }

extension ContributionGroupTypeX on ContributionGroupType {
  static ContributionGroupType fromValue(String? value) {
    return switch ((value ?? '').toLowerCase()) {
      'club' => ContributionGroupType.club,
      'community' => ContributionGroupType.community,
      'savings' => ContributionGroupType.savings,
      'fan_Group' || 'fanGroup' => ContributionGroupType.fanGroup,
      _ => ContributionGroupType.community,
    };
  }

  String get value => switch (this) {
    ContributionGroupType.club => 'club',
    ContributionGroupType.community => 'community',
    ContributionGroupType.savings => 'savings',
    ContributionGroupType.fanGroup => 'fan_Group',
  };

  String get label => switch (this) {
    ContributionGroupType.club => 'Club Project',
    ContributionGroupType.community => 'Community Group',
    ContributionGroupType.savings => 'Public Savings',
    ContributionGroupType.fanGroup => 'Fan Group',
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
