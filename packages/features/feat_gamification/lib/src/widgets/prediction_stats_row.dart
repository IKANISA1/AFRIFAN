import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Prediction stats summary widget for profile screen.
///
/// Mirrors the fanafrika `Profile.tsx` stats chips (FET balance, accuracy).
/// Shows total predictions, win rate, and FET earned in a compact row.
class PredictionStatsRow extends StatelessWidget {
  const PredictionStatsRow({
    super.key,
    required this.totalPredictions,
    required this.accuracy,
    required this.fetEarned,
    required this.rank,
  });

  final int totalPredictions;
  final double accuracy;
  final int fetEarned;
  final int rank;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            value: '$totalPredictions',
            label: 'PREDICTIONS',
            icon: Icons.sports_esports_rounded,
          ),
        ),
        const SizedBox(width: SpacingTokens.spacing2),
        Expanded(
          child: _StatBox(
            value: '${accuracy.toStringAsFixed(1)}%',
            label: 'ACCURACY',
            icon: Icons.gps_fixed_rounded,
            highlight: true,
          ),
        ),
        const SizedBox(width: SpacingTokens.spacing2),
        Expanded(
          child: _StatBox(
            value: '$fetEarned',
            label: 'FET EARNED',
            icon: Icons.toll_rounded,
          ),
        ),
        const SizedBox(width: SpacingTokens.spacing2),
        Expanded(
          child: _StatBox(
            value: '#$rank',
            label: 'RANK',
            icon: Icons.leaderboard_rounded,
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.value,
    required this.label,
    required this.icon,
    this.highlight = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: SpacingTokens.spacing3,
        horizontal: SpacingTokens.spacing2,
      ),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: highlight
            ? BorderTokens.all(
                color: ColorTokens.clubAccent.withValues(alpha: 0.3),
              )
            : BorderTokens.ghost(),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 16,
            color: highlight
                ? ColorTokens.clubAccent
                : ColorTokens.onSurfaceVariant,
          ),
          const SizedBox(height: SpacingTokens.spacing1),
          Text(
            value,
            style: TypographyTokens.monolithFont(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: highlight
                  ? ColorTokens.clubAccent
                  : ColorTokens.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TypographyTokens.editorialFont(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: ColorTokens.onSurfaceVariant,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
