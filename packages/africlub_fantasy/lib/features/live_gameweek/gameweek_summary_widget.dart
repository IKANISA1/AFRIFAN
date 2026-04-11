import 'package:africlub_fantasy/core/constants.dart';
import 'package:africlub_fantasy/models/player_gameweek_stats.dart';
import 'package:africlub_fantasy/models/squad_selection.dart';
import 'package:flutter/material.dart';

class GameweekSummaryWidget extends StatelessWidget {
  const GameweekSummaryWidget({
    required this.squad,
    required this.statsByPlayer,
    super.key,
  });

  final List<SquadSelection> squad;
  final Map<int, PlayerGameweekStats> statsByPlayer;

  @override
  Widget build(BuildContext context) {
    final events = squad
        .where((slot) => slot.player != null)
        .map((slot) {
          final stats = statsByPlayer[slot.playerId];
          if (stats == null) return null;
          if (stats.goals > 0) {
            return '${slot.player!.shortName} scored';
          }
          if (stats.assists > 0) {
            return '${slot.player!.shortName} assisted';
          }
          if (stats.redCards > 0) {
            return '${slot.player!.shortName} saw red';
          }
          if (stats.yellowCards > 0) {
            return '${slot.player!.shortName} booked';
          }
          return null;
        })
        .whereType<String>()
        .toList(growable: false);

    if (events.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Match timeline',
          style: FantasyTypography.h3.copyWith(
            color: FantasyColors.textPrimary,
          ),
        ),
        const SizedBox(height: FantasySpacing.sm),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (BuildContext context, int index) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: FantasySpacing.md,
                vertical: FantasySpacing.sm,
              ),
              decoration: BoxDecoration(
                color: FantasyColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: FantasyColors.border),
              ),
              child: Text(
                events[index],
                style: FantasyTypography.caption.copyWith(
                  color: FantasyColors.textPrimary,
                ),
              ),
            ),
            separatorBuilder: (_, __) =>
                const SizedBox(width: FantasySpacing.sm),
            itemCount: events.length,
          ),
        ),
      ],
    );
  }
}
