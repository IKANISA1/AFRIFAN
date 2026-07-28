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

typedef ShopProductLoader = Future<List<Map<String, dynamic>>> Function();

enum ShopCatalogFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class ShopCatalogFailure implements Exception {
  const ShopCatalogFailure(this.kind);

  final ShopCatalogFailureKind kind;

  static ShopCatalogFailure fromError(Object error) {
    if (error is ShopCatalogFailure) {
      return error;
    }
    if (error is TimeoutException) {
      return const ShopCatalogFailure(ShopCatalogFailureKind.securityTimeout);
    }

    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const ShopCatalogFailure(ShopCatalogFailureKind.permissionDenied);
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision')) {
      return const ShopCatalogFailure(ShopCatalogFailureKind.conflict);
    }
    return const ShopCatalogFailure(ShopCatalogFailureKind.unknown);
  }

  @override
  String toString() => 'ShopCatalogFailure(${kind.name})';
}

/// Shop catalog with compact filters and a product-first grid.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({
    super.key,
    this.productLoader,
    this.loadTimeout = const Duration(seconds: 12),
    this.autofocusProductId,
  });

  final ShopProductLoader? productLoader;
  final Duration loadTimeout;
  final String? autofocusProductId;

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  static const _productsTable = 'shop_products';

  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isStale = false;
  ShopCatalogFailure? _failure;
  String _selectedCategory = 'All';
  final List<String> _categories = ['All'];
  late bool _wasOnline;

  @override
  void initState() {
    super.initState();
    _wasOnline = ConnectivityService.isOnline;
    ConnectivityService.onlineNotifier.addListener(_handleConnectivityChange);
    unawaited(_loadProducts());
  }

  @override
  void dispose() {
    ConnectivityService.onlineNotifier.removeListener(
      _handleConnectivityChange,
    );
    super.dispose();
  }

  void _handleConnectivityChange() {
    final isOnline = ConnectivityService.isOnline;
    final restored = !_wasOnline && isOnline;
    _wasOnline = isOnline;

    if (!mounted) return;
    if (!isOnline && _products.isNotEmpty) {
      setState(() => _isStale = true);
    } else if (restored) {
      unawaited(_loadProducts());
    }
  }

  Future<void> _loadProducts() async {
    if (!ConnectivityService.isOnline) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _isStale = _products.isNotEmpty;
        _failure = _products.isEmpty
            ? const ShopCatalogFailure(ShopCatalogFailureKind.offline)
            : null;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isRefreshing = _products.isNotEmpty;
        if (_products.isEmpty) {
          _isLoading = true;
        }
        _failure = null;
      });
    }

    try {
      final productRequest = widget.productLoader == null
          ? _fetchProducts()
          : widget.productLoader!();
      final products = await productRequest.timeout(widget.loadTimeout);

      if (mounted) {
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
          _isRefreshing = false;
          _isStale = false;
          _failure = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          _isStale = _products.isNotEmpty;
          _failure = _products.isEmpty
              ? ShopCatalogFailure.fromError(error)
              : null;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchProducts() async {
    final client = ref.read(supabaseClientProvider);
    final user = ref.read(currentUserProvider);
    final resolver = ClubScopeResolver(client: client);
    final scope = await resolver.requireResolved(user?.clubId);
    var query = client.from(_productsTable).select().eq('is_active', true);
    query = resolver.apply(query, scope);
    final response = await query.order('sort_order', ascending: true);
    return List<Map<String, dynamic>>.from(response);
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

    return AfriScreenScaffold(
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
      scrollable: false,
      child: Stack(
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
                  isRefreshing: _isRefreshing,
                  isStale: _isStale,
                  isOnline: ConnectivityService.isOnline,
                  failure: _failure,
                  products: _products,
                  filteredProducts: _filteredProducts,
                  categories: _categories,
                  selectedCategory: _selectedCategory,
                  onCategorySelected: (category) =>
                      setState(() => _selectedCategory = category),
                  onRetry: () {
                    unawaited(_loadProducts());
                  },
                  onProductTap: (product) {
                    final id = product['id']?.toString() ?? '';
                    unawaited(context.push('/shop/product/$id'));
                  },
                  onAddToCart: _addToCart,
                  autofocusProductId: widget.autofocusProductId,
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
    this.isRefreshing = false,
    this.isStale = false,
    this.isOnline = true,
    this.failure,
    this.error,
    required this.products,
    required this.filteredProducts,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onRetry,
    required this.onProductTap,
    required this.onAddToCart,
    this.autofocusProductId,
  });

  final bool isLoading;
  final bool isRefreshing;
  final bool isStale;
  final bool isOnline;
  final ShopCatalogFailure? failure;

  /// Legacy direct-harness seam retained for catalog layout tests.
  final String? error;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> filteredProducts;
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onRetry;
  final ValueChanged<Map<String, dynamic>> onProductTap;
  final ValueChanged<Map<String, dynamic>> onAddToCart;
  final String? autofocusProductId;

  @override
  Widget build(BuildContext context) {
    final usesLargeTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final effectiveFailure =
        failure ??
        (error == null
            ? null
            : const ShopCatalogFailure(ShopCatalogFailureKind.unknown));

    if (isLoading) {
      return const SliverToBoxAdapter(child: ShopLoadingSkeleton());
    }

    if (effectiveFailure != null) {
      return SliverToBoxAdapter(
        child: _ShopFailureState(
          failure: effectiveFailure,
          isOnline: isOnline,
          onRetry: onRetry,
        ),
      );
    }

    if (products.isEmpty || filteredProducts.isEmpty) {
      return SliverToBoxAdapter(
        child: _ShopEmptyState(
          title: products.isEmpty
              ? 'No products available'
              : 'No products in $selectedCategory',
          message: products.isEmpty
              ? 'Official merchandise will appear here when the club publishes store inventory.'
              : 'Try another category or clear the filter to see the full store.',
          actionLabel: products.isEmpty ? 'Retry' : 'Show all',
          onAction: products.isEmpty
              ? onRetry
              : () => onCategorySelected('All'),
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        if (isStale || isRefreshing)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              SpacingTokens.spacing6,
              SpacingTokens.spacing4,
              SpacingTokens.spacing6,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: AfriStateBanner(
                icon: isRefreshing
                    ? AfriIcons.refresh
                    : AfriIcons.statusWarning,
                title: isRefreshing
                    ? 'Refreshing store'
                    : 'Saved store content',
                subtitle: isRefreshing
                    ? 'Current inventory is being checked.'
                    : 'Inventory may be out of date. Reconnect to refresh before checkout.',
                tone: isRefreshing
                    ? AfriStateBannerTone.info
                    : AfriStateBannerTone.warning,
                semanticsLabel: isRefreshing
                    ? 'Information status: Refreshing store. Current inventory is being checked.'
                    : 'Warning status: Saved store content. Inventory may be out of date. Reconnect to refresh before checkout.',
              ),
            ),
          ),
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
            height: SizeTokens.touchTargetMin,
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
        if (usesLargeTextLayout)
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.spacing6,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: SpacingTokens.spacing4,
                  ),
                  child: _buildProductCard(filteredProducts[index], index),
                ),
                childCount: filteredProducts.length,
              ),
            ),
          )
        else
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
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _buildProductCard(filteredProducts[index], index),
                childCount: filteredProducts.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, int index) {
    return RepaintBoundary(
      child: ArmouryProductCard(
        key: ValueKey<String>('shop-product-${product['id'] ?? index}'),
        product: product,
        index: index,
        onTap: () => onProductTap(product),
        onAddToCart: () => onAddToCart(product),
        autofocus: autofocusProductId == product['id']?.toString(),
      ),
    );
  }
}

