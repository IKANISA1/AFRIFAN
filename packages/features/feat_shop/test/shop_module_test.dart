import 'package:feat_shop/feat_shop.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('ShopModule', () {
    late ShopModule module;

    setUp(() {
      module = ShopModule();
    });

    test('featureKey is shop', () {
      expect(module.featureKey, 'shop');
    });

    test('has no tab route (accessed via Home quick actions)', () {
      expect(module.tabRoute, isNull);
    });

    test('root route is /shop', () {
      final rootPaths = module.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(rootPaths, contains('/shop'));
    });

    group('/shop sub-routes', () {
      late GoRoute rootRoute;

      setUp(() {
        rootRoute = module.routes
            .whereType<GoRoute>()
            .firstWhere((r) => r.path == '/shop');
      });

      test('has cart sub-route', () {
        final subPaths = rootRoute.routes
            .whereType<GoRoute>()
            .map((r) => r.path)
            .toSet();
        expect(subPaths, contains('cart'));
      });

      test('has product/:productId sub-route', () {
        final subPaths = rootRoute.routes
            .whereType<GoRoute>()
            .map((r) => r.path)
            .toSet();
        expect(subPaths, contains('product/:productId'));
      });
    });

    test('isEnabled defaults to true when key is absent', () {
      expect(module.isEnabled({}), isTrue);
    });

    test('isEnabled returns false when explicitly disabled', () {
      expect(module.isEnabled({'shop': false}), isFalse);
    });

    test('isEnabled returns true when explicitly enabled', () {
      expect(module.isEnabled({'shop': true}), isTrue);
    });
  });
}
