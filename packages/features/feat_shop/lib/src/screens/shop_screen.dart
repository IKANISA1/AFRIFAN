import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shop_cart_provider.dart';
import '../widgets/checkout_bar.dart';
import '../widgets/product_card.dart';
import '../widgets/shop_category_chip.dart';
import '../widgets/shop_loading_skeleton.dart';
import '../widgets/shop_search_sheet.dart';
import '../widgets/shop_top_bar.dart';

/// "THE ARMOURY" — cinematic, editorial merchandise catalog.
///
/// Full-width product cards, category chips, floating checkout bar.
/// Dark midnight stadium aesthetic per Tactile Monolith.
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
      final response = await client
          .from(_productsTable)
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

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
    final primary = Theme.of(context).colorScheme.primary;
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
                // ── Top Bar (Back + Search + Cart) ──
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

                // ── Breadcrumb ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SpacingTokens.spacing6,
                      SpacingTokens.spacing2,
                      SpacingTokens.spacing6,
                      0,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.home_rounded,
                          size: 14,
                          color: ColorTokens.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '> SHOP',
                          style: TypographyTokens.editorialFont(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: ColorTokens.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── "THE ARMOURY" Title ──
                SliverToBoxAdapter(
                  child:
                      Padding(
                            padding: const EdgeInsets.fromLTRB(
                              SpacingTokens.spacing6,
                              SpacingTokens.spacing4,
                              SpacingTokens.spacing6,
                              SpacingTokens.spacing3,
                            ),
                            child: Text(
                              'THE ARMOURY',
                              style: TypographyTokens.monolithFont(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: ColorTokens.onSurface,
                                letterSpacing: 1.0,
                                height: 1.0,
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 500.ms, curve: Curves.easeOut)
                          .slideX(begin: -0.03, end: 0, duration: 500.ms),
                ),

                // ── Category Chips ──
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
                            label: cat.toUpperCase(),
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

                // ── Loading State ──
                if (_isLoading)
                  const SliverToBoxAdapter(child: ShopLoadingSkeleton()),

                // ── Error State ──
                if (_error != null && !_isLoading)
                  SliverToBoxAdapter(child: _buildErrorState(primary)),

                // ── Products List (full-width cards) ──
                if (!_isLoading &&
                    _error == null &&
                    _filteredProducts.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.spacing6,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final product = _filteredProducts[index];
                        return RepaintBoundary(
                          child: ArmouryProductCard(
                            product: product,
                            index: index,
                            onTap: () {
                              final id = product['id']?.toString() ?? '';
                              context.go('/shop/product/$id');
                            },
                            onAddToCart: () => _addToCart(product),
                          ),
                        );
                      }, childCount: _filteredProducts.length),
                    ),
                  ),

                // §2.3 LOCKED — no empty state card. Render nothing.
                if (!_isLoading && _error == null && _filteredProducts.isEmpty)
                  const SliverToBoxAdapter(child: SizedBox.shrink()),

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

          // ── Floating Checkout Bar ──
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

  // ── Error State ──
  Widget _buildErrorState(Color primary) {
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing10),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 56,
              color: primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              'CONNECTION ERROR',
              style: TypographyTokens.monolithFont(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: ColorTokens.onSurface,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              'Could not load merchandise. Try again.',
              textAlign: TextAlign.center,
              style: TypographyTokens.bodyMedium(),
            ),
            const SizedBox(height: SpacingTokens.spacing6),
            ClaymorphicButton(
              label: 'RETRY',
              icon: Icons.refresh_rounded,
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadProducts();
              },
            ),
          ],
        ),
      ),
    );
  }
}
