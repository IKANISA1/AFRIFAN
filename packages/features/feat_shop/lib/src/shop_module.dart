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
          pageBuilder: (context, state) =>
              afriSheetPage(state, const CartScreen(), fullHeight: true),
        ),
        GoRoute(
          path: 'product/:productId',
          name: 'product-detail',
          pageBuilder: (context, state) => afriSheetPage(
            state,
            ProductDetailScreen(productId: state.pathParameters['productId']!),
            fullHeight: true,
          ),
        ),
      ],
    ),
  ];

  @override
  List<RoutePresentationDecision> get routePresentationDecisions => const [
    RoutePresentationDecision(
      path: '/shop',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      rationale: 'Merchandise browsing is a primary revenue surface.',
    ),
    RoutePresentationDecision(
      path: '/shop/product/:productId',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'convert to sheet',
      targetPath: '/shop',
      rationale: 'Product details should feel like quick commerce.',
    ),
    RoutePresentationDecision(
      path: '/shop/cart',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'convert to sheet',
      targetPath: '/shop',
      rationale: 'Cart review is transactional context inside Shop.',
    ),
  ];
}
