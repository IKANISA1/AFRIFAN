import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_gamification/src/controllers/venue_order_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test('loads the current check-in, approved menu, and latest order', () async {
    final gateway = _Gateway();
    final controller = VenueOrderController(gateway, autoLoad: false);

    await controller.load();

    final state = controller.state.valueOrNull!;
    expect(gateway.loadCalls, 1);
    expect(state.context.hasCheckin, isTrue);
    expect(state.context.menu, hasLength(2));
    expect(state.context.latestOrder?.status, 'preparing');
  });

  test('publishes an honest empty state when no check-in exists', () async {
    final gateway = _Gateway(context: const VenueOrderContext());
    final controller = VenueOrderController(gateway, autoLoad: false);

    await controller.load();

    expect(controller.state.valueOrNull!.context.hasCheckin, isFalse);
    expect(controller.state.hasError, isFalse);
  });

  test('fails before loading or submitting while offline', () async {
    ConnectivityService.setOnlineForTest(false);
    final gateway = _Gateway();
    final controller = VenueOrderController(gateway, autoLoad: false);

    await controller.load();

    expect(
      (controller.state.error as VenueOrderFailure).kind,
      VenueOrderFailureKind.offline,
    );
    expect(gateway.loadCalls, 0);
  });

  test(
    'selection computes the review total and enforces the age gate',
    () async {
      final gateway = _Gateway();
      final controller = VenueOrderController(gateway, autoLoad: false);
      await controller.load();

      controller.setQuantity('water', 2);
      controller.setQuantity('beer', 1);
      var state = controller.state.valueOrNull!;
      expect(state.totalItems, 3);
      expect(state.totalAmount, 5500);
      expect(state.hasAlcoholSelection, isTrue);

      expect(await controller.submit(), isFalse);
      expect(
        controller.state.valueOrNull!.failure?.kind,
        VenueOrderFailureKind.ageGateRequired,
      );

      controller.setAgeGateConfirmed(true);
      state = controller.state.valueOrNull!;
      expect(state.ageGateConfirmed, isTrue);
      expect(state.failure, isNull);
    },
  );

  test(
    'creates once with selected items and publishes server result',
    () async {
      final gateway = _Gateway();
      final controller = VenueOrderController(gateway, autoLoad: false);
      await controller.load();
      controller.setQuantity('water', 2);

      expect(await controller.submit(), isTrue);

      final state = controller.state.valueOrNull!;
      expect(gateway.createCalls, 1);
      expect(gateway.lastQuantities, <String, int>{'water': 2});
      expect(gateway.lastIdempotencyKey, isNotEmpty);
      expect(state.phase, VenueOrderPhase.confirmed);
      expect(state.result?.orderId, 'order-new');
    },
  );

  test('coalesces overlapping loads and submissions', () async {
    final loadCompleter = Completer<VenueOrderContext>();
    final gateway = _Gateway(pendingLoad: loadCompleter.future);
    final controller = VenueOrderController(gateway, autoLoad: false);

    final firstLoad = controller.load();
    final secondLoad = controller.load();
    expect(gateway.loadCalls, 1);
    loadCompleter.complete(_readyContext);
    await Future.wait<void>([firstLoad, secondLoad]);

    final createCompleter = Completer<VenueOrderResult>();
    gateway.pendingCreate = createCompleter.future;
    controller.setQuantity('water', 1);
    final firstCreate = controller.submit();
    final secondCreate = controller.submit();
    expect(await secondCreate, isFalse);
    expect(gateway.createCalls, 1);
    createCompleter.complete(_createdOrder);
    expect(await firstCreate, isTrue);
  });

  test(
    'uncertain timeout blocks replay until deliberately acknowledged',
    () async {
      final gateway = _Gateway(
        pendingCreate: Completer<VenueOrderResult>().future,
      );
      final controller = VenueOrderController(
        gateway,
        autoLoad: false,
        mutationTimeout: const Duration(milliseconds: 10),
      );
      await controller.load();
      controller.setQuantity('water', 1);

      expect(await controller.submit(), isFalse);
      expect(controller.state.valueOrNull!.uncertainMutation, isTrue);
      expect(
        controller.state.valueOrNull!.failure?.kind,
        VenueOrderFailureKind.securityTimeout,
      );
      expect(await controller.submit(), isFalse);
      expect(gateway.createCalls, 1);

      controller.acknowledgeFailure();
      expect(controller.state.valueOrNull!.uncertainMutation, isFalse);
    },
  );

  test(
    'reconnect refreshes retained offline menu without replaying an order',
    () async {
      final gateway = _Gateway();
      final controller = VenueOrderController(gateway, autoLoad: false);
      await controller.load();
      controller.setQuantity('water', 1);

      ConnectivityService.setOnlineForTest(false);
      expect(await controller.submit(), isFalse);
      expect(gateway.createCalls, 0);

      ConnectivityService.setOnlineForTest(true);
      await controller.connectionRestored();

      expect(gateway.loadCalls, 2);
      expect(gateway.createCalls, 0);
      expect(controller.state.valueOrNull!.quantityFor('water'), 1);
    },
  );
}

const _createdOrder = VenueOrderResult(
  status: 'created',
  code: 'ok',
  orderId: 'order-new',
  totalAmount: 3000,
);

const _readyContext = VenueOrderContext(
  checkinId: 'checkin-1',
  venueId: 'venue-1',
  menu: <VenueDrinkItem>[
    VenueDrinkItem(
      id: 'water',
      venueId: 'venue-1',
      name: 'Water',
      description: 'Still water',
      priceAmount: 1500,
      currencyCode: 'RWF',
    ),
    VenueDrinkItem(
      id: 'beer',
      venueId: 'venue-1',
      name: 'Malt drink',
      description: 'Age-restricted venue item',
      priceAmount: 2500,
      currencyCode: 'RWF',
      isAlcohol: true,
    ),
  ],
  latestOrder: VenueOrderResult(
    status: 'preparing',
    code: 'loaded',
    orderId: 'order-old',
    totalAmount: 1500,
  ),
);

class _Gateway implements VenueOrderGateway {
  _Gateway({
    this.context = _readyContext,
    this.pendingLoad,
    this.pendingCreate,
  });

  final VenueOrderContext context;
  final Future<VenueOrderContext>? pendingLoad;
  Future<VenueOrderResult>? pendingCreate;
  int loadCalls = 0;
  int createCalls = 0;
  Map<String, int> lastQuantities = const <String, int>{};
  String lastIdempotencyKey = '';

  @override
  Future<VenueOrderContext> load() {
    loadCalls += 1;
    return pendingLoad ?? Future<VenueOrderContext>.value(context);
  }

  @override
  Future<VenueOrderResult> create({
    required VenueOrderContext context,
    required Map<String, int> quantities,
    required bool ageGateConfirmed,
    required String idempotencyKey,
  }) {
    createCalls += 1;
    lastQuantities = Map<String, int>.from(quantities);
    lastIdempotencyKey = idempotencyKey;
    return pendingCreate ?? Future<VenueOrderResult>.value(_createdOrder);
  }
}
