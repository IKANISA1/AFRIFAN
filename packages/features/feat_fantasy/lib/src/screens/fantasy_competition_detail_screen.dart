import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/fantasy_models.dart';
import '../providers/fantasy_providers.dart';

class FantasyCompetitionDetailScreen extends ConsumerWidget {
  const FantasyCompetitionDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final competitionAsync = ref.watch(fantasyCompetitionProvider(slug));
    final leaderboardAsync = ref.watch(fantasyLeaderboardProvider(slug));

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Fantasy competition'),
      ),
      body: GradientBackground(
        child: SafeArea(
          top: false,
          child: competitionAsync.when(
            data: (competition) {
              if (competition == null) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(SpacingTokens.spacing6),
                    child: Text('Competition not found.'),
                  ),
                );
              }

              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                children: [
                  _Hero(competition: competition),
                  const SizedBox(height: SpacingTokens.spacing4),
                  _Actions(competition: competition),
                  const SizedBox(height: SpacingTokens.spacing4),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What this mode means'.toUpperCase(),
                          style: TypographyTokens.titleMedium().copyWith(
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        Text(
                          competition.mode == FantasyCompetitionMode.tournament
                              ? 'Tournament fantasy compresses decisions into a short, high-intensity window. Stage progression, transfer resets, and knockout survival matter more than long-run price mechanics.'
                              : 'Season-long fantasy rewards planning across multiple rounds. Transfers, captaincy, and fixture swings shape rank movement over time.',
                          style: TypographyTokens.bodyMedium(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Top managers'.toUpperCase(),
                          style: TypographyTokens.titleMedium().copyWith(
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        leaderboardAsync.when(
                          data: (rows) {
                            if (rows.isEmpty) {
                              return Text(
                                'No public leaderboard is available for this competition yet.',
                                style: TypographyTokens.bodySmall(),
                              );
                            }
                            return Column(
                              children: rows
                                  .take(5)
                                  .map(
                                    (row) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: SpacingTokens.spacing3,
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 36,
                                            child: Text(
                                              '#${row.rank}',
                                              style:
                                                  TypographyTokens.labelLarge()
                                                      .copyWith(
                                                        color: ColorTokens
                                                            .clubAccent,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              row.teamName,
                                              style:
                                                  TypographyTokens.bodyMedium(),
                                            ),
                                          ),
                                          Text(
                                            '${row.points} pts',
                                            style: TypographyTokens.labelLarge()
                                                .copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            );
                          },
                          loading: () => const AfriSkeletonList(itemCount: 3),
                          error: (_, __) => Text(
                            'Leaderboard data is temporarily unavailable.',
                            style: TypographyTokens.bodySmall(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(itemCount: 3),
            ),
            error: (_, __) => const Center(
              child: Padding(
                padding: EdgeInsets.all(SpacingTokens.spacing6),
                child: Text('Competition details failed to load.'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.competition});

  final FantasyCompetitionSummary competition;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            competition.name.toUpperCase(),
            style: TypographyTokens.monolithFont(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: ColorTokens.onSurface,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            '${competition.season}  •  ${competition.modeLabel}  •  ${competition.statusLabel}',
            style: TypographyTokens.labelLarge().copyWith(
              color: ColorTokens.clubAccent,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Text(competition.heroBody, style: TypographyTokens.bodyMedium()),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.competition});

  final FantasyCompetitionSummary competition;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: SpacingTokens.spacing3,
      runSpacing: SpacingTokens.spacing3,
      children: [
        FilledButton.icon(
          onPressed: () => context.push('/fantasy/${competition.slug}/rules'),
          icon: const Icon(Icons.rule_rounded),
          label: const Text('Rules'),
        ),
        FilledButton.tonalIcon(
          onPressed: () =>
              context.push('/fantasy/${competition.slug}/leaderboard'),
          icon: const Icon(Icons.leaderboard_rounded),
          label: const Text('Leaderboard'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => context.push(
            '/fantasy/${competition.slug}/${competition.hasEntry ? 'squad' : 'entry'}',
          ),
          icon: const Icon(Icons.playlist_add_check_circle_rounded),
          label: Text(competition.hasEntry ? 'Manage entry' : 'Create entry'),
        ),
      ],
    );
  }
}
