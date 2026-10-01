import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';

import '../models/partner_pool_models.dart';

class HubPartnerPoolRow extends StatelessWidget {
  const HubPartnerPoolRow({super.key, required this.pool, this.onJoin});

  final PartnerPredictionPool pool;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    const ink = ColorTokens.discoveryInk;
    final secondary = ink.withValues(alpha: 0.76);
    final viewerEntry = pool.viewerEntry;
    final points = CurrencyFormatter(
      currencyCode: 'FET',
      currencySymbol: l10n.gameFet,
    ).formatPlain(pool.partnerStakeFet);

    return AfriEditorialCard(
      lightSurface: true,
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              pool.partnerName,
              style: TypographyTokens.bodyMedium(secondary),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(pool.title, style: TypographyTokens.headlineMedium(ink)),
            const SizedBox(height: SpacingTokens.spacing5),
            Text(
              l10n.gamePartnerPoolFundingLabel,
              style: TypographyTokens.bodySmall(secondary),
            ),
            const SizedBox(height: SpacingTokens.spacing1),
            Text(
              '$points ${l10n.gameFet}',
              style: TypographyTokens.headlineLarge(
                ink,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Wrap(
              spacing: SpacingTokens.spacing4,
              runSpacing: SpacingTokens.spacing2,
              children: [
                Text(
                  l10n.gamePointEntry(pool.fanEntryFet),
                  style: TypographyTokens.bodyMedium(ink),
                ),
                Text(
                  l10n.gameFansCount(pool.totalEntries),
                  style: TypographyTokens.bodyMedium(secondary),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              partnerPoolEligibilityLabel(l10n, pool.eligibilityMode),
              style: TypographyTokens.bodySmall(secondary),
            ),
            if (viewerEntry != null) ...[
              const SizedBox(height: SpacingTokens.spacing4),
              Row(
                children: [
                  const Icon(
                    AfriIcons.check,
                    color: ink,
                    size: SizeTokens.iconSm,
                  ),
                  const SizedBox(width: SpacingTokens.spacing2),
                  Expanded(
                    child: Text(
                      l10n.gameSelectedOutcome(
                        partnerPoolOutcomeLabel(
                          l10n,
                          viewerEntry.selectedOutcome,
                        ),
                      ),
                      style: TypographyTokens.titleMedium(ink),
                    ),
                  ),
                ],
              ),
            ] else if (!pool.isOpen) ...[
              const SizedBox(height: SpacingTokens.spacing4),
              Text(pool.status, style: TypographyTokens.titleMedium(ink)),
            ] else if (onJoin != null) ...[
              const SizedBox(height: SpacingTokens.spacing5),
              AfriButton(label: l10n.gameJoinRound, onTap: onJoin!),
            ],
          ],
        ),
      ),
    );
  }
}

class PartnerPoolOutcomeOption extends StatelessWidget {
  const PartnerPoolOutcomeOption({
    super.key,
    required this.outcome,
    required this.isSelected,
    required this.onTap,
  });

  final PartnerPoolOutcome outcome;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? ColorTokens.primaryContainer
        : ColorTokens.ghostBorder;
    final label = partnerPoolOutcomeLabel(context.afriL10n, outcome);

    return Semantics(
      selected: isSelected,
      label: isSelected ? context.afriL10n.gameSelectedOutcome(label) : label,
      child: AfriPressFeedback(
        onTap: onTap,
        tooltip: label,
        semanticsLabel: label,
        builder: (context, state) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(SpacingTokens.spacing4),
          decoration: BoxDecoration(
            color: isSelected
                ? ColorTokens.primaryContainer.withValues(alpha: 0.14)
                : ColorTokens.surfaceContainerLow,
            border: BorderTokens.all(color: color),
            borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? AfriIcons.check : AfriIcons.predict,
                color: isSelected
                    ? ColorTokens.primaryContainer
                    : context.afriSemanticColors.secondaryText,
                size: SpacingTokens.spacing5,
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              Expanded(
                child: Text(
                  label,
                  style: TypographyTokens.titleSmall(
                    isSelected
                        ? ColorTokens.contrastForeground(
                            Color.alphaBlend(
                              ColorTokens.primaryContainer.withValues(
                                alpha: 0.14,
                              ),
                              Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHigh,
                            ),
                          )
                        : ColorTokens.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String partnerPoolOutcomeLabel(
  AfriLocalizations l10n,
  PartnerPoolOutcome outcome,
) {
  return switch (outcome) {
    PartnerPoolOutcome.homeWin => l10n.gamePartnerOutcomeHomeWin,
    PartnerPoolOutcome.draw => l10n.gamePartnerOutcomeDraw,
    PartnerPoolOutcome.awayWin => l10n.gamePartnerOutcomeAwayWin,
    PartnerPoolOutcome.unknown => l10n.gamePartnerOutcomeUnknown,
  };
}

String partnerPoolEligibilityLabel(
  AfriLocalizations l10n,
  String eligibilityMode,
) {
  return switch (eligibilityMode) {
    'partner_earn_required' => l10n.gamePartnerEarnRequired,
    'initiative_earn_required' => l10n.gamePromotionEarnRequired,
    _ => l10n.gameOpenToAllFans,
  };
}
