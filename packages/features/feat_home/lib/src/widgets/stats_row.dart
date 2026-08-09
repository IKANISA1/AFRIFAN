import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Home summary metrics — personal FET balance and, when known, supporter rank.
///
/// A zero rank is an unavailable sentinel and is not rendered. This lets an
/// owner-only membership read retain the supporter's balance without presenting
/// a synthetic `#000` rank.
class StatsRow extends StatelessWidget {
  final int globalFet;
  final int fanRank;
  final VoidCallback? onFetTap;
  final VoidCallback? onRankTap;

  const StatsRow({
    super.key,
    this.globalFet = 0,
    this.fanRank = 0,
    this.onFetTap,
    this.onRankTap,
  });

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
          label: context.afriL10n.homeFetLabel,
          value: _formatFet(globalFet),
          icon: AfriIcons.earn,
          onTap: onFetTap,
        ),
        if (fanRank > 0)
          AfriStat(
            label: context.afriL10n.homeRankLabel,
            value: '#${fanRank.toString().padLeft(3, '0')}',
            icon: AfriIcons.rank,
            accentColor: ColorTokens.clubAccent,
            onTap: onRankTap,
          ),
      ],
    );
  }
}
