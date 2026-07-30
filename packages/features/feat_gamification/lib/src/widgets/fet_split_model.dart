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
                'Points share',
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
                  currentTier,
                  style: TypographyTokens.labelSmall(ColorTokens.clubAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            'Tier rules decide how earned points support you and collective club rewards.',
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
                        '$personalPct% you',
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
                          '$clubPct% club',
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
                            tier.name,
                            style: TypographyTokens.labelMedium(
                              isCurrent
                                  ? ColorTokens.clubAccent
                                  : ColorTokens.onSurface,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(tier.price, style: TypographyTokens.bodySmall()),
                        ],
                      ),
                    ),
                    Text(
                      '${tier.personalPct}/${tier.clubPct}',
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
                    'Your points earn is shared by tier: the personal share stays with you and the club share supports collective rewards.',
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
}

class _TierInfo {
  const _TierInfo({
    required this.slug,
    required this.name,
    required this.icon,
    required this.price,
    required this.personalPct,
    required this.clubPct,
  });

  final String slug;
  final String name;
  final IconData icon;
  final String price;
  final int personalPct;
  final int clubPct;
}

const List<_TierInfo> _allTiers = [
  _TierInfo(
    slug: 'supporter',
    name: 'Supporter',
    icon: AfriIcons.fanzone,
    price: 'Free',
    personalPct: 100,
    clubPct: 0,
  ),
  _TierInfo(
    slug: 'member',
    name: 'Member',
    icon: AfriIcons.badge,
    price: '500 RWF / month',
    personalPct: 90,
    clubPct: 10,
  ),
  _TierInfo(
    slug: 'ultra',
    name: 'Ultra',
    icon: AfriIcons.streak,
    price: '1,500 RWF / month',
    personalPct: 80,
    clubPct: 20,
  ),
  _TierInfo(
    slug: 'legend',
    name: 'Legend',
    icon: AfriIcons.premium,
    price: '5,000 RWF / month',
    personalPct: 65,
    clubPct: 35,
  ),
];
