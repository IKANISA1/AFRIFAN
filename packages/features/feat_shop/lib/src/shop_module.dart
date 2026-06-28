import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

import 'screens/cart_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/shop_screen.dart';

/// Shop feature module — merchandise catalog.
/// Accessed via Home quick actions, NOT a bottom nav tab.
class ShopModule extends FeatureModule {
  @override
  String get featureKey => 'shop';

  // Tab route omitted; accessed via Home quick actions.

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/shop',
      name: 'shop',
      builder: (context, state) => const ShopScreen(),
      routes: [
        GoRoute(
          path: 'cart',
          name: 'shop-cart',
          builder: (context, state) => const CartScreen(),
        ),
        GoRoute(
          path: 'product/:productId',
          name: 'product-detail',
          builder: (context, state) => ProductDetailScreen(
            productId: state.pathParameters['productId']!,
          ),
        ),
      ],
    ),
  ];
}
