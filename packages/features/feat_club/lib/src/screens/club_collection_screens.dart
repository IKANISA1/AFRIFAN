import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/club_content_models.dart';
import '../providers/club_content_providers.dart';
import 'club_content_state_widgets.dart';

class ClubTeamScreen extends ConsumerWidget {
  const ClubTeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.afriL10n;
    final state = ref.watch(clubSquadProvider);
    return _ClubCollectionScaffold(
      title: l10n.clubTeamTitle.toUpperCase(),
      state: state,
      emptyTitle: l10n.clubTeamEmptyTitle,
      emptyMessage: l10n.clubTeamEmptyMessage,
      onRetry: () => ref.invalidate(clubSquadProvider),
      itemBuilder: (context, player) => AfriListRow(
        icon: AfriIcons.people,
        title: player.shirtNumber > 0
            ? '${player.shirtNumber}  ${player.name}'
            : player.name,
        subtitle: <String>[
          player.position,
          player.nationality,
        ].where((value) => value.isNotEmpty).join(' • '),
      ),
    );
  }
}

class ClubNewsScreen extends ConsumerWidget {
  const ClubNewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.afriL10n;
    final state = ref.watch(clubNewsProvider);
    return _ClubCollectionScaffold(
      title: l10n.clubNewsTitle.toUpperCase(),
      state: state,
      emptyTitle: l10n.clubNewsEmptyTitle,
      emptyMessage: l10n.clubNewsEmptyMessage,
      onRetry: () => ref.invalidate(clubNewsProvider),
      itemBuilder: (context, article) => AfriListRow(
        icon: AfriIcons.article,
        title: article.title,
        subtitle: <String>[
          article.category,
          _shortDate(context, article.publishedAt),
        ].where((value) => value.isNotEmpty).join(' • '),
        onTap: article.id.isEmpty
            ? null
            : () => context.push('/club/news/${article.id}'),
      ),
    );
  }
}

class ClubNewsDetailScreen extends ConsumerWidget {
  const ClubNewsDetailScreen({required this.articleId, super.key});

  final String articleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.afriL10n;
    final state = ref.watch(clubNewsProvider);
    return _ClubDetailScaffold(
      title: l10n.clubNewsTitle.toUpperCase(),
      state: state,
      onRetry: () => ref.invalidate(clubNewsProvider),
      select: (items) => _firstWhereOrNull(
        items,
        (item) => item.id == articleId,
      ),
      notFoundTitle: l10n.clubArticleUnavailableTitle,
      notFoundMessage: l10n.clubArticleUnavailableMessage,
      builder: (article) => GlassCard(
        animate: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.category.isNotEmpty)
              AfriStatusChip(
                label: article.category,
                tone: AfriStatusTone.info,
              ),
            const SizedBox(height: SpacingTokens.spacing3),
            Text(
              article.title,
              style: TypographyTokens.headlineLarge().copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            if (article.subtitle.isNotEmpty) ...[
              const SizedBox(height: SpacingTokens.spacing3),
              Text(
                article.subtitle,
                style: TypographyTokens.titleMedium(
                  ColorTokens.onSurfaceVariant,
                ),
              ),
            ],
            if (article.author.isNotEmpty || article.publishedAt != null) ...[
              const SizedBox(height: SpacingTokens.spacing4),
              Text(
                <String>[
                  article.author,
                  _shortDate(context, article.publishedAt),
                ].where((value) => value.isNotEmpty).join(' • '),
                style: TypographyTokens.bodySmall(
                  ColorTokens.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: SpacingTokens.spacing5),
            Text(
              article.body.isEmpty
                  ? l10n.clubArticleBodyUnavailable
                  : article.body,
              style: TypographyTokens.bodyLarge(),
            ),
          ],
        ),
      ),
    );
  }
}

class ClubFixturesScreen extends ConsumerWidget {
  const ClubFixturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.afriL10n;
    final state = ref.watch(clubMatchesProvider).whenData(
          (items) => items.where((item) => !item.isCompleted).toList(),
        );
    return _ClubCollectionScaffold(
      title: l10n.clubFixturesTitle.toUpperCase(),
      state: state,
      emptyTitle: l10n.clubFixturesEmptyTitle,
      emptyMessage: l10n.clubFixturesEmptyMessage,
      onRetry: () => ref.invalidate(clubMatchesProvider),
      itemBuilder: (context, fixture) => AfriListRow(
        icon: AfriIcons.fixture,
        title: l10n.clubFixtureTitle(fixture.homeTeam, fixture.awayTeam),
        subtitle: _fixtureSubtitle(context, fixture),
        onTap: fixture.id.isEmpty
            ? null
            : () => context.push('/club/fixtures/${fixture.id}'),
        trailing: fixture.isOnSale
            ? AfriStatusChip(
                label: l10n.clubTicketsTitle,
                tone: AfriStatusTone.success,
              )
            : null,
      ),
    );
  }
}

