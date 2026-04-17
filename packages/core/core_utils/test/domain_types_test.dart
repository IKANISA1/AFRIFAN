import 'package:core_utils/core_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for AfriClub domain types, enums, and validation logic.
///
/// Covers: FanTier, TicketStatus, SeatType, OrderStatus, ProductCategory,
/// FetEventType, and ContributionGroupType.
void main() {
  // ═══════════════════════════════════════════════════════════
  // FAN TIER — Gamification Levels
  // ═══════════════════════════════════════════════════════════

  group('FanTier', () {
    test('fromValue parses canonical values', () {
      expect(FanTierX.fromValue('fan'), FanTier.fan);
      expect(FanTierX.fromValue('bronze'), FanTier.bronze);
      expect(FanTierX.fromValue('gold'), FanTier.gold);
      expect(FanTierX.fromValue('platinum'), FanTier.platinum);
    });

    test('fromValue handles ', () {
      expect(FanTierX.fromValue('blue'), FanTier.fan);
      expect(FanTierX.fromValue('silver'), FanTier.bronze);
    });

    test('fromValue defaults to fan for unknown input', () {
      expect(FanTierX.fromValue('diamond'), FanTier.fan);
      expect(FanTierX.fromValue(null), FanTier.fan);
      expect(FanTierX.fromValue(''), FanTier.fan);
    });

    test('fromPoints returns correct tier boundaries', () {
      expect(FanTierX.fromPoints(0), FanTier.fan);
      expect(FanTierX.fromPoints(999), FanTier.fan);
      expect(FanTierX.fromPoints(1000), FanTier.bronze);
      expect(FanTierX.fromPoints(1999), FanTier.bronze);
      expect(FanTierX.fromPoints(2000), FanTier.gold);
      expect(FanTierX.fromPoints(4999), FanTier.gold);
      expect(FanTierX.fromPoints(5000), FanTier.platinum);
      expect(FanTierX.fromPoints(99999), FanTier.platinum);
    });

    test('value round-trips correctly', () {
      for (final tier in FanTier.values) {
        expect(FanTierX.fromValue(tier.value), tier);
      }
    });

    test('minPoints are monotonically increasing', () {
      final minPoints = FanTier.values.map((t) => t.minPoints).toList();
      for (var i = 1; i < minPoints.length; i++) {
        expect(
          minPoints[i],
          greaterThan(minPoints[i - 1]),
          reason:
              '${FanTier.values[i].name} minPoints should > ${FanTier.values[i - 1].name}',
        );
      }
    });

    test('membershipDiscount is non-negative', () {
      for (final tier in FanTier.values) {
        expect(tier.membershipDiscount, greaterThanOrEqualTo(0));
      }
    });
  });

  // ═══════════════════════════════════════════════════════════
  // TICKET STATUS
  // ═══════════════════════════════════════════════════════════

  group('TicketStatus', () {
    test('fromValue parses all canonical values', () {
      expect(TicketStatusX.fromValue('pending'), TicketStatus.pending);
      expect(TicketStatusX.fromValue('valid'), TicketStatus.active);
      expect(TicketStatusX.fromValue('active'), TicketStatus.active);
      expect(TicketStatusX.fromValue('used'), TicketStatus.used);
      expect(TicketStatusX.fromValue('expired'), TicketStatus.expired);
      expect(TicketStatusX.fromValue('cancelled'), TicketStatus.cancelled);
    });

    test('fromValue defaults to pending for unknown', () {
      expect(TicketStatusX.fromValue('invalid'), TicketStatus.pending);
      expect(TicketStatusX.fromValue(null), TicketStatus.pending);
    });

    test('value round-trips', () {
      for (final status in TicketStatus.values) {
        expect(TicketStatusX.fromValue(status.value), status);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════
  // SEAT TYPE
  // ═══════════════════════════════════════════════════════════

  group('SeatType', () {
    test('fromValue parses correctly', () {
      expect(SeatTypeX.fromValue('general'), SeatType.general);
      expect(SeatTypeX.fromValue('vip'), SeatType.vip);
    });

    test('fromValue defaults to general', () {
      expect(SeatTypeX.fromValue('premium'), SeatType.general);
      expect(SeatTypeX.fromValue(null), SeatType.general);
    });

    test('label is human-readable', () {
      expect(SeatType.general.label, 'General');
      expect(SeatType.vip.label, 'VIP');
    });
  });

  // ═══════════════════════════════════════════════════════════
  // ORDER STATUS
  // ═══════════════════════════════════════════════════════════

  group('OrderStatus', () {
    test('fromValue parses all values', () {
      expect(OrderStatusX.fromValue('pending'), OrderStatus.pending);
      expect(OrderStatusX.fromValue('confirmed'), OrderStatus.confirmed);
      expect(OrderStatusX.fromValue('processing'), OrderStatus.processing);
      expect(OrderStatusX.fromValue('completed'), OrderStatus.completed);
      expect(OrderStatusX.fromValue('cancelled'), OrderStatus.cancelled);
    });

    test('fromValue defaults to pending', () {
      expect(OrderStatusX.fromValue('unknown'), OrderStatus.pending);
      expect(OrderStatusX.fromValue(null), OrderStatus.pending);
    });

    test('label is capitalized', () {
      expect(OrderStatus.pending.label, 'Pending');
      expect(OrderStatus.completed.label, 'Completed');
    });
  });

  // ═══════════════════════════════════════════════════════════
  // PRODUCT CATEGORY
  // ═══════════════════════════════════════════════════════════

  group('ProductCategory', () {
    test('fromValue parses all values', () {
      expect(ProductCategoryX.fromValue('jersey'), ProductCategory.jersey);
      expect(ProductCategoryX.fromValue('scarf'), ProductCategory.scarf);
      expect(ProductCategoryX.fromValue('cap'), ProductCategory.cap);
    });

    test('fromValue defaults to other', () {
      expect(ProductCategoryX.fromValue('shoes'), ProductCategory.other);
      expect(ProductCategoryX.fromValue(null), ProductCategory.other);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // FET EVENT TYPE — Gamification
  // ═══════════════════════════════════════════════════════════

  group('FetEventType', () {
    test('all event types have positive FET rewards', () {
      for (final type in FetEventType.values) {
        expect(
          type.fetReward,
          greaterThan(0),
          reason: '${type.name} should award positive FET',
        );
      }
    });

    test('fromKey round-trips for all types', () {
      for (final type in FetEventType.values) {
        expect(FetEventTypeX.fromKey(type.eventKey), type);
      }
    });

    test('fromKey returns null for unknown keys', () {
      expect(FetEventTypeX.fromKey('nonexistent'), isNull);
    });

    test('streak rewards are higher than daily', () {
      expect(
        FetEventType.weekStreak.fetReward,
        greaterThan(FetEventType.dailyOpen.fetReward),
      );
      expect(
        FetEventType.monthStreak.fetReward,
        greaterThan(FetEventType.weekStreak.fetReward),
      );
    });

    test('eventKey format is snake_case', () {
      for (final type in FetEventType.values) {
        expect(
          type.eventKey,
          matches(RegExp(r'^[a-z_]+$')),
          reason: '${type.name} eventKey should be snake_case',
        );
      }
    });
  });

  // ═══════════════════════════════════════════════════════════
  // FET EVENT MODEL
  // ═══════════════════════════════════════════════════════════

  group('FetEvent.fromJson', () {
    test('parses valid JSON', () {
      final event = FetEvent.fromJson({
        'id': 'event-1',
        'user_id': 'user-1',
        'event_type': 'daily_open',
        'fet_awarded': 10,
        'event_at': '2025-01-01T00:00:00Z',
      });
      expect(event.id, 'event-1');
      expect(event.userId, 'user-1');
      expect(event.eventType, FetEventType.dailyOpen);
      expect(event.fetAwarded, 10);
    });

    test('handles null/missing fields gracefully', () {
      final event = FetEvent.fromJson({
        'id': null,
        'user_id': null,
        'event_type': null,
        'fet_awarded': 0,
        'event_at': null,
      });
      expect(event.id, '');
      expect(event.eventType, FetEventType.dailyOpen);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // CONTRIBUTION GROUP TYPE
  // ═══════════════════════════════════════════════════════════

  group('ContributionGroupType', () {
    test('fromValue parses all values', () {
      expect(
        ContributionGroupTypeX.fromValue('club'),
        ContributionGroupType.project,
      );
      expect(
        ContributionGroupTypeX.fromValue('community'),
        ContributionGroupType.community,
      );
      expect(
        ContributionGroupTypeX.fromValue('savings'),
        ContributionGroupType.community,
      );
      expect(
        ContributionGroupTypeX.fromValue('fan_Group'),
        ContributionGroupType.community,
      );
      expect(
        ContributionGroupTypeX.fromValue('fanGroup'),
        ContributionGroupType.community,
      );
    });

    test('fromValue defaults to community', () {
      expect(
        ContributionGroupTypeX.fromValue('unknown'),
        ContributionGroupType.community,
      );
    });

    test('value round-trips', () {
      for (final type in ContributionGroupType.values) {
        expect(ContributionGroupTypeX.fromValue(type.value), type);
      }
    });
  });
}
