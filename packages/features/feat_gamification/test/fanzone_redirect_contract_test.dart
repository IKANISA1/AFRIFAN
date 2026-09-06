import 'package:feat_gamification/feat_gamification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  const redirects = <String, String>{
    '/fanzone/fixtures': '/club/fixtures',
    '/fanzone/live': '/club/fixtures',
    '/fanzone/my': '/predict?section=history',
    '/fanzone/offers': '/predict?section=wallet',
    '/fanzone/rewards': '/predict?section=wallet',
    '/fanzone/history': '/predict?section=wallet',
    '/fanzone/leaderboard': '/club/fixtures',
    '/fanzone/notifications': '/predict?section=history',
    '/fanzone/badges': '/predict?section=wallet',
    '/fanzone/streak': '/predict?section=wallet',
    '/fanzone/league': '/club/fixtures',
    '/fanzone/league/premier-league': '/club/fixtures',
    '/fanzone/standings/premier-league': '/club/fixtures',
    '/fanzone/team/rayon-sports': '/club/fixtures',
    '/fanzone/club-zone': '/fan-clubs',
    '/fanzone/fan-id': '/fan-clubs',
    '/fanzone/social': '/fan-clubs',
    '/fanzone/privacy': '/settings/privacy',
  };

  for (final entry in redirects.entries) {
    testWidgets('${entry.key} resolves to ${entry.value}', (tester) async {
      final module = FanzoneModule();
      final router = GoRouter(
        initialLocation: entry.key,
        routes: <RouteBase>[
          GoRoute(
            path: '/fanzone',
            builder: (context, state) =>
                Scaffold(body: Text('Target: ${state.uri}')),
            routes: module.standaloneRoutes
                .whereType<GoRoute>()
                .singleWhere((r) => r.path == '/fanzone')
                .routes,
          ),
          for (final path in ['/predict', '/club/fixtures', '/fan-clubs'])
            GoRoute(
              path: path,
              builder: (_, state) =>
                  Scaffold(body: Text('Target: ${state.uri}')),
            ),
          GoRoute(
            path: '/settings/privacy',
            builder: (context, state) =>
                Scaffold(body: Text('Target: ${state.uri}')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Target: ${entry.value}'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.toString(), entry.value);
      expect(
        router.routeInformationProvider.value.uri.path,
        isNot(Uri.parse(entry.key).path),
      );
    });
  }

  testWidgets(
    '/fanzone/my/:predictionId/settlement preserves the id and resolves to detail',
    (tester) async {
      final module = FanzoneModule();
      final settlementRoute = module.standaloneRoutes
          .whereType<GoRoute>()
          .singleWhere((r) => r.path == '/fanzone')
          .routes
          .whereType<GoRoute>()
          .singleWhere((route) => route.path == 'my/:predictionId/settlement');
      final router = GoRouter(
        initialLocation: '/fanzone/my/prediction-1/settlement',
        routes: <RouteBase>[
          GoRoute(
            path: '/fanzone',
            builder: (context, state) =>
                Scaffold(body: Text('Target: ${state.uri}')),
            routes: <RouteBase>[
              settlementRoute,
              GoRoute(
                path: 'my/:predictionId',
                builder: (context, state) =>
                    Scaffold(body: Text('Target: ${state.uri}')),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      const target = '/fanzone/my/prediction-1';
      expect(find.text('Target: $target'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.toString(), target);
    },
  );

  test('presentation decisions match every governed redirect target', () {
    final decisions = {
      for (final decision in FanzoneModule().routePresentationDecisions.where(
        (decision) => decision.targetPath != null,
      ))
        decision.path: decision.targetPath,
    };

    expect(decisions['/fanzone/fixtures'], '/club/fixtures');
    expect(decisions['/fanzone/live'], '/club/fixtures');
    expect(decisions['/fanzone/my'], '/predict?section=history');
    expect(decisions['/fanzone/offers'], '/predict?section=wallet');
    expect(decisions['/fanzone/rewards'], '/predict?section=wallet');
    expect(decisions['/fanzone/history'], '/predict?section=wallet');
    expect(decisions['/fanzone/leaderboard'], '/club/fixtures');
    expect(decisions['/fanzone/notifications'], '/predict?section=history');
    expect(decisions['/fanzone/badges'], '/predict?section=wallet');
    expect(decisions['/fanzone/streak'], '/predict?section=wallet');
    expect(decisions['/fanzone/league'], '/club/fixtures');
    expect(decisions['/fanzone/league/:competitionSlug'], '/club/fixtures');
    expect(decisions['/fanzone/standings/:competitionSlug'], '/club/fixtures');
    expect(decisions['/fanzone/team/:teamSlug'], '/club/fixtures');
    expect(decisions['/fanzone/club-zone'], '/fan-clubs');
    expect(decisions['/fanzone/fan-id'], '/fan-clubs');
    expect(decisions['/fanzone/social'], '/fan-clubs');
    expect(decisions['/fanzone/privacy'], '/settings/privacy');
    expect(
      decisions['/fanzone/my/:predictionId/settlement'],
      '/fanzone/my/:predictionId',
    );
  });
}
