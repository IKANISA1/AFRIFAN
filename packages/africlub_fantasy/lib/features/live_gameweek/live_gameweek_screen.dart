import 'package:africlub_fantasy/core/constants.dart';
import 'package:africlub_fantasy/features/live_gameweek/gameweek_summary_widget.dart';
import 'package:africlub_fantasy/features/live_gameweek/live_pitch_widget.dart';
import 'package:africlub_fantasy/features/live_gameweek/score_ticker_widget.dart';
import 'package:africlub_fantasy/features/shared/fantasy_ui.dart';
import 'package:africlub_fantasy/features/squad_builder/pitch_layout_widget.dart';
import 'package:africlub_fantasy/models/entry_gameweek_score.dart';
import 'package:africlub_fantasy/models/squad_selection.dart';
import 'package:africlub_fantasy/providers/competition_providers.dart';
import 'package:africlub_fantasy/providers/realtime_providers.dart';
import 'package:africlub_fantasy/providers/scoring_providers.dart';
import 'package:africlub_fantasy/providers/squad_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LiveGameweekScreen extends ConsumerWidget {
  const LiveGameweekScreen({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final competitionAsync = ref.watch(competitionProvider(slug));

    return FantasyScaffold(
      title: 'Live Gameweek',
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: FantasyColors.surface,
        foregroundColor: FantasyColors.textPrimary,
        onPressed: () => context.push('/fantasy/$slug/leaderboard'),
        label: const Text('Full Stats'),
        icon: const Icon(Icons.insights_rounded),
      ),
      child: competitionAsync.when(
        data: (competition) {
          final entryAsync = ref.watch(myEntryProvider(competition.id));
          final gwAsync = ref.watch(currentGameweekProvider(competition.id));

          return entryAsync.when(
            data: (entry) {
              if (entry == null) {
                return const Center(
                  child: FantasyStateCard.empty(
                    title: 'No fantasy entry found',
                    message: 'Build your squad first to unlock live scoring.',
                  ),
                );
              }

              return gwAsync.when(
                data: (gameweek) {
                  if (gameweek == null) {
                    return const Center(
                      child: FantasyStateCard.empty(
                        title: 'No live gameweek',
                        message: 'There is no active scoring window right now.',
                      ),
                    );
                  }

                  final squadAsync = ref.watch(
                    squadForGameweekProvider((
                      entryId: entry.id,
                      gameweekId: gameweek.id,
                    )),
                  );
                  final liveScoreAsync = ref.watch(
                    liveEntryScoreProvider(entry.id),
                  );
                  final scoreAsync = ref.watch(
                    gameweekScoreProvider((
                      entryId: entry.id,
                      gameweekId: gameweek.id,
                    )),
                  );
                  final statsAsync = ref.watch(
                    livePlayerStatsProvider(gameweek.id),
                  );

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(
                        gameweekScoreProvider((
                          entryId: entry.id,
                          gameweekId: gameweek.id,
                        )),
                      );
                      ref.invalidate(
                        squadForGameweekProvider((
                          entryId: entry.id,
                          gameweekId: gameweek.id,
                        )),
                      );
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(FantasySpacing.md),
                      children: <Widget>[
                        ScoreTickerWidget(
                          label: _tickerLabel(
                            gameweek.number,
                            liveScoreAsync.valueOrNull ??
                                scoreAsync.valueOrNull,
                            entry,
                          ),
                        ),
                        const SizedBox(height: FantasySpacing.md),
                        squadAsync.when(
                          data: (squad) => statsAsync.when(
                            data: (stats) {
                              final statsMap = {
                                for (final item in stats) item.playerId: item,
                              };
                              final rows = _rowsFromSquad(squad);
                              final bench = _benchFromSquad(squad);

                              return Column(
                                children: <Widget>[
                                  LivePitchWidget(
                                    rows: rows,
                                    bench: bench,
                                    statsByPlayer: statsMap,
                                  ),
                                  const SizedBox(height: FantasySpacing.lg),
                                  GameweekSummaryWidget(
                                    squad: squad,
                                    statsByPlayer: statsMap,
                                  ),
                                ],
                              );
                            },
                            loading: () =>
                                const FantasySkeletonCard(height: 560),
                            error: (error, _) => FantasyStateCard.error(
                              title: 'Live stats failed to load',
                              message: error.toString(),
                            ),
                          ),
                          loading: () => const FantasySkeletonCard(height: 560),
                          error: (error, _) => FantasyStateCard.error(
                            title: 'Squad failed to load',
                            message: error.toString(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: FantasyStateCard.loading()),
                error: (error, _) => Center(
                  child: FantasyStateCard.error(
                    title: 'Gameweek failed to load',
                    message: error.toString(),
                  ),
                ),
              );
            },
            loading: () => const Center(child: FantasyStateCard.loading()),
            error: (error, _) => Center(
              child: FantasyStateCard.error(
                title: 'Entry failed to load',
                message: error.toString(),
              ),
            ),
          );
        },
        loading: () => const Center(child: FantasyStateCard.loading()),
        error: (error, _) => Center(
          child: FantasyStateCard.error(
            title: 'Competition failed to load',
            message: error.toString(),
          ),
        ),
      ),
    );
  }

  String _tickerLabel(int gameweekNumber, EntryGameweekScore? score, entry) {
    final points = score?.points ?? 0;
    final rank = score?.rank ?? entry.overallRank;
    return 'GW$gameweekNumber · $points pts · Rank #${rank ?? '-'}';
  }

  List<List<PitchSlotData>> _rowsFromSquad(List<SquadSelection> squad) {
    final starters = squad
        .where((slot) => slot.isStarter)
        .toList(growable: false);
    final grouped = <List<SquadSelection>>[
      starters
          .where((slot) => slot.position.name == 'gk')
          .toList(growable: false),
      starters
          .where((slot) => slot.position.name == 'def')
          .toList(growable: false),
      starters
          .where((slot) => slot.position.name == 'mid')
          .toList(growable: false),
      starters
          .where((slot) => slot.position.name == 'fwd')
          .toList(growable: false),
    ];
    return grouped
        .map((row) {
          return row
              .map(
                (slot) => PitchSlotData(
                  label: slot.position.name.toUpperCase(),
                  position: slot.position,
                  player: slot.player,
                  onTap: () {},
                  isCaptain: slot.isCaptain,
                  isViceCaptain: slot.isViceCaptain,
                ),
              )
              .toList(growable: false);
        })
        .toList(growable: false);
  }

  List<PitchSlotData> _benchFromSquad(List<SquadSelection> squad) {
    final bench = squad.where((slot) => !slot.isStarter).toList(growable: false)
      ..sort(
        (left, right) =>
            (left.benchOrder ?? 9).compareTo(right.benchOrder ?? 9),
      );
    return bench
        .map(
          (slot) => PitchSlotData(
            label: 'Bench ${(slot.benchOrder ?? 0)}',
            position: slot.position,
            player: slot.player,
            onTap: () {},
            isCaptain: slot.isCaptain,
            isViceCaptain: slot.isViceCaptain,
            isBench: true,
          ),
        )
        .toList(growable: false);
  }
}
