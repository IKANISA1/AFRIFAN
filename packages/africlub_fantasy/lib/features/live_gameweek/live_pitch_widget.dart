import 'package:africlub_fantasy/features/live_gameweek/player_score_badge_widget.dart';
import 'package:africlub_fantasy/features/squad_builder/pitch_layout_widget.dart';
import 'package:africlub_fantasy/models/player_gameweek_stats.dart';
import 'package:flutter/material.dart';

class LivePitchWidget extends StatelessWidget {
  const LivePitchWidget({
    required this.rows,
    required this.bench,
    required this.statsByPlayer,
    super.key,
  });

  final List<List<PitchSlotData>> rows;
  final List<PitchSlotData> bench;
  final Map<int, PlayerGameweekStats> statsByPlayer;

  @override
  Widget build(BuildContext context) {
    List<List<PitchSlotData>> decorateRows(List<List<PitchSlotData>> source) {
      return source
          .map(
            (row) => row
                .map(
                  (slot) => PitchSlotData(
                    label: slot.label,
                    position: slot.position,
                    player: slot.player,
                    onTap: slot.onTap,
                    isCaptain: slot.isCaptain,
                    isViceCaptain: slot.isViceCaptain,
                    trailing: slot.player == null
                        ? null
                        : PlayerScoreBadgeWidget(
                            points:
                                statsByPlayer[slot.player!.externalId]
                                    ?.rawPoints ??
                                0,
                          ),
                  ),
                )
                .toList(growable: false),
          )
          .toList(growable: false);
    }

    final decoratedBench = bench
        .map(
          (slot) => PitchSlotData(
            label: slot.label,
            position: slot.position,
            player: slot.player,
            onTap: slot.onTap,
            isCaptain: slot.isCaptain,
            isViceCaptain: slot.isViceCaptain,
            isBench: true,
            trailing: slot.player == null
                ? null
                : PlayerScoreBadgeWidget(
                    points:
                        statsByPlayer[slot.player!.externalId]?.rawPoints ?? 0,
                  ),
          ),
        )
        .toList(growable: false);

    return PitchLayoutWidget(
      rows: decorateRows(rows),
      bench: decoratedBench,
      readOnly: true,
    );
  }
}
