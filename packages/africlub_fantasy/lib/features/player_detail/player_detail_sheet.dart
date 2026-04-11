import 'package:africlub_fantasy/core/constants.dart';
import 'package:africlub_fantasy/features/player_detail/form_sparkline_widget.dart';
import 'package:africlub_fantasy/features/player_detail/stat_bar_widget.dart';
import 'package:africlub_fantasy/features/shared/fantasy_ui.dart';
import 'package:africlub_fantasy/models/fantasy_player.dart';
import 'package:africlub_fantasy/providers/competition_providers.dart';
import 'package:africlub_fantasy/providers/player_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlayerDetailSheet extends ConsumerWidget {
  const PlayerDetailSheet({
    required this.competitionId,
    required this.playerId,
    this.isSelected = false,
    this.slug,
    super.key,
  });

  const PlayerDetailSheet.standalone({
    required this.slug,
    required this.playerId,
    super.key,
  }) : competitionId = '',
       isSelected = false;

  final String competitionId;
  final int playerId;
  final bool isSelected;
  final String? slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(playerHistoryProvider(playerId));
    final resolvedCompetitionId = competitionId.isNotEmpty
        ? AsyncValue<String>.data(competitionId)
        : _resolveCompetitionId(ref);

    return FantasyScaffold(
      title: 'Player',
      child: resolvedCompetitionId.when(
        data: (resolvedCompetitionId) {
          final playerAsync = ref.watch(
            playerProvider((
              competitionId: resolvedCompetitionId,
              playerId: playerId,
            )),
          );

          return playerAsync.when(
            data: (player) {
              if (player == null) {
                return const Center(
                  child: FantasyStateCard.empty(
                    title: 'Player not found',
                    message: 'The requested player could not be loaded.',
                  ),
                );
              }

              return historyAsync.when(
                data: (history) {
                  final values = history
                      .map((item) => item.rawPoints.toDouble())
                      .toList(growable: false);
                  final goals = history.fold<int>(
                    0,
                    (sum, item) => sum + item.goals,
                  );
                  final assists = history.fold<int>(
                    0,
                    (sum, item) => sum + item.assists,
                  );
                  final cleanSheets = history
                      .where((item) => item.cleanSheet)
                      .length;
                  final totalPoints = history.fold<int>(
                    0,
                    (sum, item) => sum + item.rawPoints,
                  );
                  final fixtureDifficulties = player.fixtureDifficulty
                      .map(
                        (item) => <String, dynamic>{
                          'label':
                              item['label']?.toString() ??
                              item['opponent']?.toString() ??
                              'Next',
                          'difficulty':
                              (item['difficulty'] as num?)?.toInt() ??
                              (item['rating'] as num?)?.toInt() ??
                              0,
                        },
                      )
                      .where((item) => (item['difficulty'] as int) > 0)
                      .toList(growable: false);

                  return ListView(
                    padding: const EdgeInsets.all(FantasySpacing.md),
                    children: <Widget>[
                      FantasyGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: FantasyColors.surfaceAlt,
                                  child: Text(
                                    player.shortName.substring(0, 1),
                                    style: FantasyTypography.h3.copyWith(
                                      color: FantasyColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: FantasySpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        player.name,
                                        style: FantasyTypography.h2.copyWith(
                                          color: FantasyColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: FantasySpacing.xs),
                                      Text(
                                        '${player.teamName} · ${player.positionLabel}',
                                        style: FantasyTypography.caption
                                            .copyWith(
                                              color:
                                                  FantasyColors.textSecondary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: FantasySpacing.md),
                            Row(
                              children: <Widget>[
                                Text(
                                  player.priceDisplay,
                                  style: FantasyTypography.body.copyWith(
                                    color: FantasyColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: FantasySpacing.sm),
                                Text(
                                  '${player.priceChange >= 0 ? '▲' : '▼'} £${(player.priceChange.abs() / 10).toStringAsFixed(1)}M',
                                  style: FantasyTypography.caption.copyWith(
                                    color: player.priceChange >= 0
                                        ? FantasyColors.successGreen
                                        : FantasyColors.dangerRed,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: FantasySpacing.md),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: FantasySpacing.sm,
                        crossAxisSpacing: FantasySpacing.sm,
                        childAspectRatio: 1.8,
                        children: <Widget>[
                          _StatTile(label: 'Goals', value: goals.toString()),
                          _StatTile(
                            label: 'Assists',
                            value: assists.toString(),
                          ),
                          _StatTile(label: 'CS', value: cleanSheets.toString()),
                          _StatTile(
                            label: 'Points',
                            value: totalPoints.toString(),
                          ),
                        ],
                      ),
                      const SizedBox(height: FantasySpacing.md),
                      FantasyGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const FantasySectionHeader(
                              title: 'Form',
                              subtitle: 'Last 6 gameweeks',
                            ),
                            const SizedBox(height: FantasySpacing.md),
                            FormSparklineWidget(values: values),
                          ],
                        ),
                      ),
                      const SizedBox(height: FantasySpacing.md),
                      FantasyGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const FantasySectionHeader(
                              title: 'Ownership',
                              subtitle: 'Current effective ownership',
                            ),
                            const SizedBox(height: FantasySpacing.md),
                            Text(
                              '${player.ownershipPercent.toStringAsFixed(1)}% ownership',
                              style: FantasyTypography.body.copyWith(
                                color: FantasyColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: FantasySpacing.sm),
                            StatBarWidget(
                              label: 'Ownership',
                              value: player.ownershipPercent,
                              max: 100,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: FantasySpacing.md),
                      if (fixtureDifficulties.isNotEmpty) ...<Widget>[
                        FantasyGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const FantasySectionHeader(
                                title: 'Fixture difficulty',
                                subtitle: 'Upcoming fixtures',
                              ),
                              const SizedBox(height: FantasySpacing.md),
                              Wrap(
                                spacing: FantasySpacing.sm,
                                runSpacing: FantasySpacing.sm,
                                children: fixtureDifficulties
                                    .map(
                                      (fixture) => Container(
                                        width: 72,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: FantasySpacing.sm,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _difficultyColor(
                                            fixture['difficulty'] as int,
                                          ).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: Column(
                                          children: <Widget>[
                                            Text(
                                              fixture['label'] as String,
                                              style: FantasyTypography.label
                                                  .copyWith(
                                                    color:
                                                        FantasyColors.textMuted,
                                                  ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              (fixture['difficulty'] as int)
                                                  .toString(),
                                              style: FantasyTypography.body
                                                  .copyWith(
                                                    color: _difficultyColor(
                                                      fixture['difficulty']
                                                          as int,
                                                    ),
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: FantasySpacing.md),
                      ] else ...<Widget>[
                        const FantasyGlassCard(
                          child: FantasyStateCard.empty(
                            title: 'Fixture difficulty unavailable',
                            message:
                                'Upcoming fixture ratings will appear here once provider data is available.',
                          ),
                        ),
                        const SizedBox(height: FantasySpacing.md),
                      ],
                      FilledButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: Text(isSelected ? 'Remove' : 'Add to squad'),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: FantasyStateCard.loading()),
                error: (error, _) => Center(
                  child: FantasyStateCard.error(
                    title: 'Form failed to load',
                    message: error.toString(),
                  ),
                ),
              );
            },
            loading: () => const Center(child: FantasyStateCard.loading()),
            error: (error, _) => Center(
              child: FantasyStateCard.error(
                title: 'Player failed to load',
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

  AsyncValue<String> _resolveCompetitionId(WidgetRef ref) {
    final slug = this.slug;
    if (slug == null || slug.isEmpty) {
      return const AsyncValue<String>.error(
        'Competition context missing',
        StackTrace.empty,
      );
    }

    return ref
        .watch(competitionProvider(slug))
        .whenData((competition) => competition.id);
  }

  Color _difficultyColor(int rating) {
    if (rating <= 2) return FantasyColors.successGreen;
    if (rating == 3) return FantasyColors.warningAmber;
    return FantasyColors.dangerRed;
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return FantasyGlassCard(
      padding: const EdgeInsets.all(FantasySpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            value,
            style: FantasyTypography.scoreSm.copyWith(
              color: FantasyColors.textPrimary,
            ),
          ),
          const SizedBox(height: FantasySpacing.xs),
          Text(
            label,
            style: FantasyTypography.caption.copyWith(
              color: FantasyColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
