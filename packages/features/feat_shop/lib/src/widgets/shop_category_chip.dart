import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Animated category filter chip for the Shop screen.
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
      scaleEnd: 0.96,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing5,
          vertical: SpacingTokens.spacing2,
        ),
        decoration: BoxDecoration(
          color: isSelected ? primary : Colors.transparent,
          borderRadius: ShapeTokens.buttonRadius,
          border: Border.all(
            color: isSelected ? primary : ColorTokens.ghostBorder,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? ColorTokens.onSurface
                  : ColorTokens.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}
