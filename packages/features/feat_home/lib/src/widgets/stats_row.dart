import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Home summary metrics — using shared AfriStatRow for consistency.
class StatsRow extends StatelessWidget {
  final int globalFet;
  final int fanRank;

  const StatsRow({super.key, this.globalFet = 42880, this.fanRank = 12});

  String _formatFet(int fet) {
    if (fet >= 1000) {
      final formatted = fet.toString();
      final buffer = StringBuffer();
      for (var i = 0; i < formatted.length; i++) {
        if (i > 0 && (formatted.length - i) % 3 == 0) {
          buffer.write(',');
        }
        buffer.write(formatted[i]);
      }
      return buffer.toString();
    }
    return fet.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AfriStatRow(
      stats: [
        AfriStat(
          label: 'FET',
          value: _formatFet(globalFet),
          icon: AfriIcons.earn,
        ),
        AfriStat(
          label: 'Rank',
          value: '#${fanRank.toString().padLeft(3, '0')}',
          icon: AfriIcons.rank,
          accentColor: ColorTokens.clubAccent,
        ),
      ],
    );
  }
}
