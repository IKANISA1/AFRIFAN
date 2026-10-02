import 'dart:async';
import 'dart:convert';

import 'package:club_data/club_data.dart';
import 'package:feat_shop/src/shop_checkout_recovery.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shop_checkout_test_support.dart';

void main() {
  late MemoryShopCheckoutJournal journal;
  ShopCheckoutReceipt? server;
  late List<String> created;
  late List<String> dialed;
  var current = true;
  var loseResponse = false;
  var launcherResult = true;
  ShopCheckoutFlow flow({String userId = checkoutUserId}) => ShopCheckoutFlow(
    userId: userId,
    clubId: '24',
    journal: journal,
    place:
        ({
          required userId,
          required partnerId,
          required items,
          required deliveryAddress,
          required paymentReference,
        }) async {
          expect(journal.values.values.single, contains(paymentReference));
          created.add(paymentReference);
          server = checkoutReceipt(reference: paymentReference);
          if (loseResponse) {
            throw TimeoutException('reply lost after acceptance');
          }
          return server!;
        },
    recover:
        ({required userId, required clubId, required paymentReference}) async {
          expect(paymentReference, created.single);
          return server;
        },
    validate: (_) async => server!,
    launch: (ussd) async {
      dialed.add(ussd);
      return launcherResult;
    },
    isCurrent: () => current,
  );
  setUp(() {
    journal = MemoryShopCheckoutJournal();
    server = null;
    created = [];
    dialed = [];
    current = true;
    loseResponse = false;
    launcherResult = true;
  });

  test(
    'cannot mutate when durable encrypted journal persistence fails',
    () async {
      journal.failWrites = true;
      await expectLater(
        flow().begin([checkoutItem()], '12 Amahoro Avenue'),
        throwsStateError,
      );
      expect(created, isEmpty);
      expect(dialed, isEmpty);
    },
  );

  test(
    'response loss and relaunch recover original order without creating another',
    () async {
      loseResponse = true;
      final first = flow();
      await expectLater(
        first.begin([checkoutItem()], '12 Amahoro Avenue'),
        throwsA(isA<TimeoutException>()),
      );
      final reference = created.single;
      final restarted = flow();
      await restarted.restore();
      expect(restarted.attempt!.reference, reference);
      await restarted.retryOriginal();
      expect(restarted.receipt!.id, checkoutOrderId);
      expect(restarted.attempt!.orderId, checkoutOrderId);
      expect(created, [reference]);
      expect(dialed, isEmpty);
      expect(restarted.receipt!.pending, isTrue);
    },
  );

  test(
    'explicit retry retains original key and frozen request when server has no order',
    () async {
      loseResponse = true;
      await expectLater(
        flow().begin([checkoutItem()], '12 Amahoro Avenue'),
        throwsA(isA<TimeoutException>()),
      );
      final reference = created.single;
      server = null;
      loseResponse = false;
      final restarted = flow();
      await restarted.restore();
      await restarted.retryOriginal();
      expect(created, [reference, reference]);
      expect(restarted.receipt!.paymentReference, reference);
    },
  );

  test(
    'handoff uses reviewed server money and receiver; rapid double confirm dials once',
    () async {
      final active = flow();
      await active.begin([checkoutItem(price: 1000)], '12 Amahoro Avenue');
      final review = active.receipt!;
      final results = await Future.wait([
        active
            .confirm(review)
            .then<Object>((value) => value)
            .catchError((Object e) => e),
        active
            .confirm(review)
            .then<Object>((value) => value)
            .catchError((Object e) => e),
      ]);
      expect(results.whereType<bool>(), [true]);
      expect(dialed, ['*182*8*1*1300*12345#']);
      expect(active.receipt!.pending, isTrue);
      final restarted = flow();
      await restarted.restore();
      await restarted.check();
      await expectLater(
        restarted.confirm(restarted.receipt!),
        throwsStateError,
      );
      expect(dialed, hasLength(1));
    },
  );

  test(
    'revoked receiver blocks dial and original order remains recoverable',
    () async {
      final active = flow();
      await active.begin([checkoutItem()], '12 Amahoro Avenue');
      final response = checkoutResponse(
        reference: created.single,
        canPay: false,
      );
      response['receipt'] = active.receipt!.frozen;
      response['order']['reservation_expires_at'] =
          active.receipt!.frozen['expires_at'];
      server = ShopCheckoutReceipt.fromJson(response);
      await expectLater(active.confirm(active.receipt!), throwsStateError);
      expect(dialed, isEmpty);
      expect(journal.values, isNotEmpty);
    },
  );

  test(
    'changed instruction requires a new truthful review before dial',
    () async {
      final active = flow();
      await active.begin([checkoutItem()], '12 Amahoro Avenue');
      final review = active.receipt!;
      server = checkoutReceipt(reference: created.single, receiver: '54321');
      await expectLater(
        active.confirm(review),
        throwsA(isA<ShopCheckoutReviewChanged>()),
      );
      expect(dialed, isEmpty);
      expect(active.receipt!.recipientCode, '54321');
      await active.confirm(active.receipt!);
      expect(dialed, ['*182*8*1*1300*54321#']);
    },
  );

  test(
    'uncertain launch persists handoff boundary through restart and never marks paid',
    () async {
      launcherResult = false;
      final active = flow();
      await active.begin([checkoutItem()], '12 Amahoro Avenue');
      expect(await active.confirm(active.receipt!), isFalse);
      final restarted = flow();
      await restarted.restore();
      await restarted.check();
      expect(restarted.attempt!.handoffStarted, isTrue);
      expect(restarted.receipt!.serverStatus, 'pending');
      await expectLater(restarted.retryOriginal(), throwsStateError);
      await expectLater(restarted.closeTerminal(), throwsStateError);
      expect(created, hasLength(1));
    },
  );

  test(
    'account switch during request cannot expose receipt or launch another account payment',
    () async {
      final reply = Completer<ShopCheckoutReceipt>();
      final active = ShopCheckoutFlow(
        userId: checkoutUserId,
        clubId: '24',
        journal: journal,
        place:
            ({
              required userId,
              required partnerId,
              required items,
              required deliveryAddress,
              required paymentReference,
            }) async {
              created.add(paymentReference);
              return reply.future;
            },
        recover:
            ({
              required userId,
              required clubId,
              required paymentReference,
            }) async => null,
        validate: (value) async => value,
        launch: (ussd) async {
          dialed.add(ussd);
          return true;
        },
        isCurrent: () => current,
      );
      final operation = active.begin([checkoutItem()], '12 Amahoro Avenue');
      await Future<void>.delayed(Duration.zero);
      current = false;
      reply.complete(checkoutReceipt(reference: created.single));
      await expectLater(operation, throwsStateError);
      expect(active.receipt, isNull);
      expect(dialed, isEmpty);
      final another = flow(userId: '99962000-0000-4000-8000-000000000002');
      current = true;
      await another.restore();
      expect(another.attempt, isNull);
      expect(journal.values, hasLength(1));
    },
  );

  test(
    'corrupted journal cannot discard original request or create another',
    () async {
      final active = flow();
      journal.values[active.scope] = '{broken';
      await expectLater(active.restore(), throwsStateError);
      await expectLater(
        active.begin([checkoutItem()], '12 Amahoro Avenue'),
        throwsStateError,
      );
      expect(journal.values[active.scope], '{broken');
      expect(created, isEmpty);
    },
  );

  test(
    'server confirmed cancellation allows explicit return with original key retained until closure',
    () async {
      final active = flow();
      await active.begin([checkoutItem()], '12 Amahoro Avenue');
      await active.cancelUnpaid((review) async {
        final response = checkoutResponse(
          reference: review.paymentReference,
          status: 'cancelled',
          canPay: false,
        );
        response['receipt'] = review.frozen;
        response['order']['reservation_expires_at'] =
            review.frozen['expires_at'];
        server = ShopCheckoutReceipt.fromJson(response);
      });
      expect(active.receipt!.serverStatus, 'cancelled');
      expect(journal.values, isNotEmpty);
      await active.closeTerminal();
      expect(journal.values, isEmpty);
    },
  );

  test(
    'typed receipt rejects price, owner scope, currency and line disagreement',
    () {
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (data) => data['order']['total'] = 1000,
        (data) => data['order']['club_id'] = 25,
        (data) => data['receipt']['currency'] = 'rwf',
        (data) => data['order']['items'][0]['product']['price'] = 999,
      ]) {
        final data =
            jsonDecode(jsonEncode(checkoutResponse())) as Map<String, dynamic>;
        mutate(data);
        expect(() => ShopCheckoutReceipt.fromJson(data), throwsFormatException);
      }
      final valid = checkoutReceipt();
      valid.frozen['total'] = 1;
      expect(valid.total, 1300);
      expect(valid.frozen['total'], 1300);
    },
  );
}
