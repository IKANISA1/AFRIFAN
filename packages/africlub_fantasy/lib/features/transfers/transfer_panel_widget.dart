import 'package:africlub_fantasy/core/constants.dart';
import 'package:africlub_fantasy/models/squad_selection.dart';
import 'package:africlub_fantasy/features/shared/fantasy_ui.dart';
import 'package:flutter/material.dart';

class TransferPanelWidget extends StatelessWidget {
  const TransferPanelWidget({
    required this.title,
    required this.subtitle,
    required this.players,
    required this.selectedPlayerId,
    required this.onSelect,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<SquadSelection> players;
  final int? selectedPlayerId;
  final ValueChanged<SquadSelection> onSelect;

  @override
  Widget build(BuildContext context) {
    return FantasyGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FantasySectionHeader(title: title, subtitle: subtitle),
          const SizedBox(height: FantasySpacing.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.1,
              crossAxisSpacing: FantasySpacing.sm,
              mainAxisSpacing: FantasySpacing.sm,
            ),
            itemCount: players.length,
            itemBuilder: (BuildContext context, int index) {
              final player = players[index];
              final selected = selectedPlayerId == player.playerId;
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onSelect(player),
                child: Container(
                  padding: const EdgeInsets.all(FantasySpacing.sm),
                  decoration: BoxDecoration(
                    color: selected
                        ? FantasyColors.successGreen.withValues(alpha: 0.18)
                        : FantasyColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected
                          ? FantasyColors.successGreen
                          : FantasyColors.border,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(
                        Icons.swap_vert_circle_rounded,
                        color: FantasyColors.textPrimary,
                      ),
                      const SizedBox(height: FantasySpacing.xs),
                      Text(
                        player.player?.shortName ?? player.playerId.toString(),
                        textAlign: TextAlign.center,
                        style: FantasyTypography.caption.copyWith(
                          color: FantasyColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: FantasySpacing.xs),
                      Text(
                        '£${((player.player?.price ?? player.purchasePrice) / 10).toStringAsFixed(1)}',
                        style: FantasyTypography.label.copyWith(
                          color: FantasyColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
