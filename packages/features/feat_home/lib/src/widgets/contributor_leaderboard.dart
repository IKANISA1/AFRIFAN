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

  String _formatPoints(int pts) {
    if (pts >= 1000) {
      final str = pts.toString();
      final buf = StringBuffer();
      for (var i = 0; i < str.length; i++) {
        if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
        buf.write(str[i]);
      }
      return buf.toString();
    }
    return pts.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AfriSectionHeader(
          title: 'Supporters',
          subtitle: 'Top active ',
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        ...entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
            child: _ContributorRow(
              data: entry,
              pointsLabel: '${_formatPoints(entry.points)} pts',
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

    return ClayCard(
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
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isFirst
                  ? ColorTokens.primaryTint(0.18)
                  : ColorTokens.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              data.rank.toString(),
              style: TypographyTokens.labelMedium(
                isFirst
                    ? ColorTokens.primaryContainer
                    : ColorTokens.onSurfaceVariant,
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
                  : ColorTokens.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
