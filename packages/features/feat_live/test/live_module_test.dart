import 'package:core_router/core_router.dart';
import 'package:feat_live/feat_live.dart';
import 'package:feat_live/src/widgets/live_match_widgets.dart';
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
              path: '/fanzone/match/:fixtureId',
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

        const target = '/fanzone/match/live';
        expect(find.text('Target: $target'), findsOneWidget);
        expect(router.routeInformationProvider.value.uri.toString(), target);
        expect(
          router.routeInformationProvider.value.uri.path,
          isNot(Uri.parse(source).path),
        );
      });
    }
  });

  // ═══════════════════════════════════════════════════════════
  // MatchIntelEvent (data model)
  // ═══════════════════════════════════════════════════════════

  group('MatchIntelEvent', () {
    test('stores minute, title, and body correctly', () {
      const event = MatchIntelEvent(
        minute: "45'",
        title: 'GOAL',
        body: 'Nshuti scores from a free kick.',
      );

      expect(event.minute, "45'");
      expect(event.title, 'GOAL');
      expect(event.body, 'Nshuti scores from a free kick.');
    });

    test('supports const construction', () {
      // Verify const semantics (should compile without issues)
      const events = [
        MatchIntelEvent(minute: "12'", title: 'CORNER', body: 'Left side'),
        MatchIntelEvent(minute: "23'", title: 'YELLOW CARD', body: 'Foul'),
      ];
      expect(events, hasLength(2));
    });
  });
}
