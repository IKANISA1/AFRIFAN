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

    test('is the fourth primary supporter tab', () {
      expect(module.tabRoute, isNotNull);
      expect(module.tabRoute.path, '/membership');
      expect(module.tabRoute.label, 'Membership');
    });

    test('registers membership child routes', () {
      final paths = module.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toList();

      expect(paths, hasLength(2));
      expect(paths, contains('fans'));
      expect(paths, contains('tier/:tierId'));
    });

    test('/membership/fans route is a compatibility redirect', () {
      final route = module.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == 'fans',
      );

      expect(route.name, 'membership-fans');
      expect(route.redirect, isNotNull);
      expect(route.builder, isNull);
      expect(route.pageBuilder, isNull);
    });

    test('pushed membership routes use shared route pages', () {
      for (final route in module.routes.whereType<GoRoute>().where(
        (r) => r.path == 'tier/:tierId',
      )) {
        expect(route.pageBuilder, isNotNull, reason: route.path);
        expect(route.builder, isNull, reason: route.path);
      }
    });

    test('membership tab root keeps standard builder', () {
      expect(module.tabRoute.builder, isNotNull);
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
        (r) => r.path == 'tier/:tierId',
      );

      // Route exists and accepts tierId param
      expect(tierRoute.path, 'tier/:tierId');
    });

    test('isEnabled defaults to true when key is absent', () {
      expect(module.isEnabled({}), isTrue);
    });

    test('remains enabled as a governed primary navigation anchor', () {
      expect(module.isEnabled({'membership': false}), isTrue);
      expect(
        module.isEnabledForConfig(
          configSnapshot: <String, dynamic>{
            'features': <Map<String, dynamic>>[
              <String, dynamic>{
                'feature_key': 'membership',
                'is_enabled': false,
              },
            ],
          },
        ),
        isTrue,
      );
    });

    test('standaloneRoutes is empty by default', () {
      expect(module.standaloneRoutes, isEmpty);
    });
  });
}
