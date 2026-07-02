import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
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

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  static const _productsTable = 'shop_products';
  static const _auditSampleProductId = 'sample-product';

  bool _isLoading = true;
  Map<String, dynamic>? _product;
  String? _error;

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
    unawaited(_loadProduct());
  }

  Future<void> _loadProduct() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final user = ref.read(currentUserProvider);
      final resolver = ClubScopeResolver(client: client);
      final scope = await resolver.requireResolved(user?.clubId);
      var query = client
          .from(_productsTable)
          .select()
          .eq('id', widget.productId);
      query = resolver.apply(query, scope);
      final response = await query.maybeSingle();

      if (!mounted) return;

      if (response == null) {
        setState(() {
          if (_usesAuditSampleFallback) {
            _applyAuditSampleProduct();
          } else {
            _error = 'Product not found';
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
        _error = null;
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
          } else {
            _error = 'Failed to load product';
            _isLoading = false;
          }
        });
      }
    }
  }

  bool get _usesAuditSampleFallback =>
      widget.productId == _auditSampleProductId;

  void _applyAuditSampleProduct() {
    final product = <String, dynamic>{
      'id': _auditSampleProductId,
      'name': 'Rayon Home Jersey',
      'price': 25000,
      'description':
          'Official matchday jersey with a premium woven crest, breathable '
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
    _error = null;
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
    if (_error != null && !_isLoading) {
      return Scaffold(
        backgroundColor: ColorTokens.background,
        appBar: AfriAppBar(
          backgroundColor: ColorTokens.transparent,
          elevation: 0,
          leading: AfriIconButton(
            icon: AfriIcons.close,
            onTap: () => context.pop(),
            tooltip: 'Close',
          ),
        ),
        body: Center(
          child: Text(
            _error ?? 'Product Not Found',
            style: TypographyTokens.bodyLarge().copyWith(
              color: ColorTokens.onSurfaceVariant,
            ),
          ),
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
    final badge = product['badge_label']?.toString();
    final primary = ColorTokens.clubAccent;
    final sizes = _availableSizes(product);
    final inStock = _isInStock(product);
    final stockCount = _stockCount(product);
    final maxQuantity = _maxQuantityFor(product);

    if (isSkeleton) {
      return Scaffold(
        backgroundColor: ColorTokens.background,
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(SpacingTokens.spacing6),
            child: AfriSkeletonList(),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              AfriSliverAppBar(
                expandedHeight: 320,
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
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          cacheManager: AfriImageCacheManager.instance,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: ColorTokens.surfaceContainerLow),
                          errorWidget: (_, __, ___) =>
                              _ImageFallback(primary: primary),
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
                        ).animate().fadeIn(duration: 400.ms),
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TypographyTokens.headlineLarge(),
                            ),
                          ),
                          const SizedBox(width: SpacingTokens.spacing4),
                          Text(
                            currency.format(price),
                            style: TypographyTokens.titleLarge(primary),
                          ),
                        ],
                      ).animate().fadeIn(duration: 400.ms),
                      const SizedBox(height: SpacingTokens.spacing4),
                      Text(
                        description,
                        style: TypographyTokens.bodyMedium().copyWith(
                          color: ColorTokens.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
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
                              onTap: () {
                                setState(() => _selectedSize = size);
                              },
                              selected: selected,
                              tooltip: 'Size $size',
                              semanticsLabel: 'Size $size',
                              semanticsHint: selected
                                  ? 'Selected size'
                                  : 'Select size',
                              excludeChildSemantics: true,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
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
                                  border: BorderTokens.ghost(),
                                ),
                                child: Text(
                                  size,
                                  style: TypographyTokens.labelMedium(
                                    selected
                                        ? ColorTokens.onDark
                                        : ColorTokens.onSurface,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: SpacingTokens.spacing6),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const AfriSectionHeader(
                            title: 'Quantity',
                            padding: EdgeInsets.zero,
                          ),
                          Container(
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
                                    child: Text(
                                      '$_quantity',
                                      style: TypographyTokens.titleMedium(),
                                    ),
                                  ),
                                ),
                                AfriIconButton(
                                  icon: AfriIcons.add,
                                  onTap: _quantity < maxQuantity
                                      ? _increment
                                      : null,
                                  tooltip: 'Increase quantity',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height:
                            SpacingTokens.spacing20 + SpacingTokens.spacing16,
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
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Total',
                                    style: TypographyTokens.labelSmall(
                                      ColorTokens.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    currency.format(total),
                                    style: TypographyTokens.titleLarge(
                                      ColorTokens.clubAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: SpacingTokens.spacing4),
                            Expanded(
                              flex: 2,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AfriButton(
                                    label: 'Add to cart',
                                    icon: AfriIcons.cart,
                                    onTap: _addToCart,
                                    enabled: inStock,
                                  ),
                                  const SizedBox(
                                    height: SpacingTokens.spacing2,
                                  ),
                                  AfriButton(
                                    label: 'Buy now',
                                    variant: AfriButtonVariant.outline,
                                    onTap: () {
                                      _addToCart();
                                      unawaited(context.push('/shop/cart'));
                                    },
                                    enabled: inStock,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ).animate().slideY(
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
          padding: const EdgeInsets.all(SpacingTokens.spacing6),
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
                size: 56,
                color: primary.withValues(alpha: 0.9),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              Text(
                'Official Rayon kit',
                textAlign: TextAlign.center,
                style: TypographyTokens.titleLarge(ColorTokens.onSurface),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                'Premium matchday merchandise',
                textAlign: TextAlign.center,
                style: TypographyTokens.bodyMedium().copyWith(
                  color: ColorTokens.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