class _ShopFailureState extends StatelessWidget {
  const _ShopFailureState({
    required this.failure,
    required this.isOnline,
    required this.onRetry,
  });

  final ShopCatalogFailure failure;
  final bool isOnline;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing8),
      child: !isOnline || failure.kind == ShopCatalogFailureKind.offline
          ? AfriStateView.offline(
              title: 'Store offline',
              message: 'Connect to load current club merchandise.',
            )
          : switch (failure.kind) {
              ShopCatalogFailureKind.permissionDenied => AfriStateView.error(
                title: 'Store access not available',
                message:
                    'This account cannot load club merchandise. Contact club support if access should be available.',
              ),
              ShopCatalogFailureKind.conflict => AfriStateView.error(
                title: 'Store inventory changed',
                message:
                    'Product availability changed while loading. Refresh before adding merchandise.',
                actionLabel: 'Refresh',
                onAction: onRetry,
              ),
              ShopCatalogFailureKind.securityTimeout => AfriStateView.error(
                title: 'Store security check timed out',
                message:
                    'The secure inventory check took too long. Refresh to try the check again.',
                actionLabel: 'Refresh',
                onAction: onRetry,
              ),
              ShopCatalogFailureKind.unknown => AfriStateView.error(
                title: 'Store unavailable',
                message: 'Could not load merchandise right now.',
                actionLabel: 'Retry',
                onAction: onRetry,
              ),
              ShopCatalogFailureKind.offline => AfriStateView.offline(
                title: 'Store offline',
                message: 'Connect to load current club merchandise.',
              ),
            },
    );
  }
}

class _ShopEmptyState extends StatelessWidget {
  const _ShopEmptyState({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing8),
      child: AfriStateView.empty(
        title: title,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    );
  }
}
