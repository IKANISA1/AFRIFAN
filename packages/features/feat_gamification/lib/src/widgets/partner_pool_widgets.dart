import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

import '../models/partner_pool_models.dart';

class HubPartnerPoolRow extends StatelessWidget {
  const HubPartnerPoolRow({super.key, required this.pool, this.onJoin});

  final PartnerPredictionPool pool;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final viewerEntry = pool.viewerEntry;
    final usesAccessibleTextLayout =
        MediaQuery.textScalerOf(context).scale(14) > 18;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: SpacingTokens.spacing9,
              height: SpacingTokens.spacing9,
              decoration: BoxDecoration(
                color: ColorTokens.primaryContainer.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
              ),
              alignment: Alignment.center,
              child: Icon(
                AfriIcons.predict,
                size: SpacingTokens.spacing5,
                color: ColorTokens.primaryContainer,
              ),
            ),
            const SizedBox(width: SpacingTokens.listItemGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pool.title, style: TypographyTokens.titleSmall()),
                  const SizedBox(height: SpacingTokens.spacing1),
                  Text(
                    context.afriL10n.gamePair(
                      pool.partnerName,
                      partnerPoolEligibilityLabel(
                        context.afriL10n,
                        pool.eligibilityMode,
                      ),
                    ),
                    style: TypographyTokens.bodySmall(
                      context.afriSemanticColors.secondaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!usesAccessibleTextLayout)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    pool.partnerStakeFet.toString(),
                    style: TypographyTokens.titleMedium(
                      ColorTokens.primaryContainer,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    context.afriL10n.gamePointsRoundLabel,
                    style: TypographyTokens.labelSmall(),
                  ),
                ],
              ),
          ],
        ),
        if (usesAccessibleTextLayout) ...[
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            context.afriL10n.gamePointsRound(pool.partnerStakeFet),
            style: TypographyTokens.titleMedium(
              ColorTokens.primaryContainer,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: SpacingTokens.spacing3),
        Wrap(
          spacing: SpacingTokens.spacing2,
          runSpacing: SpacingTokens.spacing2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AfriInfoChip(
              label: context.afriL10n.gamePointEntry(pool.fanEntryFet),
              color: ColorTokens.info,
            ),
            AfriInfoChip(
              label: context.afriL10n.gameFansCount(pool.totalEntries),
              color: context.afriSemanticColors.secondaryText,
            ),
            if (viewerEntry != null)
              AfriInfoChip(
                label: partnerPoolOutcomeLabel(
                  context.afriL10n,
                  viewerEntry.selectedOutcome,
                ),
                icon: AfriIcons.check,
                color: ColorTokens.success,
              )
            else if (pool.isOpen)
              AfriInfoChip(
                label: context.afriL10n.gameChooseWdw,
                icon: AfriIcons.forward,
                color: ColorTokens.primaryContainer,
                onTap: onJoin,
              )
            else
              AfriInfoChip(
                label: pool.status,
                color: context.afriSemanticColors.secondaryText,
              ),
          ],
        ),
        if (!pool.hasJoined && pool.isOpen && onJoin != null) ...[
          const SizedBox(height: SpacingTokens.spacing3),
          AfriButton(
            label: context.afriL10n.gameJoinRound,
            icon: AfriIcons.predict,
            variant: AfriButtonVariant.secondary,
            onTap: onJoin!,
          ),
        ],
      ],
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
                        ? ColorTokens.primaryContainer
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
