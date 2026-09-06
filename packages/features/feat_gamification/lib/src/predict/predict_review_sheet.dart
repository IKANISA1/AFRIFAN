import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

import 'predict_models.dart';

/// Reviews a draft selection. Dismissal never places an entry; the controller
/// rechecks balance, kickoff, connectivity and reconciliation after confirmation.
Future<bool?> showPredictReview(
  BuildContext context, {
  required PredictFixture fixture,
  required PredictSelection selection,
  required int? balanceFet,
}) => showAfriBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  builder: (context) {
    final l = context.afriL10n;
    final canAfford = balanceFet != null && balanceFet >= fixture.stakeFet;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.predictReviewTitle, style: TypographyTokens.headlineLarge()),
            const SizedBox(height: SpacingTokens.sectionGap),
            Text(
              l.clubFixtureTeams(fixture.homeTeam, fixture.awayTeam),
              style: TypographyTokens.titleLarge(),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            AfriStatusChip(
              label: fixture.selectionName(selection, l.predictDraw),
              tone: AfriStatusTone.info,
            ),
            const SizedBox(height: SpacingTokens.sectionGap),
            AfriListGroup(
              children: [
                AfriListRow(
                  icon: AfriIcons.predict,
                  title: l.predictEntryCost,
                  subtitle: l.predictFetAmount(fixture.stakeFet),
                ),
                AfriListRow(
                  icon: AfriIcons.wallet,
                  title: l.predictBalanceAfter,
                  subtitle: balanceFet == null
                      ? l.predictUnavailable
                      : !canAfford
                      ? l.predictInsufficientReview
                      : l.predictFetAmount(balanceFet - fixture.stakeFet),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.sectionGap),
            Text(l.predictReviewRule, style: TypographyTokens.bodyMedium()),
            const SizedBox(height: SpacingTokens.sectionGap),
            AfriButton(
              key: const ValueKey('predict-confirm-pick'),
              label: l.predictConfirmPick,
              enabled: canAfford && fixture.isOpen(DateTime.now()),
              onTap: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            AfriButton(
              label: l.predictCancelPick,
              variant: AfriButtonVariant.secondary,
              onTap: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  },
);
