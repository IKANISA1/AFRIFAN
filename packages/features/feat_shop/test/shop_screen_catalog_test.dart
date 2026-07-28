import 'package:core_theme/core_theme.dart';
import 'package:feat_shop/src/screens/shop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_support/touch_target_audit.dart';

void main() {
  group('ShopCatalogSlivers', () {
    testWidgets('shows an empty state when products are empty', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _CatalogHarness(
          child: ShopCatalogSlivers(
            isLoading: false,
            error: null,
            products: const [],
            filteredProducts: const [],
            categories: const ['All'],
            selectedCategory: 'All',
            onCategorySelected: (_) {},
            onRetry: () => retried = true,
            onProductTap: (_) {},
            onAddToCart: (_) {},
          ),
        ),
      );

      expect(find.text('Club store'), findsNothing);
      expect(find.text('No products available'), findsOneWidget);
      expect(find.textContaining('Official merchandise'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('shows a filter empty state with a clear action', (
      tester,
    ) async {
      String? selectedCategory;
      final products = [
        {
          'id': 'jersey-home',
          'name': 'Home Jersey',
          'category': 'Jerseys',
          'price': 25000,
        },
      ];

      await tester.pumpWidget(
        _CatalogHarness(
          child: ShopCatalogSlivers(
            isLoading: false,
            error: null,
            products: products,
            filteredProducts: const [],
            categories: const ['All', 'Jerseys', 'Scarves'],
            selectedCategory: 'Scarves',
            onCategorySelected: (category) => selectedCategory = category,
            onRetry: () {},
            onProductTap: (_) {},
            onAddToCart: (_) {},
          ),
        ),
      );

      expect(find.text('No products in Scarves'), findsOneWidget);
      expect(find.text('Show all'), findsOneWidget);
      await tester.tap(find.text('Show all'));
      expect(selectedCategory, 'All');
    });

    testWidgets('renders catalog section when products are present', (
      tester,
    ) async {
      final products = [
        {
          'id': 'jersey-home',
          'name': 'Home Jersey',
          'category': 'Jerseys',
          'price': 25000,
        },
      ];

      await tester.pumpWidget(
        _CatalogHarness(
          child: ShopCatalogSlivers(
            isLoading: false,
            error: null,
            products: products,
            filteredProducts: products,
            categories: const ['All', 'Jerseys'],
            selectedCategory: 'All',
            onCategorySelected: (_) {},
            onRetry: () {},
            onProductTap: (_) {},
            onAddToCart: (_) {},
          ),
        ),
      );

      expect(find.text('Club store'), findsOneWidget);
      expect(find.text('Home Jersey'), findsOneWidget);
      expect(find.text('No products found'), findsNothing);
      expectTapTargetsMeetMinimum(tester);
    });

    testWidgets('keeps cached products visible with an explicit stale label', (
      tester,
    ) async {
      final products = [
        {
          'id': 'jersey-home',
          'name': 'Home Jersey',
          'category': 'Jerseys',
          'price': 25000,
        },
      ];

      await tester.pumpWidget(
        _CatalogHarness(
          child: ShopCatalogSlivers(
            isLoading: false,
            isStale: true,
            error: null,
            products: products,
            filteredProducts: products,
            categories: const ['All', 'Jerseys'],
            selectedCategory: 'All',
            onCategorySelected: (_) {},
            onRetry: () {},
            onProductTap: (_) {},
            onAddToCart: (_) {},
          ),
        ),
      );

      expect(find.text('Home Jersey'), findsOneWidget);
      expect(find.text('Saved store content'), findsOneWidget);
      expect(
        find.text(
          'Inventory may be out of date. '
          'Reconnect to refresh before checkout.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('keeps cached products visible during a slow refresh', (
      tester,
    ) async {
      final products = [
        {
          'id': 'jersey-home',
          'name': 'Home Jersey',
          'category': 'Jerseys',
          'price': 25000,
        },
      ];

      await tester.pumpWidget(
        _CatalogHarness(
          child: ShopCatalogSlivers(
            isLoading: false,
            isRefreshing: true,
            error: null,
            products: products,
            filteredProducts: products,
            categories: const ['All', 'Jerseys'],
            selectedCategory: 'All',
            onCategorySelected: (_) {},
            onRetry: () {},
            onProductTap: (_) {},
            onAddToCart: (_) {},
          ),
        ),
      );

      expect(find.text('Home Jersey'), findsOneWidget);
      expect(find.text('Refreshing store'), findsOneWidget);
      expect(find.text('Current inventory is being checked.'), findsOneWidget);
    });
  });
}

class _CatalogHarness extends StatelessWidget {
  const _CatalogHarness({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ClubTheme.from(ClubConfig.fallback()),
      home: Scaffold(body: CustomScrollView(slivers: [child])),
    );
  }
}
