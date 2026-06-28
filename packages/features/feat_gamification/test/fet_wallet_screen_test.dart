import 'package:feat_gamification/src/fet_providers.dart';
import 'package:feat_gamification/src/models/fet_models.dart';
import 'package:feat_gamification/src/repositories/fet_repository.dart';
import 'package:feat_gamification/src/screens/fet_wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'package:test_support/design_font_loader.dart';

class _MockSupabaseClient extends Mock implements supabase.SupabaseClient {}

class _FakeFetRepository extends FetRepository {
  _FakeFetRepository() : super(client: _MockSupabaseClient());

  String? transferRecipientUserId;
  int? transferAmount;
  String? redeemNote;
  int? redeemAmount;

  @override
  Future<FetWalletSummary?> loadWallet() async {
    return const FetWalletSummary(
      userId: 'supporter-1',
      clubId: 24,
      membershipId: 'membership-1',
      balance: 1250,
      tier: 'gold',
      weeklyEarned: 200,
      monthlyEarned: 480,
      lifetimeEarned: 1600,
      lifetimeSpent: 350,
      transactionCount: 3,
      legacyBalanceGap: 0,
    );
  }

  @override
  Future<List<FetWalletTransaction>> loadWalletTransactions({
    int limit = 50,
    int offset = 0,
  }) async {
    return <FetWalletTransaction>[
      FetWalletTransaction(
        id: 'entry-1',
        entryType: 'transfer_in',
        direction: FetWalletEntryDirection.credit,
        amount: 300,
        balanceAfter: 1250,
        counterpartyUserId: 'supporter-2',
        counterpartyDisplayName: 'Jeanne',
        counterpartyPublicUserId: '483912',
        note: 'Away-day refund',
        referenceType: 'transfer',
        referenceId: 'ref-1',
        createdAt: DateTime.utc(2026, 4, 12, 8),
      ),
    ];
  }

  @override
  Future<List<FetWalletSupporter>> findSupporters(
    String query, {
    int limit = 8,
  }) async {
    return const <FetWalletSupporter>[
      FetWalletSupporter(
        userId: 'supporter-2',
        publicUserId: '483912',
        displayName: 'Jeanne Mukamana',
        tier: 'fan',
        balance: 640,
      ),
    ];
  }

  @override
  Future<FetWalletOperationResult> transferFet({
    required String recipientUserId,
    required int amount,
    String? note,
    String? idempotencyKey,
  }) async {
    transferRecipientUserId = recipientUserId;
    transferAmount = amount;
    return const FetWalletOperationResult(
      status: 'success',
      amount: 150,
      balance: 1100,
      referenceId: 'transfer-ref',
      alreadyProcessed: false,
      recipientUserId: 'supporter-2',
    );
  }

  @override
  Future<FetWalletOperationResult> redeemFet({
    required int amount,
    String? note,
    String? idempotencyKey,
  }) async {
    redeemAmount = amount;
    redeemNote = note;
    return const FetWalletOperationResult(
      status: 'success',
      amount: 200,
      balance: 900,
      referenceId: 'redeem-ref',
      alreadyProcessed: false,
      recipientUserId: null,
    );
  }
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required _FakeFetRepository repository,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [fetRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: FetWalletScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadDesignFonts);

  testWidgets('renders wallet balance and recent activity', (tester) async {
    final repository = _FakeFetRepository();
    await _pumpApp(tester, repository: repository);

    expect(find.textContaining('1,250'), findsOneWidget);
    expect(find.text('TRANSFER FET'), findsOneWidget);

    await _scrollTo(tester, find.text('Transfer received'));

    expect(find.text('Transfer received'), findsOneWidget);
    expect(find.textContaining('Jeanne'), findsOneWidget);
  });

  testWidgets('transfers FET to a searched supporter', (tester) async {
    final repository = _FakeFetRepository();
    await _pumpApp(tester, repository: repository);

    await tester.enterText(
      find.byKey(const ValueKey<String>('wallet-transfer-search')),
      'Jea',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jeanne Mukamana'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('wallet-transfer-amount')),
      '150',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('wallet-transfer-submit')),
    );
    await tester.pumpAndSettle();

    expect(repository.transferRecipientUserId, 'supporter-2');
    expect(repository.transferAmount, 150);
    expect(find.text('Transferred 150 FET.'), findsOneWidget);
  });

  testWidgets('submits a redemption request', (tester) async {
    final repository = _FakeFetRepository();
    await _pumpApp(tester, repository: repository);

    await _scrollTo(
      tester,
      find.byKey(const ValueKey<String>('wallet-redeem-submit')),
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('wallet-redeem-amount')),
      '200',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('wallet-redeem-submit')),
    );
    await tester.pumpAndSettle();

    expect(repository.redeemAmount, 200);
    expect(find.text('Redeemed 200 FET.'), findsOneWidget);
  });
}
