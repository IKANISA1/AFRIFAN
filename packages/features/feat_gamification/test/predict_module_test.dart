import 'package:core_router/core_router.dart';
import 'package:feat_gamification/feat_gamification.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('Predict exposes only its supported destination and detail routes', () {
    final module = PredictModule();
    expect(module.featureKey, 'predict');
    expect(module.tabRoute.path, '/predict');
    expect(module.tabRoute.label, 'Predict');
    final routes = module.standaloneRoutes.whereType<GoRoute>();
    expect(routes.map((r) => r.path).toSet(), {
      '/predict/match/:fixtureId',
      '/predict/picks/:predictionId',
      '/predict/share',
    });
    for (final route in routes) {
      expect(route.redirect, isNull);
      expect(route.pageBuilder, isNotNull);
    }
    expect(module.routePresentationDecisions.map((d) => d.path).toSet(), {
      '/predict',
      ...routes.map((r) => r.path),
    });
    expect(
      module.routePresentationDecisions.any(
        (d) => d.presentation == RoutePresentation.redirect,
      ),
      isFalse,
    );
  });
}
