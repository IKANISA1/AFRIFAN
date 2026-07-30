import 'package:core_l10n/core_l10n.dart';
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
    this.autofocus = false,
    required this.index,
  });

  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final currency = CurrencyFormatter(
      currencyCode: context.afriCurrencyCode,
      currencySymbol: context.afriCurrencySymbol,
    );
    final l10n = context.afriL10n;
    final name = product['name']?.toString() ?? l10n.shopProductFallback;
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final subtitle = product['subtitle']?.toString() ?? '';
    final badge = product['badge_label']?.toString();
    final stock =
        (product['stock'] as num?)?.toInt() ??
        (product['inventory_count'] as num?)?.toInt();
    final isAvailable =
        product['is_active'] != false &&
        product['in_stock'] != false &&
        (stock == null || stock > 0);
    final visibleBadge = isAvailable ? badge : l10n.shopOutOfStockUpper;
    final imageUrl = product['image_url']?.toString();
    final imageProvenanceId =
        product['image_provenance_id']?.toString().trim() ?? '';
    final imageRightsApproved =
        product['image_rights_approved'] == true &&
        imageProvenanceId.isNotEmpty;
    final category = product['category']?.toString() ?? '';
    final usesLargeTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final imagePanel = Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(ShapeTokens.radiusXl),
            ),
            child: _ProductImage(
              imageUrl: imageUrl,
              category: category,
              semanticLabel: l10n.shopProductImageSemantic(name),
              provenanceId: imageProvenanceId.isEmpty
                  ? 'shop:${product['id'] ?? 'unknown'}:unapproved'
                  : imageProvenanceId,
              rightsApproved: imageRightsApproved,
            ),
          ),
        ),
        if (visibleBadge != null && visibleBadge.isNotEmpty)
          Positioned(
            top: SpacingTokens.spacing3,
            left: SpacingTokens.spacing3,
            child: AfriStatusChip(
              label: visibleBadge,
              tone: isAvailable ? AfriStatusTone.live : AfriStatusTone.neutral,
            ),
          ),
        Positioned(
          right: SpacingTokens.spacing3,
          bottom: SpacingTokens.spacing3,
          child: AfriIconButton(
            key: ValueKey<String>('shop-add-${product['id'] ?? index}'),
            icon: AfriIcons.add,
            tooltip: isAvailable ? l10n.shopAddToCart : l10n.shopOutOfStock,
            onTap: isAvailable ? onAddToCart : null,
          ),
        ),
      ],
    );

    return AfriSurfaceCard(
      onTap: onTap,
      autofocus: autofocus,
      semanticsLabel: isAvailable
          ? name
          : l10n.shopProductUnavailableSemantic(name),
      semanticsHint: l10n.shopOpenProduct,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (usesLargeTextLayout)
            SizedBox(
              height: AfriComponentSizes.commerceCardMediaHeight,
              child: imagePanel,
            )
          else
            Expanded(child: imagePanel),
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
                  maxLines: usesLargeTextLayout ? 3 : 2,
                  overflow: usesLargeTextLayout
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: TypographyTokens.titleMedium(),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: SpacingTokens.spacing1),
                  Text(
                    subtitle,
                    maxLines: usesLargeTextLayout ? 3 : 1,
                    overflow: usesLargeTextLayout
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
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
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({
    required this.imageUrl,
    required this.category,
    required this.semanticLabel,
    required this.provenanceId,
    required this.rightsApproved,
  });

  final String? imageUrl;
  final String category;
  final String semanticLabel;
  final String provenanceId;
  final bool rightsApproved;

  @override
  Widget build(BuildContext context) {
    final gradient = ColorTokens.productFallbackGradient(category);

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return AfriGovernedCachedImage(
        imageUrl: imageUrl!,
        semanticLabel: semanticLabel,
        provenanceId: provenanceId,
        rightsApproved: rightsApproved,
        fit: BoxFit.cover,
        borderRadius: ShapeTokens.radiusNone,
        placeholder: _fallback(gradient),
        errorFallback: _fallback(gradient),
      );
    }
    return _fallback(gradient);
  }

  Widget _fallback(Gradient gradient) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: Center(
        child: Icon(
          AfriIcons.shop,
          size: SizeTokens.iconHero,
          color: ColorTokens.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