class ClubResultsScreen extends ConsumerWidget {
  const ClubResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.afriL10n;
    final state = ref.watch(clubMatchesProvider).whenData(
          (items) => items
              .where((item) => item.isCompleted)
              .toList()
              .reversed
              .toList(),
        );
    return _ClubCollectionScaffold(
      title: l10n.clubResultsTitle.toUpperCase(),
      state: state,
      emptyTitle: l10n.clubResultsEmptyTitle,
      emptyMessage: l10n.clubResultsEmptyMessage,
      onRetry: () => ref.invalidate(clubMatchesProvider),
      itemBuilder: (context, fixture) => AfriListRow(
        icon: AfriIcons.score,
        title: l10n.clubResultTitle(
          fixture.homeTeam,
          fixture.homeScore,
          fixture.awayScore,
          fixture.awayTeam,
        ),
        subtitle: _fixtureSubtitle(context, fixture),
        onTap: fixture.id.isEmpty
            ? null
            : () => context.push('/club/fixtures/${fixture.id}'),
      ),
    );
  }
}

class ClubFixtureDetailScreen extends ConsumerWidget {
  const ClubFixtureDetailScreen({required this.matchId, super.key});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.afriL10n;
    final state = ref.watch(clubMatchesProvider);
    return _ClubDetailScaffold(
      title: l10n.clubMatchTitle.toUpperCase(),
      state: state,
      onRetry: () => ref.invalidate(clubMatchesProvider),
      select: (items) => _firstWhereOrNull(
        items,
        (item) => item.id == matchId,
      ),
      notFoundTitle: l10n.clubMatchUnavailableTitle,
      notFoundMessage: l10n.clubMatchUnavailableMessage,
      builder: (fixture) => GlassCard(
        animate: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fixture.competition.isNotEmpty)
              AfriStatusChip(
                label: fixture.competition,
                tone: AfriStatusTone.info,
              ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              l10n.clubFixtureTitle(fixture.homeTeam, fixture.awayTeam),
              style: TypographyTokens.headlineLarge().copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            Text(
              _fixtureSubtitle(context, fixture),
              style: TypographyTokens.bodyLarge(
                ColorTokens.onSurfaceVariant,
              ),
            ),
            if (fixture.isCompleted) ...[
              const SizedBox(height: SpacingTokens.spacing5),
              Text(
                l10n.clubScore(fixture.homeScore, fixture.awayScore),
                style: TypographyTokens.displayMedium().copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
            if (fixture.isOnSale) ...[
              const SizedBox(height: SpacingTokens.spacing5),
              AfriButton(
                label: l10n.clubViewAvailableTickets,
                fullWidth: true,
                onTap: () => unawaited(context.push('/tickets/$matchId')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ClubStandingsScreen extends ConsumerWidget {
  const ClubStandingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.afriL10n;
    final state = ref.watch(clubStandingsProvider);
    return _ClubCollectionScaffold(
      title: l10n.clubStandingsTitle.toUpperCase(),
      state: state,
      emptyTitle: l10n.clubStandingsEmptyTitle,
      emptyMessage: l10n.clubStandingsEmptyMessage,
      onRetry: () => ref.invalidate(clubStandingsProvider),
      itemBuilder: (context, row) => GlassCard(
        animate: false,
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '${row.position}',
                style: TypographyTokens.titleMedium().copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Expanded(
              child: Text(
                row.clubName,
                style: TypographyTokens.titleMedium(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _StandingValue(label: l10n.clubPlayedShort, value: row.played),
            _StandingValue(
              label: l10n.clubGoalDifferenceShort,
              value: row.goalDifference,
              wide: true,
            ),
            _StandingValue(
              label: l10n.clubPointsShort,
              value: row.points,
              strong: true,
              wide: true,
            ),
          ],
        ),
      ),
    );
  }
}

class ClubHistoryScreen extends ConsumerWidget {
  const ClubHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.afriL10n;
    final state = ref.watch(clubHistoryProvider);
    return _ClubCollectionScaffold(
      title: l10n.clubHistoryTitle.toUpperCase(),
      state: state,
      emptyTitle: l10n.clubHistoryEmptyTitle,
      emptyMessage: l10n.clubHistoryEmptyMessage,
      onRetry: () => ref.invalidate(clubHistoryProvider),
      itemBuilder: (context, item) => GlassCard(
        animate: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: TypographyTokens.titleLarge().copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (item.subtitle.isNotEmpty) ...[
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                item.subtitle,
                style: TypographyTokens.titleSmall(
                  ColorTokens.onSurfaceVariant,
                ),
              ),
            ],
            if (item.body.isNotEmpty) ...[
              const SizedBox(height: SpacingTokens.spacing3),
              Text(item.body, style: TypographyTokens.bodyMedium()),
            ],
          ],
        ),
      ),
    );
  }
}

class ClubProjectsScreen extends ConsumerWidget {
  const ClubProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.afriL10n;
    final state = ref.watch(clubProjectsProvider);
    return _ClubCollectionScaffold(
      title: l10n.clubProjectsTitle.toUpperCase(),
      state: state,
      emptyTitle: l10n.clubProjectsEmptyTitle,
      emptyMessage: l10n.clubProjectsEmptyMessage,
      onRetry: () => ref.invalidate(clubProjectsProvider),
      itemBuilder: (context, project) => GlassCard(
        animate: false,
        onTap: project.id.isEmpty
            ? null
            : () => context.push('/club/projects/${project.id}'),
        semanticsLabel: project.name,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project.name,
              style: TypographyTokens.titleLarge().copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (project.description.isNotEmpty) ...[
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                project.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TypographyTokens.bodyMedium(),
              ),
            ],
            const SizedBox(height: SpacingTokens.spacing4),
            AfriLinearProgressIndicator(
              value: project.progress,
              minHeight: 8,
              borderRadius: ShapeTokens.buttonRadius,
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              l10n.clubSupporters(project.memberCount),
              style: TypographyTokens.bodySmall(
                ColorTokens.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ClubProjectDetailScreen extends ConsumerWidget {
  const ClubProjectDetailScreen({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.afriL10n;
    final state = ref.watch(clubProjectsProvider);
    return _ClubDetailScaffold(
      title: l10n.clubProjectTitle.toUpperCase(),
      state: state,
      onRetry: () => ref.invalidate(clubProjectsProvider),
      select: (items) => _firstWhereOrNull(
        items,
        (item) => item.id == projectId,
      ),
      notFoundTitle: l10n.clubProjectUnavailableTitle,
      notFoundMessage: l10n.clubProjectUnavailableMessage,
      builder: (project) => GlassCard(
        animate: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project.name,
              style: TypographyTokens.headlineLarge().copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            if (project.description.isNotEmpty) ...[
              const SizedBox(height: SpacingTokens.spacing3),
              Text(project.description, style: TypographyTokens.bodyLarge()),
            ],
            const SizedBox(height: SpacingTokens.spacing5),
            AfriLinearProgressIndicator(
              value: project.progress,
              minHeight: 10,
              borderRadius: ShapeTokens.buttonRadius,
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            Text(
              l10n.clubSupportersParticipate(project.memberCount),
              style: TypographyTokens.bodyMedium(
                ColorTokens.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing5),
            AfriButton(
              label: l10n.clubOpenContribution,
              fullWidth: true,
              onTap: () => unawaited(
                context.push('/contribute/group/${project.id}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClubCollectionScaffold<T> extends StatelessWidget {
  const _ClubCollectionScaffold({
    required this.title,
    required this.state,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onRetry,
    required this.itemBuilder,
  });

  final String title;
  final AsyncValue<List<T>> state;
  final String emptyTitle;
  final String emptyMessage;
  final VoidCallback onRetry;
  final Widget Function(BuildContext context, T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    return AfriScreenScaffold(
      title: title,
      actions: [
        AfriIconButton(
          key: const ValueKey<String>('club-refresh-action'),
          icon: AfriIcons.refresh,
          tooltip: l10n.clubRefresh,
          onTap: onRetry,
        ),
      ],
      scrollable: false,
      child: ValueListenableBuilder<bool>(
        valueListenable: ConnectivityService.onlineNotifier,
        builder: (context, isOnline, _) {
          final items = state.valueOrNull;
          if (items != null) {
            final failure = state.hasError
                ? ClubContentFailure.fromError(
                    state.error!,
                    isOnline: isOnline,
                  )
                : !isOnline
                    ? const ClubContentFailure(ClubContentFailureKind.offline)
                    : null;
            return Column(
              children: [
                if (state.isRefreshing || failure != null) ...[
                  ClubContentStatusBanner(
                    refreshing: state.isRefreshing,
                    failure: failure,
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                ],
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: AfriStateView.empty(
                            title: emptyTitle,
                            message: emptyMessage,
                            actionLabel: l10n.clubRefresh,
                            onAction: onRetry,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(
                            bottom: SpacingTokens.spacing6,
                          ),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(
                            height: SpacingTokens.spacing3,
                          ),
                          itemBuilder: (context, index) =>
                              itemBuilder(context, items[index]),
                        ),
                ),
              ],
            );
          }
          if (!isOnline) {
            return const Center(
              child: ClubContentFailureView(
                failure: ClubContentFailure(ClubContentFailureKind.offline),
              ),
            );
          }
          if (state.isLoading) {
            return Semantics(
              label: l10n.splashLoadingSemantic(title),
              liveRegion: true,
              child: ListView.separated(
                itemCount: 5,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: SpacingTokens.spacing3),
                itemBuilder: (_, __) => const AfriSkeleton.card(),
              ),
            );
          }
          return Center(
            child: ClubContentFailureView(
              failure: ClubContentFailure.fromError(
                state.error!,
                isOnline: isOnline,
              ),
              onRetry: onRetry,
            ),
          );
        },
      ),
    );
  }
}

class _ClubDetailScaffold<T> extends StatelessWidget {
  const _ClubDetailScaffold({
    required this.title,
    required this.state,
    required this.onRetry,
    required this.select,
    required this.notFoundTitle,
    required this.notFoundMessage,
    required this.builder,
  });

  final String title;
  final AsyncValue<List<T>> state;
  final VoidCallback onRetry;
  final T? Function(List<T> items) select;
  final String notFoundTitle;
  final String notFoundMessage;
  final Widget Function(T item) builder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    return AfriScreenScaffold(
      title: title,
      actions: [
        AfriIconButton(
          key: const ValueKey<String>('club-refresh-action'),
          icon: AfriIcons.refresh,
          tooltip: l10n.clubRefresh,
          onTap: onRetry,
        ),
      ],
      child: ValueListenableBuilder<bool>(
        valueListenable: ConnectivityService.onlineNotifier,
        builder: (context, isOnline, _) {
          final items = state.valueOrNull;
          if (items != null) {
            final selected = select(items);
            if (selected == null) {
              return AfriStateView.empty(
                title: notFoundTitle,
                message: notFoundMessage,
              );
            }
            final failure = state.hasError
                ? ClubContentFailure.fromError(
                    state.error!,
                    isOnline: isOnline,
                  )
                : !isOnline
                    ? const ClubContentFailure(ClubContentFailureKind.offline)
                    : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.isRefreshing || failure != null) ...[
                  ClubContentStatusBanner(
                    refreshing: state.isRefreshing,
                    failure: failure,
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                ],
                builder(selected),
              ],
            );
          }
          if (!isOnline) {
            return const ClubContentFailureView(
              failure: ClubContentFailure(ClubContentFailureKind.offline),
            );
          }
          if (state.isLoading) {
            return Semantics(
              label: l10n.splashLoadingSemantic(title),
              liveRegion: true,
              child: const AfriSkeletonList(itemCount: 3),
            );
          }
          return ClubContentFailureView(
            failure: ClubContentFailure.fromError(
              state.error!,
              isOnline: isOnline,
            ),
            onRetry: onRetry,
            linkedRecord: true,
          );
        },
      ),
    );
  }
}

class _StandingValue extends StatelessWidget {
  const _StandingValue({
    required this.label,
    required this.value,
    this.strong = false,
    this.wide = false,
  });

  final String label;
  final int value;
  final bool strong;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: wide ? 48 : 38,
      child: Column(
        children: [
          Text(
            label,
            style: TypographyTokens.labelSmall(
              ColorTokens.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing1),
          Text(
            '$value',
            style: TypographyTokens.titleSmall().copyWith(
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _shortDate(BuildContext context, DateTime? value) {
  if (value == null) return '';
  return MaterialLocalizations.of(context).formatShortDate(value.toLocal());
}

String _fixtureSubtitle(BuildContext context, ClubFixtureItem fixture) {
  return <String>[
    fixture.competition,
    _shortDate(context, fixture.matchDate),
    fixture.kickoffTime,
    fixture.venue,
  ].where((value) => value.isNotEmpty).join(' • ');
}

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) test) {
  for (final value in values) {
    if (test(value)) return value;
  }
  return null;
}
