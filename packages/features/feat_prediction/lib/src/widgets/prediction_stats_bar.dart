import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

import '../models/prediction_stats_models.dart';

/// Compact stats bar showing win rate, streak, and FET earned.
/// Displayed at the top of the My Predictions screen.
class PredictionStatsBar extends StatelessWidget {
  const PredictionStatsBar({super.key, required this.stats});

  final PredictionStats stats;

  @override
  Widget build(BuildContext context) {
    if (!stats.hasHistory) return const SizedBox.shrink();

    return GlassCard(
      animate: false,
      child: Row(
        children: [
          _StatItem(
            label: 'WIN RATE',
            value: '${stats.winRate.toStringAsFixed(0)}%',
            color: ColorTokens.success,
          ),
          _divider(),
          _StatItem(
            label: 'WON',
            value: stats.totalWon.toString(),
            color: ColorTokens.success,
          ),
          _divider(),
          _StatItem(
            label: 'LOST',
            value: stats.totalLost.toString(),
            color: ColorTokens.error,
          ),
          _divider(),
          _StatItem(
            label: 'STREAK',
            value: _streakLabel(),
            color: _streakColor(),
          ),
          _divider(),
          _StatItem(
            label: 'EARNED',
            value: '${stats.totalFetEarned}',
            suffix: ' FET',
            color: ColorTokens.clubAccent,
          ),
        ],
      ),
    );
  }

  String _streakLabel() {
    if (stats.currentStreak == 0) return '-';
    final prefix = stats.streakType == 'won' ? 'W' : 'L';
    return '$prefix${stats.currentStreak}';
  }

  Color _streakColor() {
    if (stats.streakType == 'won') return ColorTokens.success;
    if (stats.streakType == 'lost') return ColorTokens.error;
    return ColorTokens.onSurfaceVariant;
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: ColorTokens.onSurfaceVariant.withValues(alpha: 0.12),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
    this.suffix,
  });

  final String label;
  final String value;
  final Color color;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TypographyTokens.monolithFont(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (suffix != null)
                Text(
                  suffix!,
                  style: TypographyTokens.editorialFont(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: ColorTokens.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TypographyTokens.editorialFont(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: ColorTokens.onSurfaceVariant,
              letterSpacing: 1.0,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
