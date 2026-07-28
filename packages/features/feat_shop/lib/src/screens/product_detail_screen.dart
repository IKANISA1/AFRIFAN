import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shop_cart_provider.dart';

typedef ProductDetailLoader =
    Future<Map<String, dynamic>?> Function(String productId);

enum ProductDetailFailureKind {
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class ProductDetailFailure implements Exception {
  const ProductDetailFailure(this.kind);

  final ProductDetailFailureKind kind;

  static ProductDetailFailure fromError(Object error) {
    if (error is ProductDetailFailure) return error;
    if (error is TimeoutException) {
      return const ProductDetailFailure(
        ProductDetailFailureKind.securityTimeout,
      );
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const ProductDetailFailure(
        ProductDetailFailureKind.permissionDenied,
      );
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision')) {
      return const ProductDetailFailure(ProductDetailFailureKind.conflict);
    }
    return const ProductDetailFailure(ProductDetailFailureKind.unknown);
  }

  @override
  String toString() => 'ProductDetailFailure(${kind.name})';
}

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.productLoader,
    this.loadTimeout = const Duration(seconds: 12),
    this.autofocusSize,
  });

  final String productId;
  final ProductDetailLoader? productLoader;
  final Duration loadTimeout;
  final String? autofocusSize;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  static const _productsTable = 'shop_products';
  static const _auditSampleProductId = 'sample-product';

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isStale = false;
  Map<String, dynamic>? _product;
  ProductDetailFailure? _failure;
  bool _isOffline = false;
  bool _isNotFound = false;
  late bool _wasOnline;

  String? _selectedSize;
  int _quantity = 1;

  CurrencyFormatter _currencyFormatter(BuildContext context) =>
      CurrencyFormatter(
        currencyCode: context.afriCurrencyCode,
        currencySymbol: context.afriCurrencySymbol,
      );

  List<String> _availableSizes(Map<String, dynamic>? product) {
    return switch (product?['available_sizes'] ?? product?['sizes']) {
      final List<dynamic> values =>
        values
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false),
      final String value when value.trim().isNotEmpty =>
        value
            .split(',')
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false),
      _ => const <String>[],
    };
  }

  int? _stockCount(Map<String, dynamic>? product) {
    final rawValue = product?['stock'] ?? product?['inventory_count'];
    return switch (rawValue) {
      final num value => value.toInt(),
      final String value => int.tryParse(value.trim()),
      _ => null,
    };
  }

  bool _isInStock(Map<String, dynamic>? product) {
    final stockCount = _stockCount(product);
    final flaggedInStock = product?['in_stock'] as bool? ?? true;
    if (stockCount != null) {
      return flaggedInStock && stockCount > 0;
    }
    return flaggedInStock;
  }

  int _maxQuantityFor(Map<String, dynamic>? product) {
    final stockCount = _stockCount(product);
    if (stockCount != null) {
      return stockCount.clamp(0, 99);
    }
    return _isInStock(product) ? 10 : 0;
  }

  @override
  void initState() {
    super.initState();
    _wasOnline = ConnectivityService.isOnline;
    ConnectivityService.onlineNotifier.addListener(_handleConnectivityChange);
    unawaited(_loadProduct());
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
    if (!isOnline && _product != null) {
      setState(() => _isStale = true);
    } else if (restored && (_isOffline || _isStale)) {
      unawaited(_loadProduct());
    }
  }

  Future<void> _loadProduct() async {
    if (!ConnectivityService.isOnline) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _isStale = _product != null;
        _isOffline = true;
        _isNotFound = false;
        _failure = null;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isRefreshing = _product != null;
        if (_product == null) {
          _isLoading = true;
        }
        _isOffline = false;
        _isNotFound = false;
        _failure = null;
      });
    }

    try {
      final request = widget.productLoader == null
          ? _fetchProduct()
          : widget.productLoader!(widget.productId);
      final response = await request.timeout(widget.loadTimeout);

      if (!mounted) return;

      if (response == null) {
        setState(() {
          if (_usesAuditSampleFallback) {
            _applyAuditSampleProduct();
          } else if (_product != null) {
            _isLoading = false;
            _isRefreshing = false;
            _isStale = true;
            _isOffline = !ConnectivityService.isOnline;
            _isNotFound = false;
            _failure = null;
          } else {
            _product = null;
            _isNotFound = true;
            _isOffline = false;
            _isRefreshing = false;
            _isStale = false;
            _failure = null;
            _isLoading = false;
          }
        });
        return;
      }

      setState(() {
        final product = Map<String, dynamic>.from(response);
        final sizes = _availableSizes(product);
        _product = product;
        _selectedSize = sizes.isEmpty
            ? null
            : (sizes.contains(_selectedSize) ? _selectedSize : sizes.first);
        final maxQuantity = _maxQuantityFor(product);
        _quantity = maxQuantity > 0 ? _quantity.clamp(1, maxQuantity) : 1;
        _isLoading = false;
        _isRefreshing = false;
        _isStale = false;
        _isOffline = false;
        _isNotFound = false;
        _failure = null;
      });
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'ProductDetailScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (mounted) {
        setState(() {
          if (_usesAuditSampleFallback) {
            _applyAuditSampleProduct();
          } else if (_product != null) {
            _isLoading = false;
            _isRefreshing = false;
            _isStale = true;
            _isOffline = !ConnectivityService.isOnline;
            _isNotFound = false;
            _failure = null;
          } else {
            _product = null;
            _isOffline = !ConnectivityService.isOnline;
            _isNotFound = false;
            _isRefreshing = false;
            _isStale = false;
            _failure = _isOffline
                ? null
                : ProductDetailFailure.fromError(error);
            _isLoading = false;
          }
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchProduct() async {
    final client = ref.read(supabaseClientProvider);
    final user = ref.read(currentUserProvider);
    final resolver = ClubScopeResolver(client: client);
    final scope = await resolver.requireResolved(user?.clubId);
    var query = client.from(_productsTable).select().eq('id', widget.productId);
    query = resolver.apply(query, scope);
    final response = await query.maybeSingle();
    return response == null ? null : Map<String, dynamic>.from(response);
  }

  bool get _usesAuditSampleFallback =>
      widget.productId == _auditSampleProductId;

  void _applyAuditSampleProduct() {
    final product = <String, dynamic>{
      'id': _auditSampleProductId,
      'name': 'Rayon Home Jersey',
      'price': 25000,
      'description':
          'Official matchday jersey with a premium woven club mark, breathable '
          'stadium fabric, and club-blue trim for everyday supporters.',
      'image_url': '',
      'badge_label': 'OFFICIAL',
      'available_sizes': const ['S', 'M', 'L', 'XL'],
      'inventory_count': 47,
      'in_stock': true,
    };
    _product = product;
    _selectedSize = 'M';
    _quantity = 1;
    _failure = null;
    _isRefreshing = false;
    _isStale = false;
    _isOffline = false;
    _isNotFound = false;
    _isLoading = false;
  }

  void _increment() {
    final maxQuantity = _maxQuantityFor(_product);
    if (_quantity < maxQuantity) {
      setState(() => _quantity++);
      unawaited(HapticFeedback.lightImpact());
    }
  }

  void _decrement() {
    if (_quantity > 1) {
      setState(() => _quantity--);
      unawaited(HapticFeedback.lightImpact());
    }
  }

  void _addToCart() {
    final product = _product;
    final user = ref.read(currentUserProvider);

    if (product == null) return;

    if (user == null) {
      context.go('/onboarding');
      return;
    }

    if (!_isInStock(product)) {
      AfriToast.error(context, 'This item is currently out of stock.');
      return;
    }

    final sizes = _availableSizes(product);
    if (sizes.isNotEmpty &&
        (_selectedSize == null || !sizes.contains(_selectedSize))) {
      AfriToast.info(context, 'Select a size before adding to cart.');
      return;
    }

    final quantity = _quantity
        .clamp(1, math.max(1, _maxQuantityFor(product)))
        .toInt();

    ref
        .read(shopCartProvider.notifier)
        .addRawProduct(
          product,
          partnerId: user.clubId,
          selectedVariant: sizes.isEmpty ? null : _selectedSize,
          quantity: quantity,
        );

    AfriToast.success(
      context,
      '${product['name'] ?? 'Product'} added to cart.',
      actionLabel: 'View Cart',
      onAction: () => context.push('/shop/cart'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isNotFound && !_isLoading) {
      return _buildStateScreen(
        AfriStateView.empty(
          title: 'Product not found',
          message:
              'This item is no longer available in the current club store.',
          actionLabel: 'Back to store',
          onAction: _returnToShop,
        ),
      );
    }

    if (_isOffline && !_isLoading) {
      return _buildStateScreen(
        AfriStateView.offline(
          title: 'Product details offline',
          message:
              'Reconnect to check the latest price, size, and availability.',
          actionLabel: 'Back to store',
          onAction: _returnToShop,
        ),
      );
    }

    if (_failure != null && !_isLoading) {
      final failure = _failure!;
      final title = switch (failure.kind) {
        ProductDetailFailureKind.permissionDenied =>
          'Product access not available',
        ProductDetailFailureKind.conflict => 'Product details changed',
        ProductDetailFailureKind.securityTimeout =>
          'Product security check timed out',
        ProductDetailFailureKind.unknown => 'Product unavailable',
      };
      final message = switch (failure.kind) {
        ProductDetailFailureKind.permissionDenied =>
          'This product cannot be opened with the current account.',
        ProductDetailFailureKind.conflict =>
          'Refresh to load the current price, sizes, and availability.',
        ProductDetailFailureKind.securityTimeout =>
          'The secure product check took too long. Refresh before buying.',
        ProductDetailFailureKind.unknown =>
          'The latest product details could not be loaded.',
      };
      final canRetry =
          failure.kind != ProductDetailFailureKind.permissionDenied;
      return _buildStateScreen(
        AfriStateView.error(
          title: title,
          message: message,
          actionLabel: canRetry ? 'Refresh' : null,
          onAction: canRetry ? () => unawaited(_loadProduct()) : null,
        ),
      );
    }

    final isSkeleton = _isLoading && _product == null;
    final product =
        _product ??
        {
          'name': 'Official Jersey Loading',
          'price': 25000,
          'description':
              'Loading official merchandise details from the armoury...',
          'image_url': '',
          'badge_label': 'LOADING',
          'sizes': ['S', 'M', 'L', 'XL'],
          'in_stock': true,
        };

    final name = product['name']?.toString() ?? 'Product';
    final price = (product['price'] as num?)?.toInt() ?? 0;
    final currency = _currencyFormatter(context);
    final total = price * _quantity;
    final description =
        product['description']?.toString() ?? 'Official club merchandise.';
    final imageUrl = product['image_url']?.toString();
    final imageProvenanceId =
        product['image_provenance_id']?.toString().trim() ?? '';
    final imageRightsApproved =
        product['image_rights_approved'] == true &&
        imageProvenanceId.isNotEmpty;
    final badge = product['badge_label']?.toString();
    final primary = ColorTokens.clubAccent;
    final sizes = _availableSizes(product);
    final inStock = _isInStock(product);
    final stockCount = _stockCount(product);
    final maxQuantity = _maxQuantityFor(product);
    final usesLargeTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >= 1.5;

    if (isSkeleton) {
      return AfriScreenScaffold(
        backgroundColor: ColorTokens.background,
        appBar: AfriAppBar(
          backgroundColor: ColorTokens.transparent,
          elevation: 0,
          leading: AfriIconButton(
            icon: AfriIcons.close,
            onTap: _returnToShop,
            tooltip: 'Close product details',
          ),
        ),
        scrollable: false,
        child: const AfriSkeletonList(),
      );
    }

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      showAppBar: false,
      showBackButton: false,
      scrollable: false,
      child: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              AfriSliverAppBar(
                expandedHeight: usesLargeTextLayout ? 220 : 320,
                pinned: true,
                backgroundColor: ColorTokens.background,
                leading: Padding(
                  padding: const EdgeInsets.all(SpacingTokens.spacing2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: ColorTokens.glassFill,
                          borderRadius: BorderRadius.circular(
                            ShapeTokens.radiusMd,
                          ),
                          border: BorderTokens.ghost(),
                        ),
                        child: AfriIconButton(
                          icon: AfriIcons.back,
                          tooltip: 'Back',
                          onTap: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/shop');
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl != null && imageUrl.isNotEmpty)
                        AfriGovernedCachedImage(
                          imageUrl: imageUrl,
                          semanticLabel: '$name product image',
                          provenanceId: imageProvenanceId.isEmpty
                              ? 'shop:${widget.productId}:unapproved'
                              : imageProvenanceId,
                          rightsApproved: imageRightsApproved,
                          fit: BoxFit.cover,
                          borderRadius: ShapeTokens.radiusNone,
                          placeholder: Container(
                            color: ColorTokens.surfaceContainerLow,
                          ),
                          errorFallback: _ImageFallback(primary: primary),
                        )
                      else
                        _ImageFallback(primary: primary),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 120,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: ColorTokens.imageScrimGradient(
                              color: ColorTokens.background,
                            ),
                          ),
                        ),
                      ),
                      if (badge != null && badge.isNotEmpty)
                        Positioned(
                          left: SpacingTokens.spacing6,
                          bottom: SpacingTokens.spacing4,
                          child: AfriStatusChip(
                            label: badge,
                            tone: AfriStatusTone.live,
                          ),
                        ).afriAnimate(context).fadeIn(duration: 400.ms),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(SpacingTokens.spacing6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isRefreshing || _isStale) ...[
                        AfriStateBanner(
                          icon: _isRefreshing
                              ? AfriIcons.refresh
                              : AfriIcons.statusWarning,
                          title: _isRefreshing
                              ? 'Refreshing product details'
                              : 'Saved product details',
                          subtitle: _isRefreshing
                              ? 'Current price, sizes, and availability are being checked.'
                              : 'Reconnect to refresh price, sizes, and availability before buying.',
                          tone: _isRefreshing
                              ? AfriStateBannerTone.info
                              : AfriStateBannerTone.warning,
                        ),
                        const SizedBox(height: SpacingTokens.spacing5),
                      ],
                      (usesLargeTextLayout
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: TypographyTokens.headlineLarge(),
                                    ),
                                    const SizedBox(
                                      height: SpacingTokens.spacing3,
                                    ),
                                    Text(
                                      currency.format(price),
                                      style: TypographyTokens.titleLarge(
                                        primary,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: TypographyTokens.headlineLarge(),
                                      ),
                                    ),
                                    const SizedBox(
                                      width: SpacingTokens.spacing4,
                                    ),
                                    Text(
                                      currency.format(price),
                                      style: TypographyTokens.titleLarge(
                                        primary,
                                      ),
                                    ),
                                  ],
                                ))
                          .afriAnimate(context)
                          .fadeIn(duration: 400.ms),
                      const SizedBox(height: SpacingTokens.spacing4),
                      Text(
                            description,
                            style: TypographyTokens.bodyMedium().copyWith(
                              color: ColorTokens.onSurfaceVariant,
                              height: 1.5,
                            ),
                          )
                          .afriAnimate(context)
                          .fadeIn(delay: 100.ms, duration: 400.ms),
                      const SizedBox(height: SpacingTokens.spacing6),
                      AfriStatusChip(
                        label: inStock
                            ? (stockCount != null
                                  ? '$stockCount available now'
                                  : 'Available now')
                            : 'Out of stock',
                        tone: inStock
                            ? AfriStatusTone.success
                            : AfriStatusTone.error,
                      ),
                      const SizedBox(height: SpacingTokens.spacing8),
                      if (sizes.isNotEmpty) ...[
                        const AfriSectionHeader(
                          title: 'Select size',
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        Wrap(
                          spacing: SpacingTokens.spacing3,
                          runSpacing: SpacingTokens.spacing3,
                          children: sizes.map((size) {
                            final selected = size == _selectedSize;
                            return AfriPressFeedback(
                              key: ValueKey<String>(
                                'product-detail-size-$size',
                              ),
                              onTap: () {
                                setState(() => _selectedSize = size);
                              },
                              autofocus: widget.autofocusSize == size,
                              selected: selected,
                              tooltip: 'Size $size',
                              semanticsLabel: 'Size $size',
                              semanticsHint: selected
                                  ? 'Selected size'
                                  : 'Select size',
                              excludeChildSemantics: true,
                              builder: (context, state) {
                                return AnimatedContainer(
                                  duration: AfriMotion.resolve(
                                    context,
                                    AfriMotion.standard,
                                  ),
                                  constraints: const BoxConstraints(
                                    minHeight: SpacingTokens.spacing12,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: SpacingTokens.spacing5,
                                    vertical: SpacingTokens.spacing3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? primary
                                        : ColorTokens.surfaceContainerLow,
                                    borderRadius: ShapeTokens.buttonRadius,
                                    border: state.isFocused
                                        ? BorderTokens.focusAll(width: 3)
                                        : BorderTokens.ghost(),
                                  ),
                                  child: Text(
                                    size,
                                    style: TypographyTokens.labelMedium(
                                      selected
                                          ? ColorTokens.onDark
                                          : ColorTokens.onSurface,
                                    ),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: SpacingTokens.spacing6),
                      ],
                      _buildQuantitySelector(
                        usesLargeTextLayout: usesLargeTextLayout,
                        maxQuantity: maxQuantity,
                      ),
                      SizedBox(
                        height: usesLargeTextLayout
                            ? SpacingTokens.spacing20 * 3.5
                            : SpacingTokens.spacing20 * 2.5,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_usesAuditSampleFallback && !_isLoading && _product != null)
            const Positioned(
              left: SpacingTokens.spacing6,
              right: SpacingTokens.spacing6,
              bottom:
                  SpacingTokens.spacing20 +
                  SpacingTokens.spacing20 +
                  SpacingTokens.spacing12,
              child: _AuditSampleProductSummary(),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child:
                ClipRRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: SpacingTokens.spacing6,
                            vertical: SpacingTokens.spacing6,
                          ),
                          decoration: BoxDecoration(
                            color: ColorTokens.glassFill,
                            border: BorderTokens.top(),
                          ),
                          child: SafeArea(
                            top: false,
                            child: _buildPurchaseActions(
                              currency: currency,
                              total: total,
                              inStock: inStock,
                              usesLargeTextLayout: usesLargeTextLayout,
                            ),
                          ),
                        ),
                      ),
                    )
                    .afriAnimate(context)
                    .slideY(
                      begin: 1,
                      end: 0,
                      duration: 400.ms,
                      curve: Curves.easeOut,
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateScreen(Widget state) {
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        elevation: 0,
        leading: AfriIconButton(
          icon: AfriIcons.close,
          onTap: _returnToShop,
          tooltip: 'Close product details',
        ),
      ),
      scrollable: false,
      child: Center(child: state),
    );
  }

  void _returnToShop() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/shop');
    }
  }

  Widget _buildQuantitySelector({
    required bool usesLargeTextLayout,
    required int maxQuantity,
  }) {
    final controls = Container(
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerLow,
        borderRadius: ShapeTokens.buttonRadius,
        border: BorderTokens.ghost(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AfriIconButton(
            icon: AfriIcons.remove,
            onTap: _quantity > 1 ? _decrement : null,
            tooltip: 'Decrease quantity',
          ),
          SizedBox(
            width: SpacingTokens.spacing10,
            child: Center(
              child: Text('$_quantity', style: TypographyTokens.titleMedium()),
            ),
          ),
          AfriIconButton(
            icon: AfriIcons.add,
            onTap: _quantity < maxQuantity ? _increment : null,
            tooltip: 'Increase quantity',
          ),
        ],
      ),
    );

    if (usesLargeTextLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AfriSectionHeader(title: 'Quantity', padding: EdgeInsets.zero),
          const SizedBox(height: SpacingTokens.spacing3),
          controls,
        ],
      );
    }

    return Row(
      children: [
        const Expanded(
          child: AfriSectionHeader(title: 'Quantity', padding: EdgeInsets.zero),
        ),
        const SizedBox(width: SpacingTokens.spacing4),
        controls,
      ],
    );
  }

  Widget _buildPurchaseActions({
    required CurrencyFormatter currency,
    required int total,
    required bool inStock,
    required bool usesLargeTextLayout,
  }) {
    final totalSummary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Total',
          style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
        ),
        Text(
          currency.format(total),
          style: TypographyTokens.titleLarge(ColorTokens.clubAccent),
        ),
      ],
    );
    final actions = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AfriButton(
          key: const ValueKey<String>('product-detail-add'),
          label: 'Add to cart',
          icon: AfriIcons.cart,
          onTap: _addToCart,
          enabled: inStock,
        ),
        const SizedBox(height: SpacingTokens.spacing2),
        AfriButton(
          key: const ValueKey<String>('product-detail-buy'),
          label: 'Buy now',
          variant: AfriButtonVariant.outline,
          onTap: () {
            _addToCart();
            unawaited(context.push('/shop/cart'));
          },
          enabled: inStock,
        ),
      ],
    );

    if (usesLargeTextLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          totalSummary,
          const SizedBox(height: SpacingTokens.spacing3),
          actions,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: totalSummary),
        const SizedBox(width: SpacingTokens.spacing4),
        Expanded(flex: 2, child: actions),
      ],
    );
  }
}

