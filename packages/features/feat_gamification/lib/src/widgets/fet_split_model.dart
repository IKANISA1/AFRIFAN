import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// FET Split Model — visualizes how FET earnings are divided between
/// the user's personal wallet and their club's pool based on membership tier.
///
/// Mirrors the fanafrika reference `WalletHub.tsx` split model visualization.
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
          Row(
            children: [
              Text(
                'FET SPLIT MODEL',
                style: TypographyTokens.titleMedium().copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing2,
                  vertical: SpacingTokens.spacing1,
                ),
                decoration: BoxDecoration(
                  color: ColorTokens.clubAccent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  currentTier.toUpperCase(),
                  style: TypographyTokens.labelSmall(ColorTokens.clubAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            'How your earned FET is split between your wallet and your fan club\'s collective pool.',
            style: TypographyTokens.bodySmall(),
          ),
          const SizedBox(height: SpacingTokens.spacing4),

          // ── Visual Progress Bar ──
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 28,
              child: Row(
                children: [
                  Expanded(
                    flex: personalPct,
                    child: Container(
                      color: ColorTokens.clubAccent,
                      alignment: Alignment.center,
                      child: Text(
                        '$personalPct% YOU',
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
                          '$clubPct% CLUB',
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
                  borderRadius: BorderRadius.circular(12),
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
                      size: 20,
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
                            tier.name.toUpperCase(),
                            style:
                                TypographyTokens.labelMedium(
                                  isCurrent
                                      ? ColorTokens.clubAccent
                                      : ColorTokens.onSurface,
                                ).copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
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
              borderRadius: BorderRadius.circular(12),
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
                    'Your prediction FET earn is split: (100% - tier%) goes to personal wallet, tier% goes to the club\'s collective FET pool.',
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
    price: 'FREE',
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
