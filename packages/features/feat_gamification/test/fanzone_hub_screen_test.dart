import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_gamification/src/models/fet_models.dart';
import 'package:feat_gamification/src/models/partner_pool_models.dart';
import 'package:feat_gamification/src/models/prediction_models.dart';
import 'package:feat_gamification/src/prediction_providers.dart';
import 'package:feat_gamification/src/providers/fanzone_hub_provider.dart';
import 'package:feat_gamification/src/screens/fanzone_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'package:test_support/design_font_loader.dart';

class _TestFanzoneHubNotifier extends FanzoneHubNotifier {
  _TestFanzoneHubNotifier(this._snapshot);

  final FanzoneHubSnapshot _snapshot;
  int refreshCount = 0;

  @override
  Future<FanzoneHubSnapshot> build() async => _snapshot;

  @override
  Future<void> refresh() async {
    refreshCount++;
    state = AsyncData(_snapshot);
  }
}

class _PendingFanzoneHubNotifier extends FanzoneHubNotifier {
  @override
  Future<FanzoneHubSnapshot> build() => Completer<FanzoneHubSnapshot>().future;
}

class _MockSupabaseClient extends Mock implements supabase.SupabaseClient {}

class _FakePartnerPoolRepository extends PartnerPoolRepository {
  _FakePartnerPoolRepository() : super(client: _MockSupabaseClient());

  String? joinedPoolId;
  String? selectedOutcome;
  String? idempotencyKey;

  @override
  Future<PartnerPoolMutationResult> joinPool({
    required String poolId,
    required String selectedOutcome,
    String? idempotencyKey,
  }) async {
    joinedPoolId = poolId;
    this.selectedOutcome = selectedOutcome;
    this.idempotencyKey = idempotencyKey;
    return const PartnerPoolMutationResult(status: 'success');
  }
}

