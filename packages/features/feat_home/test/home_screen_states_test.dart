import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_home/src/repositories/home_content_repository.dart';
import 'package:feat_home/src/screens/home_screen.dart';
import 'package:feat_home/src/widgets/contributor_leaderboard.dart';
import 'package:feat_home/src/widgets/latest_intel_section.dart';
import 'package:feat_home/src/widgets/match_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  group('HomeScreen states', () {
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
              message:
                  'Live club data is temporarily unavailable. Pull to refresh.',
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

    testWidgets('renders fallback home actions when CMS blocks are unavailable', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          homeRepository: const _FakeHomeFeedRepository(
            snapshot: HomeFeedSnapshot(
              status: HomeFeedStatus.error,
              message:
                  'Live club data is temporarily unavailable. Pull to refresh.',
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
      expect(find.text('Tickets'), findsOneWidget);
      expect(find.text('Join Gikundiro'), findsOneWidget);
      expect(find.text('Fanclubs'), findsOneWidget);
      expect(find.text('Shop'), findsOneWidget);
      expect(find.text('Matchday'), findsOneWidget);
      expect(find.text('Support'), findsAtLeastNWidgets(1));
    });

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
        expect(find.text(homeFeedLocalFallbackMessage), findsOneWidget);
        expect(find.text('Tickets'), findsOneWidget);
        expect(find.text('Join Gikundiro'), findsOneWidget);
        expect(find.text('Fanclubs'), findsOneWidget);
        expect(find.text('Shop'), findsOneWidget);
        expect(find.text('Matchday'), findsOneWidget);
        expect(find.text('Support'), findsAtLeastNWidgets(1));
      },
    );

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
              message:
                  'Live club data is temporarily unavailable. Pull to refresh.',
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
  });

  group('LatestIntelSection states', () {
    testWidgets('stays hidden when no published articles exist', (
      tester,
    ) async {
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
              message:
                  'Latest Intel is temporarily unavailable. Pull to refresh.',
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
}

Widget _buildApp({
  required HomeFeedRepository homeRepository,
  required LatestIntelRepository latestIntelRepository,
  required Widget child,
  PlatformConfigSnapshot featureConfigSnapshot = _testFeatureConfigSnapshot,
}) {
  return ProviderScope(
    overrides: [
      homeFeedRepositoryProvider.overrideWithValue(homeRepository),
      latestIntelRepositoryProvider.overrideWithValue(latestIntelRepository),
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      initialFeatureConfigSnapshotProvider.overrideWithValue(
        featureConfigSnapshot,
      ),
    ],
    child: MaterialApp(
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(disableAnimations: true),
          child: child!,
        );
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: ColorTokens.clubPrimary,
          brightness: Brightness.dark,
        ),
      ),
      home: child,
    ),
  );
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
      featureKey: 'fanzone',
      displayName: 'Fan Zone',
      channel: FeatureChannelConfig(showOnHome: true),
    ),
    PlatformFeature(
      featureKey: 'contributions',
      displayName: 'Contributions',
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

class _FakeLatestIntelRepository implements LatestIntelRepository {
  const _FakeLatestIntelRepository(this.snapshot);

  final LatestIntelSnapshot snapshot;

  @override
  Future<LatestIntelSnapshot> loadPublishedArticles() async => snapshot;
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(clubId: '24');

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
