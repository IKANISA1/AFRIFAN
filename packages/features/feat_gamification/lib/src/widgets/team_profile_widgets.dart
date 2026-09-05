import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Pinned tab bar delegate for NestedScrollView headers.
class TeamTabBarDelegate extends SliverPersistentHeaderDelegate {
  const TeamTabBarDelegate({required this.tabBar});

  final PreferredSizeWidget tabBar;

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
    return AfriMetricTile(label: label, value: value);
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
          style: TypographyTokens.titleMedium().copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing1),
        Text(
          label,
          style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Tier count card in the Members tab grid.
class TierCountCard extends StatelessWidget {
  const TierCountCard({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: SpacingTokens.spacing7,
            color: ColorTokens.primaryContainer,
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            count.toString(),
            style: TypographyTokens.metricValue().copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing1),
          Text(
            label,
            style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant)
                .copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: TypographyTokens.trackingNone,
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
          width: SpacingTokens.spacing10 + SpacingTokens.spacing1,
          height: SpacingTokens.spacing10 + SpacingTokens.spacing1,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ColorTokens.primaryContainer.withValues(alpha: 0.12),
            border: BorderTokens.all(
              color: ColorTokens.primaryContainer.withValues(alpha: 0.3),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            stepNumber.toString(),
            style: TypographyTokens.titleLarge(
              ColorTokens.primaryContainer,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: SpacingTokens.spacing3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TypographyTokens.titleSmall()),
              const SizedBox(height: SpacingTokens.spacing1 / 2),
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
      child: AfriPanelCard(
        padding: const EdgeInsets.all(SpacingTokens.spacing3),
        backgroundColor: isMe
            ? ColorTokens.primaryContainer.withValues(alpha: 0.10)
            : ColorTokens.surfaceContainerHigh,
        borderColor: isMe
            ? ColorTokens.primaryContainer.withValues(alpha: 0.3)
            : ColorTokens.ghostBorder,
        child: Row(
          children: [
            SizedBox(
              width: SpacingTokens.spacing5,
              child: Text(
                rank.toString(),
                style: TypographyTokens.labelSmall(
                  ColorTokens.onSurfaceVariant,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: SpacingTokens.spacing2),
            const _MemberAvatar(),
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
                        AfriInfoChip(
                          label: context.afriL10n.gameYouUpper,
                          color: ColorTokens.primaryContainer,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    tier,
                    style: TypographyTokens.labelSmall(
                      ColorTokens.primaryContainer,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Text(
              fetLabel,
              style: TypographyTokens.titleSmall(
                ColorTokens.primaryContainer,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: SpacingTokens.spacing8,
      height: SpacingTokens.spacing8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ColorTokens.surfaceContainerHigh,
      ),
      alignment: Alignment.center,
      child: Icon(
        AfriIcons.profile,
        size: SpacingTokens.spacing5 - SpacingTokens.spacing1 / 2,
        color: ColorTokens.onSurfaceVariant,
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
            width: SpacingTokens.spacing20 + SpacingTokens.spacing10,
            child: Text(
              label,
              style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant)
                  .copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: TypographyTokens.trackingNone,
                  ),
            ),
          ),
          Expanded(child: Text(value, style: TypographyTokens.bodyMedium())),
        ],
      ),
    );
  }
}
