import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContributionGroup', () {
    test('fromJson parses complete initiative with is_active schema', () {
      final group = ContributionGroup.fromJson(<String, dynamic>{
        'id': 'grp-1',
        'creator_id': 'user-1',
        'name': 'Bus Fund',
        'description': 'Team transport',
        'group_type': 'community',
        'target_amount': 500000,
        'current_total': 250000,
        'momo_recipient_code': '0781234567',
        'momo_route_type': 'phone_number',
        'deadline': '2026-06-01T00:00:00.000Z',
        'is_recurring': false,
        'is_active': true,
        'member_count': 45,
        'created_at': '2026-01-15T08:00:00.000Z',
      });

      expect(group.id, 'grp-1');
      expect(group.creatorId, 'user-1');
      expect(group.name, 'Bus Fund');
      expect(group.targetAmount, 500000);
      expect(group.currentTotal, 250000);
      expect(group.paymentRecipient, '0781234567');
      expect(group.paymentRecipientType, PaymentRecipientType.phoneNumber);
      expect(group.isClosed, isFalse);
      expect(group.memberCount, 45);
    });

    test('legacy is_closed and is_active map to isClosed', () {
      final closed = ContributionGroup.fromJson(<String, dynamic>{
        'id': 'grp-2',
        'creator_id': 'user-2',
        'name': 'Old Fund',
        'is_closed': true,
        'created_at': '2025-06-01T00:00:00.000Z',
      });
      final inactive = ContributionGroup.fromJson(<String, dynamic>{
        'id': 'grp-3',
        'creator_id': 'user-3',
        'name': 'Inactive',
        'is_active': false,
        'created_at': '2025-06-01T00:00:00.000Z',
      });

      expect(closed.isClosed, isTrue);
      expect(inactive.isClosed, isTrue);
    });

    test('progress and remaining are computed from totals', () {
      final group = ContributionGroup(
        id: 'g1',
        creatorId: 'c1',
        name: 'Test',
        targetAmount: 100000,
        currentTotal: 75000,
        createdAt: DateTime(2026),
      );

      expect(group.progress, 0.75);
      expect(group.remaining, 25000);
    });

    test('expired initiatives depend on deadline', () {
      final expired = ContributionGroup(
        id: 'g6',
        creatorId: 'c6',
        name: 'Expired',
        deadline: DateTime(2020),
        createdAt: DateTime(2019),
      );
      final openEnded = ContributionGroup(
        id: 'g7',
        creatorId: 'c7',
        name: 'No Deadline',
        createdAt: DateTime(2026),
      );

      expect(expired.isExpired, isTrue);
      expect(openEnded.isExpired, isFalse);
    });

    test('toInsertJson keeps admin-managed initiative fields only', () {
      final group = ContributionGroup(
        id: 'g8',
        creatorId: 'c8',
        name: 'Insert Test',
        description: 'Test desc',
        targetAmount: 50000,
        paymentRecipient: '0781111111',
        isRecurring: true,
        deadline: DateTime(2026, 6, 1),
        createdAt: DateTime(2026),
      );

      final json = group.toInsertJson();
      expect(json['name'], 'Insert Test');
      expect(json['description'], 'Test desc');
      expect(json['target_amount'], 50000);
      expect(json['receiving_momo_code'], '0781111111');
      expect(json['is_recurring'], isTrue);
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('creator_id'), isFalse);
    });

    test('equatable compares key fields', () {
      final a = ContributionGroup(
        id: 'eq-1',
        creatorId: 'c1',
        name: 'Same',
        currentTotal: 100,
        isClosed: false,
        createdAt: DateTime(2026),
      );
      final b = ContributionGroup(
        id: 'eq-1',
        creatorId: 'c1',
        name: 'Same',
        currentTotal: 100,
        isClosed: false,
        createdAt: DateTime(2026),
      );

      expect(a, equals(b));
    });
  });
}
