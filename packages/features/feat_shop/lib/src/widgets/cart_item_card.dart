import 'package:club_data/club_data.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

import 'shop_product_image.dart';

/// A single cart item card showing product, quantity controls, and price.
class CartItemCard extends StatelessWidget {
  const CartItemCard({
    super.key,
    required this.item,
    required this.priceLabel,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final CartItem item;
  final String priceLabel;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final variant = item.selectedVariant?.trim();

    final hasImage = ShopProductImage.isPublished(
      item.product.imageUrl,
      item.product.imageRightsApproved,
      item.product.imageProvenanceId,
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.product.name, style: TypographyTokens.headlineSmall()),
        if (variant != null && variant.isNotEmpty) ...[
          const SizedBox(height: SpacingTokens.spacing2),
          Text(variant, style: TypographyTokens.bodyMedium()),
        ],
        const SizedBox(height: SpacingTokens.spacing2),
        Text(priceLabel, style: TypographyTokens.titleLarge()),
      ],
    );
    return AfriSurfaceCard(
      padding: const EdgeInsets.all(SpacingTokens.spacing4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage) ...[
                ShopProductImage(
                  url: item.product.imageUrl,
                  provenanceId: item.product.imageProvenanceId,
                  rightsApproved: item.product.imageRightsApproved,
                  name: item.product.name,
                  width: 88,
                  height: 112,
                ),
                const SizedBox(width: SpacingTokens.spacing4),
              ],
              Expanded(child: details),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Wrap(
            spacing: SpacingTokens.spacing2,
            runSpacing: SpacingTokens.spacing2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AfriIconButton(
                icon: AfriIcons.remove,
                tooltip: context.afriL10n.shopDecreaseQuantity,
                onTap: onDecrement,
              ),
              Text(
                '${item.quantity}',
                semanticsLabel: context.afriL10n.shopQuantityValue(
                  item.quantity,
                ),
                style: TypographyTokens.labelLarge(),
              ),
              AfriIconButton(
                icon: AfriIcons.add,
                tooltip: context.afriL10n.shopIncreaseQuantity,
                onTap: onIncrement,
              ),
              AfriTextButton(
                onPressed: onRemove,
                child: Text(
                  context.afriL10n.shopRemove,
                  style: TypographyTokens.labelLarge(ColorTokens.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
