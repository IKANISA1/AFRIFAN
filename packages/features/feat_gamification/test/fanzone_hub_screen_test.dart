import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
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

import 'package:test_support/app_font_loader.dart';
import 'package:test_support/touch_target_audit.dart';

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

class _ErrorFanzoneHubNotifier extends FanzoneHubNotifier {
  @override
  Future<FanzoneHubSnapshot> build() {
    throw StateError('Synthetic Fan Zone request failure');
  }
}

class _RefreshingFanzoneHubNotifier extends FanzoneHubNotifier {
  _RefreshingFanzoneHubNotifier(this._snapshot, this._refreshCompleter);

  final FanzoneHubSnapshot _snapshot;
  final Completer<FanzoneHubSnapshot> _refreshCompleter;

  @override
  Future<FanzoneHubSnapshot> build() async => _snapshot;

  @override
  Future<void> refresh() async {
    state = const AsyncLoading<FanzoneHubSnapshot>().copyWithPrevious(state);
    state = AsyncData(await _refreshCompleter.future);
  }
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

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(clubId: '24');

  @override
  Future<UserProfile?> restoreCurrentUser() async {
    return const UserProfile(
      id: 'supporter-1',
      clubId: '24',
      publicUserId: '483912',
    );
  }

  @override
  Future<AdminWorkspaceAccess> resolveAdminAccess(String userId) async {
    return AdminWorkspaceAccess.none;
  }

  @override
  Stream<supabase.AuthState> get authStateChanges =>
      const Stream<supabase.AuthState>.empty();
}

const _enabledFanzoneFeatures = PlatformConfigSnapshot(
  features: <PlatformFeature>[
    PlatformFeature(
      featureKey: 'challenge',
      displayName: 'Challenge',
      isEnabled: true,
      visibilityState: 'visible',
    ),
    PlatformFeature(
      featureKey: 'venue_checkin',
      displayName: 'Venue Check-in',
      isEnabled: true,
      visibilityState: 'visible',
    ),
  ],
);

const _disabledFanzoneFeatures = PlatformConfigSnapshot(
  features: <PlatformFeature>[
    PlatformFeature(
      featureKey: 'challenge',
      displayName: 'Challenge',
      isEnabled: true,
      visibilityState: 'visible',
    ),
    PlatformFeature(
      featureKey: 'venue_checkin',
      displayName: 'Venue Check-in',
      isEnabled: false,
      visibilityState: 'visible',
    ),
  ],
);

