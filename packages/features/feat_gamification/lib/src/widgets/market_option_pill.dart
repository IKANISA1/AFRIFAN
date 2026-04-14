import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

class MarketOptionPill extends StatelessWidget {
  const MarketOptionPill({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? ColorTokens.clubAccent.withValues(alpha: 0.18)
              : ColorTokens.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? BorderTokens.all(color: ColorTokens.clubAccent, width: 1.5)
              : BorderTokens.ghost(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: TypographyTokens.editorialFont(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? ColorTokens.clubAccent
                    : ColorTokens.onSurfaceVariant,
                letterSpacing: 1.0,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: SpacingTokens.spacing2),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
