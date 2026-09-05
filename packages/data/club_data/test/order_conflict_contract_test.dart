import 'dart:io';

import 'package:club_data/club_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shop order retains the loaded updated_at token', () {
    final order = ClubShopOrder.fromJson(<String, dynamic>{
      'id': 'order-1',
      'user_id': 'user-1',
      'items': <Object?>[],
      'subtotal': 1000,
      'discount_amount': 0,
      'delivery_fee': 0,
      'total': 1000,
      'delivery_address': 'Kigali',
      'momo_reference': 'reference',
      'status': 'pending',
      'created_at': '2026-07-24T18:00:00Z',
      'updated_at': '2026-07-24T18:05:00Z',
    });

    expect(order.updatedAt, DateTime.parse('2026-07-24T18:05:00Z'));
  });

  test('order cancellation requires the loaded version token', () {
    final packageSource = File('lib/src/repositories/club_repository.dart');
    final source =
        (packageSource.existsSync()
                ? packageSource
                : File(
                    'packages/data/club_data/lib/src/repositories/'
                    'club_repository.dart',
                  ))
            .readAsStringSync();

    expect(source, contains('cancel_shop_order_if_unchanged'));
    expect(source, contains('p_expected_updated_at'));
    expect(source, contains('throw const OrderConflictException()'));
  });
}
