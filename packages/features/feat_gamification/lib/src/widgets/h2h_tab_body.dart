import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Head-to-head tab content — shows historical encounters between two teams.
///
/// Universal match detail `H2H` tab with encounter list, win
/// distribution bar, and goal stats.
class H2hTabBody extends StatelessWidget {
  const H2hTabBody({
    super.key,
    required this.homeTeamName,
    required this.awayTeamName,
    required this.homeTeamShort,
    required this.awayTeamShort,
    this.encounters = const <H2hEncounter>[],
  });

  final String homeTeamName;
  final String awayTeamName;
  final String homeTeamShort;
  final String awayTeamShort;
  final List<H2hEncounter> encounters;

  @override
  Widget build(BuildContext context) {
    if (encounters.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: SpacingTokens.spacing16 + SpacingTokens.spacing2,
                height: SpacingTokens.spacing16 + SpacingTokens.spacing2,
                decoration: BoxDecoration(
                  color: ColorTokens.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(ShapeTokens.radiusXl),
                ),
                alignment: Alignment.center,
                child: Icon(
                  AfriIcons.versus,
                  size: SpacingTokens.spacing9,
                  color: ColorTokens.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              Text(
                'HEAD TO HEAD',
                style: TypographyTokens.titleLarge(
                  ColorTokens.onSurfaceVariant,
                ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.5),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                'Historical H2H records between $homeTeamShort and $awayTeamShort will appear here.',
                textAlign: TextAlign.center,
                style: TypographyTokens.bodySmall(),
              ),
            ],
          ),
        ),
      );
    }

    final homeWins = encounters.where((e) => e.homeScore > e.awayScore).length;
    final away = encounters.where((e) => e.awayScore > e.homeScore).length;
    final draws = encounters.length - homeWins - away;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      children: [
        // ── Win Distribution ──
        AfriSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WIN DISTRIBUTION',
                    style: TypographyTokens.metricLabel(
                      ColorTokens.onSurfaceVariant,
                    ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _DistMetric(
                        label: homeTeamShort,
                        value: '$homeWins',
                        highlight: true,
                      ),
                      _DistMetric(label: 'DRAWS', value: '$draws'),
                      _DistMetric(label: awayTeamShort, value: '$away'),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  // Visual bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(ShapeTokens.radiusSm),
                    child: SizedBox(
                      height: SpacingTokens.spacing3,
                      child: Row(
                        children: [
                          if (homeWins > 0)
                            Expanded(
                              flex: homeWins,
                              child: Container(color: ColorTokens.clubAccent),
                            ),
                          if (draws > 0)
                            Expanded(
                              flex: draws,
                              child: Container(
                                color: ColorTokens.surfaceContainerHigh,
                              ),
                            ),
                          if (away > 0)
                            Expanded(
                              flex: away,
                              child: Container(
                                color: ColorTokens.onSurfaceVariant.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
            .afriAnimate(context)
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.04, end: 0, duration: 400.ms),

        const SizedBox(height: SpacingTokens.spacing4),

        // ── Total goals ──
        Row(
          children: [
            Expanded(
              child: GlassCard(
                animate: false,
                child: Column(
                  children: [
                    Text(
                      '${encounters.fold<int>(0, (sum, e) => sum + e.homeScore)}',
                      style: TypographyTokens.headlineMedium(
                        ColorTokens.clubAccent,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: SpacingTokens.spacing1 / 2),
                    Text(
                      '$homeTeamShort GOALS',
                      style: TypographyTokens.labelSmall(
                        ColorTokens.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: SpacingTokens.spacing3),
            Expanded(
              child: GlassCard(
                animate: false,
                child: Column(
                  children: [
                    Text(
                      '${encounters.fold<int>(0, (sum, e) => sum + e.awayScore)}',
                      style: TypographyTokens.headlineMedium().copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing1 / 2),
                    Text(
                      '$awayTeamShort GOALS',
                      style: TypographyTokens.labelSmall(
                        ColorTokens.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: SpacingTokens.spacing5),

        Text(
          'RECENT ENCOUNTERS',
          style: TypographyTokens.metricLabel(
            ColorTokens.onSurfaceVariant,
          ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ),
        const SizedBox(height: SpacingTokens.spacing3),

        // ── Encounter List ──
        ...encounters.asMap().entries.map((entry) {
          final e = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
            child: GlassCard(
              animate: false,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.homeTeam,
                      style: TypographyTokens.bodyMedium(),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.spacing3,
                      vertical: SpacingTokens.spacing2,
                    ),
                    decoration: BoxDecoration(
                      color: ColorTokens.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
                    ),
                    child: Text(
                      '${e.homeScore} - ${e.awayScore}',
                      style: TypographyTokens.titleMedium().copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.awayTeam,
                      textAlign: TextAlign.end,
                      style: TypographyTokens.bodyMedium(),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _DistMetric extends StatelessWidget {
  const _DistMetric({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TypographyTokens.headlineMedium(
            highlight ? ColorTokens.clubAccent : ColorTokens.onSurface,
          ).copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: SpacingTokens.spacing1 / 2),
        Text(
          label,
          style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Model for a single H2H encounter row.
class H2hEncounter {
  const H2hEncounter({
    required this.homeTeam,
    required this.awayTeam,
    required this.homeScore,
    required this.awayScore,
    this.date,
    this.competition,
  });

  final String homeTeam;
  final String awayTeam;
  final int homeScore;
  final int awayScore;
  final String? date;
  final String? competition;
}
