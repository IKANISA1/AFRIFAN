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

/// Top contributor aliases leaderboard.
///
/// Accepts live entries from the home screen. When no contributor data exists
/// yet, the section renders a truthful empty state instead of fake rankings.
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
    // §2.3 LOCKED — if data is empty, render nothing.
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TOP SUPPORTERS',
          style: TypographyTokens.monolithFont(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: ColorTokens.onSurface,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        ...entries.map(
          (c) => _ContributorRow(data: c, formatPoints: _formatPoints),
        ),
      ],
    );
  }
}

class _ContributorRow extends StatelessWidget {
  const _ContributorRow({required this.data, required this.formatPoints});

  final ContributorEntry data;
  final String Function(int) formatPoints;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isFirst = data.rank == 1;
    final pointsLabel = '${formatPoints(data.points)} PTS';

    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
      child: ClayCard(
        borderRadius: ShapeTokens.chipRadius,
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing4,
          vertical: SpacingTokens.spacing4,
        ),
        backgroundColor: isFirst ? primaryColor.withValues(alpha: 0.08) : null,
        child: Row(
          children: [
            if (isFirst)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: BorderTokens.all(
                    color: primaryColor,
                    width: BorderTokens.standard,
                    opacity: 0.5,
                  ),
                ),
                child: Text(
                  data.rank.toString().padLeft(2, '0'),
                  style: TypographyTokens.monolithFont(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                    letterSpacing: 0.5,
                  ),
                ),
              )
            else
              SizedBox(
                width: 32,
                child: Text(
                  data.rank.toString().padLeft(2, '0'),
                  style: TypographyTokens.monolithFont(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ColorTokens.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            const SizedBox(width: SpacingTokens.spacing3),
            Expanded(
              child: Text(
                '#${data.alias}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TypographyTokens.monolithFont(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: ColorTokens.onSurface,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: SpacingTokens.spacing3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                pointsLabel,
                style: TypographyTokens.monolithFont(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isFirst ? primaryColor : ColorTokens.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
