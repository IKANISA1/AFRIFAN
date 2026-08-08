import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Points split model for tier-aware personal and club reward shares.
///
/// Uses the universal rewards visualization for tier-aware points splits.
class FetSplitModel extends StatelessWidget {
  const FetSplitModel({super.key, this.currentTier = 'supporter'});

  final String currentTier;

  @override
  Widget build(BuildContext context) {
    final (personalPct, clubPct) = _splitForTier(currentTier);

    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: SpacingTokens.spacing3,
            runSpacing: SpacingTokens.spacing2,
            children: [
              Text(
                context.afriL10n.gamePointsShare,
                style: TypographyTokens.titleMedium().copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing2,
                  vertical: SpacingTokens.spacing1,
                ),
                decoration: BoxDecoration(
                  color: ColorTokens.clubAccent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
                ),
                child: Text(
                  _tierName(context, currentTier),
                  style: TypographyTokens.labelSmall(ColorTokens.clubAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            context.afriL10n.gamePointsShareDescription,
            style: TypographyTokens.bodySmall(),
          ),
          const SizedBox(height: SpacingTokens.spacing4),

          // ── Visual Progress Bar ──
          ClipRRect(
            borderRadius: BorderRadius.circular(ShapeTokens.radiusSm),
            child: SizedBox(
              height: SpacingTokens.spacing7,
              child: Row(
                children: [
                  Expanded(
                    flex: personalPct,
                    child: Container(
                      color: ColorTokens.clubAccent,
                      alignment: Alignment.center,
                      child: Text(
                        context.afriL10n.gamePersonalPercentage(personalPct),
                        style: TypographyTokens.metricLabel(
                          ColorTokens.background,
                        ).copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  if (clubPct > 0)
                    Expanded(
                      flex: clubPct,
                      child: Container(
                        color: ColorTokens.primaryContainer,
                        alignment: Alignment.center,
                        child: Text(
                          context.afriL10n.gameClubPercentage(clubPct),
                          style: TypographyTokens.metricLabel().copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: SpacingTokens.spacing4),

          // ── Tier Breakdown Table ──
          ..._allTiers.map((tier) {
            final isCurrent =
                tier.slug.toLowerCase() == currentTier.toLowerCase();
            return Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing3,
                  vertical: SpacingTokens.spacing3,
                ),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? ColorTokens.clubAccent.withValues(alpha: 0.10)
                      : ColorTokens.transparent,
                  borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
                  border: isCurrent
                      ? BorderTokens.all(
                          color: ColorTokens.clubAccent.withValues(alpha: 0.3),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      tier.icon,
                      size: SpacingTokens.spacing5,
                      color: isCurrent
                          ? ColorTokens.clubAccent
                          : ColorTokens.onSurfaceVariant,
                    ),
                    const SizedBox(width: SpacingTokens.spacing3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _tierName(context, tier.slug),
                            style: TypographyTokens.labelMedium(
                              isCurrent
                                  ? ColorTokens.clubAccent
                                  : ColorTokens.onSurface,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            _tierPrice(context, tier.slug),
                            style: TypographyTokens.bodySmall(),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      context.afriL10n.gameTierSplit(
                        tier.personalPct,
                        tier.clubPct,
                      ),
                      style: TypographyTokens.titleSmall(
                        isCurrent
                            ? ColorTokens.clubAccent
                            : ColorTokens.onSurfaceVariant,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: SpacingTokens.spacing3),
          Container(
            padding: const EdgeInsets.all(SpacingTokens.spacing3),
            decoration: BoxDecoration(
              color: ColorTokens.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  AfriIcons.statusInfo,
                  size: AfriIcons.sizeInline,
                  color: ColorTokens.onSurfaceVariant,
                ),
                const SizedBox(width: SpacingTokens.spacing2),
                Expanded(
                  child: Text(
                    context.afriL10n.gamePointsShareExplanation,
                    style: TypographyTokens.bodySmall(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (int personalPct, int clubPct) _splitForTier(String tier) {
    return switch (tier.toLowerCase()) {
      'supporter' => (100, 0),
      'member' => (90, 10),
      'ultra' => (80, 20),
      'legend' => (65, 35),
      _ => (100, 0),
    };
  }

  String _tierName(BuildContext context, String tier) {
    return switch (tier.toLowerCase()) {
      'supporter' => context.afriL10n.gameTierSupporter,
      'member' => context.afriL10n.gameTierMember,
      'ultra' => context.afriL10n.gameTierUltra,
      'legend' => context.afriL10n.gameTierLegend,
      _ => tier,
    };
  }

  String _tierPrice(BuildContext context, String tier) {
    return switch (tier.toLowerCase()) {
      'supporter' => context.afriL10n.gameFree,
      'member' => context.afriL10n.gameMonthlyPrice('500'),
      'ultra' => context.afriL10n.gameMonthlyPrice('1,500'),
      'legend' => context.afriL10n.gameMonthlyPrice('5,000'),
      _ => context.afriL10n.gameFree,
    };
  }
}

class _TierInfo {
  const _TierInfo({
    required this.slug,
    required this.icon,
    required this.personalPct,
    required this.clubPct,
  });

  final String slug;
  final IconData icon;
  final int personalPct;
  final int clubPct;
}

const List<_TierInfo> _allTiers = [
  _TierInfo(
    slug: 'supporter',
    icon: AfriIcons.fanzone,
    personalPct: 100,
    clubPct: 0,
  ),
  _TierInfo(
    slug: 'member',
    icon: AfriIcons.badge,
    personalPct: 90,
    clubPct: 10,
  ),
  _TierInfo(
    slug: 'ultra',
    icon: AfriIcons.streak,
    personalPct: 80,
    clubPct: 20,
  ),
  _TierInfo(
    slug: 'legend',
    icon: AfriIcons.premium,
    personalPct: 65,
    clubPct: 35,
  ),
];
