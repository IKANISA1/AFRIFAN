import 'package:africlub_fantasy/core/constants.dart';
import 'package:africlub_fantasy/features/leaderboard/rank_row_widget.dart';
import 'package:africlub_fantasy/models/entry_gameweek_score.dart';
import 'package:flutter/material.dart';

class LeagueTableWidget extends StatelessWidget {
  const LeagueTableWidget({
    required this.rows,
    this.highlightEntryId,
    this.onRowTap,
    super.key,
  });

  final List<EntryGameweekScore> rows;
  final String? highlightEntryId;
  final ValueChanged<EntryGameweekScore>? onRowTap;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'No leaderboard entries available yet.',
          style: FantasyTypography.body,
        ),
      );
    }

    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: FantasySpacing.sm),
              child: RankRowWidget(
                entry: row,
                highlight: highlightEntryId == row.entryId,
                onTap: onRowTap == null ? null : () => onRowTap!(row),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}
