import 'dart:async';
import 'dart:convert';

import 'package:club_data/club_data.dart';
import 'package:feat_shop/src/shop_checkout_recovery.dart';

const checkoutUserId = '99962000-0000-4000-8000-000000000001';
const checkoutProductId = '99962000-0000-4000-8000-000000000110';
const checkoutOrderId = '99962000-0000-4000-8000-000000000210';
const checkoutReference = 'order-99962000-0000-4000-8000-000000000209';

class MemoryShopCheckoutJournal implements ShopCheckoutJournal {
  final Map<String, String> values = {};
  final Map<String, Future<void>> _locks = {};
  bool failWrites = false;
  @override
  Future<T> runExclusive<T>(String scope, Future<T> Function() work) async {
    final previous = _locks[scope] ?? Future<void>.value();
    final release = Completer<void>();
    final next = previous.then<void>((_) async {
      await release.future;
    });
    unawaited(_locks[scope] = next);
    await previous;
    try {
      return await work();
    } finally {
      release.complete();
      if (identical(_locks[scope], next)) {
        unawaited(_locks.remove(scope));
      }
    }
  }

  @override
  Future<String?> read(String scope) async => values[scope];
  @override
  Future<void> save(String scope, String? expected, String value) async {
    if (failWrites || values[scope] != expected) {
      throw StateError('storage failed');
    }
    values[scope] = value;
  }

  @override
  Future<void> remove(String scope, String expected) async {
    if (failWrites || values[scope] != expected) {
      throw StateError('storage failed');
    }
    values.remove(scope);
  }
}

CartItem checkoutItem({int price = 1000}) => CartItem(
  product: ClubProduct.fromJson({
    'id': checkoutProductId,
    'partner_id': '24',
    'club_id': 24,
    'name': 'Home shirt',
    'price': price,
    'stock': 20,
    'category': 'jersey',
    'currency': 'RWF',
  }),
  quantity: 1,
);

Map<String, dynamic> checkoutResponse({
  String userId = checkoutUserId,
  int clubId = 24,
  String reference = checkoutReference,
  int total = 1300,
  String receiver = '12345',
  String status = 'pending',
  bool canPay = true,
}) {
  final expiry = DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 15))
      .toIso8601String();
  final items = [
    {
      'product_id': checkoutProductId,
      'quantity': 1,
      'selected_variant': null,
      'product': {
        ...checkoutItem(price: total).product.toJson(),
        'club_id': clubId,
        'currency': 'RWF',
      },
    },
  ];
  final facts = {
    'version': 1,
    'order_id': checkoutOrderId,
    'user_id': userId,
    'club_id': clubId,
    'payment_reference': reference,
    'total': total,
    'currency': 'RWF',
    'recipient_code': receiver,
    'country': 'RW',
    'provider': 'mtn',
    'receiver_id': '99962000-0000-4000-8000-000000000130',
    'route_id': '99962000-0000-4000-8000-000000000120',
    'ussd_code': '*182*8*1*$total*$receiver#',
    'items': items,
    'delivery_address': '12 Amahoro Avenue',
    'expires_at': expiry,
  };
  return jsonDecode(
        jsonEncode({
          'receipt': facts,
          'can_pay': canPay,
          'order': {
            'id': checkoutOrderId,
            'user_id': userId,
            'club_id': clubId,
            'partner_id': '24',
            'items': items,
            'subtotal': total,
            'discount_pct': 0,
            'discount_amount': 0,
            'delivery_fee': 0,
            'total': total,
            'delivery_address': '12 Amahoro Avenue',
            'momo_reference': reference,
            'status': status,
            'inventory_reserved': status == 'pending',
            'reservation_expires_at': expiry,
            'payment_receipt': facts,
            'created_at': '2026-10-01T10:00:00Z',
            'updated_at': '2026-10-01T10:00:00Z',
          },
        }),
      )
      as Map<String, dynamic>;
}

ShopCheckoutReceipt checkoutReceipt({
  String reference = checkoutReference,
  int total = 1300,
  String receiver = '12345',
  String status = 'pending',
  bool canPay = true,
}) => ShopCheckoutReceipt.fromJson(
  checkoutResponse(
    reference: reference,
    total: total,
    receiver: receiver,
    status: status,
    canPay: canPay,
  ),
);
