import 'package:core_l10n/core_l10n.dart';
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

    for (final textScale in [1.0, 2.0]) {
      testWidgets(
        'editorial card separates open and add at ${textScale}x text',
        (tester) async {
          tester.view.physicalSize = const Size(320, 720);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = textScale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          var opened = 0;
          var added = 0;
          final products = [
            <String, dynamic>{
              'id': 'jersey-home',
              'name': 'Home Match Jersey',
              'subtitle': 'Official supporter edition',
              'category': 'Jerseys',
              'price': 25000,
            },
          ];
          await tester.pumpWidget(
            _CatalogHarness(
              child: ShopCatalogSlivers(
                isLoading: false,
                products: products,
                filteredProducts: products,
                categories: const ['All', 'Jerseys'],
                selectedCategory: 'All',
                onCategorySelected: (_) {},
                onRetry: () {},
                onProductTap: (_) => opened++,
                onAddToCart: (_) => added++,
              ),
            ),
          );
          await tester.ensureVisible(find.text('Home Match Jersey'));
          await tester.tap(find.text('Home Match Jersey'));
          await tester.pumpAndSettle();
          expect(opened, 1);
          expect(added, 0);
          final add = find.byKey(
            const ValueKey<String>('shop-add-jersey-home'),
          );
          await tester.ensureVisible(add);
          await tester.pumpAndSettle();
          await tester.tap(add);
          await tester.pumpAndSettle();
          expect(added, 1);
          expect(opened, 1);
          expect(tester.takeException(), isNull);
          expectTapTargetsMeetMinimum(tester);
        },
      );
    }

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

    for (final locale in const <Locale>[Locale('en')]) {
      testWidgets(
        'renders localized empty and recovery journey in ${locale.languageCode}',
        (tester) async {
          var retried = false;
          await tester.pumpWidget(
            _CatalogHarness(
              locale: locale,
              child: ShopCatalogSlivers(
                isLoading: false,
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

          final l10n = lookupAfriLocalizations(locale);
          expect(find.text(l10n.shopNoProductsTitle), findsOneWidget);
          expect(find.text(l10n.shopNoProductsMessage), findsOneWidget);
          await tester.tap(find.text(l10n.shopRetry));
          expect(retried, isTrue);
          expect(find.text('No products available'), findsOneWidget);
        },
      );
    }
  });
}

class _CatalogHarness extends StatelessWidget {
  const _CatalogHarness({
    required this.child,
    this.locale = const Locale('en'),
  });

  final Widget child;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ClubTheme.from(ClubConfig.fallback()),
      home: AfriLocalizationsScope(
        locale: locale,
        child: Scaffold(body: CustomScrollView(slivers: [child])),
      ),
    );
  }
}
