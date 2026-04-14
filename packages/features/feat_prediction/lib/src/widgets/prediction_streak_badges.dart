import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/prediction_stats_models.dart';

/// Prediction streak badges — displayed on profile and My Predictions.
/// Shows earned milestone badges based on prediction win streaks.
class PredictionStreakBadges extends StatelessWidget {
  const PredictionStreakBadges({super.key, required this.stats});

  final PredictionStats stats;

  @override
  Widget build(BuildContext context) {
    if (!stats.hasHistory) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PREDICTION BADGES',
          style: TypographyTokens.monolithFont(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ColorTokens.onSurfaceVariant,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        Row(
          children: _milestones
              .map((m) => Expanded(
                    child: _BadgeTile(
                      milestone: m,
                      isEarned: _isMilestoneEarned(m),
                      index: _milestones.indexOf(m),
                    ),
                  ))
              .toList(growable: false),
        ),
      ],
    );
  }

  bool _isMilestoneEarned(_StreakMilestone m) {
    // Badge earned if total won >= milestone threshold
    return stats.totalWon >= m.threshold;
  }
}

class _StreakMilestone {
  const _StreakMilestone({
    required this.threshold,
    required this.label,
    required this.icon,
    required this.fetReward,
  });

  final int threshold;
  final String label;
  final IconData icon;
  final int fetReward;
}

const _milestones = <_StreakMilestone>[
  _StreakMilestone(
    threshold: 3,
    label: 'BRONZE',
    icon: Icons.local_fire_department_rounded,
    fetReward: 50,
  ),
  _StreakMilestone(
    threshold: 10,
    label: 'SILVER',
    icon: Icons.bolt_rounded,
    fetReward: 150,
  ),
  _StreakMilestone(
    threshold: 25,
    label: 'GOLD',
    icon: Icons.emoji_events_rounded,
    fetReward: 500,
  ),
  _StreakMilestone(
    threshold: 50,
    label: 'LEGEND',
    icon: Icons.star_rounded,
    fetReward: 1000,
  ),
];

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.milestone,
    required this.isEarned,
    required this.index,
  });

  final _StreakMilestone milestone;
  final bool isEarned;
  final int index;

  Color _badgeColor() {
    if (!isEarned) return ColorTokens.onSurfaceVariant;
    return switch (milestone.label) {
      'BRONZE' => const Color(0xFFCD7F32),
      'SILVER' => const Color(0xFFC0C0C0),
      'GOLD' => const Color(0xFFFFD700),
      'LEGEND' => ColorTokens.clubAccent,
      _ => ColorTokens.clubAccent,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _badgeColor();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isEarned
                  ? color.withValues(alpha: 0.15)
                  : ColorTokens.surfaceContainerHigh.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: BorderTokens.all(
                color: isEarned
                    ? color.withValues(alpha: 0.4)
                    : ColorTokens.glassFill,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Icon(
                milestone.icon,
                size: isEarned ? 26 : 20,
                color: isEarned
                    ? color
                    : ColorTokens.onSurface.withValues(alpha: 0.18),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            milestone.label,
            style: TypographyTokens.editorialFont(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isEarned
                  ? color
                  : ColorTokens.onSurfaceVariant.withValues(alpha: 0.4),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${milestone.threshold}W',
            style: TypographyTokens.editorialFont(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: ColorTokens.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      )
          .animate(delay: (index * 80).ms)
          .fadeIn(duration: 300.ms)
          .scale(begin: const Offset(0.85, 0.85), duration: 300.ms),
    );
  }
}
