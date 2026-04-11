import 'package:feat_fantasy/feat_fantasy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('FantasyModule', () {
    late FantasyModule module;

    setUp(() {
      module = FantasyModule();
    });

    test('featureKey is fantasy', () {
      expect(module.featureKey, 'fantasy');
    });

    test('has no tab route', () {
      expect(module.tabRoute, isNull);
    });

    test('registers the fantasy hub and nested competition routes', () {
      final fantasyRoute = module.routes.whereType<GoRoute>().firstWhere(
        (route) => route.path == '/fantasy',
      );

      expect(fantasyRoute.path, '/fantasy');
      expect(fantasyRoute.routes.whereType<GoRoute>().length, 1);

      final competitionRoute = fantasyRoute.routes.whereType<GoRoute>().first;
      expect(competitionRoute.path, 'competition/:slug');

      final nestedPaths = competitionRoute.routes
          .whereType<GoRoute>()
          .map((route) => route.path)
          .toList();

      expect(
        nestedPaths,
        containsAll(<String>['rules', 'leaderboard', 'entry', 'squad']),
      );
    });

    test('isEnabled defaults to true when key is absent', () {
      expect(module.isEnabled({}), isTrue);
    });

    test('isEnabled returns false when explicitly disabled', () {
      expect(module.isEnabled({'fantasy': false}), isFalse);
    });
  });
}