const _fanzoneStateGoldenPaths = <String, String>{
  'loading': 'goldens/fanzone_state_loading_dark_390x844.png',
  'empty': 'goldens/fanzone_state_empty_dark_390x844.png',
  'error': 'goldens/fanzone_state_error_dark_390x844.png',
  'offline': 'goldens/fanzone_state_offline_dark_390x844.png',
  'large_text': 'goldens/fanzone_state_large_text_dark_320x720.png',
  'selected': 'goldens/fanzone_state_selected_dark_390x844.png',
  'permission_denied':
      'goldens/fanzone_state_permission_denied_dark_390x844.png',
  'disabled': 'goldens/fanzone_state_disabled_dark_390x844.png',
  'focused': 'goldens/fanzone_state_focused_dark_390x844.png',
  'pressed': 'goldens/fanzone_state_pressed_dark_390x844.png',
  'syncing': 'goldens/fanzone_state_syncing_dark_390x844.png',
  'conflict': 'goldens/fanzone_state_conflict_dark_390x844.png',
  'security_timeout': 'goldens/fanzone_state_security_timeout_dark_390x844.png',
};

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
  setUpAll(loadAppFonts);
  setUp(() => ConnectivityService.setOnlineForTest(true));

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
    expect(find.text('Fan Zone'), findsOneWidget);
    expect(find.byType(AfriSegmentedControl), findsOneWidget);
    expect(find.text('Pick'), findsOneWidget);
    expect(find.text('League'), findsOneWidget);
    expect(find.text('Points'), findsOneWidget);
    expect(find.text('Fans'), findsOneWidget);
    expect(find.text('Rewards'), findsOneWidget);
    expect(find.text('Jackpot'), findsNothing);
    expect(find.byTooltip('More options'), findsOneWidget);
    expect(find.text('Matchday rounds'), findsWidgets);
    expect(find.text('100 point entry'), findsOneWidget);
    expect(find.text('Join round'), findsOneWidget);
    expectTapTargetsMeetMinimum(tester);

    await _scrollFanzoneTo(tester, find.text('Live games'));

    expect(find.text('Matchday rounds'), findsWidgets);
    expect(find.text('Supporters'), findsOneWidget);
    expect(find.text('Live games'), findsOneWidget);
    expect(find.text('TV Code'), findsNothing);
    expect(
      find.text('Eligible club games appear here automatically.'),
      findsOneWidget,
    );
    expect(find.text('Enter TV code'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Supporters')).dy,
      lessThan(tester.getTopLeft(find.text('Live games')).dy),
    );
    expect(find.text('Challenges'), findsNothing);
    expectTapTargetsMeetMinimum(tester);
  });

  testWidgets(
    'wallet and legacy points query targets open the Points section',
    (tester) async {
      for (final location in const <String>[
        '/fanzone?section=wallet',
        '/fanzone?section=points',
      ]) {
        await tester.pumpWidget(
          _buildFanzoneApp(
            () => _TestFanzoneHubNotifier(_buildSnapshot()),
            initialLocation: location,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Points'), findsAtLeastNWidgets(1));
        expect(find.text('Points balance'), findsOneWidget);
        expect(find.text('Live games'), findsNothing);
      }
    },
  );

  testWidgets(
    'preserves selected section, route state, and scroll across resize and resume',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildFanzoneApp(
          () => _TestFanzoneHubNotifier(_buildSnapshot()),
          initialLocation: '/fanzone?section=league',
        ),
      );
      await tester.pumpAndSettle();

      AfriSegmentedControl selectedControl() => tester
          .widget<AfriSegmentedControl>(find.byType(AfriSegmentedControl));

      expect(selectedControl().selectedIndex, 1);
      expect(find.text('Live Now'), findsOneWidget);

      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -420));
      await tester.pumpAndSettle();
      final beforeResize = tester
          .state<ScrollableState>(scrollable)
          .position
          .pixels;
      expect(beforeResize, greaterThan(0));

      tester.view.physicalSize = const Size(852, 393);
      await tester.pumpAndSettle();

      expect(find.byType(FanzoneHubScreen), findsOneWidget);
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        greaterThan(0),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.byType(FanzoneHubScreen), findsOneWidget);
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        greaterThan(0),
      );

      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(selectedControl().selectedIndex, 1);
      expect(find.text('Live Now'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('matches the fanzone hub content layout', (tester) async {
    _setMobileSurface(tester);

    await tester.pumpWidget(
      _buildFanzoneApp(() => _TestFanzoneHubNotifier(_buildSnapshot())),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FanzoneHubScreen), findsOneWidget);
  });

  testWidgets('matches the fanzone hub loading layout', (tester) async {
    _setMobileSurface(tester);

    await tester.pumpWidget(_buildFanzoneApp(_PendingFanzoneHubNotifier.new));
    await tester.pump();

    expect(find.byType(FanzoneHubScreen), findsOneWidget);
    final loadingInset = tester.widget<Padding>(
      find.byKey(const ValueKey('afri-screen-bottom-inset')),
    );
    expect(
      loadingInset.padding.resolve(TextDirection.ltr).bottom,
      AfriClubBottomNav.contentBottomInset(
        tester.element(find.byKey(const ValueKey('afri-screen-bottom-inset'))),
      ),
    );
  });

  testWidgets(
    'reserves floating navigation clearance in landscape without keyboard double padding',
    (tester) async {
      tester.view.physicalSize = const Size(852, 393);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewPadding = const FakeViewPadding(bottom: 18);
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(
        _buildFanzoneApp(() => _TestFanzoneHubNotifier(_buildSnapshot())),
      );
      await tester.pumpAndSettle();

      final inset = tester.widget<Padding>(
        find.byKey(const ValueKey('afri-screen-bottom-inset')),
      );
      expect(
        inset.padding.resolve(TextDirection.ltr).bottom,
        AfriClubBottomNav.regularHeight +
            AfriClubBottomNav.bottomMargin +
            AfriClubBottomNav.contentClearance,
      );
      expect(inset.padding.resolve(TextDirection.ltr).bottom, lessThan(220));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact-height landscape keeps Fan Zone content and primary actions usable',
    (tester) async {
      tester.view.physicalSize = const Size(720, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildFanzoneApp(() => _TestFanzoneHubNotifier(_buildSnapshot())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FanzoneHubScreen), findsOneWidget);
      expect(find.byType(AfriSegmentedControl), findsOneWidget);
      await _scrollFanzoneTo(tester, find.text('Live games'));
      expect(find.text('Live games'), findsOneWidget);
      expect(find.text('Enter TV code'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('uses compact navigation clearance at 200 percent text', (
    tester,
  ) async {
    _setMobileSurface(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      _buildFanzoneApp(() => _TestFanzoneHubNotifier(_buildSnapshot())),
    );
    await tester.pumpAndSettle();

    final inset = tester.widget<Padding>(
      find.byKey(const ValueKey('afri-screen-bottom-inset')),
    );
    expect(
      inset.padding.resolve(TextDirection.ltr).bottom,
      AfriClubBottomNav.compactHeight +
          AfriClubBottomNav.bottomMargin +
          AfriClubBottomNav.contentClearance,
    );
    expect(tester.takeException(), isNull);
  });

  for (final locale in const <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('rw'),
  ]) {
    testWidgets(
      '${locale.languageCode} Fan Zone task copy fits at 320px and 200 percent',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final l10n = lookupAfriLocalizations(locale);

        await tester.pumpWidget(
          _buildFanzoneApp(
            () => _TestFanzoneHubNotifier(_buildSnapshot()),
            appLocale: locale,
          ),
        );
        await tester.pumpAndSettle();

        await _scrollFanzoneTo(tester, find.text(l10n.gameLiveGamesTitle));
        expect(find.text(l10n.gameLiveGamesSubtitle), findsOneWidget);
        expect(find.text(l10n.gameEnterTvCode), findsNothing);
        expect(find.text(l10n.fanZoneVenueCode), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('matches the fanzone degraded/offline layout', (tester) async {
    _setMobileSurface(tester);
    const snapshot = FanzoneHubSnapshot(
      status: FanzoneHubStatus.error,
      message: 'Fan Zone is temporarily unavailable.',
    );

    await tester.pumpWidget(
      _buildFanzoneApp(() => _TestFanzoneHubNotifier(snapshot)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FanzoneHubScreen), findsOneWidget);
  });

  testWidgets('store release omits partner stake and reward surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildFanzoneApp(
        () => _TestFanzoneHubNotifier(_buildSnapshot()),
        storePolicy: const StoreReleasePolicy(isEnforced: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Join round'), findsNothing);
    expect(find.text('Derby WDW Pool'), findsNothing);
    expect(find.text('Rewards'), findsNothing);
    expect(find.byType(FanzoneHubScreen), findsOneWidget);
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

    await _scrollFanzoneTo(tester, find.text('Join round'));
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

  testWidgets('keeps pool choices visible but blocks joining offline', (
    tester,
  ) async {
    final snapshot = _buildSnapshot();
    final partnerPoolRepository = _FakePartnerPoolRepository();

    await tester.pumpWidget(
      _buildFanzoneApp(
        () => _TestFanzoneHubNotifier(snapshot),
        overrides: [
          partnerPoolRepositoryProvider.overrideWithValue(
            partnerPoolRepository,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    ConnectivityService.setOnlineForTest(false);
    await tester.pump();
    await _scrollFanzoneTo(tester, find.text('Join round'));
    await tester.tap(find.widgetWithText(AfriButton, 'Join round').first);
    await tester.pumpAndSettle();

    expect(find.text('Derby WDW Pool'), findsAtLeastNWidgets(1));
    expect(find.text('Connection required'), findsOneWidget);
    final submit = tester.widget<AfriButton>(
      find.widgetWithText(AfriButton, 'Connection required'),
    );
    expect(submit.enabled, isFalse);
    expect(partnerPoolRepository.joinedPoolId, isNull);
  });

  testWidgets('loading state still exposes fanzone route shortcuts', (
    tester,
  ) async {
    await tester.pumpWidget(_buildFanzoneApp(_PendingFanzoneHubNotifier.new));
    await tester.pump();

    expect(find.text('Opening Fan Zone'), findsOneWidget);
    expect(find.text('Pick'), findsOneWidget);
    expect(find.text('League'), findsOneWidget);
    expect(find.text('Points'), findsOneWidget);
    expect(find.text('Fans'), findsOneWidget);
    expect(find.text('Rewards'), findsOneWidget);
    expect(find.text('Jackpot'), findsNothing);
  });

  testWidgets('offline snapshot shows bounded degraded sections', (
    tester,
  ) async {
    const snapshot = FanzoneHubSnapshot(
      status: FanzoneHubStatus.error,
      message: 'Fan Zone is temporarily unavailable.',
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
    expect(find.text('League'), findsOneWidget);
    expect(find.text('Live games'), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Markets unavailable'), findsNothing);
    expect(find.text('No matchday rounds'), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('Leaderboard unavailable'), findsOneWidget);
    expect(find.text('Challenges unavailable'), findsNothing);
  });

  for (final profile in _compactGoldenProfiles) {
    testWidgets('golden compact Fan Zone route ${profile.id}', (tester) async {
      _setGoldenSurface(tester, profile.size);
      TypographyTokens.debugUseFallbackFonts = true;
      addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
      ColorTokens.setBrightness(profile.brightness);
      addTearDown(() => ColorTokens.setBrightness(Brightness.dark));

      await tester.pumpWidget(
        _buildFanzoneApp(
          () => _TestFanzoneHubNotifier(_buildSnapshot()),
          brightness: profile.brightness,
          goldenKey: const ValueKey<String>('fanzone-route-golden'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey<String>('fanzone-route-golden')),
        matchesGoldenFile('goldens/fanzone_${profile.id}.png'),
      );
    });
  }

  testWidgets('golden Fan Zone route loading state', (tester) async {
    await _pumpFanzoneStateGolden(
      tester,
      id: 'loading',
      createNotifier: _PendingFanzoneHubNotifier.new,
      settle: false,
    );
  });

  testWidgets('golden Fan Zone route empty state', (tester) async {
    await _pumpFanzoneStateGolden(
      tester,
      id: 'empty',
      createNotifier: () => _TestFanzoneHubNotifier(const FanzoneHubSnapshot()),
      scrollToText: 'No matchday rounds',
    );
  });

  testWidgets('golden Fan Zone route error state', (tester) async {
    await _pumpFanzoneStateGolden(
      tester,
      id: 'error',
      createNotifier: _ErrorFanzoneHubNotifier.new,
    );
  });

  testWidgets('golden Fan Zone route offline state', (tester) async {
    await _pumpFanzoneStateGolden(
      tester,
      id: 'offline',
      createNotifier: () => _TestFanzoneHubNotifier(
        const FanzoneHubSnapshot(
          status: FanzoneHubStatus.error,
          message: 'Connect to load Fan Zone.',
        ),
      ),
      online: false,
    );
  });

  testWidgets('golden Fan Zone route large-text state', (tester) async {
    await _pumpFanzoneStateGolden(
      tester,
      id: 'large_text',
      createNotifier: () => _TestFanzoneHubNotifier(_buildSnapshot()),
      size: const Size(320, 720),
      textScale: 2,
    );
  });

  testWidgets('golden Fan Zone route selected state', (tester) async {
    await _pumpFanzoneStateGolden(
      tester,
      id: 'selected',
      createNotifier: () => _TestFanzoneHubNotifier(_buildSnapshot()),
      initialLocation: '/fanzone?section=league',
    );
  });

  testWidgets('golden Fan Zone route permission-denied state', (tester) async {
    await _pumpFanzoneStateGolden(
      tester,
      id: 'permission_denied',
      createNotifier: () => FanzoneHubNotifier(
        loadOverride: () async {
          throw StateError('row-level security policy rejected account 991');
        },
      ),
      beforeCapture: (tester) async {
        expect(find.text('Fan Zone access not available'), findsOneWidget);
        expect(find.text('Retry'), findsNothing);
        expect(find.textContaining('991'), findsNothing);
      },
    );
  });

  testWidgets('golden Fan Zone route disabled state', (tester) async {
    await _pumpFanzoneStateGolden(
      tester,
      id: 'disabled',
      createNotifier: () => _TestFanzoneHubNotifier(_buildSnapshot()),
      overrides: [
        initialFeatureConfigSnapshotProvider.overrideWithValue(
          _disabledFanzoneFeatures,
        ),
      ],
      beforeCapture: (tester) async {
        expect(find.text('Unavailable'), findsNWidgets(2));
        final venueRow = tester.widget<AfriListRow>(
          find.ancestor(
            of: find.text('Venue check-in'),
            matching: find.byType(AfriListRow),
          ),
        );
        expect(venueRow.enabled, isFalse);
      },
    );
  });

  testWidgets('golden Fan Zone route focused state', (tester) async {
    final previousHighlightStrategy = FocusManager.instance.highlightStrategy;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousHighlightStrategy,
    );
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;

    await _pumpFanzoneStateGolden(
      tester,
      id: 'focused',
      createNotifier: () => _TestFanzoneHubNotifier(_buildSnapshot()),
      beforeCapture: (tester) async {
        final focusable = find
            .descendant(
              of: find.byType(AfriSegmentedControl),
              matching: find.byType(FocusableActionDetector),
            )
            .at(1);
        final gestureDetector = find
            .descendant(of: focusable, matching: find.byType(GestureDetector))
            .first;
        Focus.of(tester.element(gestureDetector)).requestFocus();
        await tester.pumpAndSettle();
        expect(Focus.of(tester.element(gestureDetector)).hasFocus, isTrue);
      },
    );
  });

  testWidgets('golden Fan Zone route pressed state', (tester) async {
    TestGesture? heldGesture;
    await _pumpFanzoneStateGolden(
      tester,
      id: 'pressed',
      createNotifier: () => _TestFanzoneHubNotifier(_buildSnapshot()),
      beforeCapture: (tester) async {
        heldGesture = await tester.startGesture(
          tester.getCenter(find.bySemanticsLabel('League')),
        );
        await tester.pump(const Duration(milliseconds: 120));
      },
      afterCapture: (tester) async {
        await heldGesture?.up();
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('golden Fan Zone route syncing state', (tester) async {
    final refreshCompleter = Completer<FanzoneHubSnapshot>();
    late _RefreshingFanzoneHubNotifier notifier;
    await _pumpFanzoneStateGolden(
      tester,
      id: 'syncing',
      createNotifier: () => notifier = _RefreshingFanzoneHubNotifier(
        _buildSnapshot(),
        refreshCompleter,
      ),
      beforeCapture: (tester) async {
        unawaited(notifier.refresh());
        await tester.pump();
        expect(find.text('Refreshing Fan Zone'), findsOneWidget);
        expect(find.text('Live games'), findsOneWidget);
      },
      afterCapture: (tester) async {
        refreshCompleter.complete(_buildSnapshot());
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('golden Fan Zone route conflict state', (tester) async {
    await _pumpFanzoneStateGolden(
      tester,
      id: 'conflict',
      createNotifier: () => FanzoneHubNotifier(
        loadOverride: () async {
          throw StateError('stale revision conflict for supporter-991');
        },
      ),
      beforeCapture: (tester) async {
        expect(find.text('Fan Zone changed'), findsOneWidget);
        expect(find.text('Refresh'), findsOneWidget);
        expect(find.textContaining('991'), findsNothing);
      },
    );
  });

  testWidgets('golden Fan Zone route security-timeout state', (tester) async {
    final pending = Completer<FanzoneHubSnapshot>();
    await _pumpFanzoneStateGolden(
      tester,
      id: 'security_timeout',
      createNotifier: () => FanzoneHubNotifier(
        loadOverride: () => pending.future,
        loadTimeout: const Duration(milliseconds: 1),
      ),
      beforeCapture: (tester) async {
        expect(find.text('Fan Zone security check timed out'), findsOneWidget);
        expect(find.text('Refresh'), findsOneWidget);
      },
    );
  });
}

Future<void> _pumpFanzoneStateGolden(
  WidgetTester tester, {
  required String id,
  required FanzoneHubNotifier Function() createNotifier,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool settle = true,
  bool online = true,
  String initialLocation = '/fanzone',
  String? scrollToText,
  List<Override> overrides = const [],
  Future<void> Function(WidgetTester tester)? beforeCapture,
  Future<void> Function(WidgetTester tester)? afterCapture,
}) async {
  _setGoldenSurface(tester, size);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  TypographyTokens.debugUseFallbackFonts = true;
  addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
  ColorTokens.setBrightness(Brightness.dark);
  addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
  ConnectivityService.setOnlineForTest(online);
  addTearDown(() => ConnectivityService.setOnlineForTest(true));

  await tester.pumpWidget(
    _buildFanzoneApp(
      createNotifier,
      overrides: overrides,
      initialLocation: initialLocation,
      goldenKey: const ValueKey<String>('fanzone-state-golden'),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }

  await beforeCapture?.call(tester);

  final scrollables = find.byType(Scrollable);
  if (scrollToText != null) {
    await tester.scrollUntilVisible(
      find.text(scrollToText),
      300,
      scrollable: scrollables.first,
    );
    await tester.pumpAndSettle();
  } else if (scrollables.evaluate().isNotEmpty) {
    tester.state<ScrollableState>(scrollables.first).position.jumpTo(0);
    await tester.pump();
  }

  expect(tester.takeException(), isNull);
  final goldenPath = _fanzoneStateGoldenPaths[id];
  expect(
    goldenPath,
    isNotNull,
    reason: 'Missing Fan Zone golden path for $id.',
  );
  await expectLater(
    find.byKey(const ValueKey<String>('fanzone-state-golden')),
    matchesGoldenFile(goldenPath!),
  );
  await afterCapture?.call(tester);
}

Widget _buildFanzoneApp(
  FanzoneHubNotifier Function() createNotifier, {
  List<Override> overrides = const [],
  String initialLocation = '/fanzone',
  Brightness brightness = Brightness.dark,
  Key? goldenKey,
  Locale? appLocale,
  StoreReleasePolicy storePolicy = const StoreReleasePolicy.unenforced(),
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/fanzone',
        builder: (context, state) =>
            RepaintBoundary(key: goldenKey, child: const FanzoneHubScreen()),
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
      storeReleasePolicyProvider.overrideWithValue(storePolicy),
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      initialFeatureConfigSnapshotProvider.overrideWithValue(
        _enabledFanzoneFeatures,
      ),
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
        final appChild = MediaQuery(
          data: mediaQuery.copyWith(
            disableAnimations: true,
            alwaysUse24HourFormat: true,
          ),
          child: child ?? const SizedBox.shrink(),
        );
        return appLocale == null
            ? appChild
            : AfriLocalizationsScope(locale: appLocale, child: appChild);
      },
      theme: ClubTheme.from(ClubConfig.fallback(), brightness: brightness),
      routerConfig: router,
    ),
  );
}

const _compactGoldenProfiles =
    <({String id, Size size, Brightness brightness})>[
      (
        id: 'compact_dark_320x760',
        size: Size(320, 760),
        brightness: Brightness.dark,
      ),
      (
        id: 'compact_light_374x812',
        size: Size(374, 812),
        brightness: Brightness.light,
      ),
      (
        id: 'standard_dark_390x844',
        size: Size(390, 844),
        brightness: Brightness.dark,
      ),
      (
        id: 'large_light_430x900',
        size: Size(430, 900),
        brightness: Brightness.light,
      ),
      (
        id: 'wide_dark_599x900',
        size: Size(599, 900),
        brightness: Brightness.dark,
      ),
      (
        id: 'foldable_half_light_674x842',
        size: Size(674, 842),
        brightness: Brightness.light,
      ),
      (
        id: 'tablet_dark_834x1194',
        size: Size(834, 1194),
        brightness: Brightness.dark,
      ),
    ];

void _setGoldenSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(
        disableAnimations: true,
        accessibleNavigation: true,
      );
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

void _setMobileSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _scrollFanzoneTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}
