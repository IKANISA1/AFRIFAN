import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/club_content_models.dart';
import '../providers/club_content_providers.dart';
import 'club_content_state_widgets.dart';

class ClubTeamScreen extends ConsumerStatefulWidget {
  const ClubTeamScreen({super.key, this.group});
  final String? group;
  @override
  ConsumerState<ClubTeamScreen> createState() => _ClubTeamScreenState();
}

class _ClubTeamScreenState extends ConsumerState<ClubTeamScreen> {
  String? _position;
  late String? _group = widget.group;
  String _groupLabel(String? group) => switch (group) {
    'first_team' => context.afriL10n.clubSquadFirstTeam,
    'women' => context.afriL10n.clubSquadWomen,
    'academy' => context.afriL10n.clubSquadAcademy,
    'staff' => context.afriL10n.clubSquadStaff,
    _ => context.afriL10n.clubSquadAllTeams,
  };
  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final state = ref.watch(clubSquadProvider);
    final positions = <String>{
      for (final player in state.valueOrNull ?? <ClubSquadMember>[])
        if (player.position.isNotEmpty) player.position,
    }.toList()..sort();
    final groups = <String>{
      for (final p in state.valueOrNull ?? <ClubSquadMember>[]) p.squadGroup,
      if (_group != null) _group!,
    }.toList();
    final selected = positions.contains(_position) ? _position : null;
    return ClubCollectionScaffold<ClubSquadMember>(
      title: l10n.clubTeamTitle,
      state: state.whenData(
        (players) => players
            .where(
              (p) =>
                  (_group == null || p.squadGroup == _group) &&
                  (selected == null || p.position == selected),
            )
            .toList(),
      ),
      emptyTitle: l10n.clubTeamEmptyTitle,
      emptyMessage: l10n.clubTeamEmptyMessage,
      onRetry: () => ref.invalidate(clubSquadProvider),
      columns:
          (state.valueOrNull?.length ?? 0) < 2 ||
              MediaQuery.textScalerOf(context).scale(1) >= 1.5 ||
              MediaQuery.sizeOf(context).width < 360
          ? 1
          : 2,
      header: positions.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final group in <String?>[null, ...groups])
                          Padding(
                            padding: const EdgeInsets.only(
                              right: SpacingTokens.spacing2,
                            ),
                            child: AfriChoiceChip(
                              label: Text(_groupLabel(group)),
                              selected: _group == group,
                              onSelected: (_) => setState(() {
                                _group = group;
                                _position = null;
                              }),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final position in <String?>[null, ...positions])
                          Padding(
                            padding: const EdgeInsets.only(
                              right: SpacingTokens.spacing2,
                            ),
                            child: AfriChoiceChip(
                              label: Text(position ?? l10n.clubAllPlayers),
                              selected: selected == position,
                              onSelected: (_) =>
                                  setState(() => _position = position),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      itemBuilder: (context, player) => _ClubPortraitCard(
        player: player,
        onTap: () =>
            context.push('/club/team/${Uri.encodeComponent(player.id)}'),
      ),
    );
  }
}

class _ClubPortraitCard extends StatelessWidget {
  const _ClubPortraitCard({required this.player, required this.onTap});
  final ClubSquadMember player;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => AfriEditorialCard(
    imageUrl: player.imageUrl,
    imageRightsApproved: player.imageUrl != null,
    imageProvenanceId: 'published-player:${player.id}',
    imageLabel: player.name,
    imageAspectRatio: 4 / 5,
    imageAlignment: Alignment.center,
    onTap: onTap,
    semanticsLabel: player.name,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(player.name, style: TypographyTokens.headlineMedium()),
        const SizedBox(height: SpacingTokens.spacing2),
        Text(
          [
            player.position,
            if (player.shirtNumber > 0) '#${player.shirtNumber}',
          ].where((p) => p.isNotEmpty).join(' · '),
          style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
        ),
      ],
    ),
  );
}

