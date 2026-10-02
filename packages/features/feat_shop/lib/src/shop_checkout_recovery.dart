import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:club_data/club_data.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

final shopCheckoutJournalProvider = Provider<ShopCheckoutJournal>(
  (ref) => HiveShopCheckoutJournal(),
);

/// Durable operation data, scoped to one authenticated subject and club. It is
/// never an authority for prices, status, eligibility or payment confirmation.
class ShopCheckoutAttempt {
  const ShopCheckoutAttempt({
    required this.userId,
    required this.clubId,
    required this.reference,
    required this.items,
    required this.address,
    this.orderId,
    this.handoffStarted = false,
  });
  final String userId, clubId, reference, address;
  final List<CartItem> items;
  final String? orderId;
  final bool handoffStarted;
  String get scope => 'africlub-shop-v1:$clubId:$userId';
  ShopCheckoutAttempt bind(String id) => ShopCheckoutAttempt(
    userId: userId,
    clubId: clubId,
    reference: reference,
    items: items,
    address: address,
    orderId: id,
    handoffStarted: handoffStarted,
  );
  ShopCheckoutAttempt handoff() => ShopCheckoutAttempt(
    userId: userId,
    clubId: clubId,
    reference: reference,
    items: items,
    address: address,
    orderId: orderId,
    handoffStarted: true,
  );
  String encode() => jsonEncode({
    'version': 1,
    'user_id': userId,
    'club_id': clubId,
    'reference': reference,
    'address': address,
    'order_id': orderId,
    'handoff_started': handoffStarted,
    'items': items
        .map(
          (item) => {
            'product': item.product.toJson(),
            'quantity': item.quantity,
            'selected_variant': item.selectedVariant,
          },
        )
        .toList(growable: false),
  });
  static ShopCheckoutAttempt? decode(
    String? value,
    String userId,
    String clubId,
  ) {
    if (value == null) return null;
    try {
      if (value.length > 65536) throw const FormatException();
      final data = jsonDecode(value) as Map<String, dynamic>;
      if (data['version'] != 1 ||
          data['user_id'] != userId ||
          data['club_id'] != clubId ||
          data['handoff_started'] is! bool ||
          data['address'] is! String ||
          (data['address'] as String).length > 500 ||
          !RegExp(r'^order-[0-9a-f-]{36}$').hasMatch('${data['reference']}')) {
        throw const FormatException();
      }
      final items = (data['items'] as List)
          .map(
            (item) => CartItem(
              product: ClubProduct.fromJson(
                Map<String, dynamic>.from(item['product'] as Map),
              ),
              quantity: item['quantity'] as int,
              selectedVariant: item['selected_variant'] as String?,
            ),
          )
          .toList(growable: false);
      if (items.isEmpty ||
          items.length > 20 ||
          items.any((item) => item.quantity < 1 || item.quantity > 20)) {
        throw const FormatException();
      }
      return ShopCheckoutAttempt(
        userId: userId,
        clubId: clubId,
        reference: data['reference'] as String,
        address: data['address'] as String,
        items: List.unmodifiable(items),
        orderId: data['order_id'] as String?,
        handoffStarted: data['handoff_started'] as bool,
      );
    } catch (_) {
      throw StateError('SHOP_RECOVERY_INVALID');
    }
  }
}

abstract interface class ShopCheckoutJournal {
  Future<T> runExclusive<T>(String scope, Future<T> Function() work);
  Future<String?> read(String scope);
  Future<void> save(String scope, String? expected, String value);
  Future<void> remove(String scope, String expected);
}

/// Reuses the application's keychain-backed Hive cipher with a dedicated,
/// non-evicting journal. Cache migrations/TTL never clear pending operations.
/// Encryption, opening, writes and readback fail closed; no plaintext fallback.
class HiveShopCheckoutJournal implements ShopCheckoutJournal {
  static Future<Box<String>>? _opening;
  static final Map<String, Future<void>> _locks = {};
  Future<Box<String>> _box() async {
    if (HiveEncryptionService.cipher == null) {
      throw StateError('SHOP_RECOVERY_UNAVAILABLE');
    }
    final pending = _opening;
    if (pending != null) {
      final opened = await pending;
      if (opened.isOpen) return opened;
      if (identical(_opening, pending)) _opening = null;
    }
    return _opening ??=
        Hive.openBox<String>(
          'africlub_shop_checkout_v1',
          encryptionCipher: HiveEncryptionService.cipher,
        ).catchError((Object error) {
          _opening = null;
          throw error;
        });
  }

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
  Future<String?> read(String scope) async => (await _box()).get(scope);
  @override
  Future<void> save(String scope, String? expected, String value) async {
    final box = await _box();
    if (box.get(scope) != expected || value.length > 65536) {
      throw StateError('SHOP_RECOVERY_CONFLICT');
    }
    await box.put(scope, value);
    await box.flush();
    if (box.get(scope) != value) throw StateError('SHOP_RECOVERY_UNAVAILABLE');
  }

