import 'package:core_router/core_router.dart';
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
        rootRoute = module.routes.whereType<GoRoute>().firstWhere(
          (r) => r.path == '/shop',
        );
      });

      test('has cart sub-route', () {
        final subPaths = rootRoute.routes
            .whereType<GoRoute>()
            .map((r) => r.path)
            .toSet();
        expect(subPaths, contains('cart'));
      });

      test('has authoritative order history destination', () {
        final orders = rootRoute.routes.whereType<GoRoute>().singleWhere(
          (route) => route.path == 'orders',
        );
        expect(orders.name, 'shop-orders');
        expect(orders.builder, isNotNull);
      });

      test('has product/:productId sub-route', () {
        final subPaths = rootRoute.routes
            .whereType<GoRoute>()
            .map((r) => r.path)
            .toSet();
        expect(subPaths, contains('product/:productId'));
      });

      test('product detail uses shared pushed-route page', () {
        final route = rootRoute.routes.whereType<GoRoute>().firstWhere(
          (r) => r.path == 'product/:productId',
        );

        expect(route.pageBuilder, isNotNull);
        expect(route.builder, isNull);
      });

      test('shop root keeps a standard builder and cart is a sheet page', () {
        final cartRoute = rootRoute.routes.whereType<GoRoute>().firstWhere(
          (r) => r.path == 'cart',
        );

        expect(rootRoute.builder, isNotNull);
        expect(rootRoute.pageBuilder, isNull);
        expect(cartRoute.pageBuilder, isNotNull);
        expect(cartRoute.builder, isNull);
      });
    });

    test(
      'declares route presentation decisions for the minimal app policy',
      () {
        final decisions = {
          for (final decision in module.routePresentationDecisions)
            decision.path: decision.presentation,
        };

        expect(decisions['/shop'], RoutePresentation.fullScreen);
        expect(
          decisions['/shop/product/:productId'],
          RoutePresentation.fullHeightSheet,
        );
        expect(decisions['/shop/cart'], RoutePresentation.fullHeightSheet);
        expect(decisions['/shop/orders'], RoutePresentation.fullScreen);
      },
    );

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
