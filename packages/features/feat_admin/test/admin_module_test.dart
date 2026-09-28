import 'package:feat_admin/feat_admin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Smoke tests for the Admin module — route structure, sub-routes, RBAC guard.
void main() {
  group('AdminModule', () {
    late AdminModule module;

    setUp(() {
      module = AdminModule();
    });

    test('featureKey is admin', () {
      expect(module.featureKey, 'admin');
    });

    test('has no tab route', () {
      expect(module.tabRoute, isNull);
    });

    test('registers /admin as the top-level route', () {
      final topRoutes = module.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toList();

      expect(topRoutes, contains('/admin'));
      expect(topRoutes, hasLength(1));
    });

    test('/admin has the full admin sub-route set', () {
      final adminRoute = module.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == '/admin',
      );
      final subPaths = adminRoute.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toList();

      expect(subPaths, hasLength(8));
      expect(subPaths, contains('cms'));
      expect(subPaths, contains('matches'));
      expect(subPaths, contains('contributions'));
      expect(subPaths, contains('notifications'));
      expect(subPaths, contains('settle'));
      expect(subPaths, contains('predict'));
      expect(subPaths, contains('competitions'));
      expect(subPaths, contains('features'));
    });

    test('isEnabled defaults to false when mobile admin is absent', () {
      expect(module.isEnabled({}), isFalse);
    });

    test('isEnabled returns false when explicitly disabled', () {
      expect(module.isEnabled({'admin': false}), isFalse);
    });

    test('isEnabled returns true for explicit mobile admin builds', () {
      expect(module.isEnabled({'mobile_admin': true}), isTrue);
      expect(module.isEnabled({'admin': true}), isTrue);
    });

    test('standaloneRoutes is empty by default', () {
      expect(module.standaloneRoutes, isEmpty);
    });
  });
}
