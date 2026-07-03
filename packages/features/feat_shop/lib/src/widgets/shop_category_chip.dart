import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Compact category filter chip for the shop screen.
class ShopCategoryChip extends StatelessWidget {
  const ShopCategoryChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      onTap: onTap,
      scaleEnd: 0.98,
      child: AnimatedContainer(
        duration: AfriMotion.quick,
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing4,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: 0.16)
              : ColorTokens.surfaceContainerLow,
          borderRadius: ShapeTokens.buttonRadius,
          border: BorderTokens.all(
            color: isSelected ? primary : ColorTokens.ghostBorder,
            width: BorderTokens.standard,
          ),
        ),
        child: Text(
          label,
          style: TypographyTokens.labelMedium(
            isSelected ? primary : ColorTokens.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
