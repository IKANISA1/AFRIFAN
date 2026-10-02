import 'dart:convert';

import 'package:club_data/club_data.dart';
import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const checkoutUserId = '99962000-0000-4000-8000-000000000001';
const checkoutProductId = '99962000-0000-4000-8000-000000000110';
const checkoutOrderId = '99962000-0000-4000-8000-000000000210';
const checkoutReference = 'order-99962000-0000-4000-8000-000000000209';

void main() {
  late SupabaseClient client;
  late ClubRepository repository;
  late List<http.Request> requests;
  late Map<String, dynamic> remoteUser;
  ShopCheckoutReceipt? prepared;
  var switchDuringPrepare = false;
  Map<String, dynamic> user(String id, {bool anonymous = false}) => {
    'id': id,
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': 'synthetic@example.invalid',
    'email_confirmed_at': '2026-10-01T10:00:00Z',
    'app_metadata': {'club_id': 24},
    'user_metadata': {'club_id': 25},
    'is_anonymous': anonymous,
    'created_at': '2026-10-01T10:00:00Z',
  };
  Future<void> signIn(Map<String, dynamic> subject) =>
      client.auth.recoverSession(
        jsonEncode({
          'access_token': 'synthetic-token',
          'refresh_token': 'synthetic-refresh',
          'token_type': 'bearer',
          'user': subject,
        }),
      );
  setUp(() async {
    requests = [];
    prepared = null;
    switchDuringPrepare = false;
    remoteUser = user(checkoutUserId);
    client = SupabaseClient(
      'https://checkout.invalid',
      'synthetic-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        final name = request.url.path.split('/').last;
        Object? result;
        if (name == 'user') {
          result = remoteUser;
        } else if (name == 'prepare_shop_checkout_for_club') {
          final params = jsonDecode(request.body) as Map<String, dynamic>;
          final response = checkoutResponse(
            reference: params['p_payment_reference'] as String,
          );
          prepared = ShopCheckoutReceipt.fromJson(response);
          if (switchDuringPrepare) {
            remoteUser = user('99962000-0000-4000-8000-000000000002');
            await signIn(remoteUser);
          }
          result = response;
        } else if (name == 'recover_shop_checkout_for_club' ||
            name == 'validate_shop_checkout_for_club') {
          result = prepared == null
              ? null
              : {
                  'order': checkoutResponse(
                    reference: prepared!.paymentReference,
                  )['order'],
                  'receipt': prepared!.frozen,
                  'can_pay': true,
                };
          if (result != null) {
            final data = result as Map<String, dynamic>;
            data['order']['reservation_expires_at'] =
                prepared!.frozen['expires_at'];
          }
        } else if (name == 'shop_orders') {
          final row =
              checkoutResponse(reference: prepared!.paymentReference)['order']
                  as Map<String, dynamic>;
          row['reservation_expires_at'] = prepared!.frozen['expires_at'];
          row['payment_receipt'] = prepared!.frozen;
          result = [row];
        } else {
          throw StateError('Unexpected request: ${request.url}');
        }
        return http.Response(
          jsonEncode(result),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    await signIn(remoteUser);
    repository = ClubRepository(
      client: client,
      healthService: OperationalHealthService(client: client),
      storeReleasePolicy: const StoreReleasePolicy.unenforced(),
    );
  });

  Future<ShopCheckoutReceipt> prepare({String club = '24'}) =>
      repository.placeShopOrder(
        userId: checkoutUserId,
        partnerId: club,
        items: [checkoutItem(price: 1000)],
        deliveryAddress: '12 Amahoro Avenue',
        paymentReference: checkoutReference,
      );

  test(
    'actual adapter returns authoritative receipt and sends only product choices to prepare',
    () async {
      final receipt = await prepare();
      expect(receipt.total, 1300);
      expect(receipt.currency, 'RWF');
      expect(receipt.recipientCode, '12345');
      final call = requests.singleWhere(
        (r) => r.url.path.endsWith('/prepare_shop_checkout_for_club'),
      );
      final params = jsonDecode(call.body) as Map<String, dynamic>;
      expect(params, {
        'p_items': [
          {
            'product_id': checkoutProductId,
            'quantity': 1,
            'selected_variant': null,
          },
        ],
        'p_delivery_address': '12 Amahoro Avenue',
        'p_payment_reference': checkoutReference,
        'p_expected_club_id': 24,
      });
      expect(call.headers['authorization'], 'Bearer synthetic-token');
      final recovered = await repository.recoverShopOrder(
        userId: checkoutUserId,
        clubId: '24',
        paymentReference: checkoutReference,
      );
      expect(recovered!.sameInstruction(receipt), isTrue);
      final validated = await repository.validateShopPayment(receipt);
      expect(validated.sameInstruction(receipt), isTrue);
      final validate = requests.singleWhere(
        (r) => r.url.path.endsWith('/validate_shop_checkout_for_club'),
      );
      expect(jsonDecode(validate.body), {
        'p_order_id': receipt.id,
        'p_expected_club_id': 24,
        'p_receipt': receipt.frozen,
      });
      expect(
        requests.where((r) => r.url.path.endsWith('/create_shop_order')),
        isEmpty,
      );
    },
  );

  test(
    'existing release policy blocks new checkout but permits original status recovery',
    () async {
      repository = ClubRepository(
        client: client,
        healthService: OperationalHealthService(client: client),
        storeReleasePolicy: const StoreReleasePolicy(isEnforced: true),
      );
      await expectLater(prepare(), throwsUnsupportedError);
      expect(
        requests.where((request) => request.url.path.contains('/rpc/')),
        isEmpty,
      );
      expect(
        await repository.recoverShopOrder(
          userId: checkoutUserId,
          clubId: '24',
          paymentReference: checkoutReference,
        ),
        isNull,
      );
    },
  );

  test(
    'history reads actual RLS owner plus trusted club and never enables payment',
    () async {
      await prepare();
      final history = await repository.getMyShopCheckouts(checkoutUserId);
      expect(history.single.id, checkoutOrderId);
      expect(history.single.pending, isTrue);
      expect(history.single.canPay, isFalse);
      final request = requests.singleWhere(
        (r) => r.url.path.endsWith('/shop_orders'),
      );
      expect(request.url.queryParameters['user_id'], 'eq.$checkoutUserId');
      expect(request.url.queryParameters['club_id'], 'eq.24');
      expect(request.url.queryParameters['payment_receipt'], 'not.is.null');
    },
  );

  test(
    'forged club hint and anonymous remote subject are rejected before mutation',
    () async {
      await expectLater(prepare(club: '25'), throwsStateError);
      remoteUser = user(checkoutUserId, anonymous: true);
      await expectLater(prepare(), throwsStateError);
      expect(requests.where((r) => r.url.path.contains('/rpc/')), isEmpty);
    },
  );

  test(
    'account switch during accepted prepare cannot return previous owner receipt',
    () async {
      switchDuringPrepare = true;
      await expectLater(prepare(), throwsStateError);
      expect(prepared!.userId, checkoutUserId);
    },
  );
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
