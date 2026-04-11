import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Home summary metrics.
class StatsRow extends StatelessWidget {
  final int globalXp;
  final int fanRank;

  const StatsRow({super.key, this.globalXp = 42880, this.fanRank = 12});

  String _formatXp(int xp) {
    if (xp >= 1000) {
      final formatted = xp.toString();
      final buffer = StringBuffer();
      for (var i = 0; i < formatted.length; i++) {
        if (i > 0 && (formatted.length - i) % 3 == 0) {
          buffer.write(',');
        }
        buffer.write(formatted[i]);
      }
      return buffer.toString();
    }
    return xp.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AfriMetricTile(
            label: 'XP',
            value: _formatXp(globalXp),
            meta: 'Supporter total',
            icon: Icons.auto_graph_rounded,
          ),
        ),
        const SizedBox(width: SpacingTokens.spacing3),
        Expanded(
          child: AfriMetricTile(
            label: 'Rank',
            value: '#${fanRank.toString().padLeft(3, '0')}',
            meta: 'Club standing',
            icon: Icons.leaderboard_outlined,
            accentColor: ColorTokens.clubAccent,
          ),
        ),
      ],
    );
  }
}
