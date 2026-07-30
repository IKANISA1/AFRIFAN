import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';

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

    return AfriSurfaceCard(
      padding: const EdgeInsets.all(SpacingTokens.spacing4),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: ColorTokens.surfaceContainer,
              borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
            ),
            alignment: Alignment.center,
            child: const Icon(AfriIcons.shop),
          ),
          const SizedBox(width: SpacingTokens.spacing4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TypographyTokens.titleMedium(),
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.spacing2),
                    Flexible(
                      child: Text(
                        priceLabel,
                        textAlign: TextAlign.end,
                        style: TypographyTokens.titleMedium(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing1),
                Wrap(
                  spacing: SpacingTokens.spacing2,
                  runSpacing: SpacingTokens.spacing2,
                  children: [
                    if (variant != null && variant.isNotEmpty)
                      AfriStatusChip(label: variant),
                    AfriStatusChip(
                      label: context.afriL10n.shopQuantityValue(item.quantity),
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing3),
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
                    SizedBox(
                      width: SpacingTokens.spacing6,
                      child: Text(
                        '${item.quantity}',
                        textAlign: TextAlign.center,
                        style: TypographyTokens.labelLarge(),
                      ),
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
          ),
        ],
      ),
    );
  }
}
