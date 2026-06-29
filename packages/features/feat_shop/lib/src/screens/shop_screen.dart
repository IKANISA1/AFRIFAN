import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shop_cart_provider.dart';
import '../widgets/checkout_bar.dart';
import '../widgets/product_card.dart';
import '../widgets/shop_loading_skeleton.dart';
import '../widgets/shop_search_sheet.dart';

/// Shop catalog with compact filters and a product-first grid.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  static const _productsTable = 'shop_products';

  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  String? _error;
  String _selectedCategory = 'All';
  final List<String> _categories = ['All'];

  @override
  void initState() {
    super.initState();
    unawaited(_loadProducts());
  }

  Future<void> _loadProducts() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final user = ref.read(currentUserProvider);
      final resolver = ClubScopeResolver(client: client);
      final scope = await resolver.requireResolved(user?.clubId);
      var query = client.from(_productsTable).select().eq('is_active', true);
      query = resolver.apply(query, scope);
      final response = await query.order('sort_order', ascending: true);

      if (mounted) {
        final products = List<Map<String, dynamic>>.from(response);
        final categories = <String>{'All'};
        for (final p in products) {
          final cat = p['category']?.toString();
          if (cat != null && cat.isNotEmpty) {
            categories.add(cat);
          }
        }

        setState(() {
          _products = products;
          _categories.clear();
          _categories.addAll(categories);
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load products';
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    if (_selectedCategory == 'All') return _products;
    return _products
        .where((p) => p['category']?.toString() == _selectedCategory)
        .toList();
  }

  void _addToCart(Map<String, dynamic> product) {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.go('/onboarding');
      return;
    }

    ref
        .read(shopCartProvider.notifier)
        .addRawProduct(product, partnerId: user.clubId);
    unawaited(HapticFeedback.lightImpact());
    AfriToast.success(
      context,
      '${product['name'] ?? 'Product'} added to cart.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartItemCount = ref.watch(shopCartItemCountProvider);
    final cartTotal = ref.watch(shopCartTotalProvider);

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text('Store', style: TypographyTokens.headlineSmall()),
        actions: [
          AfriIconButton(
            icon: AfriIcons.search,
            onTap: () =>
                showShopSearchSheet(context: context, products: _products),
            tooltip: 'Search products',
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              AfriIconButton(
                icon: AfriIcons.cart,
                onTap: () => unawaited(context.push('/shop/cart')),
                tooltip: 'View cart',
              ),
              if (cartItemCount > 0)
                Positioned(
                  right: SpacingTokens.spacing2,
                  top: SpacingTokens.spacing2,
                  child: Container(
                    padding: const EdgeInsets.all(SpacingTokens.spacing1),
                    decoration: BoxDecoration(
                      color: ColorTokens.clubAccent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: SpacingTokens.spacing5,
                      minHeight: SpacingTokens.spacing5,
                    ),
                    child: Text(
                      '$cartItemCount',
                      style: TypographyTokens.labelSmall(
                        ColorTokens.onDark,
                      ).copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: SpacingTokens.spacing4),
        ],
      ),
      body: Stack(
        children: [
          // ── Main Scrollable Content ──
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                ShopCatalogSlivers(
                  isLoading: _isLoading,
                  error: _error,
                  products: _products,
                  filteredProducts: _filteredProducts,
                  categories: _categories,
                  selectedCategory: _selectedCategory,
                  onCategorySelected: (category) =>
                      setState(() => _selectedCategory = category),
                  onRetry: () {
                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });
                    unawaited(_loadProducts());
                  },
                  onProductTap: (product) {
                    final id = product['id']?.toString() ?? '';
                    unawaited(context.push('/shop/product/$id'));
                  },
                  onAddToCart: _addToCart,
                ),

                // Bottom padding for checkout bar
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: cartItemCount > 0
                        ? SpacingTokens.spacing20 + SpacingTokens.spacing20
                        : SpacingTokens.spacing20,
                  ),
                ),
              ],
            ),
          ),

          if (cartItemCount > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CheckoutBar(
                itemCount: cartItemCount,
                total: cartTotal.toDouble(),
                onCheckout: () => context.push('/shop/cart'),
              ),
            ),
        ],
      ),
    );
  }
}

class ShopCatalogSlivers extends StatelessWidget {
  const ShopCatalogSlivers({
    super.key,
    required this.isLoading,
    required this.error,
    required this.products,
    required this.filteredProducts,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onRetry,
    required this.onProductTap,
    required this.onAddToCart,
  });

  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> filteredProducts;
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onRetry;
  final ValueChanged<Map<String, dynamic>> onProductTap;
  final ValueChanged<Map<String, dynamic>> onAddToCart;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SliverToBoxAdapter(child: ShopLoadingSkeleton());
    }

    if (error != null) {
      return SliverToBoxAdapter(child: _ShopErrorState(onRetry: onRetry));
    }

    if (products.isEmpty || filteredProducts.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: AfriSectionHeader(
            title: 'Club store',
            subtitle: '${filteredProducts.length} items available now.',
            padding: const EdgeInsets.fromLTRB(
              SpacingTokens.spacing6,
              SpacingTokens.spacing4,
              SpacingTokens.spacing6,
              SpacingTokens.spacing4,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: SpacingTokens.spacing10,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.spacing6,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = cat == selectedCategory;

                return Padding(
                  padding: const EdgeInsets.only(right: SpacingTokens.spacing2),
                  child: AfriChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (_) => onCategorySelected(cat),
                    selectedColor: ColorTokens.clubAccent.withValues(
                      alpha: 0.2,
                    ),
                    labelStyle: TypographyTokens.labelSmall(
                      isSelected
                          ? ColorTokens.clubAccent
                          : ColorTokens.onSurfaceVariant,
                    ),
                    backgroundColor: ColorTokens.transparent,
                    side: BorderTokens.side(
                      color: isSelected
                          ? ColorTokens.clubAccent
                          : ColorTokens.ghostBorder,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        ShapeTokens.radiusFull,
                      ),
                    ),
                    showCheckmark: false,
                  ),
                );
              },
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: SpacingTokens.spacing6),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing6,
          ),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: SpacingTokens.spacing4,
              crossAxisSpacing: SpacingTokens.spacing3,
              childAspectRatio: 0.65,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final product = filteredProducts[index];
              return RepaintBoundary(
                child: ArmouryProductCard(
                  product: product,
                  index: index,
                  onTap: () => onProductTap(product),
                  onAddToCart: () => onAddToCart(product),
                ),
              );
            }, childCount: filteredProducts.length),
          ),
        ),
      ],
    );
  }
}

class _ShopErrorState extends StatelessWidget {
  const _ShopErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing8),
      child: AfriStateView.offline(
        title: 'Store unavailable',
        message: 'Could not load merchandise right now.',
        actionLabel: 'Retry',
        onAction: onRetry,
      ),
    );
  }
}
