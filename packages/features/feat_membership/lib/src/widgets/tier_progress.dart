import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tier progress — shows all tiers with current position.
class TierProgress extends StatelessWidget {
  const TierProgress({super.key, required this.currentXp});

  final int currentXp;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    final tiers = [
      ('BRONZE', 0),
      ('SILVER', 5000),
      ('GOLD', 15000),
      ('LEGEND', 50000),
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
          final isReached = currentXp >= threshold;
          final isCurrent = nextThreshold == null
              ? currentXp >= threshold
              : currentXp >= threshold && currentXp < nextThreshold;
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
                              ? primary.withValues(alpha: 0.2)
                              : isReached
                              ? ColorTokens.success.withValues(alpha: 0.18)
                              : ColorTokens.surfaceContainerHigh,
                          border: Border.all(
                            color: isCurrent
                                ? primary
                                : isReached
                                ? ColorTokens.success
                                : ColorTokens.ghostBorder,
                            width: isCurrent ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: isReached
                              ? Icon(Icons.check, size: 16, color: primary)
                              : Icon(
                                  Icons.lock_outline,
                                  size: 14,
                                  color: ColorTokens.onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tier.$1,
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isCurrent
                              ? primary
                              : isReached
                              ? ColorTokens.success
                              : ColorTokens.onSurfaceVariant.withValues(alpha: 0.5),
                          letterSpacing: 1.0,
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
                          ? primary.withValues(alpha: 0.3)
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
