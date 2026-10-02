import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_home/src/providers/home_feed_provider.dart';
import 'package:feat_home/src/repositories/home_content_repository.dart';
import 'package:feat_home/src/repositories/home_discovery_repository.dart';
import 'package:feat_home/src/screens/home_screen.dart';
import 'package:feat_home/src/widgets/contributor_leaderboard.dart';
import 'package:feat_home/src/widgets/home_discovery_section.dart';
import 'package:feat_home/src/widgets/latest_intel_section.dart';
import 'package:feat_home/src/widgets/match_card.dart';
import 'package:feat_home/src/widgets/quick_actions_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:test_support/app_font_loader.dart';
import 'package:test_support/predict_fixture_images.dart';
import 'package:test_support/tab_shell_fixture.dart';
import 'package:test_support/touch_target_audit.dart';

import '../../../testing/test_support/test/fixtures/local_route_state_assertions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(
    () => RuntimeBranding.configure(
      appName: localRouteFixtureConfig?.appName ?? 'Gikundiro',
      clubName: localRouteFixtureConfig?.clubName ?? 'Rayon Sports FC',
    ),
  );
  tearDown(RuntimeBranding.resetForTest);

  group('HomeScreen states', () {
    testWidgets('scrolling Home keeps content below native status controls', (
      tester,
    ) async {
      _setGoldenSurface(tester, const Size(402, 874));
      tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 62, bottom: 34);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      TypographyTokens.debugUseFallbackFonts = true;
      addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
      await tester.pumpWidget(
        _buildApp(
          homeRepository: const _FakeHomeFeedRepository(
            snapshot: HomeFeedSnapshot(
              status: HomeFeedStatus.success,
              quickActions: homeFeedLocalFallbackActions,
            ),
          ),
          latestIntelRepository: const _FakeLatestIntelRepository(
            LatestIntelSnapshot(status: LatestIntelStatus.empty),
          ),
          child: const HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();
      final viewport = find.byType(CustomScrollView);
      ScrollPosition position() => tester
          .state<ScrollableState>(
            find
                .descendant(of: viewport, matching: find.byType(Scrollable))
                .first,
          )
          .position;
      for (final scale in [1.0, 2.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await tester.pumpAndSettle();
        for (final offset in [0.0, position().maxScrollExtent]) {
          position().jumpTo(offset);
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(viewport).dy, greaterThanOrEqualTo(62));
          expect(tester.takeException(), isNull);
        }
      }
    });

    for (final appName in [
      "Vital'O",
      'Gikundiro',
      'Nkana FC',
      'AS Vita Club',
    ]) {
      testWidgets('$appName names its own membership action', (tester) async {
        final clubName = {
          'Gikundiro': 'Rayon Sports FC',
          "Vital'O": "Vital'O FC",
          'Nkana FC': 'Nkana FC',
          'AS Vita Club': 'AS Vita Club',
        }[appName]!;
        RuntimeBranding.configure(appName: appName, clubName: clubName);
        final clubId = {
          "Vital'O": 'vitalo',
          'Gikundiro': 'rayon_sports',
          'Nkana FC': 'nkana',
          'AS Vita Club': 'as_vita',
        }[appName]!;
        await _pumpHomeStateGolden(
          tester,
          id: 'club_$clubId',
          homeRepository: _FakeHomeFeedRepository(
            snapshot: HomeFeedSnapshot(
              status: HomeFeedStatus.success,
              quickActions: homeFeedLocalFallbackActions,
              heroSlides: [
                MatchSlide(
                  homeTeam: clubName,
                  awayTeam: 'APR FC',
                  status: 'Upcoming',
                  dateInfo: 'Saturday · 18:00',
                  route: '/club/fixtures',
                ),
              ],
            ),
          ),
        );
        expect(find.text('Join $appName'), findsWidgets);
        if (appName != 'Gikundiro') {
          expect(find.text('Join Gikundiro'), findsNothing);
        }
      });
    }

    for (final scenario
        in <({String name, FeatureConfigService service, bool available})>[
          (
            name: 'registered and permitted',
            service: const FeatureConfigService(
              _testFeatureConfigSnapshot,
              storeReleasePolicy: StoreReleasePolicy.unenforced(),
            ),
            available: true,
          ),
          (
            name: 'unregistered',
            service: const FeatureConfigService(
              PlatformConfigSnapshot(),
              storeReleasePolicy: StoreReleasePolicy.unenforced(),
            ),
            available: false,
          ),
          (
            name: 'disabled',
            service: const FeatureConfigService(
              _disabledHomeFeatureConfigSnapshot,
              storeReleasePolicy: StoreReleasePolicy.unenforced(),
            ),
            available: false,
          ),
          (
            name: 'hidden',
            service: const FeatureConfigService(
              PlatformConfigSnapshot(
                contentBlocks: [
                  ContentBlock(
                    blockKey: 'home_match_score',
                    blockType: 'widget',
                    placementKey: 'home_hero',
                    content: {'widget': 'match_score_card'},
                  ),
                ],
                features: [
                  PlatformFeature(
                    featureKey: 'predict',
                    displayName: 'Predict',
                    visibilityState: 'hidden',
                  ),
                ],
              ),
              storeReleasePolicy: StoreReleasePolicy.unenforced(),
            ),
            available: false,
          ),
          (
            name: 'store policy blocked',
            service: const FeatureConfigService(_testFeatureConfigSnapshot),
            available: false,
          ),
        ]) {
      testWidgets('empty match action respects ${scenario.name} Predict', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildApp(
            homeRepository: const _FakeHomeFeedRepository(
              snapshot: HomeFeedSnapshot(status: HomeFeedStatus.empty),
            ),
            latestIntelRepository: const _FakeLatestIntelRepository(
              LatestIntelSnapshot(status: LatestIntelStatus.empty),
            ),
            overrides: [
              featureConfigServiceProvider.overrideWithValue(scenario.service),
            ],
            child: const HomeScreen(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Matchday'), findsNothing);
        expect(find.text('Open Predict'), findsNothing);
        expect(
          find.byKey(const ValueKey<String>('home-hero-state-compact')),
          findsNothing,
        );
        expect(find.byType(HomeDiscoverySection), findsWidgets);
      });
    }

    testWidgets('shows loading skeletons before home data resolves', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          homeRepository: const _FakeHomeFeedRepository(
            delay: Duration(milliseconds: 200),
            snapshot: HomeFeedSnapshot(
              status: HomeFeedStatus.empty,
              showFixturePlaceholder: true,
            ),
          ),
          latestIntelRepository: const _FakeLatestIntelRepository(
            LatestIntelSnapshot(status: LatestIntelStatus.empty),
          ),
          child: const HomeScreen(),
        ),
      );

      await tester.pump();

      expect(find.byType(MatchScoreCard), findsNothing);
      expect(find.text('NO FIXTURE'), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('NO FIXTURE'), findsNothing);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();

      expect(find.byType(MatchScoreCard), findsNothing);
    });

    testWidgets('shows explicit hero error state when home feed fails', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          homeRepository: const _FakeHomeFeedRepository(
            snapshot: HomeFeedSnapshot(
              status: HomeFeedStatus.error,
              notice: HomeFeedNotice.liveUnavailable,
            ),
          ),
          latestIntelRepository: const _FakeLatestIntelRepository(
            LatestIntelSnapshot(status: LatestIntelStatus.empty),
          ),
          child: const HomeScreen(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.byType(AfriErrorView), findsOneWidget);
      expect(find.textContaining('temporarily unavailable'), findsOneWidget);
      expect(find.text('NO FIXTURE'), findsNothing);
    });

    testWidgets(
      'renders fallback home actions when CMS blocks are unavailable',
      (tester) async {
        await tester.pumpWidget(
          _buildApp(
            homeRepository: const _FakeHomeFeedRepository(
              snapshot: HomeFeedSnapshot(
                status: HomeFeedStatus.error,
                notice: HomeFeedNotice.liveUnavailable,
              ),
            ),
            latestIntelRepository: const _FakeLatestIntelRepository(
              LatestIntelSnapshot(status: LatestIntelStatus.empty),
            ),
            featureConfigSnapshot: const PlatformConfigSnapshot(),
            child: const HomeScreen(),
          ),
        );

        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();

        expect(find.textContaining('temporarily unavailable'), findsOneWidget);
        await _scrollHomeTo(tester, find.text('Tickets'));
        expect(find.text('Tickets'), findsOneWidget);
        expect(
          find.text('Join ${localRouteFixtureConfig?.appName ?? 'Gikundiro'}'),
          findsWidgets,
        );
        expect(find.text('Predict\nUnavailable'), findsOneWidget);
        expect(find.text('Shop'), findsOneWidget);
      },
    );

    testWidgets(
      'does not mix local quick actions into configured Home composition',
      (tester) async {
        await tester.pumpWidget(
          _buildApp(
            homeRepository: const _FakeHomeFeedRepository(
              snapshot: HomeFeedSnapshot(status: HomeFeedStatus.success),
            ),
            latestIntelRepository: const _FakeLatestIntelRepository(
              LatestIntelSnapshot(status: LatestIntelStatus.empty),
            ),
            featureConfigSnapshot: const PlatformConfigSnapshot(
              contentBlocks: <ContentBlock>[
                ContentBlock(
                  blockKey: 'configured_home_quick_actions',
                  blockType: 'widget',
                  placementKey: 'home_top',
                  content: <String, dynamic>{'widget': 'quick_actions_grid'},
                ),
              ],
            ),
            child: const HomeScreen(),
          ),
        );

        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.byType(QuickActionsGrid), findsOneWidget);
      },
    );

    testWidgets(
      'renders local shortcuts when active club scope is unavailable',
      (tester) async {
        await tester.pumpWidget(
          _buildApp(
            homeRepository: _FakeHomeFeedRepository(
              snapshot: localHomeFeedFallbackSnapshot(),
            ),
            latestIntelRepository: const _FakeLatestIntelRepository(
              LatestIntelSnapshot(status: LatestIntelStatus.empty),
            ),
            featureConfigSnapshot: const PlatformConfigSnapshot(),
            child: const HomeScreen(),
          ),
        );

        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();

        expect(find.byType(AfriErrorView), findsNothing);
        expect(find.textContaining('Could not resolve'), findsNothing);
        expect(
          find.text(
            'Live club data is temporarily unavailable. Pull to refresh.',
          ),
          findsOneWidget,
        );
        expect(find.text('Matchday'), findsNothing);
        expect(find.text('Open Predict'), findsNothing);
        await _scrollHomeTo(tester, find.text('Tickets'));
        expect(find.text('Tickets'), findsOneWidget);
        expect(
          find.text('Join ${localRouteFixtureConfig?.appName ?? 'Gikundiro'}'),
          findsWidgets,
        );
        expect(find.text('Predict\nUnavailable'), findsOneWidget);
        expect(find.text('Shop'), findsOneWidget);
      },
    );

    testWidgets('renders Home task surfaces in English', (tester) async {
      for (final testCase in <({Locale locale, String ticket, String notice})>[
        (
          locale: const Locale('en'),
          ticket: 'Tickets',
          notice: 'Live club data is temporarily unavailable. Pull to refresh.',
        ),
        (
          locale: const Locale('en'),
          ticket: 'Tickets',
          notice: 'Live club data is temporarily unavailable. Pull to refresh.',
        ),
      ]) {
        await tester.pumpWidget(
          _buildApp(
            homeRepository: _FakeHomeFeedRepository(
              snapshot: localHomeFeedFallbackSnapshot(),
            ),
            latestIntelRepository: const _FakeLatestIntelRepository(
              LatestIntelSnapshot(status: LatestIntelStatus.empty),
            ),
            featureConfigSnapshot: const PlatformConfigSnapshot(),
            locale: testCase.locale,
            child: const HomeScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();

        expect(find.text(testCase.notice), findsOneWidget);
        await _scrollHomeTo(tester, find.text(testCase.ticket));
        expect(find.text(testCase.ticket), findsOneWidget);
      }
    });

    testWidgets('matches the redesigned home command center layout', (
      tester,
    ) async {
      _setMobileSurface(tester);

      await tester.pumpWidget(
        _buildApp(
          homeRepository: const _FakeHomeFeedRepository(
            snapshot: HomeFeedSnapshot(
              heroSlides: [
                MatchSlide(
                  homeTeam: 'Rayon Sports',
                  awayTeam: 'AS Kigali',
                  status: 'UPCOMING',
                  dateInfo: '12 APR • 15:00',
                ),
              ],
              leaderboard: [
                ContributorEntry(rank: 1, alias: '261452', points: 2140),
                ContributorEntry(rank: 2, alias: '623025', points: 1640),
                ContributorEntry(rank: 3, alias: '293164', points: 920),
              ],
              userFet: 5260,
              fanRank: 8,
              status: HomeFeedStatus.success,
            ),
          ),
          latestIntelRepository: const _FakeLatestIntelRepository(
            LatestIntelSnapshot(
              status: LatestIntelStatus.ready,
              articles: [
                {
                  'id': 'news-1',
                  'title': 'TRANSFER WINDOW: DEFENSIVE REINFORCEMENTS',
                  'subtitle':
                      'Two signings strengthen the back line before derby week.',
                },
                {
                  'id': 'news-2',
                  'title': 'MATCH DAY: STADIUM GUIDE',
                  'subtitle':
                      'Arrival windows, gate flow, and supporter choreography.',
                },
              ],
            ),
          ),
          child: const HomeScreen(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(MatchScoreCard), findsOneWidget);
      expect(find.text('Fans'), findsNothing);
      expect(find.text('Support'), findsNothing);
      expect(find.text('Live'), findsNothing);
      expectTapTargetsMeetMinimum(tester);
    });

    testWidgets('Home search command opens the truthful search route', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: <RouteBase>[
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Search destination'))),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeFeedRepositoryProvider.overrideWithValue(
              _FakeHomeFeedRepository(
                snapshot: localHomeFeedFallbackSnapshot(),
              ),
            ),
            latestIntelRepositoryProvider.overrideWithValue(
              const _FakeLatestIntelRepository(
                LatestIntelSnapshot(status: LatestIntelStatus.empty),
              ),
            ),
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
            initialFeatureConfigSnapshotProvider.overrideWithValue(
              const PlatformConfigSnapshot(),
            ),
          ],
          child: MaterialApp.router(
            theme: ClubTheme.from(localRouteConfigOrFallback()),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Find'));
      await tester.pumpAndSettle();

      expect(find.text('Search destination'), findsOneWidget);
    });

    testWidgets('matches the home loading state layout', (tester) async {
      _setMobileSurface(tester);

      await tester.pumpWidget(
        _buildApp(
          homeRepository: const _PendingHomeFeedRepository(),
          latestIntelRepository: const _FakeLatestIntelRepository(
            LatestIntelSnapshot(status: LatestIntelStatus.empty),
          ),
          child: const HomeScreen(),
        ),
      );

      await tester.pump();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('matches the home error state layout', (tester) async {
      _setMobileSurface(tester);

      await tester.pumpWidget(
        _buildApp(
          homeRepository: const _FakeHomeFeedRepository(
            snapshot: HomeFeedSnapshot(
              status: HomeFeedStatus.error,
              notice: HomeFeedNotice.liveUnavailable,
            ),
          ),
          latestIntelRepository: const _FakeLatestIntelRepository(
            LatestIntelSnapshot(status: LatestIntelStatus.empty),
          ),
          child: const HomeScreen(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('matches the home empty fallback layout', (tester) async {
      _setMobileSurface(tester);

      await tester.pumpWidget(
        _buildApp(
          homeRepository: _FakeHomeFeedRepository(
            snapshot: localHomeFeedFallbackSnapshot(),
          ),
          latestIntelRepository: const _FakeLatestIntelRepository(
            LatestIntelSnapshot(status: LatestIntelStatus.empty),
          ),
          featureConfigSnapshot: const PlatformConfigSnapshot(),
          child: const HomeScreen(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      final compactHero = find.byKey(
        const ValueKey<String>('home-hero-state-compact'),
      );
      expect(compactHero, findsNothing);
      await _scrollHomeTo(tester, find.text('Tickets'));
      expect(find.text('Tickets'), findsOneWidget);
    });

    testWidgets('matches the home layout at 200 percent text scale', (
      tester,
    ) async {
      _setMobileSurface(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        _buildApp(
          homeRepository: const _FakeHomeFeedRepository(
            snapshot: HomeFeedSnapshot(
              heroSlides: [
                MatchSlide(
                  homeTeam: 'Rayon Sports',
                  awayTeam: 'AS Kigali',
                  status: 'UPCOMING',
                  dateInfo: '12 APR • 15:00',
                ),
              ],
              leaderboard: [
                ContributorEntry(rank: 1, alias: '261452', points: 2140),
                ContributorEntry(rank: 2, alias: '623025', points: 1640),
              ],
              userFet: 5260,
              fanRank: 8,
              status: HomeFeedStatus.success,
            ),
          ),
          latestIntelRepository: const _FakeLatestIntelRepository(
            LatestIntelSnapshot(status: LatestIntelStatus.empty),
          ),
          child: const HomeScreen(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    for (final profile in <String, Size>{
      'standard landscape': const Size(852, 393),
      'compact-height landscape': const Size(720, 320),
    }.entries) {
      testWidgets(
        '${profile.key} keeps Home media and primary commands usable',
        (tester) async {
          tester.view.physicalSize = profile.value;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            _buildApp(
              homeRepository: const _FakeHomeFeedRepository(
                snapshot: HomeFeedSnapshot(
                  heroSlides: [
                    MatchSlide(
                      homeTeam: 'Rayon Sports',
                      awayTeam: 'AS Kigali',
                      status: 'UPCOMING',
                      dateInfo: '12 APR • 15:00',
                    ),
                  ],
                  leaderboard: [
                    ContributorEntry(rank: 1, alias: '261452', points: 2140),
                  ],
                  userFet: 5260,
                  fanRank: 8,
                  status: HomeFeedStatus.success,
                ),
              ),
              latestIntelRepository: const _FakeLatestIntelRepository(
                LatestIntelSnapshot(status: LatestIntelStatus.empty),
              ),
              child: const HomeScreen(),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pumpAndSettle();

          expect(find.byType(MatchScoreCard), findsOneWidget);
          final primary = find.byType(MatchScoreCard);
          final findCommand = find.text('Find');
          await tester.ensureVisible(findCommand);
          await tester.scrollUntilVisible(
            primary,
            120,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(primary, findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('LatestIntelSection states', () {
    testWidgets('news cards reflow after native-sized text enlargement', (
      tester,
    ) async {
      _setGoldenSurface(tester, const Size(412, 915));
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      TypographyTokens.debugUseFallbackFonts = true;
      addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
      await tester.pumpWidget(
        _buildApp(
          homeRepository: const _FakeHomeFeedRepository(),
          latestIntelRepository: const _FakeLatestIntelRepository(
            LatestIntelSnapshot(
              status: LatestIntelStatus.ready,
              articles: [
                {
                  'id': 'training',
                  'title': 'Training ground update',
                  'subtitle': 'First-team preparations continue this week.',
                },
              ],
            ),
          ),
          child: const Scaffold(
            body: SingleChildScrollView(child: LatestIntelSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final scale in [1.0, 2.0, 3.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await tester.pumpAndSettle();
        expect(find.text('Training ground update'), findsOneWidget);
        expect(
          find.text('First-team preparations continue this week.'),
          findsOneWidget,
        );
        if (scale > 1.3) {
          for (final text in [
            'Training ground update',
            'First-team preparations continue this week.',
          ]) {
            expect(
              tester
                  .renderObject<RenderParagraph>(find.text(text))
                  .didExceedMaxLines,
              isFalse,
            );
          }
        }
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('hides unpublished Home news', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          homeRepository: const _FakeHomeFeedRepository(),
          latestIntelRepository: const _FakeLatestIntelRepository(
            LatestIntelSnapshot(status: LatestIntelStatus.empty),
          ),
          child: const Scaffold(body: LatestIntelSection()),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('News'), findsNothing);
      expect(find.text('No news yet'), findsNothing);
      expect(find.byType(AfriEmptyView), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('shows a retryable error state', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          homeRepository: const _FakeHomeFeedRepository(),
          latestIntelRepository: const _FakeLatestIntelRepository(
            LatestIntelSnapshot(
              status: LatestIntelStatus.error,
              notice: LatestIntelNotice.unavailable,
            ),
          ),
          child: const Scaffold(body: LatestIntelSection()),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Latest Intel is temporarily unavailable. Pull to refresh.'),
        findsOneWidget,
      );
      expect(find.text('Try Again'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  for (final brightness in [Brightness.dark, Brightness.light]) {
    for (final largeText in [false, true]) {
      for (final expanded in [false, true]) {
        final state = expanded ? 'expanded' : 'collapsed';
        final text = largeText ? 'large_text' : 'normal_text';
        testWidgets('golden Home shortcuts $state $text ${brightness.name}', (
          tester,
        ) async {
          await _pumpHomeStateGolden(
            tester,
            id: 'shortcuts_${state}_$text',
            brightness: brightness,
            preserveScrollForCapture: true,
            size: largeText ? const Size(320, 720) : const Size(390, 844),
            textScale: largeText ? 2 : 1,
            homeRepository: const _FakeHomeFeedRepository(
              snapshot: HomeFeedSnapshot(
                status: HomeFeedStatus.success,
                quickActions: [
                  ...homeFeedLocalFallbackActions,
                  HomeQuickAction(
                    actionKey: 'fixtures',
                    title: 'Fixtures',
                    route: '/club/fixtures',
                    iconKey: 'league',
                  ),
                ],
              ),
            ),
            beforeCapture: (tester) async {
              final toggle = find.byKey(
                const ValueKey<String>('home-secondary-actions-toggle'),
              );
              await tester.ensureVisible(toggle);
              await tester.pumpAndSettle();
              if (expanded) {
                await tester.tap(toggle);
                await tester.pumpAndSettle();
                expect(find.text('Fixtures'), findsOneWidget);
                await tester.ensureVisible(find.text('Fixtures'));
                await tester.pumpAndSettle();
              }
              expect(find.text('Shortcuts'), findsOneWidget);
              expect(find.text('More shortcuts'), findsNothing);
            },
          );
        });
      }
    }
  }

  for (final brightness in [Brightness.dark, Brightness.light]) {
    for (final section in [
      'Active predictions',
      'News',
      'Partners',
      'Fan clubs',
    ]) {
      for (final large in [false, true]) {
        testWidgets(
          'golden Home discovery $section ${brightness.name} large=$large',
          (tester) async {
            await installPredictFixtureImages();
            try {
              await _pumpHomeStateGolden(
                tester,
                id: 'discovery_${section.toLowerCase().replaceAll(' ', '_')}${large ? '_large_text' : ''}',
                brightness: brightness,
                textScale: large ? 2 : 1,
                size: large ? const Size(320, 720) : const Size(390, 844),
                preserveScrollForCapture: true,
                homeRepository: const _FakeHomeFeedRepository(
                  snapshot: HomeFeedSnapshot(
                    status: HomeFeedStatus.success,
                    quickActions: homeFeedLocalFallbackActions,
                  ),
                ),
                latestIntelRepository: const _FakeLatestIntelRepository(
                  LatestIntelSnapshot(
                    status: LatestIntelStatus.ready,
                    articles: [
                      {
                        'id': 'preview-news',
                        'title': 'Ready for matchday',
                        'subtitle':
                            'Inside the club: preparation, players and supporters.',
                        'image_url': 'https://fixture.test/fixture.webp',
                        'image_rights_approved': true,
                        'image_provenance_id':
                            'review-only-existing-club-photography',
                      },
                    ],
                  ),
                ),
                overrides: [
                  homeDiscoveryRepositoryProvider.overrideWithValue(
                    _HomeDiscoveryFixture(photos: true),
                  ),
                ],
                beforeCapture: (tester) async {
                  final target = find.text(section);
                  await tester.scrollUntilVisible(
                    target,
                    400,
                    scrollable: find
                        .descendant(
                          of: find.byType(CustomScrollView),
                          matching: find.byType(Scrollable),
                        )
                        .first,
                  );
                  await Scrollable.ensureVisible(
                    tester.element(target),
                    // The pinned app bar overlays offset zero. A fixture
                    // viewport must show the section below that chrome.
                    alignment: localRouteFixtureConfig == null ? 0 : 0.1,
                  );
                  await tester.pumpAndSettle();
                  await tester.runAsync(() async {
                    final context = tester.element(find.byType(HomeScreen));
                    await Future.wait(
                      tester
                          .widgetList<Image>(find.byType(Image))
                          .map((i) => precacheImage(i.image, context)),
                    );
                  });
                  await tester.pumpAndSettle();
                },
              );
              if (large && section == 'Active predictions') {
                // The static capture ends partway through the next section.
                // Verify its actual large-text scroll reachability separately.
                final news = find.text('News');
                final scrollable = find
                    .descendant(
                      of: find.byType(CustomScrollView),
                      matching: find.byType(Scrollable),
                    )
                    .first;
                await tester.scrollUntilVisible(
                  news,
                  160,
                  scrollable: scrollable,
                );
                await Scrollable.ensureVisible(
                  tester.element(news),
                  alignment: .15,
                );
                await tester.pumpAndSettle();
                expect(tester.getTopLeft(news).dy, greaterThanOrEqualTo(64));
                expect(
                  tester.getBottomRight(news).dy,
                  lessThanOrEqualTo(
                    tester.getTopLeft(find.byType(AfriClubBottomNav)).dy,
                  ),
                );
                expect(tester.takeException(), isNull);
              }
            } finally {
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump();
              debugNetworkImageHttpClientProvider = null;
            }
          },
        );
      }
    }
  }

  testWidgets('golden Home populated football overview', (tester) async {
    await _pumpHomeStateGolden(
      tester,
      id: 'populated',
      homeRepository: const _FakeHomeFeedRepository(
        snapshot: HomeFeedSnapshot(
          status: HomeFeedStatus.success,
          heroSlides: [
            MatchSlide(
              homeTeam: 'Rayon Sports FC',
              awayTeam: 'APR FC',
              homeScore: 2,
              awayScore: 1,
              status: 'Full time',
              dateInfo: 'Saturday · 18:00',
              venue: 'Club stadium',
              route: '/predict',
            ),
          ],
          quickActions: homeFeedLocalFallbackActions,
          membershipTier: 'Gold',
          membershipPaymentStatus: 'confirmed',
        ),
      ),
      beforeCapture: (tester) async {
        final match = find.byType(AfriFixtureTeams).first;
        expect(
          find.descendant(of: match, matching: find.text('RAY')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: match, matching: find.text('APR')),
          findsOneWidget,
        );
        final crests = tester.widgetList<RawImage>(
          find.descendant(of: match, matching: find.byType(RawImage)),
        );
        expect(crests.where((image) => image.image != null), hasLength(2));
      },
    );
  });

  for (final profile in _compactGoldenProfiles) {
    testWidgets('golden compact Home route ${profile.id}', (tester) async {
      _setGoldenSurface(tester, profile.size);
      TypographyTokens.debugUseFallbackFonts = true;
      addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
      ColorTokens.setBrightness(profile.brightness);
      addTearDown(() => ColorTokens.setBrightness(Brightness.dark));

      await tester.pumpWidget(
        _buildApp(
          homeRepository: _FakeHomeFeedRepository(
            snapshot: localHomeFeedFallbackSnapshot(),
          ),
          latestIntelRepository: const _FakeLatestIntelRepository(
            LatestIntelSnapshot(status: LatestIntelStatus.empty),
          ),
          featureConfigSnapshot: const PlatformConfigSnapshot(),
          brightness: profile.brightness,
          child: const RepaintBoundary(
            key: ValueKey<String>('home-route-golden'),
            child: TabShellFixture(index: 0, child: HomeScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectGoldenOrClubAssertions(
        tester,
        find.byKey(const ValueKey<String>('home-route-golden')),
        'goldens/home_${profile.id}.png',
        route: '/home',
        kind: 'tab',
      );
    });
  }

  testWidgets('golden Home route loading state', (tester) async {
    await _pumpHomeStateGolden(
      tester,
      id: 'loading',
      homeRepository: const _PendingHomeFeedRepository(),
      settle: false,
    );
  });

  testWidgets('golden Home route empty state', (tester) async {
    await _pumpHomeStateGolden(
      tester,
      id: 'empty',
      homeRepository: _FakeHomeFeedRepository(
        snapshot: localHomeFeedFallbackSnapshot(),
      ),
      featureConfigSnapshot: const PlatformConfigSnapshot(),
    );
  });

  testWidgets('golden Home route error state', (tester) async {
    await _pumpHomeStateGolden(
      tester,
      id: 'error',
      homeRepository: const _FakeHomeFeedRepository(
        snapshot: HomeFeedSnapshot(
          status: HomeFeedStatus.error,
          notice: HomeFeedNotice.liveUnavailable,
        ),
      ),
    );
  });

  testWidgets('golden Home route large-text state', (tester) async {
    await _pumpHomeStateGolden(
      tester,
      id: 'large_text',
      size: const Size(320, 720),
      textScale: 2,
      homeRepository: const _FakeHomeFeedRepository(
        snapshot: HomeFeedSnapshot(
          heroSlides: [
            MatchSlide(
              homeTeam: 'Rayon Sports',
              awayTeam: 'AS Kigali',
              status: 'UPCOMING',
              dateInfo: '12 APR • 15:00',
            ),
          ],
          leaderboard: [
            ContributorEntry(rank: 1, alias: '261452', points: 2140),
          ],
          userFet: 5260,
          fanRank: 8,
          status: HomeFeedStatus.success,
        ),
      ),
    );
  });

  testWidgets('golden Home route offline state', (tester) async {
    await _pumpHomeStateGolden(
      tester,
      id: 'offline',
      homeRepository: const _PendingHomeFeedRepository(),
      online: false,
      beforeCapture: (tester) async {
        expect(find.text('Live updates paused'), findsOneWidget);
        expect(
          find.text('Connect to refresh Home. Showing saved shortcuts.'),
          findsOneWidget,
        );
        expect(find.text('Tickets'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Home route permission-denied state', (tester) async {
    await _pumpHomeStateGolden(
      tester,
      id: 'permission_denied',
      homeRepository: const _ThrowingHomeFeedRepository(
        'row-level security policy rejected account 991',
      ),
      beforeCapture: (tester) async {
        expect(find.text('Home access not available'), findsOneWidget);
        expect(find.text('Try Again'), findsNothing);
        expect(find.textContaining('991'), findsNothing);
      },
    );
  });

  testWidgets('golden Home route disabled state', (tester) async {
    await _pumpHomeStateGolden(
      tester,
      id: 'disabled',
      homeRepository: const _FakeHomeFeedRepository(
        snapshot: _interactiveHomeSnapshot,
      ),
      featureConfigSnapshot: _disabledHomeFeatureConfigSnapshot,
      beforeCapture: (tester) async {
        expect(find.text('Matchday unavailable'), findsNothing);
        expect(find.text('Predict\nUnavailable'), findsOneWidget);
        final predictAction = tester.widget<AfriQuickAction>(
          find.descendant(
            of: find.byKey(
              const ValueKey<String>('home-primary-action-predict'),
            ),
            matching: find.byType(AfriQuickAction),
          ),
        );
        expect(predictAction.enabled, isFalse);
      },
    );
  });

  testWidgets('golden Home route focused state', (tester) async {
    final previousHighlightStrategy = FocusManager.instance.highlightStrategy;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousHighlightStrategy,
    );
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;

    await _pumpHomeStateGolden(
      tester,
      id: 'focused',
      homeRepository: const _FakeHomeFeedRepository(
        snapshot: _interactiveHomeSnapshot,
      ),
      beforeCapture: (tester) async {
        final focusable = find
            .descendant(
              of: find.byKey(
                const ValueKey<String>('home-primary-action-tickets'),
              ),
              matching: find.byType(FocusableActionDetector),
            )
            .first;
        final gestureDetector = find
            .descendant(of: focusable, matching: find.byType(GestureDetector))
            .first;
        Focus.of(tester.element(gestureDetector)).requestFocus();
        await tester.pumpAndSettle();
        expect(Focus.of(tester.element(gestureDetector)).hasFocus, isTrue);
      },
    );
  });

  testWidgets('golden Home route pressed state', (tester) async {
    TestGesture? heldGesture;
    await _pumpHomeStateGolden(
      tester,
      id: 'pressed',
      homeRepository: const _FakeHomeFeedRepository(
        snapshot: _interactiveHomeSnapshot,
      ),
      beforeCapture: (tester) async {
        heldGesture = await tester.startGesture(
          tester.getCenter(find.bySemanticsLabel('Tickets')),
        );
        await tester.pump(const Duration(milliseconds: 120));
      },
      afterCapture: (tester) async {
        await heldGesture?.cancel();
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('golden Home route selected state', (tester) async {
    await _pumpHomeStateGolden(
      tester,
      id: 'selected',
      homeRepository: const _FakeHomeFeedRepository(
        snapshot: _selectedHomeSnapshot,
      ),
      beforeCapture: (tester) async {
        await tester.drag(find.byType(PageView), const Offset(-340, 0));
        await tester.pumpAndSettle();
        expect(find.textContaining('27 APR'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Home route syncing state', (tester) async {
    final refreshCompleter = Completer<HomeFeedSnapshot>();
    final repository = _SequencedHomeFeedRepository([
      () async => _interactiveHomeSnapshot,
      () => refreshCompleter.future,
    ]);
    await _pumpHomeStateGolden(
      tester,
      id: 'syncing',
      homeRepository: repository,
      beforeCapture: (tester) async {
        final container = ProviderScope.containerOf(
          tester.element(find.byType(HomeScreen)),
        );
        unawaited(container.read(homeFeedProvider.notifier).refresh());
        await tester.pump();
        expect(find.text('Refreshing Home'), findsOneWidget);
        expect(find.byType(MatchScoreCard), findsOneWidget);
        expect(find.text('Tickets'), findsOneWidget);
      },
      afterCapture: (tester) async {
        refreshCompleter.complete(_interactiveHomeSnapshot);
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('golden Home route conflict state', (tester) async {
    await _pumpHomeStateGolden(
      tester,
      id: 'conflict',
      homeRepository: const _ThrowingHomeFeedRepository(
        'stale revision conflict for supporter-991',
      ),
      beforeCapture: (tester) async {
        expect(find.text('Home changed'), findsOneWidget);
        expect(find.text('Refresh'), findsOneWidget);
        expect(find.textContaining('991'), findsNothing);
      },
    );
  });

  testWidgets('golden Home route security-timeout state', (tester) async {
    await _pumpHomeStateGolden(
      tester,
      id: 'security_timeout',
      homeRepository: const _PendingHomeFeedRepository(),
      overrides: [
        homeFeedProvider.overrideWith(
          () => HomeFeedNotifier(loadTimeout: const Duration(milliseconds: 1)),
        ),
      ],
      beforeCapture: (tester) async {
        expect(find.text('Home security check timed out'), findsOneWidget);
        expect(find.text('Refresh'), findsOneWidget);
      },
    );
  });

  testWidgets('golden high-contrast Home route dark', (tester) async {
    _setGoldenSurface(tester, const Size(390, 844), highContrast: true);
    TypographyTokens.debugUseFallbackFonts = true;
    addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
    ColorTokens.setBrightness(Brightness.dark);
    addTearDown(() => ColorTokens.setBrightness(Brightness.dark));

    await tester.pumpWidget(
      _buildApp(
        homeRepository: _FakeHomeFeedRepository(
          snapshot: localHomeFeedFallbackSnapshot(),
        ),
        latestIntelRepository: const _FakeLatestIntelRepository(
          LatestIntelSnapshot(status: LatestIntelStatus.empty),
        ),
        featureConfigSnapshot: const PlatformConfigSnapshot(),
        highContrast: true,
        child: const RepaintBoundary(
          key: ValueKey<String>('home-high-contrast-golden'),
          child: TabShellFixture(index: 0, child: HomeScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final topChrome = find.byKey(const ValueKey<String>('home-top-chrome'));
    final homeScrollable = find
        .ancestor(of: topChrome, matching: find.byType(Scrollable))
        .first;
    final homePosition = tester.state<ScrollableState>(homeScrollable).position;
    homePosition.jumpTo(homePosition.minScrollExtent);
    await tester.pumpAndSettle();
    expect(homePosition.pixels, homePosition.minScrollExtent);

    expect(tester.takeException(), isNull);
    await expectGoldenOrClubAssertions(
      tester,
      find.byKey(const ValueKey<String>('home-high-contrast-golden')),
      'goldens/home_high_contrast_dark_390x844.png',
      route: '/home',
      kind: 'tab',
    );
  });

  testWidgets('shows the current membership projection on Home', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        homeRepository: const _FakeHomeFeedRepository(
          snapshot: HomeFeedSnapshot(
            status: HomeFeedStatus.success,
            quickActions: homeFeedLocalFallbackActions,
            membershipTier: 'Gold',
            membershipPaymentStatus: 'confirmed',
          ),
        ),
        latestIntelRepository: const _FakeLatestIntelRepository(
          LatestIntelSnapshot(status: LatestIntelStatus.empty),
        ),
        child: const HomeScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Gold · Current'), findsOneWidget);
    expect(
      find.text('View membership status and club benefits.'),
      findsOneWidget,
    );
  });
}

Future<void> _scrollHomeTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    260,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpHomeStateGolden(
  WidgetTester tester, {
  required String id,
  required HomeFeedRepository homeRepository,
  Size size = const Size(390, 844),
  double textScale = 1,
  Brightness brightness = Brightness.dark,
  bool preserveScrollForCapture = false,
  bool settle = true,
  bool online = true,
  List<Override> overrides = const [],
  Future<void> Function(WidgetTester tester)? beforeCapture,
  Future<void> Function(WidgetTester tester)? afterCapture,
  PlatformConfigSnapshot featureConfigSnapshot = _testFeatureConfigSnapshot,
  LatestIntelRepository latestIntelRepository =
      const _FakeLatestIntelRepository(
        LatestIntelSnapshot(status: LatestIntelStatus.empty),
      ),
}) async {
  _setGoldenSurface(tester, size);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  TypographyTokens.debugUseFallbackFonts = true;
  addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
  ColorTokens.setBrightness(brightness);
  addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
  ConnectivityService.setOnlineForTest(online);
  addTearDown(() => ConnectivityService.setOnlineForTest(true));

  await tester.pumpWidget(
    _buildApp(
      brightness: brightness,
      homeRepository: homeRepository,
      latestIntelRepository: latestIntelRepository,
      featureConfigSnapshot: featureConfigSnapshot,
      overrides: [
        storeReleasePolicyProvider.overrideWithValue(
          const StoreReleasePolicy.unenforced(),
        ),
        ...overrides,
      ],
      child: const RepaintBoundary(
        key: ValueKey<String>('home-state-golden'),
        child: TabShellFixture(index: 0, child: HomeScreen()),
      ),
    ),
  );
  if (settle) {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }

  await tester.runAsync(() async {
    final context = tester.element(find.byType(HomeScreen));
    await Future.wait(
      tester
          .widgetList<Image>(find.byType(Image))
          .map((image) => precacheImage(image.image, context)),
    );
  });
  await tester.pump();

  final topChrome = find.byKey(const ValueKey<String>('home-top-chrome'));
  final homeScrollable = find
      .ancestor(of: topChrome, matching: find.byType(Scrollable))
      .first;
  final homePosition = tester.state<ScrollableState>(homeScrollable).position;
  await beforeCapture?.call(tester);
  if (!preserveScrollForCapture) {
    homePosition.jumpTo(homePosition.minScrollExtent);
    await tester.pumpAndSettle();
    homePosition.jumpTo(homePosition.minScrollExtent);
    await tester.pump();
  }

  expect(tester.takeException(), isNull);
  await expectGoldenOrClubAssertions(
    tester,
    find.byKey(const ValueKey<String>('home-state-golden')),
    'goldens/home_state_${id}_${brightness.name}_${size.width.toInt()}x${size.height.toInt()}.png',
    route: '/home',
    kind: 'tab',
  );
  await afterCapture?.call(tester);
}

Widget _buildApp({
  required HomeFeedRepository homeRepository,
  required LatestIntelRepository latestIntelRepository,
  required Widget child,
  PlatformConfigSnapshot featureConfigSnapshot = _testFeatureConfigSnapshot,
  Brightness brightness = Brightness.dark,
  bool highContrast = false,
  Locale locale = const Locale('en'),
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      homeFeedRepositoryProvider.overrideWithValue(homeRepository),
      homeDiscoveryRepositoryProvider.overrideWithValue(
        _HomeDiscoveryFixture(),
      ),
      latestIntelRepositoryProvider.overrideWithValue(latestIntelRepository),
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      initialFeatureConfigSnapshotProvider.overrideWithValue(
        featureConfigSnapshot,
      ),
      ...overrides,
    ],
    child: AfriLocalizationsScope(
      locale: locale,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AfriLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AfriLocalizations.supportedLocales,
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(disableAnimations: true),
            child: child!,
          );
        },
        theme: ClubTheme.from(
          localRouteConfigOrFallback(),
          brightness: brightness,
          highContrast: highContrast,
        ),
        home: child,
      ),
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

void _setGoldenSurface(
  WidgetTester tester,
  Size size, {
  bool highContrast = false,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(
        disableAnimations: true,
        accessibleNavigation: true,
        highContrast: highContrast,
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

const _testFeatureConfigSnapshot = PlatformConfigSnapshot(
  features: [
    PlatformFeature(
      featureKey: 'predict',
      displayName: 'Predict',
      channel: FeatureChannelConfig(showOnHome: true),
    ),
    PlatformFeature(
      featureKey: 'contributions',
      displayName: 'Contributed',
      channel: FeatureChannelConfig(showOnHome: true),
    ),
    PlatformFeature(
      featureKey: 'live',
      displayName: 'Live',
      channel: FeatureChannelConfig(showOnHome: true),
    ),
  ],
  contentBlocks: [
    ContentBlock(
      blockKey: 'home_match_score',
      blockType: 'widget',
      placementKey: 'home_hero',
      content: {'widget': 'match_score_card'},
      sortOrder: 1,
    ),
    ContentBlock(
      blockKey: 'home_primary_actions',
      blockType: 'widget',
      placementKey: 'home_top',
      content: {'widget': 'primary_action_buttons'},
      sortOrder: 2,
    ),
    ContentBlock(
      blockKey: 'home_quick_actions',
      blockType: 'widget',
      placementKey: 'home_mid',
      content: {'widget': 'quick_actions_grid'},
      sortOrder: 3,
    ),
    ContentBlock(
      blockKey: 'home_stats',
      blockType: 'widget',
      placementKey: 'home_mid',
      content: {'widget': 'stats_row'},
      sortOrder: 4,
    ),
    ContentBlock(
      blockKey: 'home_leaderboard',
      blockType: 'widget',
      placementKey: 'home_bottom',
      content: {'widget': 'contributor_leaderboard'},
      sortOrder: 5,
    ),
    ContentBlock(
      blockKey: 'home_latest_intel',
      blockType: 'widget',
      placementKey: 'home_bottom',
      content: {'widget': 'latest_intel_section'},
      sortOrder: 6,
    ),
  ],
);

const _disabledHomeFeatureConfigSnapshot = PlatformConfigSnapshot(
  features: [
    PlatformFeature(
      featureKey: 'predict',
      displayName: 'Predict',
      isEnabled: false,
      visibilityState: 'visible',
      channel: FeatureChannelConfig(showOnHome: true),
    ),
    PlatformFeature(
      featureKey: 'contributions',
      displayName: 'Contributed',
      channel: FeatureChannelConfig(showOnHome: true),
    ),
    PlatformFeature(
      featureKey: 'live',
      displayName: 'Live',
      channel: FeatureChannelConfig(showOnHome: true),
    ),
  ],
  contentBlocks: [
    ContentBlock(
      blockKey: 'home_match_score',
      blockType: 'widget',
      placementKey: 'home_hero',
      content: {'widget': 'match_score_card'},
      sortOrder: 1,
    ),
    ContentBlock(
      blockKey: 'home_primary_actions',
      blockType: 'widget',
      placementKey: 'home_top',
      content: {'widget': 'primary_action_buttons'},
      sortOrder: 2,
    ),
    ContentBlock(
      blockKey: 'home_quick_actions',
      blockType: 'widget',
      placementKey: 'home_mid',
      content: {'widget': 'quick_actions_grid'},
      sortOrder: 3,
    ),
    ContentBlock(
      blockKey: 'home_stats',
      blockType: 'widget',
      placementKey: 'home_mid',
      content: {'widget': 'stats_row'},
      sortOrder: 4,
    ),
    ContentBlock(
      blockKey: 'home_leaderboard',
      blockType: 'widget',
      placementKey: 'home_bottom',
      content: {'widget': 'contributor_leaderboard'},
      sortOrder: 5,
    ),
    ContentBlock(
      blockKey: 'home_latest_intel',
      blockType: 'widget',
      placementKey: 'home_bottom',
      content: {'widget': 'latest_intel_section'},
      sortOrder: 6,
    ),
  ],
);

const _interactiveHomeSnapshot = HomeFeedSnapshot(
  heroSlides: [
    MatchSlide(
      homeTeam: 'Rayon Sports',
      awayTeam: 'AS Kigali',
      status: 'UPCOMING',
      dateInfo: '12 APR • 15:00',
      route: '/predict',
    ),
  ],
  quickActions: homeFeedLocalFallbackActions,
  userFet: 5260,
  fanRank: 8,
  status: HomeFeedStatus.success,
);

const _selectedHomeSnapshot = HomeFeedSnapshot(
  heroSlides: [
    MatchSlide(
      homeTeam: 'Rayon Sports',
      awayTeam: 'AS Kigali',
      status: 'UPCOMING',
      dateInfo: '12 APR • 15:00',
    ),
    MatchSlide(
      homeTeam: 'APR FC',
      awayTeam: 'Rayon Sports',
      status: 'UPCOMING',
      dateInfo: '27 APR • 18:00',
    ),
  ],
  quickActions: homeFeedLocalFallbackActions,
  status: HomeFeedStatus.success,
);

class _FakeHomeFeedRepository implements HomeFeedRepository {
  const _FakeHomeFeedRepository({
    this.snapshot = const HomeFeedSnapshot(),
    this.delay = Duration.zero,
  });

  final HomeFeedSnapshot snapshot;
  final Duration delay;

  @override
  Future<HomeFeedSnapshot> load() async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return snapshot;
  }
}

class _PendingHomeFeedRepository implements HomeFeedRepository {
  const _PendingHomeFeedRepository();

  @override
  Future<HomeFeedSnapshot> load() => Completer<HomeFeedSnapshot>().future;
}

class _ThrowingHomeFeedRepository implements HomeFeedRepository {
  const _ThrowingHomeFeedRepository(this.message);

  final String message;

  @override
  Future<HomeFeedSnapshot> load() async => throw StateError(message);
}

class _SequencedHomeFeedRepository implements HomeFeedRepository {
  _SequencedHomeFeedRepository(this._loads);

  final List<Future<HomeFeedSnapshot> Function()> _loads;
  int _calls = 0;

  @override
  Future<HomeFeedSnapshot> load() {
    final load = _loads[_calls];
    _calls += 1;
    return load();
  }
}

class _FakeLatestIntelRepository implements LatestIntelRepository {
  const _FakeLatestIntelRepository(this.snapshot);

  final LatestIntelSnapshot snapshot;

  @override
  Future<LatestIntelSnapshot> loadPublishedArticles() async => snapshot;
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository()
    : super(clubId: localRouteFixtureConfig?.clubId ?? '24');

  @override
  Future<UserProfile?> restoreCurrentUser() async => null;

  @override
  Future<AdminWorkspaceAccess> resolveAdminAccess(String userId) async {
    return AdminWorkspaceAccess.none;
  }

  @override
  Stream<supabase.AuthState> get authStateChanges =>
      const Stream<supabase.AuthState>.empty();
}

class _HomeDiscoveryFixture implements HomeDiscoveryRepository {
  _HomeDiscoveryFixture({this.photos = false});
  final bool photos;
  @override
  Future<List<Map<String, dynamic>>> load(HomeDiscoveryKind kind) async =>
      switch (kind) {
        HomeDiscoveryKind.predictions => [
          {
            'id': 'preview-match',
            'home_team': RuntimeBranding.displayHomeTeamName,
            'away_team': 'APR FC',
            'competition': 'Matchday',
            'kickoff_at': '2030-08-08T16:00:00Z',
          },
        ],
        HomeDiscoveryKind.partners => [
          {
            'id': 'preview-partner',
            'name': 'Community partnership',
            'category': 'Supporting club activities',
            if (photos) 'image_url': 'https://fixture.test/partner.webp',
            'image_rights_approved': photos,
            'image_provenance_id': 'review-only-existing-club-photography',
          },
        ],
        HomeDiscoveryKind.fanClubs => [
          {
            'id': 'preview-community',
            'name': 'City supporters',
            'region': 'Local community',
            'member_count': 42,
            if (photos) 'banner_image_url': 'https://fixture.test/fanclub.webp',
          },
        ],
      };
}
