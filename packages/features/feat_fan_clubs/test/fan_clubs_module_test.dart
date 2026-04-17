import 'package:feat_fan_clubs/feat_fan_clubs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('FanClubsModule', () {
    late FanClubsModule module;

    setUp(() {
      module = FanClubsModule();
    });

    test('featureKey is fan_clubs', () {
      expect(module.featureKey, 'fan_clubs');
    });

    test('has no tab route', () {
      expect(module.tabRoute, isNull);
    });

    test('root route is /fan-clubs', () {
      final rootPaths = module.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(rootPaths, contains('/fan-clubs'));
    });

    group('/fan-clubs sub-routes', () {
      late GoRoute rootRoute;

      setUp(() {
        rootRoute = module.routes
            .whereType<GoRoute>()
            .firstWhere((r) => r.path == '/fan-clubs');
      });

      test('has :clubId sub-route', () {
        final subPaths = rootRoute.routes
            .whereType<GoRoute>()
            .map((r) => r.path)
            .toSet();
        expect(subPaths, contains(':clubId'));
      });
    });

    test('isEnabled defaults to true when key is absent', () {
      expect(module.isEnabled({}), isTrue);
    });

    test('isEnabled returns false when explicitly disabled', () {
      expect(module.isEnabled({'fan_clubs': false}), isFalse);
    });

    test('isEnabled returns true when explicitly enabled', () {
      expect(module.isEnabled({'fan_clubs': true}), isTrue);
    });
  });
}
