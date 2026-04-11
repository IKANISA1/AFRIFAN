import 'package:africlub_fantasy/core/constants.dart';
import 'package:africlub_fantasy/features/shared/fantasy_ui.dart';
import 'package:africlub_fantasy/features/world_cup/bracket_node_widget.dart';
import 'package:africlub_fantasy/features/world_cup/stage_advance_banner.dart';
import 'package:africlub_fantasy/models/world_cup_bracket_match.dart';
import 'package:africlub_fantasy/providers/competition_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class WCBracketScreen extends ConsumerWidget {
  const WCBracketScreen({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final competitionAsync = ref.watch(competitionProvider(slug));

    return FantasyScaffold(
      title: 'World Cup Bracket',
      child: competitionAsync.when(
        data: (competition) {
          final standingsAsync = ref.watch(worldCupStandingsProvider);
          final bracketAsync = ref.watch(
            worldCupBracketProvider(competition.id),
          );

          return standingsAsync.when(
            data: (standings) => bracketAsync.when(
              data: (matches) => OrientationBuilder(
                builder: (context, orientation) {
                  final groups = _groupStandings(standings);
                  final stages = _groupStages(matches);
                  return ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(FantasySpacing.md),
                    children: <Widget>[
                      SizedBox(
                        width: orientation == Orientation.landscape ? 420 : 320,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            StageAdvanceBanner(
                              label: _buildBannerLabel(matches),
                            ),
                            const SizedBox(height: FantasySpacing.md),
                            Text(
                              'Groups',
                              style: FantasyTypography.h2.copyWith(
                                color: FantasyColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: FantasySpacing.md),
                            Expanded(
                              child: GridView.count(
                                crossAxisCount:
                                    orientation == Orientation.landscape
                                    ? 3
                                    : 2,
                                mainAxisSpacing: FantasySpacing.md,
                                crossAxisSpacing: FantasySpacing.md,
                                childAspectRatio: 1.2,
                                children: groups.entries
                                    .map(
                                      (entry) => _GroupCard(
                                        group: entry.key,
                                        rows: entry.value,
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: FantasySpacing.lg),
                      SizedBox(
                        width: 760,
                        child: ListView(
                          children: stages.entries
                              .map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: FantasySpacing.md,
                                  ),
                                  child: _StageColumn(
                                    title: entry.key,
                                    matches: entry.value,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ],
                  );
                },
              ),
              loading: () => const Center(child: FantasyStateCard.loading()),
              error: (error, _) => Center(
                child: FantasyStateCard.error(
                  title: 'Bracket failed to load',
                  message: error.toString(),
                ),
              ),
            ),
            loading: () => const Center(child: FantasyStateCard.loading()),
            error: (error, _) => Center(
              child: FantasyStateCard.error(
                title: 'Standings failed to load',
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

  Map<String, List<Map<String, dynamic>>> _groupStandings(
    List<Map<String, dynamic>> standings,
  ) {
    if (standings.isEmpty) {
      return <String, List<Map<String, dynamic>>>{
        for (final label in List<String>.generate(
          12,
          (index) => String.fromCharCode(65 + index),
        ))
          label: <Map<String, dynamic>>[],
      };
    }

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in standings) {
      final group = row['group']?.toString() ?? 'A';
      grouped.putIfAbsent(group, () => <Map<String, dynamic>>[]).add(row);
    }
    return grouped;
  }

  Map<String, List<WorldCupBracketMatch>> _groupStages(
    List<WorldCupBracketMatch> matches,
  ) {
    final grouped = <String, List<WorldCupBracketMatch>>{};
    for (final match in matches) {
      grouped
          .putIfAbsent(match.stage, () => <WorldCupBracketMatch>[])
          .add(match);
    }
    final entries = grouped.entries.toList()
      ..sort((left, right) {
        final leftOrder = left.value.isEmpty ? 99 : left.value.first.stageOrder;
        final rightOrder = right.value.isEmpty
            ? 99
            : right.value.first.stageOrder;
        return leftOrder.compareTo(rightOrder);
      });
    return <String, List<WorldCupBracketMatch>>{
      for (final entry in entries) entry.key: entry.value,
    };
  }

  String _buildBannerLabel(List<WorldCupBracketMatch> matches) {
    if (matches.isEmpty) {
      return 'Knockout fixtures will appear here once tournament data syncs.';
    }
    final live = matches.where((match) => match.isLive).length;
    final finished = matches.where((match) => match.isFinished).length;
    if (live > 0) {
      return '$live knockout fixtures are live. Stage-advance scoring will update automatically when results lock.';
    }
    return '$finished knockout fixtures have synced. Follow the bracket from groups through the final.';
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.rows});

  final String group;
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    return FantasyGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Group $group',
            style: FantasyTypography.h3.copyWith(
              color: FantasyColors.textPrimary,
            ),
          ),
          const SizedBox(height: FantasySpacing.sm),
          Expanded(
            child: rows.isEmpty
                ? Text(
                    'No table data yet',
                    style: FantasyTypography.caption.copyWith(
                      color: FantasyColors.textSecondary,
                    ),
                  )
                : Column(
                    children: rows
                        .take(4)
                        .map(
                          (row) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: FantasySpacing.sm,
                            ),
                            child: Row(
                              children: <Widget>[
                                const Text('🏳️'),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    row['nation']?.toString() ??
                                        row['team_name']?.toString() ??
                                        'Nation',
                                    style: FantasyTypography.caption.copyWith(
                                      color: FantasyColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${row['points'] ?? row['pts'] ?? 0} pts',
                                  style: FantasyTypography.label.copyWith(
                                    color: FantasyColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StageColumn extends StatelessWidget {
  const _StageColumn({required this.title, required this.matches});

  final String title;
  final List<WorldCupBracketMatch> matches;

  @override
  Widget build(BuildContext context) {
    return FantasyGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: FantasyTypography.h3.copyWith(
              color: FantasyColors.textPrimary,
            ),
          ),
          const SizedBox(height: FantasySpacing.md),
          Wrap(
            spacing: FantasySpacing.md,
            runSpacing: FantasySpacing.md,
            children: matches
                .map(
                  (match) => BracketNodeWidget(
                    label: '${match.homeTeamName}\nvs\n${match.awayTeamName}',
                    subtitle: match.scoreLabel,
                    statusLabel: _statusLabel(match),
                    highlight: match.isLive || match.isFinished,
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  String _statusLabel(WorldCupBracketMatch match) {
    if (match.isFinished) {
      return 'Final';
    }
    if (match.isLive) {
      return 'Live';
    }
    if (match.kickoffAt == null) {
      return match.label;
    }
    return DateFormat('dd MMM, HH:mm').format(match.kickoffAt!.toLocal());
  }
}
