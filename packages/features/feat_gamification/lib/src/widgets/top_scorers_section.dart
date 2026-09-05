import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Top scorers section for League Hub.
///
/// Mirrors the fanafrika `LeagueHub.tsx` `TopScorers` section.
class TopScorersSection extends StatelessWidget {
  const TopScorersSection({super.key, this.scorers = const <TopScorerEntry>[]});

  final List<TopScorerEntry> scorers;

  @override
  Widget build(BuildContext context) {
    if (scorers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.afriL10n.gameTopScorers,
          style: TypographyTokens.titleLarge().copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: TypographyTokens.trackingNone,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        AfriSurfaceCard(
          child: Column(
            children: scorers.asMap().entries.map((entry) {
              final index = entry.key;
              final scorer = entry.value;
              return Column(
                children: [
                  if (index > 0) const AfriDivider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: SpacingTokens.spacing3,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: SpacingTokens.spacing5,
                          child: Text(
                            '${scorer.rank}',
                            style: TypographyTokens.titleSmall(
                              scorer.rank <= 3
                                  ? ColorTokens.primaryContainer
                                  : ColorTokens.onSurfaceVariant,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: SpacingTokens.spacing3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                scorer.name,
                                style: TypographyTokens.titleSmall(),
                              ),
                              Text(
                                scorer.team,
                                style:
                                    TypographyTokens.metricLabel(
                                      ColorTokens.onSurfaceVariant,
                                    ).copyWith(
                                      fontWeight: FontWeight.w600,
                                      letterSpacing:
                                          TypographyTokens.trackingNone,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${scorer.goals}',
                              style: TypographyTokens.headlineSmall(
                                ColorTokens.primaryContainer,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: SpacingTokens.spacing1),
                            Text(
                              context.afriL10n.gameGoals,
                              style:
                                  TypographyTokens.metricLabel(
                                    ColorTokens.onSurfaceVariant,
                                  ).copyWith(
                                    fontWeight: FontWeight.w600,
                                    letterSpacing:
                                        TypographyTokens.trackingNone,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// Model for a top scorer row.
class TopScorerEntry {
  const TopScorerEntry({
    required this.rank,
    required this.name,
    required this.team,
    required this.goals,
  });

  final int rank;
  final String name;
  final String team;
  final int goals;
}
