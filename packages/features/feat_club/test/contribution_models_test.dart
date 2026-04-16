import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for ContributionGroup model — deserialization, progress,
/// schema compatibility, and GroupMessage model.
void main() {
  // ═══════════════════════════════════════════════════════════
  // ContributionGroup.fromJson
  // ═══════════════════════════════════════════════════════════

  group('ContributionGroup.fromJson', () {
    final validJson = {
      'id': 'group-1',
      'creator_id': 'user-1',
      'name': 'Stadium Fund',
      'description': 'Help rebuild the east stand',
      'group_type': 'club',
      'privacy': 'public',
      'target_amount': 500000,
      'current_total': 125000,
      'invite_code': 'ABCD1234',
      'member_count': 42,
      'is_closed': false,
      'created_at': '2026-01-15T10:00:00Z',
    };

    test('parses all fields correctly', () {
      final group = ContributionGroup.fromJson(validJson);
      expect(group.id, 'group-1');
      expect(group.creatorId, 'user-1');
      expect(group.name, 'Stadium Fund');
      expect(group.description, 'Help rebuild the east stand');
      expect(group.groupType, ContributionGroupType.club);
      expect(group.privacy, GroupPrivacy.public);
      expect(group.targetAmount, 500000);
      expect(group.currentTotal, 125000);
      expect(group.inviteCode, 'ABCD1234');
      expect(group.memberCount, 42);
      expect(group.isClosed, isFalse);
    });

    test('progress calculates correctly', () {
      final group = ContributionGroup.fromJson(validJson);
      expect(group.progress, closeTo(0.25, 0.01)); // 125k / 500k
      expect(group.remaining, 375000);
    });

    test('progress is clamped to 1.0 when overfunded', () {
      final group = ContributionGroup.fromJson({
        ...validJson,
        'current_total': 600000, // Over target
      });
      expect(group.progress, 1.0);
    });

    test('progress is 0 when target_amount is 0', () {
      final group = ContributionGroup.fromJson({
        ...validJson,
        'target_amount': 0,
      });
      expect(group.progress, 0.0);
    });

    test('handles is_active → is_closed inversion', () {
      final activeGroup = ContributionGroup.fromJson({
        ...validJson,
        'is_active': true,
      });
      expect(activeGroup.isClosed, isFalse);

      final inactiveGroup = ContributionGroup.fromJson({
        ...validJson,
        'is_active': false,
      });
      expect(inactiveGroup.isClosed, isTrue);
    });

    test('handles momo_recipient_code field', () {
      final group = ContributionGroup.fromJson({
        ...validJson,
        'momo_recipient_code': '*182*1*1*123456#',
      });
      expect(group.paymentRecipient, '*182*1*1*123456#');
    });

    test('handles receiving_momo_code as fallback', () {
      final group = ContributionGroup.fromJson({
        ...validJson,
        'receiving_momo_code': '*182*code#',
      });
      expect(group.paymentRecipient, '*182*code#');
    });

    test('parses momo_route_type to PaymentRecipientType', () {
      final phoneGroup = ContributionGroup.fromJson({
        ...validJson,
        'momo_route_type': 'phone_number',
      });
      expect(
        phoneGroup.paymentRecipientType,
        PaymentRecipientType.phoneNumber,
      );

      final codeGroup = ContributionGroup.fromJson({
        ...validJson,
        'momo_route_type': 'code',
      });
      expect(codeGroup.paymentRecipientType, PaymentRecipientType.code);
    });

    test('isExpired checks deadline', () {
      final expired = ContributionGroup.fromJson({
        ...validJson,
        'deadline': '2020-01-01T00:00:00Z',
      });
      expect(expired.isExpired, isTrue);

      final future = ContributionGroup.fromJson({
        ...validJson,
        'deadline': '2030-01-01T00:00:00Z',
      });
      expect(future.isExpired, isFalse);
    });

    test('no deadline means not expired', () {
      final noDl = ContributionGroup.fromJson(validJson);
      expect(noDl.isExpired, isFalse);
    });
  });

  group('ContributionGroup.toInsertJson', () {
    test('produces insert-compatible JSON', () {
      final group = ContributionGroup.fromJson({
        'id': 'g-1',
        'creator_id': 'u-1',
        'name': 'Test Group',
        'description': 'Testing',
        'group_type': 'savings',
        'privacy': 'private',
        'target_amount': 100000,
        'current_total': 0,
        'created_at': '2026-01-01T00:00:00Z',
      });

      final insert = group.toInsertJson();
      expect(insert['name'], 'Test Group');
      expect(insert['group_type'], 'savings');
      expect(insert['privacy'], 'private');
      expect(insert['target_amount'], 100000);
      // insert should NOT include id or creator_id (server-set)
      expect(insert.containsKey('id'), isFalse);
      expect(insert.containsKey('creator_id'), isFalse);
    });

    test('serializes momo route type for merchant codes', () {
      final group = ContributionGroup(
        id: 'g-2',
        creatorId: 'u-2',
        name: 'Code Group',
        paymentRecipient: '123456',
        paymentRecipientType: PaymentRecipientType.code,
        createdAt: DateTime(2026),
      );

      final insert = group.toInsertJson();
      expect(insert['receiving_momo_code'], '123456');
      expect(insert['momo_route_type'], 'code');
    });
  });

  // ═══════════════════════════════════════════════════════════
  // GroupMessage Model
  // ═══════════════════════════════════════════════════════════

  group('GroupMessage.fromJson', () {
    test('parses all fields', () {
      final msg = GroupMessage.fromJson({
        'id': 'msg-1',
        'group_id': 'group-1',
        'sender_id': 'user-1',
        'alias': '482913',
        'content': 'Let\'s contribute today!',
        'created_at': '2026-03-01T10:00:00Z',
      });

      expect(msg.id, 'msg-1');
      expect(msg.groupId, 'group-1');
      expect(msg.senderId, 'user-1');
      expect(msg.alias, '482913');
      expect(msg.content, contains('contribute'));
    });

    test('toInsertJson only includes group_id and content', () {
      final msg = GroupMessage.fromJson({
        'id': 'msg-2',
        'group_id': 'group-2',
        'sender_id': 'user-2',
        'content': 'Hello team',
        'created_at': '2026-03-01T10:00:00Z',
      });

      final insert = msg.toInsertJson();
      expect(insert.keys, containsAll(['group_id', 'content']));
      expect(insert.keys, isNot(contains('sender_id')));
      expect(insert.keys, isNot(contains('id')));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // ClubProduct + CartItem
  // ═══════════════════════════════════════════════════════════

  group('ClubProduct', () {
    test('fromJson parses correctly', () {
      final product = ClubProduct.fromJson({
        'id': 'prod-1',
        'partner_id': 'rayon',
        'name': 'Home Jersey 2026',
        'category': 'jersey',
        'price': 35000,
        'stock': 100,
        'is_active': true,
        'is_new': true,
        'sizes': ['S', 'M', 'L', 'XL'],
      });

      expect(product.id, 'prod-1');
      expect(product.name, 'Home Jersey 2026');
      expect(product.category, ProductCategory.jersey);
      expect(product.price, 35000);
      expect(product.availableSizes, hasLength(4));
    });

    test('falls back to club_id when partner_id is absent', () {
      final product = ClubProduct.fromJson({
        'id': 'prod-2',
        'club_id': 24,
        'name': 'Away Jersey',
        'category': 'jersey',
        'price': 42000,
        'is_active': true,
      });

      expect(product.partnerId, '24');
    });

    test('discountedPrice calculates correctly', () {
      final product = ClubProduct.fromJson({
        'id': 'p-1',
        'partner_id': 'r',
        'name': 'Item',
        'price': 10000,
        'is_active': true,
      });

      expect(product.discountedPrice(10), 9000); // 10% off
      expect(product.discountedPrice(0), 10000);
      expect(product.discountedPrice(100), 0);
    });
  });

  group('CartItem', () {
    test('lineTotal is price × quantity', () {
      final product = ClubProduct.fromJson({
        'id': 'p-2',
        'partner_id': 'r',
        'name': 'Scarf',
        'price': 5000,
        'is_active': true,
      });
      final item = CartItem(product: product, quantity: 3);
      expect(item.lineTotal, 15000);
    });

    test('copyWith preserves product', () {
      final product = ClubProduct.fromJson({
        'id': 'p-3',
        'partner_id': 'r',
        'name': 'Cap',
        'price': 8000,
        'is_active': true,
      });
      final item = CartItem(product: product, quantity: 1);
      final updated = item.copyWith(quantity: 5);
      expect(updated.quantity, 5);
      expect(updated.product.id, 'p-3');
    });
  });

  group('club scoped compatibility fields', () {
    test('FanMembership falls back to club_id when partner_id is absent', () {
      final membership = FanMembership.fromJson({
        'id': 'membership-1',
        'user_id': 'user-1',
        'club_id': 24,
        'tier': 'fan',
        'points': 10,
        'chapter': 'Main',
        'membership_number': 'FAN-24',
        'joined_at': '2026-01-01T00:00:00Z',
      });

      expect(membership.partnerId, '24');
    });

    test('FanClub falls back to club_id when partner_id is absent', () {
      final club = FanClub.fromJson({
        'id': 'club-1',
        'club_id': 24,
        'name': 'Kigali Blue Army',
        'region': 'Kigali',
      });

      expect(club.partnerId, '24');
    });

    test('ClubShopOrder falls back to club_id when partner_id is absent', () {
      final order = ClubShopOrder.fromJson({
        'id': 'order-1',
        'user_id': 'user-1',
        'club_id': 24,
        'items': const [],
        'subtotal': 1000,
        'discount_amount': 0,
        'delivery_fee': 0,
        'total': 1000,
        'status': 'pending',
        'created_at': '2026-01-01T00:00:00Z',
      });

      expect(order.partnerId, '24');
    });

    test('PartnerPaymentRoute falls back to club_id when partner_id is absent',
        () {
      final route = PartnerPaymentRoute.fromJson({
        'id': 'route-1',
        'club_id': 24,
        'partner_name': 'Rayon Sports FC',
        'partner_slug': 'rayon_sports',
        'country': 'RW',
        'provider': 'mtn',
        'recipient_code': '123456',
        'reconciliation_label': 'Matchday',
        'status': 'active',
      });

      expect(route.partnerId, '24');
    });
  });
}
