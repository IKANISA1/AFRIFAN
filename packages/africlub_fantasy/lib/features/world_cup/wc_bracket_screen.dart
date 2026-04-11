import 'package:africlub_fantasy/core/constants.dart';
import 'package:africlub_fantasy/features/shared/fantasy_ui.dart';
import 'package:africlub_fantasy/features/world_cup/bracket_node_widget.dart';
import 'package:africlub_fantasy/features/world_cup/stage_advance_banner.dart';
import 'package:africlub_fantasy/providers/competition_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WCBracketScreen extends ConsumerWidget {
  const WCBracketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standingsAsync = ref.watch(worldCupStandingsProvider);

    return OrientationBuilder(
      builder: (context, orientation) {
        return FantasyScaffold(
          title: 'World Cup Bracket',
          child: standingsAsync.when(
            data: (standings) {
              final groups = _groupStandings(standings);
              return ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(FantasySpacing.md),
                children: <Widget>[
                  SizedBox(
                    width: orientation == Orientation.landscape ? 420 : 320,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const StageAdvanceBanner(
                          label:
                              'Your tracked nation just advanced to the next round.',
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
                            crossAxisCount: orientation == Orientation.landscape
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
                    width: 700,
                    child: ListView(
                      children: const <Widget>[
                        _StageColumn(
                          title: 'R32',
                          labels: <String>[
                            'A1 vs B2',
                            'C1 vs D2',
                            'E1 vs F2',
                            'G1 vs H2',
                          ],
                        ),
                        SizedBox(height: FantasySpacing.md),
                        _StageColumn(
                          title: 'R16',
                          labels: <String>[
                            'Winner 1',
                            'Winner 2',
                            'Winner 3',
                            'Winner 4',
                          ],
                        ),
                        SizedBox(height: FantasySpacing.md),
                        _StageColumn(
                          title: 'QF',
                          labels: <String>[
                            'Quarter 1',
                            'Quarter 2',
                            'Quarter 3',
                            'Quarter 4',
                          ],
                        ),
                        SizedBox(height: FantasySpacing.md),
                        _StageColumn(
                          title: 'SF',
                          labels: <String>['Semi 1', 'Semi 2'],
                        ),
                        SizedBox(height: FantasySpacing.md),
                        _StageColumn(
                          title: 'Final',
                          labels: <String>['Champion'],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: FantasyStateCard.loading()),
            error: (error, _) => Center(
              child: FantasyStateCard.error(
                title: 'Standings failed to load',
                message: error.toString(),
              ),
            ),
          ),
        );
      },
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
                        .map((row) {
                          return Padding(
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
                          );
                        })
                        .toList(growable: false),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StageColumn extends StatelessWidget {
  const _StageColumn({required this.title, required this.labels});

  final String title;
  final List<String> labels;

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
            children: labels
                .map(
                  (label) => BracketNodeWidget(
                    label: label,
                    highlight: label == 'Champion',
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}
