import 'package:africlub_fantasy/core/constants.dart';
import 'package:africlub_fantasy/features/leaderboard/league_table_widget.dart';
import 'package:africlub_fantasy/features/leaderboard/rank_row_widget.dart';
import 'package:africlub_fantasy/features/shared/fantasy_ui.dart';
import 'package:africlub_fantasy/models/entry_gameweek_score.dart';
import 'package:africlub_fantasy/models/fantasy_league.dart';
import 'package:africlub_fantasy/providers/competition_providers.dart';
import 'package:africlub_fantasy/providers/league_providers.dart';
import 'package:africlub_fantasy/providers/squad_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({required this.slug, super.key});

  final String slug;

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );
  FantasyLeague? _selectedLeague;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final competitionAsync = ref.watch(competitionProvider(widget.slug));

    return FantasyScaffold(
      title: 'Leaderboard',
      appBarBottom: TabBar(
        controller: _tabController,
        labelColor: FantasyColors.textPrimary,
        unselectedLabelColor: FantasyColors.textSecondary,
        indicatorColor: FantasyColors.successGreen,
        tabs: const <Tab>[
          Tab(text: 'Global'),
          Tab(text: 'My Leagues'),
        ],
      ),
      child: competitionAsync.when(
        data: (competition) {
          final currentGwAsync = ref.watch(
            currentGameweekProvider(competition.id),
          );
          final entryAsync = ref.watch(myEntryProvider(competition.id));

          return currentGwAsync.when(
            data: (gameweek) {
              final globalAsync = ref.watch(
                globalLeaderboardProvider((
                  competitionId: competition.id,
                  gameweekId: gameweek?.id,
                )),
              );
              final leaguesAsync = ref.watch(myLeaguesProvider(competition.id));

              return TabBarView(
                controller: _tabController,
                children: <Widget>[
                  globalAsync.when(
                    data: (rows) => _GlobalLeaderboardTab(
                      rows: rows,
                      myEntryId: entryAsync.valueOrNull?.id,
                    ),
                    loading: () =>
                        const Center(child: FantasyStateCard.loading()),
                    error: (error, _) => Center(
                      child: FantasyStateCard.error(
                        title: 'Leaderboard failed to load',
                        message: error.toString(),
                      ),
                    ),
                  ),
                  leaguesAsync.when(
                    data: (leagues) {
                      if (leagues.isEmpty) {
                        return const Center(
                          child: FantasyStateCard.empty(
                            title: 'No leagues joined',
                            message:
                                'Create or join a league to track private standings.',
                          ),
                        );
                      }

                      final selected = _selectedLeague ?? leagues.first;
                      final tableAsync = gameweek == null
                          ? const AsyncValue<List<EntryGameweekScore>>.data(
                              <EntryGameweekScore>[],
                            )
                          : ref.watch(
                              leagueTableProvider((
                                leagueId: selected.id,
                                gameweekId: gameweek.id,
                              )),
                            );

                      return ListView(
                        padding: const EdgeInsets.all(FantasySpacing.md),
                        children: <Widget>[
                          Wrap(
                            spacing: FantasySpacing.sm,
                            runSpacing: FantasySpacing.sm,
                            children: leagues
                                .map(
                                  (league) => FantasyChipChoice(
                                    label: league.name,
                                    selected: selected.id == league.id,
                                    onTap: () => setState(
                                      () => _selectedLeague = league,
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                          const SizedBox(height: FantasySpacing.md),
                          FantasyGlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                FantasySectionHeader(
                                  title: selected.name,
                                  subtitle:
                                      'Code ${selected.code} · ${selected.memberCount} members',
                                ),
                                const SizedBox(height: FantasySpacing.md),
                                tableAsync.when(
                                  data: (rows) => LeagueTableWidget(
                                    rows: rows,
                                    highlightEntryId:
                                        entryAsync.valueOrNull?.id,
                                  ),
                                  loading: () =>
                                      const FantasySkeletonCard(height: 260),
                                  error: (error, _) => FantasyStateCard.error(
                                    title: 'League table failed to load',
                                    message: error.toString(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () =>
                        const Center(child: FantasyStateCard.loading()),
                    error: (error, _) => Center(
                      child: FantasyStateCard.error(
                        title: 'Leagues failed to load',
                        message: error.toString(),
                      ),
                    ),
                  ),
                ],
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
            title: 'Competition failed to load',
            message: error.toString(),
          ),
        ),
      ),
    );
  }
}

class _GlobalLeaderboardTab extends StatelessWidget {
  const _GlobalLeaderboardTab({required this.rows, required this.myEntryId});

  final List<EntryGameweekScore> rows;
  final String? myEntryId;

  @override
  Widget build(BuildContext context) {
    final myRow = myEntryId == null
        ? null
        : rows.where((row) => row.entryId == myEntryId).firstOrNull;

    return Stack(
      children: <Widget>[
        ListView(
          padding: const EdgeInsets.fromLTRB(
            FantasySpacing.md,
            FantasySpacing.md,
            FantasySpacing.md,
            120,
          ),
          children: <Widget>[
            LeagueTableWidget(rows: rows.take(100).toList(growable: false)),
          ],
        ),
        if (myRow != null)
          Positioned(
            left: FantasySpacing.md,
            right: FantasySpacing.md,
            bottom: FantasySpacing.md,
            child: RankRowWidget(entry: myRow, highlight: true),
          ),
      ],
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
