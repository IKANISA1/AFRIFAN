import 'package:africlub_fantasy/core/constants.dart';
import 'package:africlub_fantasy/features/shared/fantasy_ui.dart';
import 'package:africlub_fantasy/models/fantasy_notification_topic.dart';
import 'package:africlub_fantasy/providers/competition_providers.dart';
import 'package:africlub_fantasy/providers/squad_providers.dart';
import 'package:core_network/core_network.dart';
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
    final client = ref.watch(supabaseClientProvider);

    return FantasyScaffold(
      title: 'Competition',
      child: competitionAsync.when(
        data: (competition) {
          final entryAsync = ref.watch(myEntryProvider(competition.id));
          final gameweekAsync = ref.watch(
            currentGameweekProvider(competition.id),
          );
          final topicAsync = ref.watch(
            fantasyNotificationTopicProvider(competition.id),
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
              topicAsync.when(
                data: (topic) => topic == null
                    ? const SizedBox.shrink()
                    : _NotificationCard(
                        topic: topic,
                        enabled: client.auth.currentUser != null,
                        onChanged: (next) async {
                          if (client.auth.currentUser == null) {
                            AfriToast.error(
                              context,
                              'Sign in to update fantasy notifications.',
                            );
                            return;
                          }
                          try {
                            await ref
                                .read(competitionRepositoryProvider)
                                .updateNotificationTopic(
                                  competitionId: competition.id,
                                  enabled: next.enabled,
                                  deadlineAlerts: next.deadlineAlerts,
                                  gameplayAlerts: next.gameplayAlerts,
                                  leagueAlerts: next.leagueAlerts,
                                );
                            ref.invalidate(fantasyNotificationTopicsProvider);
                            ref.invalidate(
                              fantasyNotificationTopicProvider(competition.id),
                            );
                            if (context.mounted) {
                              AfriToast.success(
                                context,
                                'Fantasy notification preferences updated.',
                              );
                            }
                          } catch (error) {
                            if (context.mounted) {
                              AfriToast.error(context, error.toString());
                            }
                          }
                        },
                      ),
                loading: () => const FantasySkeletonCard(height: 180),
                error: (_, __) => const SizedBox.shrink(),
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
                subtitle: 'See global standings, private leagues, and H2H.',
                icon: Icons.leaderboard_rounded,
                onTap: () => context.push('/fantasy/$slug/leaderboard'),
              ),
              if (competition.competitionType.name == 'tournament') ...<Widget>[
                const SizedBox(height: FantasySpacing.md),
                _ActionTile(
                  title: 'World Cup bracket',
                  subtitle:
                      'Track groups, knockouts, and live bracket progression.',
                  icon: Icons.account_tree_rounded,
                  onTap: () => context.push('/fantasy/$slug/wc-bracket'),
                ),
              ],
              const SizedBox(height: FantasySpacing.md),
              _ActionTile(
                title: 'AI advisor',
                subtitle:
                    'Ask for transfers, captaincy, or a post-gameweek debrief.',
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
            FantasySkeletonCard(height: 160),
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

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.topic,
    required this.enabled,
    required this.onChanged,
  });

  final FantasyNotificationTopic topic;
  final bool enabled;
  final ValueChanged<FantasyNotificationTopic> onChanged;

  @override
  Widget build(BuildContext context) {
    return FantasyGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FantasySectionHeader(
            title: 'Notifications',
            subtitle: 'Topic ${topic.topic}',
            trailing: FantasyStatusBadge(
              label: topic.enabled ? 'Subscribed' : 'Muted',
              color: topic.enabled
                  ? FantasyColors.successGreen
                  : FantasyColors.textMuted,
            ),
          ),
          const SizedBox(height: FantasySpacing.md),
          _NotificationToggleRow(
            label: 'Competition topic',
            subtitle: 'Receive public competition alerts on this device.',
            value: topic.enabled,
            enabled: enabled,
            onChanged: (value) => onChanged(topic.copyWith(enabled: value)),
          ),
          _NotificationToggleRow(
            label: 'Deadline alerts',
            subtitle: '24h, 3h, and 30m squad reminders.',
            value: topic.deadlineAlerts,
            enabled: enabled && topic.enabled,
            onChanged: (value) =>
                onChanged(topic.copyWith(deadlineAlerts: value)),
          ),
          _NotificationToggleRow(
            label: 'Gameplay alerts',
            subtitle: 'Captain goals, rank swings, and fantasy match events.',
            value: topic.gameplayAlerts,
            enabled: enabled && topic.enabled,
            onChanged: (value) =>
                onChanged(topic.copyWith(gameplayAlerts: value)),
          ),
          _NotificationToggleRow(
            label: 'League alerts',
            subtitle: 'Private-league and H2H updates for joined leagues.',
            value: topic.leagueAlerts,
            enabled: enabled && topic.enabled,
            onChanged: (value) =>
                onChanged(topic.copyWith(leagueAlerts: value)),
          ),
        ],
      ),
    );
  }
}

class _NotificationToggleRow extends StatelessWidget {
  const _NotificationToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      activeThumbColor: FantasyColors.successGreen,
      activeTrackColor: FantasyColors.successGreen.withValues(alpha: 0.35),
      title: Text(
        label,
        style: FantasyTypography.body.copyWith(
          color: FantasyColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: FantasyTypography.caption.copyWith(
          color: FantasyColors.textSecondary,
        ),
      ),
      value: value,
      onChanged: enabled ? onChanged : null,
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
