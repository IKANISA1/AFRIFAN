import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_gamification/src/models/fet_models.dart';
import 'package:feat_gamification/src/providers/fet_wallet_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test('loads wallet and bounded activity projection', () async {
    final gateway = _Gateway();
    final controller = FetWalletController(gateway, autoLoad: false);
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.state.valueOrNull?.wallet?.balance, 1250);
    expect(controller.state.valueOrNull?.transactions, hasLength(1));
    expect(gateway.requestedLimit, 40);
  });

  test('offline load fails before gateway access', () async {
    ConnectivityService.setOnlineForTest(false);
    final gateway = _Gateway();
    final controller = FetWalletController(gateway, autoLoad: false);
    addTearDown(controller.dispose);

    await controller.load();

    expect(gateway.walletLoads, 0);
    expect(
      FetWalletFailure.fromError(controller.state.error!).kind,
      FetWalletFailureKind.offline,
    );
  });

  test('bounded load maps timeout to safe failure', () async {
    final gateway = _Gateway()..walletFuture = Completer<FetWalletSummary?>();
    final controller = FetWalletController(
      gateway,
      loadTimeout: const Duration(milliseconds: 1),
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(
      FetWalletFailure.fromError(controller.state.error!).kind,
      FetWalletFailureKind.securityTimeout,
    );
  });

  test('backend diagnostics map to typed permission failure', () {
    expect(
      FetWalletFailure.fromError(
        StateError('row-level security rejected private ledger row 991'),
      ).kind,
      FetWalletFailureKind.permissionDenied,
    );
    expect(
      FetWalletFailure.fromError(StateError('transport socket 991')).kind,
      FetWalletFailureKind.unknown,
    );
  });

  test('refresh retains confirmed wallet after conflict', () async {
    final gateway = _Gateway();
    final controller = FetWalletController(gateway, autoLoad: false);
    addTearDown(controller.dispose);
    await controller.load();
    gateway.error = StateError('stale revision');

    await controller.refresh();

    final snapshot = controller.state.valueOrNull!;
    expect(snapshot.wallet?.balance, 1250);
    expect(snapshot.phase, FetWalletPhase.degraded);
    expect(snapshot.failure?.kind, FetWalletFailureKind.conflict);
  });

  test(
    'permission revocation hides previously confirmed private data',
    () async {
      final gateway = _Gateway();
      final controller = FetWalletController(gateway, autoLoad: false);
      addTearDown(controller.dispose);
      await controller.load();
      gateway.error = StateError('permission denied');

      await controller.refresh();

      expect(controller.state.hasError, isTrue);
      expect(controller.state.valueOrNull, isNull);
    },
  );

  test('overlapping reads coalesce', () async {
    final completer = Completer<FetWalletSummary?>();
    final gateway = _Gateway()..walletFuture = completer;
    final controller = FetWalletController(gateway, autoLoad: false);
    addTearDown(controller.dispose);

    final first = controller.load();
    final second = controller.refresh();
    completer.complete(_wallet);
    await Future.wait([first, second]);

    expect(gateway.walletLoads, 1);
  });

  test('reconnect refreshes only an offline retained snapshot', () async {
    final gateway = _Gateway();
    final controller = FetWalletController(gateway, autoLoad: false);
    addTearDown(controller.dispose);
    await controller.load();
    ConnectivityService.setOnlineForTest(false);
    await controller.refresh();
    expect(
      controller.state.valueOrNull?.failure?.kind,
      FetWalletFailureKind.offline,
    );
    ConnectivityService.setOnlineForTest(true);

    await controller.connectionRestored();

    expect(gateway.walletLoads, 2);
    expect(controller.state.valueOrNull?.failure, isNull);
  });

  test('reconnect also recovers an initial offline load', () async {
    final gateway = _Gateway();
    final controller = FetWalletController(gateway, autoLoad: false);
    addTearDown(controller.dispose);
    ConnectivityService.setOnlineForTest(false);
    await controller.load();
    expect(controller.state.error, isA<FetWalletFailure>());
    ConnectivityService.setOnlineForTest(true);

    await controller.connectionRestored();

    expect(gateway.walletLoads, 1);
    expect(controller.state.valueOrNull?.wallet, _wallet);
    expect(controller.state.valueOrNull?.failure, isNull);
  });
}

const _wallet = FetWalletSummary(
  userId: 'supporter-synthetic',
  clubId: 24,
  membershipId: 'membership-synthetic',
  balance: 1250,
  tier: 'gold',
  weeklyEarned: 200,
  monthlyEarned: 480,
  lifetimeEarned: 1600,
  lifetimeSpent: 350,
  transactionCount: 1,
  historicalBalanceGap: 0,
);

final _transaction = FetWalletTransaction(
  id: 'entry-synthetic',
  entryType: 'partner_promotion_earn',
  direction: FetWalletEntryDirection.credit,
  amount: 300,
  balanceAfter: 1250,
  counterpartyUserId: null,
  counterpartyDisplayName: null,
  counterpartyPublicUserId: null,
  note: 'Matchday partner reward',
  referenceType: 'partner_initiative',
  referenceId: 'initiative-synthetic',
  createdAt: DateTime.utc(2026, 4, 12, 8),
);

class _Gateway implements FetWalletGateway {
  int walletLoads = 0;
  int requestedLimit = 0;
  Object? error;
  Completer<FetWalletSummary?>? walletFuture;

  @override
  Future<FetWalletSummary?> loadWallet() async {
    walletLoads += 1;
    if (error case final value?) throw value;
    return walletFuture?.future ?? _wallet;
  }

  @override
  Future<List<FetWalletTransaction>> loadTransactions({
    required int limit,
  }) async {
    requestedLimit = limit;
    if (error case final value?) throw value;
    return <FetWalletTransaction>[_transaction];
  }
}
