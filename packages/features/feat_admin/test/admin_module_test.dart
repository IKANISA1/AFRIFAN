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

      expect(subPaths, hasLength(9));
      expect(subPaths, contains('cms'));
      expect(subPaths, contains('matches'));
      expect(subPaths, contains('contributions'));
      expect(subPaths, contains('notifications'));
      expect(subPaths, contains('sms-monitor'));
      expect(subPaths, contains('settle'));
      expect(subPaths, contains('challenges'));
      expect(subPaths, contains('competitions'));
      expect(subPaths, contains('features'));
    });

    test('isEnabled defaults to true when key is absent', () {
      expect(module.isEnabled({}), isTrue);
    });

    test('isEnabled returns false when explicitly disabled', () {
      expect(module.isEnabled({'admin': false}), isFalse);
    });

    test('standaloneRoutes is empty by default', () {
      expect(module.standaloneRoutes, isEmpty);
    });
  });
}
