import 'package:feat_home/feat_home.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeModule', () {
    late HomeModule module;

    setUp(() {
      module = HomeModule();
    });

    test('featureKey is home', () {
      expect(module.featureKey, 'home');
    });

    test('has tab route at /home', () {
      final tab = module.tabRoute;
      expect(tab, isNotNull);
      expect(tab!.path, '/home');
      expect(tab.label, isNotEmpty);
    });

    test('isEnabled defaults to true', () {
      expect(module.isEnabled({}), isTrue);
    });

    test('routes are empty (home is just the tab screen)', () {
      expect(module.routes, isEmpty);
    });

    test('standaloneRoutes is empty', () {
      expect(module.standaloneRoutes, isEmpty);
    });
  });
}
