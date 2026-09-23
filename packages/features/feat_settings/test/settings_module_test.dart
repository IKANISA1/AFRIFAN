import 'package:core_router/core_router.dart';
import 'package:feat_settings/feat_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('SettingsModule', () {
    late SettingsModule module;

    setUp(() {
      module = SettingsModule();
    });

    test('featureKey is settings', () {
      expect(module.featureKey, 'settings');
    });

    test('has tab route at /settings', () {
      final tab = module.tabRoute;
      expect(tab.path, '/settings');
      expect(tab.label, isNotEmpty);
    });

    test('provides edit-profile sub-route', () {
      final subPaths = module.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(subPaths, contains('edit-profile'));
    });

    test('provides notifications sub-route', () {
      final subPaths = module.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(subPaths, contains('notifications'));
    });

    test('provides privacy sub-route', () {
      final subPaths = module.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(subPaths, contains('privacy'));
    });

    test('settings detail routes use shared pushed-route pages', () {
      final routes = module.routes.whereType<GoRoute>();
      for (final route in routes) {
        expect(route.pageBuilder, isNotNull, reason: route.path);
        expect(route.builder, isNull, reason: route.path);
      }
    });

    test(
      'declares route presentation decisions for the minimal app policy',
      () {
        final decisions = {
          for (final decision in module.routePresentationDecisions)
            decision.path: decision.presentation,
        };

        expect(decisions['/settings'], RoutePresentation.fullScreen);
        expect(
          decisions['/settings/edit-profile'],
          RoutePresentation.fullHeightSheet,
        );
        expect(
          decisions['/settings/notifications'],
          RoutePresentation.fullHeightSheet,
        );
        expect(
          decisions['/settings/privacy'],
          RoutePresentation.fullHeightSheet,
        );
      },
    );

    test('does not keep legacy standalone profile setup routes', () {
      final standalonePaths = module.standaloneRoutes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(standalonePaths, isEmpty);
    });

    test('isEnabled defaults to true', () {
      expect(module.isEnabled({}), isTrue);
    });

    test('isEnabled returns false when explicitly disabled', () {
      expect(module.isEnabled({'settings': false}), isFalse);
    });
  });
}
