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
