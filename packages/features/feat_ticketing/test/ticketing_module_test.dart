import 'package:core_router/core_router.dart';
import 'package:feat_ticketing/feat_ticketing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Unit tests for the Ticketing module — route structure and module configuration.
void main() {
  // ═══════════════════════════════════════════════════════════
  // TicketingModule
  // ═══════════════════════════════════════════════════════════

  group('TicketingModule', () {
    late TicketingModule module;

    setUp(() {
      module = TicketingModule();
    });

    test('featureKey is ticketing', () {
      expect(module.featureKey, 'ticketing');
    });

    test('has no tab route (not a bottom nav item)', () {
      expect(module.tabRoute, isNull);
    });

    test('registers correct top-level routes', () {
      final paths = module.routes
          .whereType<GoRoute>()
          .map((route) => route.path)
          .toList();

      expect(paths, contains('/tickets'));
      expect(paths, contains('/my-tickets'));
      expect(paths, contains('/e-ticket/:id'));
    });

    test('/tickets has match detail and seat map sub-routes', () {
      final ticketsRoute = module.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == '/tickets',
      );
      final subPaths = ticketsRoute.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toList();

      expect(subPaths, contains('detail/:id'));
      expect(subPaths, contains('map/:id'));
    });

    test('detail routes use shared pushed-route pages', () {
      final ticketsRoute = module.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == '/tickets',
      );
      final subRoutes = ticketsRoute.routes.whereType<GoRoute>().toList();

      for (final route in <GoRoute>[
        ...subRoutes.where((route) => route.path == 'detail/:id'),
        ...subRoutes.where((route) => route.path == 'map/:id'),
        module.routes.whereType<GoRoute>().firstWhere(
          (route) => route.path == '/e-ticket/:id',
        ),
      ]) {
        expect(route.pageBuilder, isNotNull, reason: route.path);
        expect(route.builder, isNull, reason: route.path);
      }
    });

    test('only ticket list keeps a standard builder', () {
      final ticketsRoute = module.routes.whereType<GoRoute>().firstWhere(
        (route) => route.path == '/tickets',
      );
      final myTicketsRoute = module.routes.whereType<GoRoute>().firstWhere(
        (route) => route.path == '/my-tickets',
      );

      expect(ticketsRoute.builder, isNotNull);
      expect(ticketsRoute.pageBuilder, isNull);
      expect(myTicketsRoute.redirect, isNotNull);
      expect(myTicketsRoute.pageBuilder, isNull);
      expect(myTicketsRoute.builder, isNull);
    });

    test(
      'declares route presentation decisions for the minimal app policy',
      () {
        final decisions = {
          for (final decision in module.routePresentationDecisions)
            decision.path: decision.presentation,
        };

        expect(decisions['/tickets'], RoutePresentation.fullScreen);
        expect(
          decisions['/tickets/detail/:id'],
          RoutePresentation.fullHeightSheet,
        );
        expect(decisions['/my-tickets'], RoutePresentation.redirect);
        expect(decisions['/e-ticket/:id'], RoutePresentation.fullScreen);
      },
    );

    test('isEnabled returns true when ticketing feature is present', () {
      expect(module.isEnabled({'ticketing': true}), isTrue);
    });

    test('isEnabled defaults to true when key is absent (always-on)', () {
      // FeatureModule defaults missing keys to true
      expect(module.isEnabled({}), isTrue);
    });

    test('isEnabled returns false when explicitly disabled', () {
      expect(module.isEnabled({'ticketing': false}), isFalse);
    });
  });
}
