import 'package:core_router/core_router.dart';
import 'package:feat_live/feat_live.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Unit tests for the Live module — routes, feature toggle, and data models.
void main() {
  // ═══════════════════════════════════════════════════════════
  // LiveModule
  // ═══════════════════════════════════════════════════════════

  group('LiveModule', () {
    late LiveModule module;

    setUp(() {
      module = LiveModule();
    });

    test('featureKey is live', () {
      expect(module.featureKey, 'live');
    });

    test('live is a standalone module (not a tab)', () {
      expect(module.tabRoute, isNull);
    });

    test('/live route exists at root level', () {
      final paths = module.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(paths, contains('/live'));
    });

    test('registers news reader and standalone live-match alias', () {
      final rootPaths = module.routes
          .whereType<GoRoute>()
          .map((route) => route.path)
          .toList();
      final standalonePaths = module.standaloneRoutes
          .whereType<GoRoute>()
          .map((route) => route.path)
          .toList();

      expect(
        rootPaths,
        containsAll(<String>['/live', '/live/news/:articleId']),
      );
      expect(standalonePaths, orderedEquals(<String>['/live-match']));
    });

    test('isEnabled returns true when live feature is in config', () {
      expect(module.isEnabled({'live': true}), isTrue);
    });

    test('isEnabled defaults to true when key is absent', () {
      // FeatureModule defaults missing keys to true
      expect(module.isEnabled({}), isTrue);
    });

    test('isEnabled returns false when explicitly disabled', () {
      expect(module.isEnabled({'live': false}), isFalse);
    });

    testWidgets('legacy news links open the canonical Club reader', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/live/news/club%20update',
        routes: <RouteBase>[
          ...module.routes,
          GoRoute(
            path: '/club/news/:articleId',
            builder: (_, state) => Scaffold(
              body: Text('Article: ${state.pathParameters['articleId']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Article: club update'), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/club/news/club%20update',
      );
    });

    test(
      'declares route presentation decisions for the minimal app policy',
      () {
        final decisions = {
          for (final decision in module.routePresentationDecisions)
            decision.path: decision.presentation,
        };

        expect(decisions['/live'], RoutePresentation.redirect);
        expect(decisions['/live/news/:articleId'], RoutePresentation.redirect);
        expect(decisions['/live-match'], RoutePresentation.redirect);
      },
    );

    for (final source in <String>['/live', '/live-match']) {
      testWidgets('$source resolves to the governed Match Detail target', (
        tester,
      ) async {
        final redirectRoute = source == '/live'
            ? module.routes.whereType<GoRoute>().singleWhere(
                (route) => route.path == source,
              )
            : module.standaloneRoutes.whereType<GoRoute>().singleWhere(
                (route) => route.path == source,
              );
        final router = GoRouter(
          initialLocation: source,
          routes: <RouteBase>[
            redirectRoute,
            GoRoute(
              path: '/predict/match/:fixtureId',
              builder: (context, state) =>
                  Scaffold(body: Text('Target: ${state.uri}')),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          MaterialApp.router(
            debugShowCheckedModeBanner: false,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();

        const target = '/predict/match/live';
        expect(find.text('Target: $target'), findsOneWidget);
        expect(router.routeInformationProvider.value.uri.toString(), target);
        expect(
          router.routeInformationProvider.value.uri.path,
          isNot(Uri.parse(source).path),
        );
      });
    }
  });

}
