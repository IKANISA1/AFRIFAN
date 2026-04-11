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
      return stockCount.clamp(0, 99).toInt();
    }
    return _isInStock(product) ? 10 : 0;
  }

  @override
  void initState() {
    super.initState();
    _loadProduct();
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
          _error = 'Product not found';
          _isLoading = false;
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
        _quantity = maxQuantity > 0
            ? _quantity.clamp(1, maxQuantity).toInt()
            : 1;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load product';
          _isLoading = false;
        });
      }
    }
  }

  void _increment() {
    final maxQuantity = _maxQuantityFor(_product);
    if (_quantity < maxQuantity) {
      setState(() => _quantity++);
      HapticFeedback.lightImpact();
    }
  }

  void _decrement() {
    if (_quantity > 1) {
      setState(() => _quantity--);
      HapticFeedback.lightImpact();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This item is currently out of stock.'),
          backgroundColor: ColorTokens.error,
        ),
      );
      return;
    }

    final sizes = _availableSizes(product);
    if (sizes.isNotEmpty &&
        (_selectedSize == null || !sizes.contains(_selectedSize))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a size before adding to cart.')),
      );
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product['name'] ?? 'Product'} added to cart.'),
        backgroundColor: ColorTokens.success,
        action: SnackBarAction(
          label: 'View Cart',
          onPressed: () => context.push('/shop/cart'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && !_isLoading) {
      return Scaffold(
        backgroundColor: ColorTokens.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close_rounded, color: ColorTokens.onSurface),
            onPressed: () => context.pop(),
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
    final primary = Theme.of(context).colorScheme.primary;
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
              SliverAppBar(
                expandedHeight: 400,
                pinned: true,
                backgroundColor: ColorTokens.background,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: ColorTokens.glassFill,
                          borderRadius: BorderRadius.circular(12),
                          border: BorderTokens.ghost(),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: ColorTokens.onSurface,
                          ),
                          onPressed: () {
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
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                ColorTokens.background,
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (badge != null && badge.isNotEmpty)
                        Positioned(
                          left: SpacingTokens.spacing6,
                          bottom: SpacingTokens.spacing4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: ColorTokens.background.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: BorderTokens.ghost(),
                            ),
                            child: Text(
                              badge.toUpperCase(),
                              style: TypographyTokens.editorialFont(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: ColorTokens.onSurface.withValues(
                                  alpha: 0.9,
                                ),
                                letterSpacing: 1.5,
                              ),
                            ),
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
                              name.toUpperCase(),
                              style: TypographyTokens.headlineLarge(),
                            ),
                          ),
                          const SizedBox(width: SpacingTokens.spacing4),
                          Text(
                            currency.format(price),
                            style: TypographyTokens.displayMedium(primary),
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
                      const SizedBox(height: SpacingTokens.spacing4),
                      Text(
                        inStock
                            ? (stockCount != null
                                  ? '$stockCount available now'
                                  : 'Available now')
                            : 'Out of stock',
                        style: TypographyTokens.bodyMedium().copyWith(
                          color: inStock
                              ? ColorTokens.success
                              : ColorTokens.error,
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.spacing8),
                      if (sizes.isNotEmpty) ...[
                        Text(
                          'SELECT SIZE',
                          style: TypographyTokens.editorialFont(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: ColorTokens.onSurfaceVariant,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        Wrap(
                          spacing: SpacingTokens.spacing3,
                          runSpacing: SpacingTokens.spacing3,
                          children: sizes.map((size) {
                            final selected = size == _selectedSize;
                            return GestureDetector(
                              onTap: () {
                                setState(() => _selectedSize = size);
                                HapticFeedback.lightImpact();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? primary
                                      : Colors.transparent,
                                  borderRadius: ShapeTokens.buttonRadius,
                                  border: selected
                                      ? BorderTokens.all(color: primary)
                                      : BorderTokens.ghost(),
                                ),
                                child: Text(
                                  size,
                                  style: TypographyTokens.editorialFont(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: ColorTokens.onSurface,
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
                          Text(
                            'QUANTITY',
                            style: TypographyTokens.editorialFont(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: ColorTokens.onSurfaceVariant,
                              letterSpacing: 1,
                            ),
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
                                IconButton(
                                  icon: const Icon(Icons.remove_rounded),
                                  onPressed: _quantity > 1 ? _decrement : null,
                                ),
                                SizedBox(
                                  width: 40,
                                  child: Center(
                                    child: Text(
                                      '$_quantity',
                                      style: TypographyTokens.displaySmall(
                                        ColorTokens.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_rounded),
                                  onPressed: _quantity < maxQuantity
                                      ? _increment
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
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
                        vertical: SpacingTokens.spacing5,
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
                                    'TOTAL',
                                    style: TypographyTokens.editorialFont(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: ColorTokens.onSurfaceVariant,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  Text(
                                    currency.format(total),
                                    style: TypographyTokens.displayMedium(
                                      ColorTokens.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ClaymorphicButton(
                                    label: 'ADD TO CART',
                                    icon: Icons.shopping_bag_outlined,
                                    onPressed: inStock ? _addToCart : null,
                                  ),
                                  const SizedBox(
                                    height: SpacingTokens.spacing2,
                                  ),
                                  OutlinedButton(
                                    onPressed: inStock
                                        ? () {
                                            _addToCart();
                                            context.push('/shop/cart');
                                          }
                                        : null,
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(
                                        double.infinity,
                                        48,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text('REVIEW CHECKOUT'),
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

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.primary});

  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ColorTokens.surfaceContainerLow,
      child: Icon(
        Icons.shield_rounded,
        size: 64,
        color: primary.withValues(alpha: 0.2),
      ),
    );
  }
}
