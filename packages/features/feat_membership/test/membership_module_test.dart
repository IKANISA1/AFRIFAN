import 'package:feat_membership/feat_membership.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Smoke tests for the Membership module — routes, tier params, and feature toggle.
void main() {
  group('MembershipModule', () {
    late MembershipModule module;

    setUp(() {
      module = MembershipModule();
    });

    test('featureKey is membership', () {
      expect(module.featureKey, 'membership');
    });

    test('has no tab route (Settings tab is in SettingsModule)', () {
      expect(module.tabRoute, isNull);
    });

    test('registers 3 top-level routes', () {
      final paths = module.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toList();

      expect(paths, hasLength(3));
      expect(paths, contains('/membership'));
      expect(paths, contains('/profile'));
      expect(paths, contains('/membership/tier/:tierId'));
    });

    test('/membership route has name membership', () {
      final route = module.routes
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == '/membership');

      expect(route.name, 'membership');
    });

    test('/profile route has name profile', () {
      final route = module.routes
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == '/profile');

      expect(route.name, 'profile');
    });

    test('tier detail route supports :tierId parameter', () {
      final tierRoute = module.routes
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == '/membership/tier/:tierId');

      // Route exists and accepts tierId param
      expect(tierRoute.path, '/membership/tier/:tierId');
    });

    test('isEnabled defaults to true when key is absent', () {
      expect(module.isEnabled({}), isTrue);
    });

    test('isEnabled returns false when explicitly disabled', () {
      expect(module.isEnabled({'membership': false}), isFalse);
    });

    test('standaloneRoutes is empty by default', () {
      expect(module.standaloneRoutes, isEmpty);
    });
  });
}
