import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';

/// Compact product card used in the shop grid.
class ArmouryProductCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final currency = CurrencyFormatter(
      currencyCode: context.afriCurrencyCode,
      currencySymbol: context.afriCurrencySymbol,
    );
    final name = product['name']?.toString() ?? 'Product';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final subtitle = product['subtitle']?.toString() ?? '';
    final badge = product['badge_label']?.toString();
    final imageUrl = product['image_url']?.toString();
    final category = product['category']?.toString() ?? '';

    return AfriPressFeedback(
      onTap: onTap,
      semanticsLabel: name,
      semanticsHint: 'Open product',
      tooltip: name,
      excludeChildSemantics: true,
      builder: (context, state) => ClayCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: _ProductImage(
                        imageUrl: imageUrl,
                        category: category,
                      ),
                    ),
                  ),
                  if (badge != null && badge.isNotEmpty)
                    Positioned(
                      top: SpacingTokens.spacing3,
                      left: SpacingTokens.spacing3,
                      child: AfriStatusChip(
                        label: badge,
                        tone: AfriStatusTone.live,
                      ),
                    ),
                  Positioned(
                    right: SpacingTokens.spacing3,
                    bottom: SpacingTokens.spacing3,
                    child: AfriIconButton(
                      icon: Icons.add_rounded,
                      tooltip: 'Add to cart',
                      onTap: onAddToCart,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SpacingTokens.spacing4,
                SpacingTokens.spacing4,
                SpacingTokens.spacing4,
                SpacingTokens.spacing4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TypographyTokens.titleMedium(),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: SpacingTokens.spacing1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TypographyTokens.bodySmall(
                        ColorTokens.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: SpacingTokens.spacing3),
                  Text(
                    currency.format(price),
                    style: TypographyTokens.titleLarge(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.imageUrl, required this.category});

  final String? imageUrl;
  final String category;

  @override
  Widget build(BuildContext context) {
    final gradient = _gradientForCategory(category);

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        cacheManager: AfriImageCacheManager.instance,
        fit: BoxFit.cover,
        placeholder: (_, __) => _fallback(gradient),
        errorWidget: (_, __, ___) => _fallback(gradient),
      );
    }
    return _fallback(gradient);
  }

  Widget _fallback(List<Color> colors) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.shopping_bag_outlined,
          size: 40,
          color: ColorTokens.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  List<Color> _gradientForCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('kit')) {
      return [
        ColorTokens.primaryTint(0.55),
        ColorTokens.surfaceContainerHighest,
      ];
    }
    if (lower.contains('access')) {
      return [
        ColorTokens.surfaceContainerHighest,
        ColorTokens.surfaceContainerLow,
      ];
    }
    return [ColorTokens.surfaceContainerHigh, ColorTokens.surfaceContainerLow];
  }
}
