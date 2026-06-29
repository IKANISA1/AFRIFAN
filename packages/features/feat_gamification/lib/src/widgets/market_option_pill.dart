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
    final semanticsLabel = odds == null
        ? label
        : '$label, odds ${odds!.toStringAsFixed(2)}';

    return AfriPressFeedback(
      onTap: onTap,
      selected: isSelected,
      tooltip: semanticsLabel,
      semanticsLabel: semanticsLabel,
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
                if (odds != null) ...[
                  const SizedBox(height: SpacingTokens.spacing1 / 2),
                  Text(
                    '${odds!.toStringAsFixed(2)}x',
                    style: TypographyTokens.titleSmall(
                      isSelected
                          ? ColorTokens.clubAccent
                          : ColorTokens.onSurface,
                    ).copyWith(fontWeight: FontWeight.w800),
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
