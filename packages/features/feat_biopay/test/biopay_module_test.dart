import 'package:feat_biopay/feat_biopay.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('BioPayModule', () {
    late BioPayModule module;

    setUp(() {
      module = BioPayModule();
    });

    test('featureKey is biopay', () {
      expect(module.featureKey, 'biopay');
    });

    test('has tab route at /biopay', () {
      final tab = module.tabRoute;
      expect(tab, isNotNull);
      expect(tab!.path, '/biopay');
      expect(tab.label, isNotEmpty);
    });

    test('provides profile sub-route', () {
      final subPaths = module.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(subPaths, contains('profile'));
    });

    test('provides register sub-route', () {
      final subPaths = module.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(subPaths, contains('register'));
    });

    test('provides review sub-route', () {
      final subPaths = module.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(subPaths, contains('review'));
    });

    test('provides result sub-route', () {
      final subPaths = module.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(subPaths, contains('result'));
    });

    test('provides recovery sub-route', () {
      final subPaths = module.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(subPaths, contains('recovery'));
    });

    test('provides scan sub-route', () {
      final subPaths = module.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(subPaths, contains('scan'));
    });

    test('provides qr sub-route', () {
      final subPaths = module.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(subPaths, contains('qr'));
    });

    test('provides nfc sub-route', () {
      final subPaths = module.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(subPaths, contains('nfc'));
    });

    test('has at least 8 sub-routes', () {
      expect(module.routes.whereType<GoRoute>().length, greaterThanOrEqualTo(8));
    });

    test('isEnabled defaults to true when key is absent', () {
      expect(module.isEnabled({}), isTrue);
    });

    test('isEnabled returns false when explicitly disabled', () {
      expect(module.isEnabled({'biopay': false}), isFalse);
    });

    test('isEnabled returns true when explicitly enabled', () {
      expect(module.isEnabled({'biopay': true}), isTrue);
    });
  });
}