class _AuditSampleProductSummary extends StatelessWidget {
  const _AuditSampleProductSummary();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      padding: const EdgeInsets.all(SpacingTokens.spacing5),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: ColorTokens.clubAccent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
            ),
            child: Icon(
              AfriIcons.shop,
              color: ColorTokens.clubAccent,
              size: SpacingTokens.spacing8,
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rayon Home Jersey',
                  style: TypographyTokens.titleMedium(),
                ),
                const SizedBox(height: SpacingTokens.spacing1),
                Text(
                  'Official kit · S M L XL · 47 available',
                  style: TypographyTokens.bodySmall().copyWith(
                    color: ColorTokens.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.primary});

  final Color primary;

  @override
  Widget build(BuildContext context) {
    final usesLargeTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    return Container(
      decoration: BoxDecoration(
        gradient: ColorTokens.universalGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ColorTokens.surfaceContainerLow,
            primary.withValues(alpha: 0.22),
            ColorTokens.background,
          ],
        ),
      ),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing8,
          ),
          padding: EdgeInsets.all(
            usesLargeTextLayout
                ? SpacingTokens.spacing4
                : SpacingTokens.spacing6,
          ),
          decoration: BoxDecoration(
            color: ColorTokens.glassFill,
            borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
            border: BorderTokens.ghost(),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AfriIcons.shop,
                size: usesLargeTextLayout ? 40 : 56,
                color: primary.withValues(alpha: 0.9),
              ),
              SizedBox(
                height: usesLargeTextLayout
                    ? SpacingTokens.spacing2
                    : SpacingTokens.spacing4,
              ),
              Text(
                usesLargeTextLayout
                    ? 'Product image unavailable'
                    : 'Official Rayon kit',
                textAlign: TextAlign.center,
                style: usesLargeTextLayout
                    ? TypographyTokens.titleMedium(ColorTokens.onSurface)
                    : TypographyTokens.titleLarge(ColorTokens.onSurface),
              ),
              if (!usesLargeTextLayout) ...[
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  'Premium matchday merchandise',
                  textAlign: TextAlign.center,
                  style: TypographyTokens.bodyMedium().copyWith(
                    color: ColorTokens.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
