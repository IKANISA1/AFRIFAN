import 'package:feat_shop/src/screens/shop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShopCatalogSlivers', () {
    testWidgets('hides catalog section when products are empty', (
      tester,
    ) async {
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
            onRetry: () {},
            onProductTap: (_) {},
            onAddToCart: (_) {},
          ),
        ),
      );

      expect(find.text('Club store'), findsNothing);
      expect(find.text('No products found'), findsNothing);
      expect(find.textContaining('No items match'), findsNothing);
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
    });
  });
}

class _CatalogHarness extends StatelessWidget {
  const _CatalogHarness({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(body: CustomScrollView(slivers: [child])),
    );
  }
}
