import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContributionGroup.fromJson', () {
    final validJson = <String, dynamic>{
      'id': 'group-1',
      'creator_id': 'user-1',
      'name': 'Stadium Fund',
      'description': 'Help rebuild the east stand',
      'group_type': 'club',
      'target_amount': 500000,
      'current_total': 125000,
      'member_count': 42,
      'is_closed': false,
      'created_at': '2026-01-15T10:00:00Z',
    };

    test('parses active initiative fields correctly', () {
      final group = ContributionGroup.fromJson(validJson);
      expect(group.id, 'group-1');
      expect(group.creatorId, 'user-1');
      expect(group.name, 'Stadium Fund');
      expect(group.description, 'Help rebuild the east stand');
      expect(group.groupType, ContributionGroupType.project);
      expect(group.targetAmount, 500000);
      expect(group.currentTotal, 125000);
      expect(group.memberCount, 42);
      expect(group.isClosed, isFalse);
    });

    test('progress and remaining derive from totals', () {
      final group = ContributionGroup.fromJson(validJson);
      expect(group.progress, closeTo(0.25, 0.01));
      expect(group.remaining, 375000);
    });

    test('parses recipient routing fallbacks', () {
      final recipientCode = ContributionGroup.fromJson(<String, dynamic>{
        ...validJson,
        'momo_recipient_code': '*182*1*1*123456#',
      });
      expect(recipientCode.paymentRecipient, '*182*1*1*123456#');

      final receivingCode = ContributionGroup.fromJson(<String, dynamic>{
        ...validJson,
        'receiving_momo_code': '*182*code#',
      });
      expect(receivingCode.paymentRecipient, '*182*code#');

      final momoNumber = ContributionGroup.fromJson(<String, dynamic>{
        ...validJson,
        'momo_number': '0781234567',
      });
      expect(momoNumber.paymentRecipient, '0781234567');
    });

    test('parses recipient type and deadline', () {
      final group = ContributionGroup.fromJson(<String, dynamic>{
        ...validJson,
        'momo_route_type': 'phone_number',
        'deadline': '2030-01-01T00:00:00Z',
      });

      expect(group.paymentRecipientType, PaymentRecipientType.phoneNumber);
      expect(group.isExpired, isFalse);
    });

    test('supports legacy is_active inversion', () {
      final active = ContributionGroup.fromJson(<String, dynamic>{
        ...validJson,
        'is_active': true,
      });
      final inactive = ContributionGroup.fromJson(<String, dynamic>{
        ...validJson,
        'is_active': false,
      });

      expect(active.isClosed, isFalse);
      expect(inactive.isClosed, isTrue);
    });
  });

  group('ContributionGroup.toInsertJson', () {
    test('serializes mutable initiative fields only', () {
      final group = ContributionGroup(
        id: 'g-1',
        creatorId: 'u-1',
        name: 'Community Drive',
        description: 'Support the next away trip',
        groupType: ContributionGroupType.community,
        targetAmount: 100000,
        paymentRecipient: '123456',
        paymentRecipientType: PaymentRecipientType.code,
        deadline: DateTime(2026, 6, 1),
        isRecurring: true,
        createdAt: DateTime(2026),
      );

      final insert = group.toInsertJson();
      expect(insert['name'], 'Community Drive');
      expect(insert['description'], 'Support the next away trip');
      expect(insert['group_type'], 'community');
      expect(insert['target_amount'], 100000);
      expect(insert['receiving_momo_code'], '123456');
      expect(insert['momo_route_type'], 'code');
      expect(insert['is_recurring'], isTrue);
      expect(insert.containsKey('id'), isFalse);
      expect(insert.containsKey('creator_id'), isFalse);
    });
  });
}
