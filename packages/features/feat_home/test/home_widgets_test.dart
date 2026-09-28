import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_home/src/repositories/home_content_repository.dart';
import 'package:feat_home/src/widgets/quick_actions_grid.dart';
import 'package:feat_home/src/widgets/stats_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Smoke tests for feat_home widgets — StatsRow and QuickActionsGrid.
///
/// These verify rendering, formatting, and child counts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ═══════════════════════════════════════════════════════════
  // StatsRow
  // ═══════════════════════════════════════════════════════════

  group('StatsRow', () {
    Widget buildTestApp({int globalFet = 42880, int fanRank = 12}) {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => Scaffold(
              body: StatsRow(globalFet: globalFet, fanRank: fanRank),
            ),
          ),
        ],
      );

      return MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: ColorTokens.primary,
            brightness: Brightness.dark,
          ),
        ),
      );
    }

    testWidgets('renders FET label', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      expect(find.text('FET'), findsOneWidget);
    });

    testWidgets('renders rank label', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      expect(find.text('Rank'), findsOneWidget);
    });

    testWidgets('renders formatted FET number with commas', (tester) async {
      await tester.pumpWidget(buildTestApp(globalFet: 42880));
      await tester.pumpAndSettle();
      expect(find.text('42,880'), findsOneWidget);
    });

    testWidgets('renders fan rank number (zero-padded)', (tester) async {
      await tester.pumpWidget(buildTestApp(fanRank: 7));
      await tester.pumpAndSettle();
      expect(find.text('#007'), findsOneWidget);
    });

    testWidgets('keeps own FET visible without rendering an unknown rank', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp(globalFet: 2140, fanRank: 0));
      await tester.pumpAndSettle();

      expect(find.text('2,140'), findsOneWidget);
      expect(find.text('Rank'), findsNothing);
      expect(find.text('#000'), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // QuickActionsGrid
  // ═══════════════════════════════════════════════════════════

  group('QuickActionsGrid', () {
    const actions = <HomeQuickAction>[
      HomeQuickAction(
        actionKey: 'tickets',
        title: 'Tickets',
        route: '/tickets',
        iconKey: 'tickets',
        subtitle: 'Official match access',
        sortOrder: 10,
      ),
      HomeQuickAction(
        actionKey: 'membership',
        title: 'Membership',
        route: '/membership',
        iconKey: 'membership',
        subtitle: 'Supporter identity',
        sortOrder: 20,
      ),
      HomeQuickAction(
        actionKey: 'predict',
        title: 'Predict',
        route: '/fan-clubs',
        iconKey: 'members',
        sortOrder: 30,
      ),
      HomeQuickAction(
        actionKey: 'shop',
        title: 'Shop',
        route: '/shop',
        iconKey: 'shop',
        sortOrder: 40,
      ),
      HomeQuickAction(
        actionKey: 'matchday',
        title: 'Matchday',
        route: '/club/fixtures',
        iconKey: 'league',
        sortOrder: 0,
      ),
    ];

    Widget buildTestApp() {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(
              body: SingleChildScrollView(
                child: QuickActionsGrid(actions: actions),
              ),
            ),
          ),
          // Stub routes for navigation
          GoRoute(path: '/club/fixtures', builder: (_, __) => const SizedBox()),
          GoRoute(
            path: '/predict?section=history',
            builder: (_, __) => const SizedBox(),
          ),
          GoRoute(
            path: '/predict/picks/:predictionId',
            builder: (_, __) => const SizedBox(),
          ),
          GoRoute(path: '/live', builder: (_, __) => const SizedBox()),
          GoRoute(
            path: '/club/standings',
            builder: (_, __) => const SizedBox(),
          ),
          GoRoute(path: '/predict', builder: (_, __) => const SizedBox()),
          GoRoute(path: '/tickets', builder: (_, __) => const SizedBox()),
          GoRoute(path: '/membership', builder: (_, __) => const SizedBox()),
          GoRoute(path: '/fan-clubs', builder: (_, __) => const SizedBox()),
          GoRoute(path: '/shop', builder: (_, __) => const SizedBox()),
          GoRoute(path: '/contribute', builder: (_, __) => const SizedBox()),
        ],
      );

      return ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: ColorTokens.primary,
              brightness: Brightness.dark,
            ),
          ),
        ),
      );
    }

    testWidgets('caps the primary shortcut group at four actions', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Tickets'), findsOneWidget);
      expect(find.text('Membership'), findsOneWidget);
      expect(find.text('Predict'), findsOneWidget);
      expect(find.text('Shop'), findsOneWidget);
      expect(find.text('Matchday'), findsNothing);
      expect(find.byType(AfriQuickAction), findsNWidgets(4));
      expect(
        find.byKey(const ValueKey<String>('home-primary-actions-4col')),
        findsOneWidget,
      );
    });

    testWidgets('reveals secondary actions in a separate lower layer', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('home-secondary-actions-toggle')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shortcuts'), findsOneWidget);
      expect(find.text('More shortcuts'), findsNothing);
      expect(find.text('Matchday'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('home-secondary-actions-2col')),
        findsOneWidget,
      );

      await tester.tap(find.text('Less'));
      await tester.pumpAndSettle();
      expect(find.text('Matchday'), findsNothing);
    });

    testWidgets('uses two primary columns at 200 percent text', (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('home-primary-actions-2col')),
        findsOneWidget,
      );
      expect(find.byType(AfriQuickAction), findsNWidgets(4));

      await tester.tap(
        find.byKey(const ValueKey<String>('home-secondary-actions-toggle')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('home-secondary-actions-1col')),
        findsOneWidget,
      );
    });

    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('separates and aligns shortcuts at $width / $scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await tester.pumpWidget(buildTestApp());
          await tester.pumpAndSettle();

          final primaryBottom = find
              .byType(AfriQuickAction)
              .evaluate()
              .map(
                (element) =>
                    tester.getBottomLeft(find.byWidget(element.widget)).dy,
              )
              .reduce((a, b) => a > b ? a : b);
          final title = tester.getRect(find.text('Shortcuts'));
          final toggle = tester.getRect(
            find.byKey(const ValueKey<String>('home-secondary-actions-toggle')),
          );
          expect(title.top - primaryBottom, greaterThanOrEqualTo(16));
          expect(toggle.top - primaryBottom, greaterThanOrEqualTo(16));
          if (scale >= 1.5) {
            expect(toggle.top, greaterThanOrEqualTo(title.bottom));
          } else {
            expect(title.center.dy, closeTo(toggle.center.dy, 1));
            expect(title.right, lessThanOrEqualTo(toggle.left));
          }
          expect(toggle.height, greaterThanOrEqualTo(44));
          expect(toggle.right, lessThanOrEqualTo(width));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  test('prioritizes core fan jobs ahead of configured secondary actions', () {
    final prioritized = prioritizeHomeQuickActions(const <HomeQuickAction>[
      HomeQuickAction(
        actionKey: 'rewards',
        title: 'Rewards',
        route: '/predict?section=wallet',
        iconKey: 'rewards',
        sortOrder: 1,
      ),
      HomeQuickAction(
        actionKey: 'shop',
        title: 'Shop',
        route: '/shop',
        iconKey: 'shop',
        sortOrder: 99,
      ),
      HomeQuickAction(
        actionKey: 'tickets',
        title: 'Tickets',
        route: '/tickets',
        iconKey: 'tickets',
        sortOrder: 99,
      ),
      HomeQuickAction(
        actionKey: 'membership',
        title: 'Membership',
        route: '/membership',
        iconKey: 'membership',
        sortOrder: 99,
      ),
    ]);

    expect(prioritized.map((action) => action.actionKey), <String>[
      'tickets',
      'membership',
      'rewards',
      'shop',
    ]);
  });
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
