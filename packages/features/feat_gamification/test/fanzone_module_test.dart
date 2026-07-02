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

    test('secondary routes use sheet or pushed route pages', () {
      final routeMap = _routeMap(module.routes);

      for (final path in const <String>[
        'fixtures',
        'my',
        'my/:predictionId',
        'my/:predictionId/settlement',
        'match/:fixtureId',
        'offers',
        'rewards',
        'leaderboard',
        'league/:competitionSlug',
        'standings/:competitionSlug',
        'team/:teamSlug',
      ]) {
        final route = routeMap[path];
        expect(route, isNotNull, reason: path);
        expect(route!.pageBuilder, isNotNull, reason: path);
        expect(route.builder, isNull, reason: path);
      }
    });

    test('only wallet remains a full fanzone sub-screen builder', () {
      final routeMap = _routeMap(module.routes);

      final walletRoute = routeMap['wallet'];
      expect(walletRoute, isNotNull);
      expect(walletRoute!.builder, isNotNull);
      expect(walletRoute.pageBuilder, isNull);

      final liveRoute = routeMap['live'];
      expect(liveRoute, isNotNull);
      expect(liveRoute!.redirect, isNotNull);
    });

    test(
      'declares route presentation decisions for the minimal app policy',
      () {
        final decisions = {
          for (final decision in module.routePresentationDecisions)
            decision.path: decision.presentation,
        };

        expect(decisions['/fanzone'], RoutePresentation.fullScreen);
        expect(
          decisions['/fanzone/fixtures'],
          RoutePresentation.fullHeightSheet,
        );
        expect(decisions['/fanzone/live'], RoutePresentation.redirect);
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
