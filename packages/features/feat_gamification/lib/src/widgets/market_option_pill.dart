import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

class MarketOptionPill extends StatelessWidget {
  const MarketOptionPill({
    super.key,
    required this.label,
    this.odds,
    required this.isSelected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final double? odds;
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TypographyTokens.editorialFont(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? ColorTokens.clubAccent
                        : ColorTokens.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                if (odds != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    odds!.toStringAsFixed(1),
                    style: TypographyTokens.monolithFont(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? ColorTokens.clubAccent
                          : ColorTokens.onSurface,
                    ),
                  ),
                ],
              ],
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
