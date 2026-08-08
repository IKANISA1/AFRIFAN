import 'package:core_router/core_router.dart';
import 'package:feat_gamification/feat_gamification.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('FanzoneModule', () {
    late FanzoneModule module;

    setUp(() {
      module = FanzoneModule();
    });

    test('keeps fanzone as the supporter tab route', () {
      expect(module.featureKey, 'fanzone');
      expect(module.tabRoute.path, '/fanzone');
      expect(module.tabRoute.label, 'Fan Zone');
    });

    test('secondary routes use redirects except true detail/action sheets', () {
      final routeMap = _routeMap(module.routes);

      for (final path in const <String>[
        'my/:predictionId',
        'match/:fixtureId',
        'share',
      ]) {
        final route = routeMap[path];
        expect(route, isNotNull, reason: path);
        expect(route!.pageBuilder, isNotNull, reason: path);
        expect(route.builder, isNull, reason: path);
      }

      for (final path in const <String>[
        'fixtures',
        'my',
        'offers',
        'rewards',
        'history',
        'my/:predictionId/settlement',
        'leaderboard',
        'notifications',
        'badges',
        'streak',
        'league',
        'league/:competitionSlug',
        'standings/:competitionSlug',
        'team/:teamSlug',
        'club-zone',
        'fan-id',
        'social',
      ]) {
        final route = routeMap[path];
        expect(route, isNotNull, reason: path);
        expect(route!.redirect, isNotNull, reason: path);
        expect(route.builder, isNull, reason: path);
        expect(route.pageBuilder, isNull, reason: path);
      }
    });

    test('wallet route remains the only full fanzone sub-screen builder', () {
      final routeMap = _routeMap(module.routes);

      final walletRoute = routeMap['wallet'];
      expect(walletRoute, isNotNull);
      expect(walletRoute!.builder, isNotNull);
      expect(walletRoute.pageBuilder, isNull);

      final liveRoute = routeMap['live'];
      expect(liveRoute, isNotNull);
      expect(liveRoute!.redirect, isNotNull);
    });

    test('live games are focused standalone routes outside the tab shell', () {
      final nestedRoutes = _routeMap(module.routes);
      final standaloneRoutes = _routeMap(module.standaloneRoutes);

      expect(nestedRoutes['game'], isNull);
      expect(nestedRoutes['game/:sessionId'], isNull);
      expect(standaloneRoutes['/fanzone/game']?.pageBuilder, isNotNull);
      expect(
        standaloneRoutes['/fanzone/game/:sessionId']?.pageBuilder,
        isNotNull,
      );
    });

    test('legacy fanzone entrypoints target consolidated hub sections', () {
      final decisions = {
        for (final decision in module.routePresentationDecisions)
          decision.path: decision.targetPath,
      };

      expect(decisions['/fanzone/live'], '/fanzone?section=league');
      expect(decisions['/fanzone/offers'], '/fanzone?section=rewards');
      expect(decisions['/fanzone/history'], '/fanzone?section=wallet');
      expect(decisions['/fanzone/my'], '/fanzone?section=predictions');
      expect(decisions['/fanzone/club-zone'], '/fanzone?section=supporters');
      expect(decisions['/fanzone/fan-id'], '/fanzone?section=supporters');
      expect(decisions['/fanzone/social'], '/fanzone?section=supporters');
    });

    test(
      'declares route presentation decisions for the minimal app policy',
      () {
        final decisions = {
          for (final decision in module.routePresentationDecisions)
            decision.path: decision.presentation,
        };

        expect(decisions['/fanzone'], RoutePresentation.fullScreen);
        expect(decisions['/fanzone/fixtures'], RoutePresentation.redirect);
        expect(decisions['/fanzone/live'], RoutePresentation.redirect);
        expect(decisions['/fanzone/my'], RoutePresentation.redirect);
        expect(decisions['/fanzone/game'], RoutePresentation.fullScreen);
        expect(
          decisions['/fanzone/game/:sessionId'],
          RoutePresentation.fullScreen,
        );
        expect(decisions['/fanzone/venue'], RoutePresentation.fullScreen);
        expect(decisions['/fanzone/venue/order'], RoutePresentation.fullScreen);
        expect(decisions['/fanzone/offers'], RoutePresentation.redirect);
        expect(decisions['/fanzone/rewards'], RoutePresentation.redirect);
        expect(decisions['/fanzone/history'], RoutePresentation.redirect);
        expect(
          decisions['/fanzone/my/:predictionId/settlement'],
          RoutePresentation.redirect,
        );
        expect(decisions['/fanzone/league'], RoutePresentation.redirect);
        expect(decisions['/fanzone/club-zone'], RoutePresentation.redirect);
        expect(decisions['/fanzone/fan-id'], RoutePresentation.redirect);
        expect(decisions['/fanzone/privacy'], RoutePresentation.redirect);
      },
    );
  });
}

Map<String, GoRoute> _routeMap(List<RouteBase> routes) {
  final result = <String, GoRoute>{};

  void visit(RouteBase route, String prefix) {
    if (route is! GoRoute) {
      return;
    }

    final path = prefix.isEmpty ? route.path : '$prefix/${route.path}';
    result[path] = route;

    for (final child in route.routes) {
      visit(child, path);
    }
  }

  for (final route in routes) {
    visit(route, '');
  }
  return result;
}
