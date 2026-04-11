import 'package:africlub_fantasy/core/constants.dart';
import 'package:africlub_fantasy/features/shared/fantasy_ui.dart';
import 'package:africlub_fantasy/providers/competition_providers.dart';
import 'package:africlub_fantasy/providers/squad_providers.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CompetitionDetailScreen extends ConsumerWidget {
  const CompetitionDetailScreen({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final competitionAsync = ref.watch(competitionProvider(slug));

    return FantasyScaffold(
      title: 'Competition',
      child: competitionAsync.when(
        data: (competition) {
          final entryAsync = ref.watch(myEntryProvider(competition.id));
          final gameweekAsync = ref.watch(
            currentGameweekProvider(competition.id),
          );

          return ListView(
            padding: const EdgeInsets.all(FantasySpacing.md),
            children: <Widget>[
              FantasyGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      competition.name,
                      style: FantasyTypography.h2.copyWith(
                        color: FantasyColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: FantasySpacing.sm),
                    Text(
                      competition.season,
                      style: FantasyTypography.body.copyWith(
                        color: FantasyColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: FantasySpacing.md),
                    gameweekAsync.when(
                      data: (gameweek) => Text(
                        gameweek == null
                            ? 'No gameweek scheduled yet.'
                            : 'Current phase: ${gameweek.name}',
                        style: FantasyTypography.caption.copyWith(
                          color: FantasyColors.textSecondary,
                        ),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                      loading: () => const AfriSkeleton.line(width: 120),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: FantasySpacing.md),
              _ActionTile(
                title: entryAsync.valueOrNull == null
                    ? 'Build your squad'
                    : 'Manage your squad',
                subtitle: 'Pick your starting XI, bench, captain, and vice.',
                icon: Icons.sports_soccer_rounded,
                onTap: () => context.push('/fantasy/$slug/build'),
              ),
              const SizedBox(height: FantasySpacing.md),
              _ActionTile(
                title: 'Live gameweek',
                subtitle: 'Track real-time scores and rank movement.',
                icon: Icons.bolt_rounded,
                onTap: () => context.push('/fantasy/$slug/live'),
              ),
              const SizedBox(height: FantasySpacing.md),
              _ActionTile(
                title: 'Transfers',
                subtitle: 'Sell, buy, and monitor transfer penalties.',
                icon: Icons.swap_horiz_rounded,
                onTap: () => context.push('/fantasy/$slug/transfers'),
              ),
              const SizedBox(height: FantasySpacing.md),
              _ActionTile(
                title: 'Leaderboard',
                subtitle: 'See global standings and your private leagues.',
                icon: Icons.leaderboard_rounded,
                onTap: () => context.push('/fantasy/$slug/leaderboard'),
              ),
              if (competition.competitionType.name == 'tournament') ...<Widget>[
                const SizedBox(height: FantasySpacing.md),
                _ActionTile(
                  title: 'World Cup bracket',
                  subtitle:
                      'Track groups, knockouts, and your selected nations.',
                  icon: Icons.account_tree_rounded,
                  onTap: () => context.push('/fantasy/$slug/wc-bracket'),
                ),
              ],
              const SizedBox(height: FantasySpacing.md),
              _ActionTile(
                title: 'AI advisor',
                subtitle: 'Ask Gemini for transfer, captain, and chip advice.',
                icon: Icons.auto_awesome_rounded,
                onTap: () => context.push('/fantasy/$slug/advisor'),
              ),
            ],
          );
        },
        loading: () => ListView(
          padding: const EdgeInsets.all(FantasySpacing.md),
          children: const <Widget>[
            FantasySkeletonCard(height: 120),
            SizedBox(height: FantasySpacing.md),
            FantasySkeletonCard(height: 84),
            SizedBox(height: FantasySpacing.md),
            FantasySkeletonCard(height: 84),
          ],
        ),
        error: (error, _) => Center(
          child: FantasyStateCard.error(
            title: 'Competition failed to load',
            message: error.toString(),
            onRetry: () => ref.invalidate(competitionProvider(slug)),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FantasyGlassCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: FantasyColors.successGreen.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: FantasyColors.successGreen),
          ),
          const SizedBox(width: FantasySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: FantasyTypography.body.copyWith(
                    color: FantasyColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: FantasySpacing.xs),
                Text(
                  subtitle,
                  style: FantasyTypography.caption.copyWith(
                    color: FantasyColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: FantasyColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
