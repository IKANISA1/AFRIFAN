import 'package:africlub_fantasy/core/constants.dart';
import 'package:africlub_fantasy/models/entry_gameweek_score.dart';
import 'package:flutter/material.dart';

class RankRowWidget extends StatelessWidget {
  const RankRowWidget({
    required this.entry,
    this.highlight = false,
    this.onTap,
    super.key,
  });

  final EntryGameweekScore entry;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final movement = entry.rankMovement ?? 0;
    final movementColor = movement == 0
        ? FantasyColors.textMuted
        : movement > 0
        ? FantasyColors.successGreen
        : FantasyColors.dangerRed;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: FantasySpacing.md,
          vertical: FantasySpacing.md,
        ),
        decoration: BoxDecoration(
          color: highlight
              ? FantasyColors.successGreen.withValues(alpha: 0.14)
              : FantasyColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: highlight
                ? FantasyColors.successGreen
                : FantasyColors.border,
          ),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 42,
              child: Text(
                '#${entry.overallRank ?? entry.rank ?? '-'}',
                style: FantasyTypography.body.copyWith(
                  color: FantasyColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.teamName ?? 'Anonymous',
                    style: FantasyTypography.body.copyWith(
                      color: FantasyColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: FantasySpacing.xs),
                  Text(
                    entry.managerName ?? 'Manager',
                    style: FantasyTypography.caption.copyWith(
                      color: FantasyColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '${entry.points} pts',
                  style: FantasyTypography.body.copyWith(
                    color: FantasyColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: FantasySpacing.xs),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      movement > 0
                          ? Icons.arrow_drop_up_rounded
                          : movement < 0
                          ? Icons.arrow_drop_down_rounded
                          : Icons.remove_rounded,
                      color: movementColor,
                    ),
                    Text(
                      movement == 0 ? '0' : movement.abs().toString(),
                      style: FantasyTypography.caption.copyWith(
                        color: movementColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
