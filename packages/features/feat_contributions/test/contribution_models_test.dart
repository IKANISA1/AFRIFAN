import 'package:feat_club/feat_club.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContributionGroup', () {
    test('fromJson parses complete group with is_active schema', () {
      final group = ContributionGroup.fromJson(<String, dynamic>{
        'id': 'grp-1',
        'creator_id': 'user-1',
        'name': 'Bus Fund',
        'description': 'Team transport',
        'group_type': 'community',
        'privacy': 'public',
        'target_amount': 500000,
        'current_total': 250000,
        'momo_recipient_code': '0781234567',
        'momo_route_type': 'phone_number',
        'deadline': '2026-06-01T00:00:00.000Z',
        'is_recurring': false,
        'is_active': true,
        'invite_code': 'BUS2026',
        'member_count': 45,
        'created_at': '2026-01-15T08:00:00.000Z',
      });

      expect(group.id, 'grp-1');
      expect(group.creatorId, 'user-1');
      expect(group.name, 'Bus Fund');
      expect(group.targetAmount, 500000);
      expect(group.currentTotal, 250000);
      expect(group.paymentRecipient, '0781234567');
      expect(group.isClosed, false);
      expect(group.inviteCode, 'BUS2026');
      expect(group.memberCount, 45);
    });

    test('fromJson handles legacy is_closed schema', () {
      final group = ContributionGroup.fromJson(<String, dynamic>{
        'id': 'grp-2',
        'creator_id': 'user-2',
        'name': 'Old Fund',
        'is_closed': true,
        'created_at': '2025-06-01T00:00:00.000Z',
      });

      expect(group.isClosed, true);
    });

    test('is_active false maps to isClosed true', () {
      final group = ContributionGroup.fromJson(<String, dynamic>{
        'id': 'grp-3',
        'creator_id': 'user-3',
        'name': 'Inactive',
        'is_active': false,
        'created_at': '2025-06-01T00:00:00.000Z',
      });

      expect(group.isClosed, true);
    });

    test('progress calculates correctly', () {
      final group = ContributionGroup(
        id: 'g1',
        creatorId: 'c1',
        name: 'Test',
        targetAmount: 100000,
        currentTotal: 75000,
        createdAt: DateTime(2026),
      );

      expect(group.progress, 0.75);
    });

    test('progress is 0 when target is 0', () {
      final group = ContributionGroup(
        id: 'g2',
        creatorId: 'c2',
        name: 'No Target',
        targetAmount: 0,
        currentTotal: 5000,
        createdAt: DateTime(2026),
      );

      expect(group.progress, 0.0);
    });

    test('progress is clamped to 1.0 when exceeding target', () {
      final group = ContributionGroup(
        id: 'g3',
        creatorId: 'c3',
        name: 'Over Target',
        targetAmount: 10000,
        currentTotal: 15000,
        createdAt: DateTime(2026),
      );

      expect(group.progress, 1.0);
    });

    test('remaining calculates correctly', () {
      final group = ContributionGroup(
        id: 'g4',
        creatorId: 'c4',
        name: 'Remaining',
        targetAmount: 100000,
        currentTotal: 60000,
        createdAt: DateTime(2026),
      );

      expect(group.remaining, 40000);
    });

    test('remaining is 0 when over target', () {
      final group = ContributionGroup(
        id: 'g5',
        creatorId: 'c5',
        name: 'Over',
        targetAmount: 10000,
        currentTotal: 20000,
        createdAt: DateTime(2026),
      );

      expect(group.remaining, 0);
    });

    test('isExpired for past deadline', () {
      final group = ContributionGroup(
        id: 'g6',
        creatorId: 'c6',
        name: 'Expired',
        deadline: DateTime(2020),
        createdAt: DateTime(2019),
      );

      expect(group.isExpired, true);
    });

    test('isExpired is false when no deadline', () {
      final group = ContributionGroup(
        id: 'g7',
        creatorId: 'c7',
        name: 'No Deadline',
        createdAt: DateTime(2026),
      );

      expect(group.isExpired, false);
    });

    test('toInsertJson includes all mutable fields', () {
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
      expect(json['is_recurring'], true);
      // Should NOT include id, creator_id, or computed fields
      expect(json.containsKey('id'), false);
      expect(json.containsKey('creator_id'), false);
    });

    test('paymentRecipient falls back through legacy column names', () {
      // Fallback 1: receiving_momo_code
      final g1 = ContributionGroup.fromJson(<String, dynamic>{
        'id': 'f1',
        'creator_id': 'c',
        'name': 'Fallback1',
        'receiving_momo_code': '078AAA',
        'created_at': '2026-01-01T00:00:00.000Z',
      });
      expect(g1.paymentRecipient, '078AAA');

      // Fallback 2: momo_number
      final g2 = ContributionGroup.fromJson(<String, dynamic>{
        'id': 'f2',
        'creator_id': 'c',
        'name': 'Fallback2',
        'momo_number': '078BBB',
        'created_at': '2026-01-01T00:00:00.000Z',
      });
      expect(g2.paymentRecipient, '078BBB');
    });

    test('equatable compares on key fields', () {
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

  group('GroupMessage', () {
    test('fromJson parses message fields', () {
      final msg = GroupMessage.fromJson(<String, dynamic>{
        'id': 'msg-1',
        'group_id': 'grp-1',
        'sender_id': 'user-1',
        'alias': 'Marie',
        'content': 'Let us contribute!',
        'created_at': '2026-03-15T10:00:00.000Z',
      });

      expect(msg.id, 'msg-1');
      expect(msg.groupId, 'grp-1');
      expect(msg.senderId, 'user-1');
      expect(msg.alias, 'Marie');
      expect(msg.content, 'Let us contribute!');
    });

    test('toInsertJson includes only group_id and content', () {
      final msg = GroupMessage(
        id: 'msg-2',
        groupId: 'grp-1',
        senderId: 'user-1',
        content: 'New message',
        createdAt: DateTime(2026),
      );

      final json = msg.toInsertJson();
      expect(json, {'group_id': 'grp-1', 'content': 'New message'});
      expect(json.containsKey('id'), false);
      expect(json.containsKey('sender_id'), false);
    });

    test('handles null alias', () {
      final msg = GroupMessage.fromJson(<String, dynamic>{
        'id': 'msg-3',
        'group_id': 'grp-2',
        'sender_id': 'user-2',
        'content': 'Anonymous',
        'created_at': '2026-03-15T10:00:00.000Z',
      });

      expect(msg.alias, isNull);
    });
  });
}
