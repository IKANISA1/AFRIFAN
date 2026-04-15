import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Top scorers section for League Hub.
///
/// Mirrors the fanafrika `LeagueHub.tsx` `TopScorers` section.
class TopScorersSection extends StatelessWidget {
  const TopScorersSection({
    super.key,
    this.scorers = const <TopScorerEntry>[],
  });

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
          'TOP SCORERS',
          style: TypographyTokens.monolithFont(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        ClayCard(
          child: Column(
            children: scorers.asMap().entries.map((entry) {
              final index = entry.key;
              final scorer = entry.value;
              return Column(
                children: [
                  if (index > 0)
                    Divider(
                      height: 1,
                      color: ColorTokens.ghostBorder,
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: SpacingTokens.spacing3,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          child: Text(
                            '${scorer.rank}',
                            style: TypographyTokens.monolithFont(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: scorer.rank <= 3
                                  ? ColorTokens.clubAccent
                                  : ColorTokens.onSurfaceVariant,
                            ),
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
                                style: TypographyTokens.editorialFont(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: ColorTokens.onSurfaceVariant,
                                  letterSpacing: 1.2,
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
                              style: TypographyTokens.monolithFont(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: ColorTokens.clubAccent,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Goals',
                              style: TypographyTokens.editorialFont(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: ColorTokens.onSurfaceVariant,
                                letterSpacing: 1,
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
