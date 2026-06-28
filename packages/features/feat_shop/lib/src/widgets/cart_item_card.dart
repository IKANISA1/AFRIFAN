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
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: const Icon(AfriIcons.shop),
          ),
          const SizedBox(width: SpacingTokens.spacing4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypographyTokens.titleMedium(),
                ),
                const SizedBox(height: SpacingTokens.spacing1),
                Wrap(
                  spacing: SpacingTokens.spacing2,
                  runSpacing: SpacingTokens.spacing2,
                  children: [
                    if (variant != null && variant.isNotEmpty)
                      AfriStatusChip(label: variant),
                    AfriStatusChip(label: 'Qty ${item.quantity}'),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                Row(
                  children: [
                    AfriIconButton(
                      icon: AfriIcons.remove,
                      tooltip: 'Decrease quantity',
                      onTap: onDecrement,
                    ),
                    const SizedBox(width: SpacingTokens.spacing2),
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${item.quantity}',
                        textAlign: TextAlign.center,
                        style: TypographyTokens.labelLarge(),
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.spacing2),
                    AfriIconButton(
                      icon: AfriIcons.add,
                      tooltip: 'Increase quantity',
                      onTap: onIncrement,
                    ),
                    const SizedBox(width: SpacingTokens.spacing3),
                    AfriTextButton(
                      onPressed: onRemove,
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Text(priceLabel, style: TypographyTokens.titleMedium()),
        ],
      ),
    );
  }
}
