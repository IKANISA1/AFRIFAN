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
import 'package:google_fonts/google_fonts.dart';

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

  String _selectedSize = 'M';
  final List<String> _sizes = ['S', 'M', 'L', 'XL', 'XXL'];
  int _quantity = 1;
  final _currency = CurrencyFormatter(
    currencyCode: 'RWF',
    currencySymbol: 'FRw',
  );

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final user = ref.read(currentUserProvider);
      if (user == null || user.clubId.isEmpty) {
        if (mounted) {
          setState(() {
            _error = 'Could not resolve the active club.';
            _isLoading = false;
          });
        }
        return;
      }
      var query = client
          .from(_productsTable)
          .select()
          .eq('id', widget.productId);
      final numericClubId = int.tryParse(user.clubId);
      query = numericClubId != null
          ? query.eq('club_id', numericClubId)
          : query.eq('partner_id', user.clubId);
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
        _product = Map<String, dynamic>.from(response);
        _isLoading = false;
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
    if (_quantity < 10) {
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

    ref
        .read(shopCartProvider.notifier)
        .addRawProduct(
          product,
          partnerId: user.clubId,
          selectedVariant: _selectedSize,
          quantity: _quantity,
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
    final total = price * _quantity;
    final description =
        product['description']?.toString() ?? 'Official club merchandise.';
    final imageUrl = product['image_url']?.toString();
    final badge = product['badge_label']?.toString();
    final primary = Theme.of(context).colorScheme.primary;

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
                          border: Border.all(
                            color: ColorTokens.ghostBorder,
                            width: 0.5,
                          ),
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
                              border: Border.all(
                                color: ColorTokens.ghostBorder,
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              badge.toUpperCase(),
                              style: GoogleFonts.inter(
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
                            _currency.format(price),
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
                      const SizedBox(height: SpacingTokens.spacing8),
                      Text(
                        'SELECT SIZE',
                        style: GoogleFonts.inter(
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
                        children: _sizes.map((size) {
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
                                color: selected ? primary : Colors.transparent,
                                borderRadius: ShapeTokens.buttonRadius,
                                border: Border.all(
                                  color: selected
                                      ? primary
                                      : ColorTokens.ghostBorder,
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                size,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? ColorTokens.onSurface
                                      : ColorTokens.onSurface,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: SpacingTokens.spacing6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'QUANTITY',
                            style: GoogleFonts.inter(
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
                              border: Border.all(
                                color: ColorTokens.ghostBorder,
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_rounded),
                                  onPressed: _decrement,
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
                                  onPressed: _increment,
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
                        border: Border(
                          top: BorderSide(
                            color: ColorTokens.ghostBorder,
                            width: 0.5,
                          ),
                        ),
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
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: ColorTokens.onSurfaceVariant,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  Text(
                                    _currency.format(total),
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
                                    onPressed: _addToCart,
                                  ),
                                  const SizedBox(
                                    height: SpacingTokens.spacing2,
                                  ),
                                  OutlinedButton(
                                    onPressed: () {
                                      _addToCart();
                                      context.push('/shop/cart');
                                    },
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(
                                        double.infinity,
                                        48,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text('PAY WITH MOMO'),
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
