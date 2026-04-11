import 'package:core_theme/core_theme.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';

/// A single cart item card showing product name, variant, quantity controls,
/// and price.
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
    final meta = [
      if (variant != null && variant.isNotEmpty) variant,
      'Qty ${item.quantity}',
    ].join('  •  ');

    return ClayCard(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: ColorTokens.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.shopping_bag_outlined),
          ),
          const SizedBox(width: SpacingTokens.spacing4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name.toUpperCase(),
                  style: TypographyTokens.monolithFont(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: ColorTokens.onSurface,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing1),
                Text(meta, style: TypographyTokens.bodySmall()),
                const SizedBox(height: SpacingTokens.spacing2),
                Row(
                  children: [
                    IconButton(
                      onPressed: onDecrement,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    Text(
                      '${item.quantity}',
                      style: TypographyTokens.labelLarge(),
                    ),
                    IconButton(
                      onPressed: onIncrement,
                      icon: const Icon(Icons.add_rounded),
                    ),
                    TextButton(
                      onPressed: onRemove,
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            priceLabel,
            style: TypographyTokens.monolithFont(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: ColorTokens.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
