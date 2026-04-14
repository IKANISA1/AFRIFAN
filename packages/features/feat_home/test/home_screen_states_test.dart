import 'package:core_theme/core_theme.dart';
import 'package:feat_home/src/repositories/home_content_repository.dart';
import 'package:feat_home/src/screens/home_screen.dart';
import 'package:feat_home/src/widgets/contributor_leaderboard.dart';
import 'package:feat_home/src/widgets/latest_intel_section.dart';
import 'package:feat_home/src/widgets/match_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:test_support/design_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(loadDesignFonts);

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

      expect(find.byType(MatchScoreCard), findsOneWidget);
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
              globalXp: 5260,
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

      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('goldens/home_screen.png'),
      );
    });
  });

  group('LatestIntelSection states', () {
    testWidgets('shows an empty state instead of disappearing', (tester) async {
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

      expect(find.text('News'), findsOneWidget);
      expect(find.text('No news yet'), findsOneWidget);

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
}) {
  return ProviderScope(
    overrides: [
      homeFeedRepositoryProvider.overrideWithValue(homeRepository),
      latestIntelRepositoryProvider.overrideWithValue(latestIntelRepository),
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

class _FakeLatestIntelRepository implements LatestIntelRepository {
  const _FakeLatestIntelRepository(this.snapshot);

  final LatestIntelSnapshot snapshot;

  @override
  Future<LatestIntelSnapshot> loadPublishedArticles() async => snapshot;
}