  @override
  Future<void> remove(String scope, String expected) async {
    final box = await _box();
    if (box.get(scope) != expected) throw StateError('SHOP_RECOVERY_CONFLICT');
    await box.delete(scope);
    await box.flush();
    if (box.containsKey(scope)) throw StateError('SHOP_RECOVERY_UNAVAILABLE');
  }
}

String newShopPaymentReference() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final value = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return 'order-${value.substring(0, 8)}-${value.substring(8, 12)}-${value.substring(12, 16)}-${value.substring(16, 20)}-${value.substring(20)}';
}

typedef ShopOrderPlacer =
    Future<ShopCheckoutReceipt> Function({
      required String userId,
      required String partnerId,
      required List<CartItem> items,
      required String deliveryAddress,
      required String paymentReference,
    });
typedef ShopOrderRecoverer =
    Future<ShopCheckoutReceipt?> Function({
      required String userId,
      required String clubId,
      required String paymentReference,
    });

class ShopCheckoutReviewChanged implements Exception {
  const ShopCheckoutReviewChanged(this.receipt);
  final ShopCheckoutReceipt receipt;
}

/// Feature controller used by the real cart. Storage is committed before any
/// creation or external handoff; retries keep the original persisted operation.
class ShopCheckoutFlow {
  ShopCheckoutFlow({
    required this.userId,
    required this.clubId,
    required this.journal,
    required this.place,
    required this.recover,
    required this.validate,
    required this.launch,
    required this.isCurrent,
    this.timeout = const Duration(seconds: 30),
    this.referenceFactory = newShopPaymentReference,
  });
  final String userId, clubId;
  final ShopCheckoutJournal journal;
  final ShopOrderPlacer place;
  final ShopOrderRecoverer recover;
  final Future<ShopCheckoutReceipt> Function(ShopCheckoutReceipt) validate;
  final Future<bool> Function(String) launch;
  final bool Function() isCurrent;
  final Duration timeout;
  final String Function() referenceFactory;
  ShopCheckoutAttempt? attempt;
  ShopCheckoutReceipt? receipt;
  String get scope => 'africlub-shop-v1:$clubId:$userId';
  void _current() {
    if (!isCurrent()) throw StateError('SHOP_SCOPE_CHANGED');
  }

  void _bind(ShopCheckoutReceipt value) {
    _current();
    if (value.userId != userId ||
        value.clubId.toString() != clubId ||
        value.paymentReference != attempt?.reference ||
        (attempt?.orderId != null && value.id != attempt!.orderId)) {
      throw StateError('SHOP_SCOPE_CHANGED');
    }
    receipt = value;
  }

  Future<void> restore() async {
    _current();
    await journal.runExclusive(scope, () async {
      final saved = await journal.read(scope);
      _current();
      attempt = ShopCheckoutAttempt.decode(saved, userId, clubId);
    });
  }

