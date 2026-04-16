import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Pinned tab bar delegate for NestedScrollView headers.
class TeamTabBarDelegate extends SliverPersistentHeaderDelegate {
  const TeamTabBarDelegate({required this.tabBar});

  final TabBar tabBar;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: ColorTokens.background, child: tabBar);
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant TeamTabBarDelegate oldDelegate) => false;
}

/// Small metric card used in the team hero section (Table, Points, Squad).
class TeamMetric extends StatelessWidget {
  const TeamMetric({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TypographyTokens.monolithFont(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact stat label used in the league standings row.
class MiniStat extends StatelessWidget {
  const MiniStat({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TypographyTokens.monolithFont(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Tier count card in the Members tab grid (emoji + count + label).
class TierCountCard extends StatelessWidget {
  const TierCountCard({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
  });

  final String icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            '$count',
            style: TypographyTokens.monolithFont(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: TypographyTokens.editorialFont(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: ColorTokens.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Numbered step card for the Contribute tab instructions.
class ContributeStep extends StatelessWidget {
  const ContributeStep({
    super.key,
    required this.stepNumber,
    required this.title,
    required this.description,
  });

  final int stepNumber;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ColorTokens.clubAccent.withValues(alpha: 0.12),
            border: BorderTokens.all(
              color: ColorTokens.clubAccent.withValues(alpha: 0.3),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$stepNumber',
            style: TypographyTokens.monolithFont(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: ColorTokens.clubAccent,
            ),
          ),
        ),
        const SizedBox(width: SpacingTokens.spacing3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TypographyTokens.titleSmall()),
              const SizedBox(height: 2),
              Text(description, style: TypographyTokens.bodySmall()),
            ],
          ),
        ),
      ],
    );
  }
}

/// Single row in the top-contributors list.
class MemberRow extends StatelessWidget {
  const MemberRow({
    super.key,
    required this.rank,
    required this.fanId,
    required this.tier,
    required this.fetLabel,
    this.isMe = false,
  });

  final int rank;
  final String fanId;
  final String tier;
  final String fetLabel;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
      child: Container(
        padding: const EdgeInsets.all(SpacingTokens.spacing3),
        decoration: BoxDecoration(
          color: isMe
              ? ColorTokens.clubAccent.withValues(alpha: 0.10)
              : ColorTokens.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: isMe
              ? BorderTokens.all(
                  color: ColorTokens.clubAccent.withValues(alpha: 0.3),
                )
              : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: Text(
                '$rank',
                style: TypographyTokens.monolithFont(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ColorTokens.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: SpacingTokens.spacing2),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ColorTokens.surfaceContainerHigh,
              ),
              alignment: Alignment.center,
              child: const Text('👤', style: TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: SpacingTokens.spacing3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(fanId, style: TypographyTokens.titleSmall()),
                      if (isMe) ...[
                        const SizedBox(width: SpacingTokens.spacing2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: ColorTokens.clubAccent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'YOU',
                            style: TypographyTokens.editorialFont(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: ColorTokens.background,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    tier,
                    style: TypographyTokens.editorialFont(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: ColorTokens.clubAccent,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              fetLabel,
              style: TypographyTokens.monolithFont(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: ColorTokens.clubAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Key-value row used in the About tab.
class TeamInfoRow extends StatelessWidget {
  const TeamInfoRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label.toUpperCase(),
              style: TypographyTokens.editorialFont(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ColorTokens.onSurfaceVariant,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(child: Text(value, style: TypographyTokens.bodyMedium())),
        ],
      ),
    );
  }
}
