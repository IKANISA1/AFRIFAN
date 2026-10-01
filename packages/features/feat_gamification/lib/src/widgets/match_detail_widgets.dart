import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

import '../models/prediction_models.dart';
import '../widgets/stats_panel.dart';

/// The "Stats" tab — shows match statistics or derived score-based stats.
class MatchStatsTabBody extends StatelessWidget {
  const MatchStatsTabBody({
    super.key,
    required this.fixture,
    required this.stats,
  });

  final FixtureSummary fixture;
  final List<MatchStatRow> stats;

  @override
  Widget build(BuildContext context) {
    final hasScores = fixture.homeScore != null && fixture.awayScore != null;

    if (!hasScores) {
      return ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        children: [
          const SizedBox(height: SpacingTokens.spacing8),
          AfriEmptyView(
            compact: true,
            title: context.afriL10n.gameStatsNotAvailableYet,
            message: context.afriL10n.predictStatsEmpty,
            icon: AfriIcons.chart,
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriSurfaceCard(
            child: Row(
              children: [
                Icon(
                  AfriIcons.statusInfo,
                  size: SpacingTokens.spacing4,
                  color: ColorTokens.onSurfaceVariant,
                ),
                const SizedBox(width: SpacingTokens.spacing2),
                Expanded(
                  child: Text(
                    context.afriL10n.gameLiveStatsUpdating,
                    style: TypographyTokens.bodySmall(),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (stats.isNotEmpty) {
      return ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        children: [
          StatsPanel(
            stats: stats,
            homeLabel: fixture.homeTeamShort,
            awayLabel: fixture.awayTeamShort,
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriSurfaceCard(
            child: Row(
              children: [
                Icon(
                  AfriIcons.statusInfo,
                  size: SpacingTokens.spacing4,
                  color: ColorTokens.onSurfaceVariant,
                ),
                const SizedBox(width: SpacingTokens.spacing2),
                Expanded(
                  child: Text(
                    fixture.isLive
                        ? context.afriL10n.gameLiveMatchDataUpdating
                        : context.afriL10n.gameStructuredMatchStats,
                    style: TypographyTokens.bodySmall(),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final homeGoals = fixture.homeScore ?? 0;
    final awayGoals = fixture.awayScore ?? 0;
    final totalGoals = homeGoals + awayGoals;

    final liveStats = <MatchStatRow>[
      MatchStatRow(
        label: context.afriL10n.gameGoals,
        leftValue: homeGoals.toDouble(),
        rightValue: awayGoals.toDouble(),
        leftDisplay: homeGoals.toString(),
        rightDisplay: awayGoals.toString(),
      ),
      MatchStatRow(
        label: context.afriL10n.gameTotalGoals,
        leftValue: totalGoals.toDouble(),
        rightValue: totalGoals.toDouble(),
        leftDisplay: totalGoals.toString(),
        rightDisplay: totalGoals.toString(),
      ),
    ];

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      children: [
        StatsPanel(
          stats: liveStats,
          homeLabel: fixture.homeTeamShort,
          awayLabel: fixture.awayTeamShort,
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        AfriSurfaceCard(
          child: Row(
            children: [
              Icon(
                AfriIcons.statusInfo,
                size: SpacingTokens.spacing4,
                color: ColorTokens.onSurfaceVariant,
              ),
              const SizedBox(width: SpacingTokens.spacing2),
              Expanded(
                child: Text(
                  fixture.isLive
                      ? context.afriL10n.gameLiveStatsUpdating
                      : context.afriL10n.gameFinalMatchStats,
                  style: TypographyTokens.bodySmall(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Pick Type Card
// ══════════════════════════════════════════════════════════════════════════════

/// Single pick-type card with outcome pills + community bar.
class MatchMetaLink extends StatelessWidget {
  const MatchMetaLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      onTap: onTap,
      semanticsLabel: label,
      excludeChildSemantics: true,
      builder: (context, _) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing3,
          vertical: SpacingTokens.spacing2,
        ),
        decoration: BoxDecoration(
          color: ColorTokens.surfaceContainerLow,
          borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
          border: BorderTokens.all(color: ColorTokens.ghostBorder),
        ),
        child: Text(
          label,
          style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
        ),
      ),
    );
  }
}
