import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Tier progress — shows all tiers with current position.
class TierProgress extends StatelessWidget {
  const TierProgress({super.key, required this.currentFet});

  final int currentFet;

  @override
  Widget build(BuildContext context) {
    final tiers = [
      (context.afriL10n.gameTierImena, 0),
      ('Inyamibwa', 250),
      (context.afriL10n.gameTierBronze, 1000),
      (context.afriL10n.gameTierSilver, 2000),
      (context.afriL10n.gameTierGold, 5000),
    ];

    return GlassCard(
      padding: const EdgeInsets.all(SpacingTokens.spacing4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
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

            return SizedBox(
              width:
                  SpacingTokens.spacing12 *
                  2 *
                  MediaQuery.textScalerOf(context).scale(1),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCurrent
                                ? ColorTokens.primaryContainer.withValues(
                                    alpha: 0.2,
                                  )
                                : isReached
                                ? ColorTokens.success.withValues(alpha: 0.18)
                                : ColorTokens.surfaceContainerHigh,
                            border: BorderTokens.all(
                              color: isCurrent
                                  ? ColorTokens.primaryContainer
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
                                    color: ColorTokens.primaryContainer,
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
                        Text(
                          tier.$1,
                          textAlign: TextAlign.center,
                          softWrap: true,
                          style: TypographyTokens.labelSmall(
                            isCurrent
                                ? ColorTokens.primaryContainer
                                : isReached
                                ? ColorTokens.success
                                : ColorTokens.onSurfaceVariant,
                          ).copyWith(fontWeight: FontWeight.w500),
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
                            ? ColorTokens.primaryContainer.withValues(
                                alpha: 0.3,
                              )
                            : ColorTokens.surfaceContainerHigh,
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
