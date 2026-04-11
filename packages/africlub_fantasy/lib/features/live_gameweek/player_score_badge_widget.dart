import 'package:africlub_fantasy/core/constants.dart';
import 'package:flutter/material.dart';

class PlayerScoreBadgeWidget extends StatelessWidget {
  const PlayerScoreBadgeWidget({required this.points, super.key});

  final int points;

  Color get _color {
    if (points > 0) return FantasyColors.successGreen;
    if (points < 0) return FantasyColors.dangerRed;
    return FantasyColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$points pts',
        style: FantasyTypography.label.copyWith(color: _color),
      ),
    );
  }
}
