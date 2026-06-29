import 'package:core_theme/core_theme.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart' show IconData;

import 'json_helpers.dart' as jh;

// ═══════════════════════════════════════════════════════════════
// Membership categories — official Gikundiro categories
// ═══════════════════════════════════════════════════════════════

enum FanTier { ingenziImanzi, inyamibwa, imena, bronze, silver, gold }

extension FanTierX on FanTier {
  static FanTier fromValue(String? value) {
    return switch ((value ?? '').toLowerCase()) {
      'ingenzi-imanzi' ||
      'ingenzi_imanzi' ||
      'ingenzi' ||
      'imanzi' => FanTier.ingenziImanzi,
      'inyamibwa' => FanTier.inyamibwa,
      'imena' => FanTier.imena,
      'bronze' => FanTier.bronze,
      'silver' => FanTier.silver,
      'gold' => FanTier.gold,
      _ => FanTier.imena,
    };
  }

  static FanTier fromPoints(int points) {
    if (points >= 5000) return FanTier.gold;
    if (points >= 2000) return FanTier.silver;
    if (points >= 1000) return FanTier.bronze;
    if (points >= 500) return FanTier.imena;
    if (points >= 250) return FanTier.inyamibwa;
    return FanTier.ingenziImanzi;
  }

  String get value => switch (this) {
    FanTier.ingenziImanzi => 'ingenzi-imanzi',
    FanTier.inyamibwa => 'inyamibwa',
    FanTier.imena => 'imena',
    FanTier.bronze => 'bronze',
    FanTier.silver => 'silver',
    FanTier.gold => 'gold',
  };

  String get label => switch (this) {
    FanTier.ingenziImanzi => 'Ingenzi / Imanzi',
    FanTier.inyamibwa => 'Inyamibwa',
    FanTier.imena => 'Imena',
    FanTier.bronze => 'Bronze',
    FanTier.silver => 'Silver',
    FanTier.gold => 'Gold',
  };

  IconData get icon => switch (this) {
    FanTier.ingenziImanzi => AfriIcons.membership,
    FanTier.inyamibwa => AfriIcons.members,
    FanTier.imena => AfriIcons.verified,
    FanTier.bronze => AfriIcons.premium,
    FanTier.silver => AfriIcons.rank,
    FanTier.gold => AfriIcons.diamond,
  };

  int get minPoints => switch (this) {
    FanTier.ingenziImanzi => 0,
    FanTier.inyamibwa => 250,
    FanTier.imena => 500,
    FanTier.bronze => 1000,
    FanTier.silver => 2000,
    FanTier.gold => 5000,
  };

  double get membershipDiscount => switch (this) {
    FanTier.ingenziImanzi => 0,
    FanTier.inyamibwa => 5,
    FanTier.imena => 10,
    FanTier.bronze => 0,
    FanTier.silver => 0,
    FanTier.gold => 0,
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

enum TicketStatus {
  pending,
  active,
  used,
  expired,
  cancelled,
  voided,
  refunded,
}

extension TicketStatusX on TicketStatus {
  static TicketStatus fromValue(String? value) {
    return switch ((value ?? '').toLowerCase()) {
      'pending' => TicketStatus.pending,
      'valid' || 'active' => TicketStatus.active,
      'used' => TicketStatus.used,
      'expired' => TicketStatus.expired,
      'cancelled' => TicketStatus.cancelled,
      'voided' => TicketStatus.voided,
      'refunded' => TicketStatus.refunded,
      _ => TicketStatus.pending,
    };
  }

  String get value => name;

  String get label => switch (this) {
    TicketStatus.pending => 'Pending verification',
    TicketStatus.active => 'Valid',
    TicketStatus.used => 'Used',
    TicketStatus.expired => 'Expired',
    TicketStatus.cancelled => 'Cancelled',
    TicketStatus.voided => 'Voided',
    TicketStatus.refunded => 'Refunded',
  };
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
    FetEventType.inviteFriends => 'Invite 3 Friends',
    FetEventType.shopPurchase => 'Shop Purchase',
    FetEventType.completeProfile => 'Complete Profile',
    FetEventType.weekStreak => '7-Day Streak',
    FetEventType.monthStreak => '30-Day Streak',
  };

  IconData get icon => switch (this) {
    FetEventType.dailyOpen => AfriIcons.today,
    FetEventType.matchAttendance => AfriIcons.stadium,
    FetEventType.contribution => AfriIcons.contribute,
    FetEventType.inviteFriends => AfriIcons.campaign,
    FetEventType.shopPurchase => AfriIcons.shop,
    FetEventType.completeProfile => AfriIcons.statusSuccess,
    FetEventType.weekStreak => AfriIcons.streak,
    FetEventType.monthStreak => AfriIcons.diamond,
  };

  String get frequency => switch (this) {
    FetEventType.dailyOpen => 'Once per day',
    FetEventType.matchAttendance => 'Per match',
    FetEventType.contribution => 'Per transaction',
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
// Contribution Group Types
// ═══════════════════════════════════════════════════════════════

enum ContributionGroupType { project, community }

extension ContributionGroupTypeX on ContributionGroupType {
  static ContributionGroupType fromValue(String? value) {
    return switch ((value ?? '').toLowerCase()) {
      'project' || 'club' || 'team_project' => ContributionGroupType.project,
      'community' => ContributionGroupType.community,
      'general' ||
      'savings' ||
      'emergency' ||
      'fan_group' ||
      'fangroup' => ContributionGroupType.community,
      _ => ContributionGroupType.community,
    };
  }

  String get value => switch (this) {
    ContributionGroupType.project => 'project',
    ContributionGroupType.community => 'community',
  };

  String get label => switch (this) {
    ContributionGroupType.project => 'Team Project',
    ContributionGroupType.community => 'Community',
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
