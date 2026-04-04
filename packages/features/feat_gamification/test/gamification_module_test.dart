import 'package:feat_gamification/feat_gamification.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Smoke tests for the Gamification module — route structure and XP sub-routes.
void main() {
  group('GamificationModule', () {
    late GamificationModule module;

    setUp(() {
      module = GamificationModule();
    });

    test('featureKey is gamification', () {
      expect(module.featureKey, 'gamification');
    });

    test('has no tab route (accessed via Home quick actions)', () {
      expect(module.tabRoute, isNull);
    });

    test('registers /xp as the top-level route', () {
      final topRoutes = module.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toList();

      expect(topRoutes, contains('/xp'));
      expect(topRoutes, hasLength(1));
    });

    test('/xp has 4 sub-routes for XP features', () {
      final xpRoute = module.routes
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == '/xp');
      final subPaths = xpRoute.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toList();

      expect(subPaths, hasLength(4));
      expect(subPaths, contains('leaderboard'));
      expect(subPaths, contains('challenges'));
      expect(subPaths, contains('badges'));
      expect(subPaths, contains('streak'));
    });

    test('/xp route has name xp-dashboard', () {
      final xpRoute = module.routes
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == '/xp');

      expect(xpRoute.name, 'xp-dashboard');
    });

    test('leaderboard sub-route has name leaderboard', () {
      final xpRoute = module.routes
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == '/xp');
      final leaderboard = xpRoute.routes
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == 'leaderboard');

      expect(leaderboard.name, 'leaderboard');
    });

    test('isEnabled defaults to true when key is absent', () {
      expect(module.isEnabled({}), isTrue);
    });

    test('isEnabled returns false when explicitly disabled', () {
      expect(module.isEnabled({'gamification': false}), isFalse);
    });
  });
}
