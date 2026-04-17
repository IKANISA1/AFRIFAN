import 'package:feat_contributions/feat_contributions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('ContributionsModule', () {
    late ContributionsModule module;

    setUp(() {
      module = ContributionsModule();
    });

    test('featureKey is contributions', () {
      expect(module.featureKey, 'contributions');
    });

    test('has no tab route', () {
      expect(module.tabRoute, isNull);
    });

    test('root route is /contribute', () {
      final rootPaths = module.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(rootPaths, contains('/contribute'));
    });

    group('/contribute sub-routes', () {
      late GoRoute rootRoute;

      setUp(() {
        rootRoute = module.routes
            .whereType<GoRoute>()
            .firstWhere((r) => r.path == '/contribute');
      });

      test('has projects sub-route', () {
        final subPaths = rootRoute.routes
            .whereType<GoRoute>()
            .map((r) => r.path)
            .toSet();
        expect(subPaths, contains('projects'));
      });

      test('has groups sub-route', () {
        final subPaths = rootRoute.routes
            .whereType<GoRoute>()
            .map((r) => r.path)
            .toSet();
        expect(subPaths, contains('groups'));
      });

      test('has group/:groupId sub-route', () {
        final subPaths = rootRoute.routes
            .whereType<GoRoute>()
            .map((r) => r.path)
            .toSet();
        expect(subPaths, contains('group/:groupId'));
      });

      group('group/:groupId nesting', () {
        late GoRoute groupRoute;

        setUp(() {
          groupRoute = rootRoute.routes
              .whereType<GoRoute>()
              .firstWhere((r) => r.path == 'group/:groupId');
        });

        test('has statement sub-route', () {
          final subPaths = groupRoute.routes
              .whereType<GoRoute>()
              .map((r) => r.path)
              .toSet();
          expect(subPaths, contains('statement'));
        });
      });
    });

    test('isEnabled defaults to true', () {
      expect(module.isEnabled({}), isTrue);
    });

    test('isEnabled returns false when explicitly disabled', () {
      expect(module.isEnabled({'contributions': false}), isFalse);
    });
  });
}
