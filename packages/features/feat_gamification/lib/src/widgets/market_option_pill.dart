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
    return AfriPressFeedback(
      onTap: onTap,
      selected: isSelected,
      tooltip: label,
      semanticsLabel: label,
      semanticsHint: isSelected ? 'Selected market option' : 'Select option',
      excludeChildSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(
          minHeight: SpacingTokens.spacing10 + SpacingTokens.spacing1,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing4,
          vertical: SpacingTokens.spacing3,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? ColorTokens.clubAccent.withValues(alpha: 0.18)
              : ColorTokens.surfaceContainerLow,
          borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
          border: isSelected
              ? BorderTokens.all(
                  color: ColorTokens.clubAccent,
                  width: BorderTokens.strong,
                )
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
                  style:
                      TypographyTokens.labelMedium(
                        isSelected
                            ? ColorTokens.clubAccent
                            : ColorTokens.onSurfaceVariant,
                      ).copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                ),
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
