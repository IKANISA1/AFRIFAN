import 'package:feat_gamification/src/gamification_module.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('GamificationModule', () {
    late GamificationModule module;

    setUp(() {
      module = GamificationModule();
    });

    test('featureKey is gamification', () {
      expect(module.featureKey, 'gamification');
    });

    test('registers FET standalone routes', () {
      final rootRoutes = module.routes.whereType<GoRoute>().toList();
      expect(rootRoutes.single.path, '/fet');
    });

    test('registers reward and progression child routes', () {
      final rootRoute = module.routes.whereType<GoRoute>().single;
      final childPaths = rootRoute.routes.whereType<GoRoute>().map(
        (route) => route.path,
      );
      expect(
        childPaths,
        containsAll(<String>[
          'leaderboard',
          'wallet',
          'rewards',
          'history',
          'challenges',
          'badges',
          'streak',
          'jackpot',
          'share',
          'friends',
          'challenge',
          'club-zone',
        ]),
      );
    });

    test('exposes legacy fanzone redirects', () {
      final standalonePaths = module.standaloneRoutes.whereType<GoRoute>().map(
        (route) => route.path,
      );
      expect(
        standalonePaths,
        containsAll(<String>[
          '/fanzone/wallet',
          '/fanzone/leaderboard',
          '/fanzone/rewards',
          '/fanzone/history',
          '/fanzone/challenges',
          '/fanzone/badges',
          '/fanzone/streak',
          '/fanzone/jackpot',
          '/fanzone/share',
          '/fanzone/friends',
          '/fanzone/challenge',
          '/fanzone/club-zone',
        ]),
      );
    });

    test('stays enabled by default and respects gamification flags', () {
      expect(module.isEnabled({}), isTrue);
      expect(module.isEnabled({'gamification': false}), isFalse);
      expect(module.isEnabled({'gamification': true}), isTrue);
      expect(module.isEnabled({'fanzone': false}), isFalse);
      expect(module.isEnabled({'fanzone': true}), isTrue);
    });
  });
}