FanzoneHubSnapshot _buildSnapshot() {
  return FanzoneHubSnapshot(
    dashboard: const PredictionDashboard(
      totalPredictions: 12,
      settledCount: 8,
      wonCount: 5,
      lostCount: 3,
      activeCount: 4,
      totalFetEarned: 240,
      currentStreak: 3,
      winRate: 62.5,
    ),
    wallet: const FetWalletSummary(
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
    ),
    liveFixtures: <FixtureSummary>[
      FixtureSummary(
        id: 'fixture-live',
        competitionSlug: 'rpl',
        competitionName: 'Rwanda Premier League',
        seasonLabel: '2025/26',
        matchday: 24,
        homeTeamName: 'Rayon Sports',
        homeTeamShort: 'RAY',
        awayTeamName: 'Rayon Sports',
        awayTeamShort: 'Rayon Sports',
        kickoffAt: DateTime.utc(2026, 4, 14, 16),
        venueName: 'Kigali Pele Stadium',
        status: 'live',
        homeScore: 2,
        awayScore: 1,
      ),
    ],
    todayFixtures: <FixtureSummary>[
      FixtureSummary(
        id: 'fixture-today',
        competitionSlug: 'rpl',
        competitionName: 'Rwanda Premier League',
        seasonLabel: '2025/26',
        matchday: 25,
        homeTeamName: 'Musanze FC',
        homeTeamShort: 'MUS',
        awayTeamName: 'Etincelles',
        awayTeamShort: 'ETI',
        kickoffAt: DateTime.utc(2026, 4, 14, 19),
        venueName: 'Musanze Stadium',
        status: 'scheduled',
      ),
    ],
    upcomingFixtures: <FixtureSummary>[
      FixtureSummary(
        id: 'fixture-upcoming',
        competitionSlug: 'epl',
        competitionName: 'Premier League',
        seasonLabel: '2025/26',
        matchday: 31,
        homeTeamName: 'Liverpool',
        homeTeamShort: 'LIV',
        awayTeamName: 'Arsenal',
        awayTeamShort: 'ARS',
        kickoffAt: DateTime.utc(2026, 4, 15, 18),
        venueName: 'Anfield',
        status: 'scheduled',
      ),
    ],
    leaderboard: const <PredictionLeaderboardEntry>[
      PredictionLeaderboardEntry(
        rank: 1,
        userId: 'user-1',
        displayName: 'Supporter One',
        wins: 12,
        totalSettled: 18,
        totalFetEarned: 640,
        winRate: 66.7,
      ),
    ],
    partnerPools: <PartnerPredictionPool>[
      PartnerPredictionPool(
        id: 'pool-1',
        clubId: 24,
        partnerId: 'partner-1',
        partnerName: 'Visit Rwanda',
        partnerSlug: 'visit-rwanda',
        fixtureId: 'fixture-upcoming',
        title: 'Derby WDW Pool',
        partnerStakeFet: 5000,
        fanEntryFet: 100,
        eligibilityMode: 'partner_earn_required',
        status: 'open',
        lockAt: DateTime.utc(2026, 4, 15, 18),
        totalEntries: 12,
        totalFanEntryFet: 1200,
      ),
    ],
    markets: const <PredictionMarket>[
      PredictionMarket(
        id: 'market-1',
        slug: '1x2',
        name: 'Match Result',
        shortName: '1X2',
        marketGroup: MarketGroup.matchResult,
        marketCategory: 'Match Betting',
        betType: 'single',
        difficultyTier: DifficultyTier.entry,
        defaultFetValue: 100,
        baseFet: 100,
        description: 'Predict the winner.',
        outcomeTemplate: <MarketOutcomeOption>[
          MarketOutcomeOption(key: 'home', label: 'Home'),
          MarketOutcomeOption(key: 'draw', label: 'Draw'),
          MarketOutcomeOption(key: 'away', label: 'Away'),
        ],
        sortOrder: 1,
        leagueAvailability: <String>['rpl', 'epl'],
      ),
    ],
    challenges: const <FetCatalogItem>[
      FetCatalogItem(
        id: 'cat-1',
        clubId: 24,
        code: 'PREDICTION_WIN',
        templateScope: 'club',
        category: 'Prediction',
        itemName: 'Correct 1X2 Prediction',
        fetValue: 10,
        triggerCondition: 'Win a 1X2 market',
        activationTiming: 'Always on',
        description: 'Base earn for a correct prediction.',
        badgeName: null,
        implementationNotes: null,
        sortOrder: 1,
        isActive: true,
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadDesignFonts);

  testWidgets('renders live fan engagement sections from repository data', (
    tester,
  ) async {
    final snapshot = _buildSnapshot();

    await tester.pumpWidget(
      _buildFanzoneApp(() => _TestFanzoneHubNotifier(snapshot)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) => widget is AfriAsyncStateView<FanzoneHubSnapshot>,
      ),
      findsOneWidget,
    );
    expect(find.text('Fanzone'), findsOneWidget);
    expect(find.byType(AfriSegmentedControl), findsOneWidget);
    expect(find.text('Pick'), findsOneWidget);
    expect(find.text('Lge'), findsOneWidget);
    expect(find.text('Pay'), findsOneWidget);
    expect(find.text('Fans'), findsOneWidget);
    expect(find.text('Gift'), findsOneWidget);
    expect(find.text('Jackpot'), findsNothing);
    expect(find.byTooltip('More options'), findsOneWidget);
    expect(find.text('TV game'), findsOneWidget);
    expect(find.text('Enter TV code'), findsOneWidget);

    expect(find.text('Matchday rounds'), findsOneWidget);
    expect(find.text('100 point entry'), findsOneWidget);
    expect(find.text('Join round'), findsOneWidget);
    expect(find.text('Challenges'), findsNothing);
  });

  testWidgets('matches the fanzone hub content layout', (tester) async {
    _setMobileSurface(tester);

    await tester.pumpWidget(
      _buildFanzoneApp(() => _TestFanzoneHubNotifier(_buildSnapshot())),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(FanzoneHubScreen),
      matchesGoldenFile('goldens/fanzone_hub_screen.png'),
    );
  });

  testWidgets('matches the fanzone hub loading layout', (tester) async {
    _setMobileSurface(tester);

    await tester.pumpWidget(_buildFanzoneApp(_PendingFanzoneHubNotifier.new));
    await tester.pump();

    await expectLater(
      find.byType(FanzoneHubScreen),
      matchesGoldenFile('goldens/fanzone_hub_screen_loading.png'),
    );
  });

  testWidgets('matches the fanzone degraded/offline layout', (tester) async {
    _setMobileSurface(tester);
    const snapshot = FanzoneHubSnapshot(
      status: FanzoneHubStatus.error,
      message: 'Fanzone is temporarily unavailable.',
    );

    await tester.pumpWidget(
      _buildFanzoneApp(() => _TestFanzoneHubNotifier(snapshot)),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(FanzoneHubScreen),
      matchesGoldenFile('goldens/fanzone_hub_screen_degraded.png'),
    );
  });

  testWidgets('joins a partner WDW pool with a fixed fan FET stake', (
    tester,
  ) async {
    final snapshot = _buildSnapshot();
    final notifier = _TestFanzoneHubNotifier(snapshot);
    final partnerPoolRepository = _FakePartnerPoolRepository();

    await tester.pumpWidget(
      _buildFanzoneApp(
        () => notifier,
        overrides: [
          partnerPoolRepositoryProvider.overrideWithValue(
            partnerPoolRepository,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Join round'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AfriButton, 'Join round').first);
    await tester.pumpAndSettle();

    expect(find.text('Derby WDW Pool'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Visit Rwanda sponsors'), findsOneWidget);
    expect(find.text('Partner earn required'), findsOneWidget);
    expect(find.text('Home win'), findsOneWidget);
    expect(find.text('Draw'), findsOneWidget);
    expect(find.text('Away win'), findsOneWidget);

    await tester.tap(find.text('Draw'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AfriButton, 'Join round').last);
    await tester.pumpAndSettle();

    expect(partnerPoolRepository.joinedPoolId, 'pool-1');
    expect(partnerPoolRepository.selectedOutcome, 'draw');
    expect(partnerPoolRepository.idempotencyKey, startsWith('pool-1-draw-'));
    expect(notifier.refreshCount, 1);
    expect(find.text('Draw joined.'), findsOneWidget);
  });

  testWidgets('loading state still exposes fanzone route shortcuts', (
    tester,
  ) async {
    await tester.pumpWidget(_buildFanzoneApp(_PendingFanzoneHubNotifier.new));
    await tester.pump();

    expect(find.text('Opening Fanzone'), findsOneWidget);
    expect(find.text('Pick'), findsOneWidget);
    expect(find.text('Lge'), findsOneWidget);
    expect(find.text('Pay'), findsOneWidget);
    expect(find.text('Fans'), findsOneWidget);
    expect(find.text('Gift'), findsOneWidget);
    expect(find.text('Jackpot'), findsNothing);
  });

  testWidgets('offline snapshot shows bounded degraded sections', (
    tester,
  ) async {
    const snapshot = FanzoneHubSnapshot(
      status: FanzoneHubStatus.error,
      message: 'Fanzone is temporarily unavailable.',
    );

    await tester.pumpWidget(
      _buildFanzoneApp(
        () => _TestFanzoneHubNotifier(snapshot),
        initialLocation: '/fanzone?section=league',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Live updates paused'), findsOneWidget);
    expect(find.byType(AfriStateBanner), findsOneWidget);
    expect(find.text('Lge'), findsOneWidget);
    expect(find.text('TV game'), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Markets unavailable'), findsNothing);
    expect(find.text('No matchday rounds'), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('Leaderboard unavailable'), findsOneWidget);
    expect(find.text('Challenges unavailable'), findsNothing);
  });
}

Widget _buildFanzoneApp(
  FanzoneHubNotifier Function() createNotifier, {
  List<Override> overrides = const [],
  String initialLocation = '/fanzone',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/fanzone',
        builder: (context, state) => const FanzoneHubScreen(),
      ),
      GoRoute(
        path: '/fanzone/my',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/fanzone/match/:fixtureId',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith(
        (ref) => const UserProfile(
          id: 'supporter-1',
          clubId: '24',
          publicUserId: '483912',
        ),
      ),
      fanzoneHubProvider.overrideWith(createNotifier),
      ...overrides,
    ],
    child: MaterialApp.router(
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(disableAnimations: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: router,
    ),
  );
}

void _setMobileSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
