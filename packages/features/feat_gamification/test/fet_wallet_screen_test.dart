import 'package:feat_gamification/src/fet_providers.dart';
import 'package:feat_gamification/src/models/fet_models.dart';
import 'package:feat_gamification/src/repositories/fet_repository.dart';
import 'package:feat_gamification/src/screens/fet_wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'package:test_support/design_font_loader.dart';

class _MockSupabaseClient extends Mock implements supabase.SupabaseClient {}

class _FakeFetRepository extends FetRepository {
  _FakeFetRepository() : super(client: _MockSupabaseClient());

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
      historicalBalanceGap: 0,
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
        entryType: 'partner_promotion_earn',
        direction: FetWalletEntryDirection.credit,
        amount: 300,
        balanceAfter: 1250,
        counterpartyUserId: null,
        counterpartyDisplayName: null,
        counterpartyPublicUserId: null,
        note: 'BK Arena match-day initiative',
        referenceType: 'partner_initiative',
        referenceId: 'initiative-1',
        createdAt: DateTime.utc(2026, 4, 12, 8),
      ),
      FetWalletTransaction(
        id: 'entry-2',
        entryType: 'partner_pool_entry',
        direction: FetWalletEntryDirection.debit,
        amount: 50,
        balanceAfter: 1200,
        counterpartyUserId: null,
        counterpartyDisplayName: null,
        counterpartyPublicUserId: null,
        note: 'WDW pool entry',
        referenceType: 'partner_prediction_pool',
        referenceId: 'pool-1',
        createdAt: DateTime.utc(2026, 4, 12, 9),
      ),
      FetWalletTransaction(
        id: 'entry-3',
        entryType: 'partner_pool_payout',
        direction: FetWalletEntryDirection.credit,
        amount: 100,
        balanceAfter: 1300,
        counterpartyUserId: null,
        counterpartyDisplayName: null,
        counterpartyPublicUserId: null,
        note: 'WDW pool payout',
        referenceType: 'partner_prediction_pool',
        referenceId: 'pool-1',
        createdAt: DateTime.utc(2026, 4, 12, 11),
      ),
    ];
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

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const FetWalletScreen()),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [fetRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(routerConfig: router),
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

    await _scrollTo(tester, find.text('Partner rewards'));

    expect(find.text('Partner rewards'), findsOneWidget);
    expect(
      find.text('Earn FET from partner initiatives and promotions.'),
      findsOneWidget,
    );

    await _scrollTo(tester, find.text('Partner FET earned'));

    expect(find.text('Partner FET earned'), findsOneWidget);
    expect(find.text('Partner pool entry'), findsOneWidget);
    expect(find.text('Partner pool payout'), findsOneWidget);
  });

  testWidgets('does not expose public transfer controls', (tester) async {
    final repository = _FakeFetRepository();
    await _pumpApp(tester, repository: repository);

    expect(
      find.byKey(const ValueKey<String>('wallet-transfer-search')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('wallet-transfer-amount')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('wallet-transfer-submit')),
      findsNothing,
    );
    expect(find.text('Send FET'), findsNothing);
  });

  testWidgets('does not expose manual redemption controls', (tester) async {
    final repository = _FakeFetRepository();
    await _pumpApp(tester, repository: repository);

    expect(
      find.byKey(const ValueKey<String>('wallet-redeem-amount')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('wallet-redeem-submit')),
      findsNothing,
    );
    expect(find.text('Redeem FET'), findsNothing);
  });
}
