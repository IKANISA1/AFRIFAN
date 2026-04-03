import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full-width "Armoury" product card -- cinematic editorial style.
///
/// Each card is a full-width glass tile with:
/// - Large product image area (real image from Supabase Storage, gradient fallback)
/// - Badge (LIMITED EDITION, NEW ARRIVAL, HERITAGE, etc.)
/// - Product name + red "+" add-to-cart FAB
/// - Subtitle & price
/// - Numeric alias ID badge
class ArmouryProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final int index;

  const ArmouryProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onAddToCart,
    required this.index,
  });

  @override
  State<ArmouryProductCard> createState() => _ArmouryProductCardState();
}

class _ArmouryProductCardState extends State<ArmouryProductCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Stagger the animation based on index
    Future.delayed(Duration(milliseconds: 100 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final currency = CurrencyFormatter(
      currencyCode: 'RWF',
      currencySymbol: 'FRw',
    );
    final name = widget.product['name']?.toString() ?? 'Product';
    final price = (widget.product['price'] as num?)?.toDouble() ?? 0;
    final subtitle = widget.product['subtitle']?.toString() ?? '';
    final badge = widget.product['badge_label']?.toString();
    final productId =
        widget.product['product_id']?.toString() ??
        widget.product['id']?.toString() ??
        '000-000';
    final imageUrl = widget.product['image_url']?.toString();
    final category = widget.product['category']?.toString() ?? '';

    // Determine image area gradient based on category
    final gradientColors = _gradientForCategory(category, primary);

    return FadeTransition(
      opacity: _fadeIn,
      child: SlideTransition(
        position: _slideUp,
        child: AfriPressFeedback(
          onTap: widget.onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: SpacingTokens.spacing6),
            decoration: BoxDecoration(
              color: ColorTokens.surfaceContainerLowest, // Very dark blue/black
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ColorTokens.ghostBorder, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // -- Image Header Section with Overlays --
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Base Image Area
                    _buildImageArea(
                      imageUrl: imageUrl,
                      badge: badge,
                      gradientColors: gradientColors,
                      primary: primary,
                      name: name,
                    ),

                    // Add to Cart FAB (overlapping bottom right corner)
                    Positioned(
                      right: SpacingTokens.spacing4,
                      bottom: -18,
                      child: _AddToCartFab(
                        primary: ColorTokens.clubPrimary,
                        onTap: widget.onAddToCart,
                      ),
                    ),
                  ],
                ),

                // -- Content Section (Below Image) --
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.spacing4,
                    SpacingTokens.spacing4,
                    SpacingTokens.spacing4,
                    SpacingTokens.spacing5,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: ColorTokens.onSurfaceVariant,
                            letterSpacing: 0.5,
                          ),
                        ),
                      const SizedBox(height: SpacingTokens.spacing2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currency.format(price),
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: ColorTokens.onSurface,
                              height: 1.0,
                            ),
                          ),
                          _ProductIdBadge(productId: productId),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageArea({
    required String? imageUrl,
    required String? badge,
    required List<Color> gradientColors,
    required Color primary,
    required String name,
  }) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Stack(
        children: [
          // Image or gradient fallback
          Container(
            width: double.infinity,
            height: 320, // Taller matching reference images
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
            ),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 320,
                    placeholder: (_, __) =>
                        _ImageSkeleton(gradientColors: gradientColors),
                    errorWidget: (_, __, ___) => _ImageFallback(
                      gradientColors: gradientColors,
                      primary: primary,
                    ),
                  )
                : _ImageFallback(
                    gradientColors: gradientColors,
                    primary: primary,
                  ),
          ),

          // Gradient Overlay to ensure text readability
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 120, // Shadow gradient height
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    ColorTokens.background.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ),

          // Badge and Title in bottom left
          Positioned(
            left: SpacingTokens.spacing4,
            bottom: SpacingTokens.spacing4,
            right: 80, // Prevent overlapping with FAB
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (badge != null && badge.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _BadgePill(label: badge),
                  ),
                Text(
                  name.toUpperCase(),
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: ColorTokens.onSurface,
                    letterSpacing: 1.0,
                    height: 1.0,
                    shadows: [
                      Shadow(
                        color: ColorTokens.background.withValues(alpha: 0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _gradientForCategory(String category, Color primary) {
    final lowerCat = category.toLowerCase();

    if (lowerCat.contains('kit')) {
      return [
        ColorTokens.surfaceContainerHigh,
        ColorTokens.surfaceContainerLowest,
      ];
    } else if (lowerCat.contains('jacket') || lowerCat.contains('outerwear')) {
      return [ColorTokens.surfaceContainer, ColorTokens.surfaceContainerLowest];
    } else if (lowerCat.contains('accessori')) {
      return [
        ColorTokens.surfaceContainerHighest,
        ColorTokens.surfaceContainerLow,
      ];
    } else if (lowerCat.contains('equipment') || lowerCat.contains('ball')) {
      return [
        ColorTokens.surfaceContainerHigh,
        ColorTokens.surfaceContainerLowest,
      ];
    } else {
      return [
        ColorTokens.surfaceContainerHigh,
        ColorTokens.surfaceContainerLow,
      ];
    }
  }
}

/// Animated skeleton placeholder while image loads.
class _ImageSkeleton extends StatelessWidget {
  final List<Color> gradientColors;

  const _ImageSkeleton({required this.gradientColors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.shield_rounded,
          size: 48,
          color: ColorTokens.onSurfaceVariant.withValues(alpha: 0.15),
        ),
      ),
    );
  }
}

/// Fallback when no image URL is set or image fails to load.
/// Shows a subtle icon on gradient background -- NOT emoji.
class _ImageFallback extends StatelessWidget {
  final List<Color> gradientColors;
  final Color primary;

  const _ImageFallback({required this.gradientColors, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.shield_rounded,
          size: 48,
          color: primary.withValues(alpha: 0.15),
        ),
      ),
    );
  }
}

/// Small red "+" FAB for adding to cart.
class _AddToCartFab extends StatelessWidget {
  final Color primary;
  final VoidCallback? onTap;

  const _AddToCartFab({required this.primary, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      onTap: onTap,
      scaleEnd: 0.90,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: primary,
          border: Border.all(
            color: ColorTokens.onSurface.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: ColorTokens.background.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(
          Icons.add_rounded,
          color: ColorTokens.onSurface,
          size: 28,
        ),
      ),
    );
  }
}

/// Badge pill (LIMITED EDITION, NEW ARRIVAL, etc.)
class _BadgePill extends StatelessWidget {
  final String label;

  const _BadgePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: ColorTokens.background.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: ColorTokens.onSurface.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: ColorTokens.onSurface.withValues(alpha: 0.9),
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Numeric alias product ID badge.
class _ProductIdBadge extends StatelessWidget {
  final String productId;

  const _ProductIdBadge({required this.productId});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: ShapeTokens.aliasPillRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: ColorTokens.glassFill,
            borderRadius: ShapeTokens.aliasPillRadius,
            border: Border.all(color: ColorTokens.ghostBorder, width: 0.5),
          ),
          child: Text(
            'ID: $productId',
            style: GoogleFonts.barlowCondensed(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: ColorTokens.onSurfaceVariant,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
