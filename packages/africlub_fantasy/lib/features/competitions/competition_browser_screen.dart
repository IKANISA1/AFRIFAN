import 'package:africlub_fantasy/core/constants.dart';
import 'package:africlub_fantasy/features/competitions/competition_card_widget.dart';
import 'package:africlub_fantasy/features/shared/fantasy_ui.dart';
import 'package:africlub_fantasy/models/competition.dart';
import 'package:africlub_fantasy/providers/competition_providers.dart';
import 'package:africlub_fantasy/providers/squad_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CompetitionBrowserScreen extends ConsumerStatefulWidget {
  const CompetitionBrowserScreen({super.key});

  @override
  ConsumerState<CompetitionBrowserScreen> createState() =>
      _CompetitionBrowserScreenState();
}

class _CompetitionBrowserScreenState
    extends ConsumerState<CompetitionBrowserScreen> {
  String _filter = 'All';

  List<String> _filtersFor(List<Competition> competitions) {
    final filters = <String>{'All'};
    if (competitions.any((item) => item.status == CompetitionStatus.active)) {
      filters.add('Playable');
    }
    if (competitions.any(
      (item) => item.competitionType == CompetitionType.seasonLong,
    )) {
      filters.add('Season long');
    }
    if (competitions.any(
      (item) => item.competitionType == CompetitionType.tournament,
    )) {
      filters.add('Tournament');
    }
    return filters.toList(growable: false);
  }

  List<Competition> _applyFilter(List<Competition> competitions) {
    switch (_filter) {
      case 'Playable':
        return competitions
            .where((item) => item.status == CompetitionStatus.active)
            .toList(growable: false);
      case 'Season long':
        return competitions
            .where((item) => item.competitionType == CompetitionType.seasonLong)
            .toList(growable: false);
      case 'Tournament':
        return competitions
            .where((item) => item.competitionType == CompetitionType.tournament)
            .toList(growable: false);
      default:
        return competitions;
    }
  }

  @override
  Widget build(BuildContext context) {
    final competitionsAsync = ref.watch(activeCompetitionsProvider);

    return FantasyScaffold(
      title: 'Fantasy',
      showBackButton: false,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeCompetitionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            FantasySpacing.md,
            FantasySpacing.sm,
            FantasySpacing.md,
            FantasySpacing.xl,
          ),
          children: <Widget>[
            competitionsAsync.when(
              data: (competitions) {
                final filters = _filtersFor(competitions);
                if (!filters.contains(_filter)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() => _filter = 'All');
                    }
                  });
                }
                final filtered = _applyFilter(competitions);
                if (competitions.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: FantasyStateCard.empty(
                      title: 'No competitions available',
                      message:
                          'Published fantasy competitions will appear here once your club enables them.',
                    ),
                  );
                }

                return Column(
                  children: <Widget>[
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (BuildContext context, int index) {
                          final label = filters[index];
                          return FantasyChipChoice(
                            label: label,
                            selected: _filter == label,
                            onTap: () => setState(() => _filter = label),
                          );
                        },
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: FantasySpacing.sm),
                        itemCount: filters.length,
                      ),
                    ),
                    const SizedBox(height: FantasySpacing.lg),
                    if (filtered.isEmpty)
                      const FantasyStateCard.empty(
                        title: 'No competitions in this filter',
                        message: 'Try a different competition view.',
                      )
                    else
                      ...filtered.map(
                        (competition) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: FantasySpacing.md,
                          ),
                          child: _CompetitionCardScope(
                            competition: competition,
                          ),
                        ),
                      ),
                  ],
                );
              },
              loading: () => Column(
                children: const <Widget>[
                  FantasySkeletonCard(),
                  SizedBox(height: FantasySpacing.md),
                  FantasySkeletonCard(),
                  SizedBox(height: FantasySpacing.md),
                  FantasySkeletonCard(),
                ],
              ),
              error: (error, _) => FantasyStateCard.error(
                title: 'Competitions failed to load',
                message: error.toString(),
                onRetry: () => ref.invalidate(activeCompetitionsProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompetitionCardScope extends ConsumerWidget {
  const _CompetitionCardScope({required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(myEntryProvider(competition.id));
    final gameweekAsync = ref.watch(currentGameweekProvider(competition.id));

    return gameweekAsync.when(
      data: (gameweek) => CompetitionCardWidget(
        competition: competition,
        gameweek: gameweek,
        entry: entryAsync.valueOrNull,
        onOpen: () {
          final route = entryAsync.valueOrNull == null ? 'build' : 'live';
          context.push('/fantasy/${competition.slug}/$route');
        },
      ),
      loading: () => CompetitionCardWidget(
        competition: competition,
        gameweek: null,
        entry: entryAsync.valueOrNull,
        onOpen: () {
          final route = entryAsync.valueOrNull == null ? 'build' : 'live';
          context.push('/fantasy/${competition.slug}/$route');
        },
      ),
      error: (_, __) => CompetitionCardWidget(
        competition: competition,
        gameweek: null,
        entry: entryAsync.valueOrNull,
        onOpen: () {
          final route = entryAsync.valueOrNull == null ? 'build' : 'live';
          context.push('/fantasy/${competition.slug}/$route');
        },
      ),
    );
  }
}
