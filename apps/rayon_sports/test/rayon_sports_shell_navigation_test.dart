import 'package:club_rayon_sports/club_rayon_sports.dart';
import 'package:core_app/core_app.dart';
import 'package:core_modules/core_modules.dart';
import 'package:core_auth/core_auth.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_home/src/repositories/home_content_repository.dart';
import 'package:feat_home/src/widgets/match_card.dart';
import 'package:feat_home/src/widgets/quick_actions_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  group('Rayon Sports app shell', () {
    late RayonSportsConfig config;
    late List<FeatureModule> modules;

    setUp(() {
      config = const RayonSportsConfig();
      ColorTokens.init(config.colors);
      modules = AppModuleRegistry.build(config);
    });

    testWidgets('renders the home shell with production modules', (
      tester,
    ) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(
            accessibleNavigation: true,
            disableAnimations: true,
            reduceMotion: true,
          );

      await tester.pumpWidget(
        _buildTestApp(
          config: config,
          modules: modules,
          initialLocation: '/home',
          overrides: [
            homeFeedRepositoryProvider.overrideWithValue(
              const _FakeHomeFeedRepository(
                snapshot: HomeFeedSnapshot(
                  heroSlides: [
                    MatchSlide(
                      homeTeam: 'RAYON SPORTS',
                      awayTeam: 'APR FC',
                      venue: 'KIGALI PELE STADIUM',
                      status: 'ON SALE',
                      dateInfo: '12 APR • 18:00',
                      route: '/tickets',
                    ),
                  ],
                  status: HomeFeedStatus.success,
                ),
              ),
            ),
            latestIntelRepositoryProvider.overrideWithValue(
              const _FakeLatestIntelRepository(
                LatestIntelSnapshot(
                  status: LatestIntelStatus.ready,
                  articles: [
                    {
                      'id': 'article-1',
                      'title': 'Training ground update',
                      'subtitle': 'First-team preparations continue this week.',
                    },
                  ],
                ),
              ),
            ),
            currentUserProvider.overrideWith(
              (ref) => const UserProfile(
                id: 'user-1',
                clubId: 'rayon_sports_rw',
                publicUserId: '483912',
                phone: '0788123456',
                momoNumber: '0788123456',
                momoProvider: 'MoMo',
              ),
            ),
          ],
        ),
      );

      await _pumpShellReady(tester);
      await _pumpUntilVisible(tester, find.byType(QuickActionsGrid));

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(QuickActionsGrid), findsOneWidget);
      expect(find.text('News'), findsOneWidget);
      expect(find.text('Training ground update'), findsOneWidget);
    });

    testWidgets('navigates between home and settings tabs', (tester) async {
      final semantics = tester.ensureSemantics();
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(
            accessibleNavigation: true,
            disableAnimations: true,
            reduceMotion: true,
          );

      await tester.pumpWidget(
        _buildTestApp(
          config: config,
          modules: modules,
          initialLocation: '/home',
          overrides: [
            homeFeedRepositoryProvider.overrideWithValue(
              const _FakeHomeFeedRepository(
                snapshot: HomeFeedSnapshot(
                  heroSlides: [
                    MatchSlide(
                      homeTeam: 'RAYON SPORTS',
                      awayTeam: 'APR FC',
                      venue: 'KIGALI PELE STADIUM',
                      status: 'ON SALE',
                      dateInfo: '12 APR • 18:00',
                      route: '/tickets',
                    ),
                  ],
                  status: HomeFeedStatus.success,
                ),
              ),
            ),
            latestIntelRepositoryProvider.overrideWithValue(
              const _FakeLatestIntelRepository(
                LatestIntelSnapshot(status: LatestIntelStatus.empty),
              ),
            ),
            currentUserProvider.overrideWith(
              (ref) => const UserProfile(
                id: 'user-1',
                clubId: 'rayon_sports_rw',
                publicUserId: '483912',
                phone: '0788123456',
                momoNumber: '0788123456',
                momoProvider: 'MoMo',
              ),
            ),
          ],
        ),
      );

      await _pumpShellReady(tester);
      await _pumpUntilVisible(tester, find.bySemanticsLabel('SETTINGS'));

      await tester.tap(find.bySemanticsLabel('SETTINGS'));
      await tester.pump(const Duration(milliseconds: 300));
      await _pumpUntilVisible(tester, find.text('Account'));
      expect(find.text('Account'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('HOME'));
      await tester.pump(const Duration(milliseconds: 300));
      await _pumpUntilVisible(tester, find.byType(QuickActionsGrid));
      expect(find.byType(QuickActionsGrid), findsOneWidget);

      semantics.dispose();
    });
  });
}

Widget _buildTestApp({
  required RayonSportsConfig config,
  required List<FeatureModule> modules,
  required String initialLocation,
  required List<Override> overrides,
}) {
  final router = AppRouter(
    modules: modules,
    initialLocation: initialLocation,
    shellBuilder: (context, shell) =>
        AppShell(shell: shell, config: config, modules: modules),
  );

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      theme: ClubTheme.from(config),
      routerConfig: router.router,
      locale: const Locale('en'),
    ),
  );
}

class _FakeHomeFeedRepository implements HomeFeedRepository {
  const _FakeHomeFeedRepository({required this.snapshot});

  final HomeFeedSnapshot snapshot;

  @override
  Future<HomeFeedSnapshot> load() async => snapshot;
}

class _FakeLatestIntelRepository implements LatestIntelRepository {
  const _FakeLatestIntelRepository(this.snapshot);

  final LatestIntelSnapshot snapshot;

  @override
  Future<LatestIntelSnapshot> loadPublishedArticles() async => snapshot;
}

Future<void> _pumpShellReady(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
  await tester.pump(const Duration(milliseconds: 150));
  await tester.pump(const Duration(milliseconds: 150));
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 20,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 150));
  }

  expect(finder, findsOneWidget);
}
