import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Tier progress — shows all tiers with current position.
class TierProgress extends StatelessWidget {
  const TierProgress({super.key, required this.currentFet});

  final int currentFet;

  @override
  Widget build(BuildContext context) {
    final tiers = [
      ('FAN', 0),
      ('BRONZE', 1000),
      ('GOLD', 2000),
      ('PLATINUM', 5000),
    ];

    return GlassCard(
      padding: const EdgeInsets.all(SpacingTokens.spacing4),
      child: Row(
        children: tiers.asMap().entries.map((entry) {
          final index = entry.key;
          final tier = entry.value;
          final threshold = tier.$2;
          final nextThreshold = index == tiers.length - 1
              ? null
              : tiers[index + 1].$2;
          final isReached = currentFet >= threshold;
          final isCurrent = nextThreshold == null
              ? currentFet >= threshold
              : currentFet >= threshold && currentFet < nextThreshold;
          final isLast = index == tiers.length - 1;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCurrent
                              ? ColorTokens.clubAccent.withValues(alpha: 0.2)
                              : isReached
                              ? ColorTokens.success.withValues(alpha: 0.18)
                              : ColorTokens.surfaceContainerHigh,
                          border: BorderTokens.all(
                            color: isCurrent
                                ? ColorTokens.clubAccent
                                : isReached
                                ? ColorTokens.success
                                : ColorTokens.ghostBorder,
                            width: isCurrent ? 2 : BorderTokens.standard,
                          ),
                        ),
                        child: Center(
                          child: isReached
                              ? Icon(
                                  AfriIcons.check,
                                  size: 16,
                                  color: ColorTokens.clubAccent,
                                )
                              : Icon(
                                  AfriIcons.lock,
                                  size: 14,
                                  color: ColorTokens.onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                ),
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.spacing1),
                      SizedBox(
                        height: SpacingTokens.spacing5,
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            tier.$1,
                            maxLines: 1,
                            style:
                                TypographyTokens.labelLarge(
                                  isCurrent
                                      ? ColorTokens.clubAccent
                                      : isReached
                                      ? ColorTokens.success
                                      : ColorTokens.onSurfaceVariant.withValues(
                                          alpha: 0.5,
                                        ),
                                ).copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      color: isReached
                          ? ColorTokens.clubAccent.withValues(alpha: 0.3)
                          : ColorTokens.surfaceContainerHigh,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