class ClubPlayerDetailScreen extends ConsumerWidget {
  const ClubPlayerDetailScreen({super.key, required this.playerId});
  final String playerId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.afriL10n;
    final state = ref.watch(clubPlayerProvider(playerId));
    return _ClubDetailScaffold<ClubSquadMember>(
      title: l10n.clubPlayerProfile,
      state: state.whenData((player) => player == null ? [] : [player]),
      select: (items) => items.firstOrNull,
      onRetry: () => ref.invalidate(clubPlayerProvider(playerId)),
      notFoundTitle: l10n.clubTeamEmptyTitle,
      notFoundMessage: l10n.clubTeamEmptyMessage,
      builder: (player) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AfriEditorialCard(
            imageUrl: player.imageUrl,
            imageRightsApproved: player.imageUrl != null,
            imageProvenanceId: 'published-player:${player.id}',
            imageLabel: player.name,
            imageAspectRatio: 4 / 5,
            imageAlignment: Alignment.center,
            child: Text(player.name, style: TypographyTokens.headlineMedium()),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Text(
            [
              player.position,
              if (player.shirtNumber > 0) '#${player.shirtNumber}',
              player.nationality,
            ].where((v) => v.isNotEmpty).join(' · '),
            style: TypographyTokens.bodyMedium(),
          ),
          const SizedBox(height: SpacingTokens.sectionGap),
          Text(
            player.bio.isEmpty ? l10n.clubPlayerBioPending : player.bio,
            style: TypographyTokens.bodyLarge(),
          ),
        ],
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
    return ClubCollectionScaffold(
      title: l10n.clubNewsTitle,
      state: state,
      emptyTitle: l10n.clubNewsEmptyTitle,
      emptyMessage: l10n.clubNewsEmptyMessage,
      onRetry: () => ref.invalidate(clubNewsProvider),
      itemBuilder: (context, article) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (article.imageUrl != null)
            AfriPressFeedback(
              semanticsLabel: article.title,
              onTap: () => context.push('/club/news/${article.id}'),
              child: ClipRRect(
                borderRadius: ShapeTokens.cardRadius,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    article.imageUrl!,
                    fit: BoxFit.cover,
                    cacheWidth: 960,
                    semanticLabel: article.title,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          AfriListRow(
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
        ],
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
    final state = ref.watch(clubArticleProvider(articleId));
    return _ClubDetailScaffold<ClubNewsItem>(
      title: l10n.clubNewsTitle,
      state: state.whenData((article) => article == null ? [] : [article]),
      onRetry: () => ref.invalidate(clubArticleProvider(articleId)),
      select: (items) =>
          _firstWhereOrNull(items, (item) => item.id == articleId),
      notFoundTitle: l10n.clubArticleUnavailableTitle,
      notFoundMessage: l10n.clubArticleUnavailableMessage,
      builder: (article) => GlassCard(
        animate: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.imageUrl != null) ...[
              ClipRRect(
                borderRadius: ShapeTokens.cardRadius,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    article.imageUrl!,
                    fit: BoxFit.cover,
                    cacheWidth: 1080,
                    semanticLabel: article.title,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
              const SizedBox(height: SpacingTokens.sectionGap),
            ],
            if (article.category.isNotEmpty)
              AfriStatusChip(
                label: article.category,
                tone: AfriStatusTone.info,
              ),
            const SizedBox(height: SpacingTokens.spacing3),
            Text(
              article.title,
              style: TypographyTokens.headlineMedium().copyWith(
                fontWeight: FontWeight.w700,
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
                style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: SpacingTokens.spacing5),
            Text(
              article.body.isEmpty
                  ? l10n.clubArticleBodyUnavailable
                  : article.body,
              style: TypographyTokens.bodyLarge(),
            ),
            if (article.sourceUrl != null) ...[
              const SizedBox(height: SpacingTokens.sectionGap),
              AfriButton(
                label: l10n.clubArticleOriginal,
                variant: AfriButtonVariant.secondary,
                onTap: () async {
                  final opened = await launchUrl(
                    Uri.parse(article.sourceUrl!),
                    mode: LaunchMode.externalApplication,
                  );
                  if (!opened && context.mounted) {
                    AfriToast.error(context, l10n.clubArticleUnavailableTitle);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ClubFixturesScreen extends ConsumerWidget {
  const ClubFixturesScreen({super.key, this.results = false});
  final bool results;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.afriL10n;
    final state = ref.watch(clubMatchesProvider).whenData((items) {
      final matches = items
          .where((item) => item.isCompleted == results)
          .toList();
      return results ? matches.reversed.toList() : matches;
    });
    return ClubCollectionScaffold(
      title: l10n.clubFixturesTitle,
      state: state,
      emptyTitle: results
          ? l10n.clubResultsEmptyTitle
          : l10n.clubFixturesEmptyTitle,
      emptyMessage: results
          ? l10n.clubResultsEmptyMessage
          : l10n.clubFixturesEmptyMessage,
      onRetry: () => ref.invalidate(clubMatchesProvider),
      header: Padding(
        padding: const EdgeInsets.only(bottom: SpacingTokens.spacing4),
        child: Wrap(
          spacing: SpacingTokens.spacing2,
          runSpacing: SpacingTokens.spacing2,
          children: [
            AfriChoiceChip(
              label: Text(l10n.clubFixturesTitle),
              selected: !results,
              onSelected: (_) => context.go('/club/fixtures'),
            ),
            AfriChoiceChip(
              label: Text(l10n.clubResultsTitle),
              selected: results,
              onSelected: (_) => context.go('/club/fixtures?tab=results'),
            ),
          ],
        ),
      ),
      itemBuilder: (context, fixture) => AfriFixtureCard(
        homeTeam: fixture.homeTeam,
        awayTeam: fixture.awayTeam,
        imageUrl: fixture.imageUrl,
        imageRightsApproved: fixture.imageUrl != null,
        imageProvenanceId: 'published-fixture:${fixture.id}',
        score: results ? '${fixture.homeScore}–${fixture.awayScore}' : null,
        subtitle: _fixtureSubtitle(context, fixture),
        onTap: fixture.id.isEmpty
            ? null
            : () => context.push('/club/fixtures/${fixture.id}'),
        trailing: !results && fixture.isOnSale
            ? AfriStatusChip(
                label: l10n.clubTicketsTitle,
                tone: AfriStatusTone.success,
              )
            : null,
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
      title: l10n.clubMatchTitle,
      state: state,
      onRetry: () => ref.invalidate(clubMatchesProvider),
      select: (items) => _firstWhereOrNull(items, (item) => item.id == matchId),
      notFoundTitle: l10n.clubMatchUnavailableTitle,
      notFoundMessage: l10n.clubMatchUnavailableMessage,
      builder: (fixture) => AfriEditorialCard(
        imageUrl: fixture.imageUrl,
        imageRightsApproved: fixture.imageUrl != null,
        imageProvenanceId: 'published-fixture:${fixture.id}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AfriFixtureTeams(
              homeTeam: fixture.homeTeam,
              awayTeam: fixture.awayTeam,
              score: fixture.isCompleted
                  ? '${fixture.homeScore}–${fixture.awayScore}'
                  : null,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              _fixtureSubtitle(context, fixture),
              style: TypographyTokens.bodyMedium(ColorTokens.onSurfaceVariant),
            ),
            const SizedBox(height: SpacingTokens.spacing5),
            AfriButton(
              label: l10n.clubViewAvailableTickets,
              labelMaxLines: 3,
              fullWidth: true,
              enabled: fixture.isOnSale,
              onTap: () => unawaited(context.push('/tickets/$matchId')),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            AfriButton(
              label: l10n.predictTitle,
              variant: AfriButtonVariant.secondary,
              fullWidth: true,
              onTap: () => context.go('/predict'),
            ),
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
    return ClubCollectionScaffold(
      title: l10n.clubStandingsTitle,
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
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(child: AfriTeamCard(name: row.clubName)),
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
    return ClubCollectionScaffold(
      title: l10n.clubHistoryTitle,
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
                fontWeight: FontWeight.w600,
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

class ClubCollectionScaffold<T> extends StatelessWidget {
  const ClubCollectionScaffold({
    super.key,
    required this.title,
    required this.state,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onRetry,
    required this.itemBuilder,
    this.header,
    this.columns = 1,
  });

  final String title;
  final AsyncValue<List<T>> state;
  final String emptyTitle;
  final String emptyMessage;
  final VoidCallback onRetry;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget? header;
  final int columns;

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
          if (state.hasError &&
              ClubContentFailure.fromError(state.error!, isOnline: true).kind ==
                  ClubContentFailureKind.permissionDenied) {
            return const ClubContentFailureView(
              failure: ClubContentFailure(
                ClubContentFailureKind.permissionDenied,
              ),
            );
          }
          final items = state.valueOrNull;
          if (items != null) {
            final failure = state.hasError
                ? ClubContentFailure.fromError(state.error!, isOnline: isOnline)
                : !isOnline
                ? const ClubContentFailure(ClubContentFailureKind.offline)
                : null;
            return Column(
              children: [
                if (header != null) header!,
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
                          itemCount: (items.length / columns).ceil(),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: SpacingTokens.spacing3),
                          itemBuilder: (context, index) => columns == 1
                              ? itemBuilder(context, items[index])
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (
                                      var column = 0;
                                      column < columns;
                                      column++
                                    ) ...[
                                      if (column > 0)
                                        const SizedBox(
                                          width: SpacingTokens.spacing3,
                                        ),
                                      Expanded(
                                        child:
                                            index * columns + column <
                                                items.length
                                            ? itemBuilder(
                                                context,
                                                items[index * columns + column],
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ],
                                  ],
                                ),
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
          if (state.hasError &&
              ClubContentFailure.fromError(state.error!, isOnline: true).kind ==
                  ClubContentFailureKind.permissionDenied) {
            return const ClubContentFailureView(
              failure: ClubContentFailure(
                ClubContentFailureKind.permissionDenied,
              ),
            );
          }
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
                ? ClubContentFailure.fromError(state.error!, isOnline: isOnline)
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
            style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
          ),
          const SizedBox(height: SpacingTokens.spacing1),
          Text(
            '$value',
            style: TypographyTokens.titleSmall().copyWith(
              fontWeight: strong ? FontWeight.w700 : FontWeight.w700,
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
    [
      _shortDate(context, fixture.matchDate),
      fixture.kickoffTime,
    ].where((value) => value.isNotEmpty).join(' · '),
    fixture.venue,
  ].where((value) => value.isNotEmpty).join('\n');
}

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) test) {
  for (final value in values) {
    if (test(value)) return value;
  }
  return null;
}
