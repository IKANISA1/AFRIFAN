import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

class ContributorEntry {
  const ContributorEntry({
    required this.rank,
    required this.alias,
    required this.points,
  });

  final int rank;
  final String alias;
  final int points;
}

/// Compact home leaderboard.
class ContributorLeaderboard extends StatelessWidget {
  const ContributorLeaderboard({
    super.key,
    this.entries = const <ContributorEntry>[],
  });

  final List<ContributorEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AfriSectionHeader(
          title: context.afriL10n.homeSupportersTitle,
          subtitle: context.afriL10n.homeSupportersSubtitle,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        ...entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
            child: _ContributorRow(
              data: entry,
              pointsLabel: context.afriL10n.homePoints(entry.points),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContributorRow extends StatelessWidget {
  const _ContributorRow({required this.data, required this.pointsLabel});

  final ContributorEntry data;
  final String pointsLabel;

  @override
  Widget build(BuildContext context) {
    final isFirst = data.rank == 1;

    return AfriSurfaceCard(
      borderRadius: ShapeTokens.chipRadius,
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing4,
        vertical: SpacingTokens.spacing4,
      ),
      backgroundColor: isFirst
          ? ColorTokens.primaryTint(0.10)
          : ColorTokens.surfaceContainerLow,
      child: Row(
        children: [
          Container(
            width: SpacingTokens.spacing8,
            height: SpacingTokens.spacing8,
            decoration: BoxDecoration(
              color: isFirst
                  ? ColorTokens.primaryTint(0.18)
                  : ColorTokens.surfaceContainer,
              borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
            ),
            alignment: Alignment.center,
            child: Text(
              data.rank.toString(),
              style: TypographyTokens.labelMedium(
                isFirst
                    ? ColorTokens.primaryContainer
                    : context.afriSemanticColors.secondaryText,
              ),
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Text(
              '#${data.alias}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TypographyTokens.titleMedium(),
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Text(
            pointsLabel,
            style: TypographyTokens.bodySmall(
              isFirst
                  ? ColorTokens.primaryContainer
                  : context.afriSemanticColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
