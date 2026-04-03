import 'package:core_theme/core_theme.dart';
import 'package:feat_home/src/repositories/home_content_repository.dart';
import 'package:feat_home/src/screens/home_screen.dart';
import 'package:feat_home/src/widgets/latest_intel_section.dart';
import 'package:feat_home/src/widgets/match_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('HomeScreen states', () {
    testWidgets('shows loading skeletons before home data resolves', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          homeRepository: _FakeHomeFeedRepository(
            delay: const Duration(milliseconds: 200),
            snapshot: const HomeFeedSnapshot(
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

      expect(find.text('LATEST INTEL'), findsOneWidget);
      expect(find.text('NO INTEL YET'), findsOneWidget);

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
