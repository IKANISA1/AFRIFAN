
import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../shop_cart_provider.dart';
import '../widgets/checkout_bar.dart';
import '../widgets/product_card.dart';

/// "THE ARMOURY" — cinematic, editorial merchandise catalog.
///
/// Full-width product cards, category chips, floating checkout bar.
/// Dark midnight stadium aesthetic per Kinetic Football Authority.
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

  void _showSearchSheet(BuildContext context) {
    var query = '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final results = _products
                .where((product) {
                  final haystack = [
                    product['name']?.toString() ?? '',
                    product['category']?.toString() ?? '',
                    product['description']?.toString() ?? '',
                  ].join(' ').toLowerCase();
                  return haystack.contains(query.toLowerCase());
                })
                .toList(growable: false);

            return Container(
              decoration: BoxDecoration(
                color: ColorTokens.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border.all(color: ColorTokens.ghostBorder, width: 0.5),
              ),
              padding: EdgeInsets.fromLTRB(
                SpacingTokens.spacing6,
                SpacingTokens.spacing4,
                SpacingTokens.spacing6,
                MediaQuery.of(context).padding.bottom + SpacingTokens.spacing4,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    autofocus: true,
                    onChanged: (value) => setModalState(() => query = value),
                    decoration: const InputDecoration(
                      hintText: 'Search kits, scarves, and drops',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: results.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: SpacingTokens.spacing2),
                      itemBuilder: (context, index) {
                        final product = results[index];
                        final id = product['id']?.toString() ?? '';
                        final name = product['name']?.toString() ?? 'Product';
                        final category =
                            product['category']?.toString() ?? 'Merch';
                        final price =
                            (product['price'] as num?)?.toDouble() ?? 0;

                        return ClayCard(
                          onTap: () {
                            context.pop();
                            context.go('/shop/product/$id');
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name.toUpperCase(),
                                      style: GoogleFonts.barlowCondensed(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: ColorTokens.onSurface,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: SpacingTokens.spacing1,
                                    ),
                                    Text(
                                      category,
                                      style: TypographyTokens.bodySmall(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: SpacingTokens.spacing3),
                              Text(
                                'FRw ${price.toStringAsFixed(0)}',
                                style: GoogleFonts.barlowCondensed(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: ColorTokens.clubAccent,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
                  child: _buildTopBar(
                    context,
                    primary,
                    cartItemCount: cartItemCount,
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
                          style: GoogleFonts.inter(
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
                              style: GoogleFonts.barlowCondensed(
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
                          child: _CategoryChip(
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
                if (_isLoading) SliverToBoxAdapter(child: _buildLoadingState()),

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

  // ── Top Bar ──
  Widget _buildTopBar(
    BuildContext context,
    Color primary, {
    required int cartItemCount,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.spacing4,
        SpacingTokens.spacing3,
        SpacingTokens.spacing4,
        0,
      ),
      child: Row(
        children: [
          // Back button
          AfriIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
          const Spacer(),
          // Club text logo
          Text(
            RuntimeBranding.displayAppName.toUpperCase(),
            style: GoogleFonts.barlowCondensed(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: ColorTokens.onSurface,
              letterSpacing: 3.0,
            ),
          ),
          const Spacer(),
          // Search
          AfriIconButton(
            icon: Icons.tune_rounded,
            onTap: () => showAfriFilterSortSheet(
              context: context,
              title: 'Shop Filters',
              sortOptions: const [
                AfriFilterOption(value: 'newest', label: 'Newest'),
                AfriFilterOption(value: 'price_high', label: 'Price High'),
                AfriFilterOption(value: 'price_low', label: 'Price Low'),
              ],
              typeOptions: _categories
                  .where((category) => category != 'All')
                  .map(
                    (category) => AfriFilterOption(
                      value: category.toLowerCase(),
                      label: category.toUpperCase(),
                    ),
                  )
                  .toList(growable: false),
              showDateRange: false,
              showAmountRange: true,
              maxAmount: 250000,
            ),
          ),
          const SizedBox(width: 8),
          AfriIconButton(
            icon: Icons.search_rounded,
            onTap: () => _showSearchSheet(context),
          ),
          const SizedBox(width: 8),
          // Cart with badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              AfriIconButton(
                icon: Icons.shopping_bag_outlined,
                onTap: () => context.push('/shop/cart'),
              ),
              if (cartItemCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ColorTokens.background,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$cartItemCount',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: ColorTokens.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Loading State (skeleton cards) ──
  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.spacing6),
      child: Column(
        children: List.generate(3, (index) {
          return Container(
            margin: const EdgeInsets.only(bottom: SpacingTokens.spacing4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image skeleton
                Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: ColorTokens.surfaceContainerLow,
                        borderRadius: ShapeTokens.cardRadius,
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(
                      duration: 1200.ms,
                      color: ColorTokens.surfaceContainerHigh,
                    ),
                const SizedBox(height: SpacingTokens.spacing3),
                // Title skeleton
                Container(
                      height: 22,
                      width: 200,
                      decoration: BoxDecoration(
                        color: ColorTokens.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(
                      duration: 1200.ms,
                      delay: 100.ms,
                      color: ColorTokens.surfaceContainerHigh,
                    ),
                const SizedBox(height: SpacingTokens.spacing2),
                // Price skeleton
                Container(
                      height: 18,
                      width: 100,
                      decoration: BoxDecoration(
                        color: ColorTokens.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(
                      duration: 1200.ms,
                      delay: 200.ms,
                      color: ColorTokens.surfaceContainerHigh,
                    ),
              ],
            ),
          );
        }),
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
              style: GoogleFonts.barlowCondensed(
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

/// Category filter chip.
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color primary;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      onTap: onTap,
      scaleEnd: 0.96,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing5,
          vertical: SpacingTokens.spacing2,
        ),
        decoration: BoxDecoration(
          color: isSelected ? primary : Colors.transparent,
          borderRadius: ShapeTokens.buttonRadius,
          border: Border.all(
            color: isSelected ? primary : ColorTokens.ghostBorder,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? ColorTokens.onSurface
                  : ColorTokens.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}
