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
import '../widgets/shop_category_chip.dart';
import '../widgets/shop_loading_skeleton.dart';
import '../widgets/shop_search_sheet.dart';
import '../widgets/shop_top_bar.dart';

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
    _loadProducts();
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
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product['name'] ?? 'Product'} added to cart.'),
        backgroundColor: ColorTokens.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartItemCount = ref.watch(shopCartItemCountProvider);
    final cartTotal = ref.watch(shopCartTotalProvider);

    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: Stack(
        children: [
          // ── Main Scrollable Content ──
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: ShopTopBar(
                    cartItemCount: cartItemCount,
                    categories: _categories,
                    onSearchPressed: () => showShopSearchSheet(
                      context: context,
                      products: _products,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: AfriSectionHeader(
                    title: 'Club store',
                    subtitle:
                        '${_filteredProducts.length} items${_selectedCategory == 'All' ? '' : ' in $_selectedCategory'}',
                  ),
                ),

                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 44,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: SpacingTokens.spacing6,
                      ),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = cat == _selectedCategory;

                        return Padding(
                          padding: const EdgeInsets.only(
                            right: SpacingTokens.spacing2,
                          ),
                          child: ShopCategoryChip(
                            label: cat,
                            isSelected: isSelected,
                            primary: ColorTokens.clubPrimary,
                            onTap: () =>
                                setState(() => _selectedCategory = cat),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: SpacingTokens.spacing6),
                ),

                if (_isLoading)
                  const SliverToBoxAdapter(child: ShopLoadingSkeleton()),

                if (_error != null && !_isLoading)
                  SliverToBoxAdapter(
                    child: _ShopErrorState(
                      onRetry: () {
                        setState(() {
                          _isLoading = true;
                          _error = null;
                        });
                        _loadProducts();
                      },
                    ),
                  ),

                if (!_isLoading &&
                    _error == null &&
                    _filteredProducts.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.spacing6,
                    ),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: SpacingTokens.spacing4,
                            crossAxisSpacing: SpacingTokens.spacing3,
                            childAspectRatio: 0.62,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final product = _filteredProducts[index];
                        return RepaintBoundary(
                          child: ArmouryProductCard(
                            product: product,
                            index: index,
                            onTap: () {
                              final id = product['id']?.toString() ?? '';
                              context.push('/shop/product/$id');
                            },
                            onAddToCart: () => _addToCart(product),
                          ),
                        );
                      }, childCount: _filteredProducts.length),
                    ),
                  ),

                if (!_isLoading && _error == null && _filteredProducts.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SpacingTokens.spacing6,
                      ),
                      child: AfriStateView.empty(
                        title: 'No products found',
                        message:
                            'No active products match this category yet. Try another filter.',
                        compact: true,
                      ),
                    ),
                  ),

                // Bottom padding for checkout bar
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: cartItemCount > 0
                        ? SpacingTokens.spacing20 + 56
                        : SpacingTokens.spacing20,
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CheckoutBar(
              itemCount: cartItemCount,
              total: cartTotal.toDouble(),
              onCheckout: cartItemCount == 0
                  ? null
                  : () => context.push('/shop/cart'),
            ),
          ),
        ],
      ),
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
