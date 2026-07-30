import 'package:feat_gamification/feat_gamification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  const redirects = <String, String>{
    '/fanzone/fixtures': '/fanzone?section=league',
    '/fanzone/live': '/fanzone?section=league',
    '/fanzone/my': '/fanzone?section=predictions',
    '/fanzone/offers': '/fanzone?section=rewards',
    '/fanzone/rewards': '/fanzone?section=rewards',
    '/fanzone/history': '/fanzone?section=wallet',
    '/fanzone/leaderboard': '/fanzone?section=league',
    '/fanzone/notifications': '/fanzone?section=predictions',
    '/fanzone/badges': '/fanzone?section=rewards',
    '/fanzone/streak': '/fanzone?section=rewards',
    '/fanzone/league': '/fanzone?section=league',
    '/fanzone/league/premier-league': '/fanzone?section=league',
    '/fanzone/standings/premier-league': '/fanzone?section=league',
    '/fanzone/team/rayon-sports': '/fanzone?section=league',
    '/fanzone/club-zone': '/fanzone?section=supporters',
    '/fanzone/fan-id': '/fanzone?section=supporters',
    '/fanzone/social': '/fanzone?section=supporters',
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
            routes: module.routes,
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
      final settlementRoute = module.routes.whereType<GoRoute>().singleWhere(
        (route) => route.path == 'my/:predictionId/settlement',
      );
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

    expect(decisions['/fanzone/fixtures'], '/fanzone?section=league');
    expect(decisions['/fanzone/live'], '/fanzone?section=league');
    expect(decisions['/fanzone/my'], '/fanzone?section=predictions');
    expect(decisions['/fanzone/offers'], '/fanzone?section=rewards');
    expect(decisions['/fanzone/rewards'], '/fanzone?section=rewards');
    expect(decisions['/fanzone/history'], '/fanzone?section=wallet');
    expect(decisions['/fanzone/leaderboard'], '/fanzone?section=league');
    expect(decisions['/fanzone/notifications'], '/fanzone?section=predictions');
    expect(decisions['/fanzone/badges'], '/fanzone?section=rewards');
    expect(decisions['/fanzone/streak'], '/fanzone?section=rewards');
    expect(decisions['/fanzone/league'], '/fanzone?section=league');
    expect(
      decisions['/fanzone/league/:competitionSlug'],
      '/fanzone?section=league',
    );
    expect(
      decisions['/fanzone/standings/:competitionSlug'],
      '/fanzone?section=league',
    );
    expect(decisions['/fanzone/team/:teamSlug'], '/fanzone?section=league');
    expect(decisions['/fanzone/club-zone'], '/fanzone?section=supporters');
    expect(decisions['/fanzone/fan-id'], '/fanzone?section=supporters');
    expect(decisions['/fanzone/social'], '/fanzone?section=supporters');
    expect(decisions['/fanzone/privacy'], '/settings/privacy');
    expect(
      decisions['/fanzone/my/:predictionId/settlement'],
      '/fanzone/my/:predictionId',
    );
  });
}
