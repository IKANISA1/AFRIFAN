import 'package:core_router/core_router.dart';
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

    test('registers membership routes', () {
      final paths = module.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toList();

      expect(paths, hasLength(3));
      expect(paths, contains('/membership'));
      expect(paths, contains('/membership/fans'));
      expect(paths, contains('/membership/tier/:tierId'));
    });

    test('/membership route has name membership', () {
      final route = module.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == '/membership',
      );

      expect(route.name, 'membership');
    });

    test('/membership/fans route is a compatibility redirect', () {
      final route = module.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == '/membership/fans',
      );

      expect(route.name, 'membership-fans');
      expect(route.redirect, isNotNull);
      expect(route.builder, isNull);
      expect(route.pageBuilder, isNull);
    });

    test('pushed membership routes use shared route pages', () {
      for (final route in module.routes.whereType<GoRoute>().where(
        (r) => r.path == '/membership/tier/:tierId',
      )) {
        expect(route.pageBuilder, isNotNull, reason: route.path);
        expect(route.builder, isNull, reason: route.path);
      }
    });

    test('membership root keeps standard builder', () {
      final route = module.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == '/membership',
      );

      expect(route.builder, isNotNull);
      expect(route.pageBuilder, isNull);
    });

    test(
      'declares route presentation decisions for the minimal app policy',
      () {
        final decisions = {
          for (final decision in module.routePresentationDecisions)
            decision.path: decision.presentation,
        };

        expect(decisions['/membership'], RoutePresentation.fullScreen);
        expect(decisions['/membership/fans'], RoutePresentation.redirect);
        expect(
          decisions['/membership/tier/:tierId'],
          RoutePresentation.fullHeightSheet,
        );
      },
    );

    test('tier detail route supports :tierId parameter', () {
      final tierRoute = module.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == '/membership/tier/:tierId',
      );

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