  Future<void> begin(List<CartItem> items, String address) async {
    _current();
    await journal.runExclusive(scope, () async {
      final saved = await journal.read(scope);
      _current();
      final previous = ShopCheckoutAttempt.decode(saved, userId, clubId);
      if (previous != null) {
        attempt = previous;
        throw StateError('SHOP_UNRESOLVED_ORDER');
      }
      final pending = ShopCheckoutAttempt(
        userId: userId,
        clubId: clubId,
        reference: referenceFactory(),
        items: List.unmodifiable(items),
        address: address,
      );
      if (!RegExp(
        r'^order-[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(pending.reference)) {
        throw StateError('SHOP_REFERENCE_INVALID');
      }
      await journal.save(scope, null, pending.encode());
      if (await journal.read(scope) != pending.encode()) {
        throw StateError('SHOP_RECOVERY_UNAVAILABLE');
      }
      attempt = pending;
      _current();
      await _send(pending, pending.encode());
    });
  }

  Future<void> retryOriginal() async {
    _current();
    await journal.runExclusive(scope, () async {
      final saved = await journal.read(scope);
      _current();
      final prior = ShopCheckoutAttempt.decode(saved, userId, clubId);
      if (prior == null || prior.handoffStarted) {
        throw StateError('SHOP_UNRESOLVED_ORDER');
      }
      attempt = prior;
      // Read first; an accepted order whose HTTP reply was lost is recovered.
      final found = await recover(
        userId: userId,
        clubId: clubId,
        paymentReference: prior.reference,
      ).timeout(timeout);
      _current();
      if (found != null) {
        await _accept(found, prior, saved!);
        return;
      }
      await _send(prior, saved!);
    });
  }

  Future<void> _send(ShopCheckoutAttempt pending, String saved) async {
    final result = await place(
      userId: userId,
      partnerId: clubId,
      items: pending.items,
      deliveryAddress: pending.address,
      paymentReference: pending.reference,
    ).timeout(timeout);
    // Do not expose a completed request to a different account. The original
    // pending journal remains available to its original owner after reauth.
    _current();
    await _accept(result, pending, saved);
  }

  Future<void> _accept(
    ShopCheckoutReceipt result,
    ShopCheckoutAttempt pending,
    String saved,
  ) async {
    _bind(result);
    final bound = pending.bind(result.id);
    await journal.save(scope, saved, bound.encode());
    if (await journal.read(scope) != bound.encode()) {
      throw StateError('SHOP_RECOVERY_UNAVAILABLE');
    }
    attempt = bound;
  }

  Future<ShopCheckoutReceipt?> check() async {
    _current();
    final prior = attempt;
    if (prior == null) return null;
    final result = await recover(
      userId: userId,
      clubId: clubId,
      paymentReference: prior.reference,
    ).timeout(timeout);
    _current();
    if (result != null) {
      await journal.runExclusive(scope, () async {
        final saved = await journal.read(scope);
        _current();
        final stored = ShopCheckoutAttempt.decode(saved, userId, clubId);
        if (stored == null || stored.reference != prior.reference) {
          throw StateError('SHOP_RECOVERY_CONFLICT');
        }
        await _accept(result, stored, saved!);
      });
    }
    return result;
  }

  Future<bool> confirm(ShopCheckoutReceipt review) async {
    _current();
    return journal.runExclusive(scope, () async {
      final saved = await journal.read(scope);
      _current();
      final prior = ShopCheckoutAttempt.decode(saved, userId, clubId);
      if (prior == null || prior.handoffStarted || prior.orderId != review.id) {
        throw StateError('SHOP_UNRESOLVED_ORDER');
      }
      attempt = prior;
      final current = await validate(review).timeout(timeout);
      _bind(current);
      if (!review.sameInstruction(current)) {
        throw ShopCheckoutReviewChanged(current);
      }
      if (!current.canPay ||
          !current.pending ||
          !current.expiresAt.isAfter(DateTime.now().toUtc())) {
        throw StateError('SHOP_PAYMENT_UNAVAILABLE');
      }
      final handoff = prior.handoff();
      await journal.save(scope, saved, handoff.encode());
      if (await journal.read(scope) != handoff.encode()) {
        throw StateError('SHOP_RECOVERY_UNAVAILABLE');
      }
      attempt = handoff;
      _current();
      // Never recalculate with a mutable catalog, country template or route.
      return launch(current.ussdCode).timeout(timeout);
    });
  }

  Future<void> cancelUnpaid(
    Future<void> Function(ShopCheckoutReceipt) cancel,
  ) async {
    _current();
    await journal.runExclusive(scope, () async {
      final saved = await journal.read(scope);
      _current();
      final prior = ShopCheckoutAttempt.decode(saved, userId, clubId);
      final order = receipt;
      if (prior == null ||
          prior.handoffStarted ||
          order == null ||
          !order.pending ||
          prior.orderId != order.id) {
        throw StateError('SHOP_UNRESOLVED_ORDER');
      }
      await cancel(order).timeout(timeout);
      _current();
      final result = await recover(
        userId: userId,
        clubId: clubId,
        paymentReference: prior.reference,
      ).timeout(timeout);
      _current();
      if (result == null) throw StateError('SHOP_RECOVERY_UNAVAILABLE');
      await _accept(result, prior, saved!);
    });
  }

  Future<void> closeTerminal() async {
    _current();
    if (receipt == null || !receipt!.terminal) {
      throw StateError('SHOP_UNRESOLVED_ORDER');
    }
    await journal.runExclusive(scope, () async {
      final saved = await journal.read(scope);
      _current();
      final prior = ShopCheckoutAttempt.decode(saved, userId, clubId);
      if (prior == null || prior.reference != receipt!.paymentReference) {
        throw StateError('SHOP_RECOVERY_CONFLICT');
      }
      await journal.remove(scope, saved!);
      attempt = null;
      receipt = null;
    });
  }
}
