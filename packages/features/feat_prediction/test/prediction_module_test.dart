import 'package:feat_prediction/src/prediction_module.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('PredictionModule', () {
    late PredictionModule module;

    setUp(() {
      module = PredictionModule();
    });

    test('featureKey is prediction', () {
      expect(module.featureKey, 'prediction');
    });

    test('exposes the prediction tab route', () {
      final tab = module.tabRoute;
      expect(tab.path, '/predictions');
      expect(tab.label, 'PREDICT');
    });

    test('registers prediction child routes', () {
      final childPaths = module.routes.whereType<GoRoute>().map(
        (route) => route.path,
      );
      expect(
        childPaths,
        containsAll(<String>[
          'my',
          'leaderboard',
          'notifications',
          'league',
          'league/:competitionSlug',
          'team/:teamSlug',
          'match/:fixtureId',
        ]),
      );
    });

    test('registers settlement under prediction detail', () {
      final myRoute = module.routes.whereType<GoRoute>().firstWhere(
        (route) => route.path == 'my',
      );
      final detailRoute = myRoute.routes.whereType<GoRoute>().firstWhere(
        (route) => route.path == ':predictionId',
      );
      final nestedPaths = detailRoute.routes.whereType<GoRoute>().map(
        (route) => route.path,
      );

      expect(nestedPaths, contains('settlement'));
    });

    test('exposes legacy redirects for migrated fanzone paths', () {
      final standalonePaths = module.standaloneRoutes.whereType<GoRoute>().map(
        (route) => route.path,
      );

      expect(
        standalonePaths,
        containsAll(<String>[
          '/fanzone',
          '/fanzone/fixtures',
          '/fanzone/live',
          '/fanzone/leaderboard',
          '/fanzone/my',
          '/fanzone/my/:predictionId/settlement',
          '/fanzone/league',
          '/fanzone/notifications',
          '/fanzone/league/:competitionSlug',
          '/fanzone/standings/:competitionSlug',
          '/fanzone/team/:teamSlug',
          '/fanzone/match/:fixtureId',
          '/fanzone/predictions',
        ]),
      );
    });

    test('stays enabled by default and respects prediction flags', () {
      expect(module.isEnabled({}), isTrue);
      expect(module.isEnabled({'prediction': false}), isFalse);
      expect(module.isEnabled({'prediction': true}), isTrue);
      expect(module.isEnabled({'fanzone': false}), isFalse);
      expect(module.isEnabled({'fanzone': true}), isTrue);
    });
  });
}
