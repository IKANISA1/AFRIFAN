import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/fanzone_hub_provider.dart';
import '../widgets/fanzone_hub_widgets.dart';
import '../widgets/prediction_slip_widgets.dart';

/// Fanzone Hub — predictions, wallet, fixtures, leaderboard, and challenges.
///
/// Uses [FanzoneHubNotifier] via Riverpod for async state management instead
/// of manual setState, enabling proper caching and DevTools integration.
class FanzoneHubScreen extends ConsumerWidget {
  const FanzoneHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHub = ref.watch(fanzoneHubProvider);
    final notifier = ref.read(fanzoneHubProvider.notifier);

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        title: Text(
          'Fanzone',
          style: TypographyTokens.headlineSmall(),
        ),
        actions: [
          IconButton(
            onPressed: () => _showOverflow(context, ref),
            tooltip: 'More options',
            icon: const Icon(AfriIcons.more),
          ),
        ],
      ),
      bottomNavigationBar: PredictionSlipBar(
        onTap: () => _openSlip(context, ref),
      ),
      body: asyncHub.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(SpacingTokens.screenPadding),
          child: AfriSkeletonList(),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.screenPadding),
            child: AfriStateView.offline(
              title: 'Fanzone unavailable',
              message: 'Fanzone is temporarily unavailable.',
              actionLabel: 'Retry',
              onAction: () => notifier.refresh(),
            ),
          ),
        ),
        data: (snapshot) =>
            _buildContent(context, ref, snapshot, asyncHub.isRefreshing),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    FanzoneHubSnapshot snapshot,
    bool isRefreshing,
  ) {
    final notifier = ref.read(fanzoneHubProvider.notifier);

    return GradientBackground(
      child: RefreshIndicator(
        onRefresh: () => notifier.refresh(),
        color: ColorTokens.clubAccent,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // ── Degraded / partial error banner ──
            if (snapshot.status == FanzoneHubStatus.degraded &&
                snapshot.message != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.screenPadding,
                    SpacingTokens.spacing4,
                    SpacingTokens.screenPadding,
                    0,
                  ),
                  child: AfriStateView.offline(
                    title: 'Live updates paused',
                    message: snapshot.message!,
                    compact: true,
                  ),
                ),
              ),

            // ── Hero stats ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  SpacingTokens.screenPadding,
                  SpacingTokens.spacing4,
                  SpacingTokens.screenPadding,
                  0,
                ),
                child: HubHeroStats(
                  dashboard: snapshot.dashboard,
                  wallet: snapshot.wallet,
                ),
              ),
            ),

            // ── Quick routes (capped at 6) ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  SpacingTokens.screenPadding,
                  SpacingTokens.spacing4,
                  SpacingTokens.screenPadding,
                  0,
                ),
                child: HubQuickRoutes(
                  onMore: () => _showOverflow(context, ref),
                ),
              ),
            ),

            // ── Live matches ──
            if (snapshot.liveFixtures.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.screenPadding,
                    SpacingTokens.sectionGap,
                    SpacingTokens.screenPadding,
                    0,
                  ),
                  child: AfriSectionCard(
                    title: 'Live Now',
                    child: Column(
                      children: snapshot.liveFixtures
                          .map(
                            (fixture) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: SpacingTokens.listItemGap,
                              ),
                              child: HubFixtureRow(
                                fixture: fixture,
                                isLive: true,
                                onTap: () => context.push(
                                  '/fanzone/match/${fixture.id}',
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
              ),

            // ── Today's fixtures ──
            SliverToBoxAdapter(
              child: snapshot.todayFixtures.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(
                        SpacingTokens.screenPadding,
                        SpacingTokens.sectionGap,
                        SpacingTokens.screenPadding,
                        0,
                      ),
                      child: AfriSectionCard(
                        title: 'Today',
                        trailingLabel: 'Calendar',
                        onTrailingTap: () => context.push('/fanzone/fixtures'),
                        child: Column(
                          children: snapshot.todayFixtures
                              .map(
                                (fixture) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: SpacingTokens.listItemGap,
                                  ),
                                  child: HubFixtureRow(
                                    fixture: fixture,
                                    onTap: () => context.push(
                                      '/fanzone/match/${fixture.id}',
                                    ),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                ),
              ),
            ),

            // ── Upcoming fixtures (next 7 days) ──
            if (snapshot.upcomingFixtures.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.screenPadding,
                    SpacingTokens.sectionGap,
                    SpacingTokens.screenPadding,
                    0,
                  ),
                  child: AfriSectionCard(
                    title: 'This Week',
                    trailingLabel: 'Browse',
                    onTrailingTap: () => context.push('/fanzone/fixtures'),
                    child: Column(
                      children: snapshot.upcomingFixtures
                          .map(
                            (fixture) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: SpacingTokens.listItemGap,
                              ),
                              child: HubFixtureRow(
                                fixture: fixture,
                                showDate: true,
                                onTap: () => context.push(
                                  '/fanzone/match/${fixture.id}',
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
              ),

            // ── Markets ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  SpacingTokens.screenPadding,
                  SpacingTokens.sectionGap,
                  SpacingTokens.screenPadding,
                  0,
                ),
                child: AfriSectionCard(
                  title: 'Markets',
                  child: Wrap(
                    spacing: SpacingTokens.inlineGap,
                    runSpacing: SpacingTokens.inlineGap,
                    children: snapshot.markets
                        .take(8)
                        .map(
                          (market) => AfriInfoChip(
                            label:
                                '${market.shortName} +${market.defaultFetValue}',
                            color: ColorTokens.onSurfaceVariant,
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
            ),

            // ── Leaderboard ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  SpacingTokens.screenPadding,
                  SpacingTokens.sectionGap,
                  SpacingTokens.screenPadding,
                  0,
                ),
                child: AfriSectionCard(
                  title: 'Leaderboard',
                  trailingLabel: 'Open',
                  onTrailingTap: () => context.push('/fanzone/leaderboard'),
                  child: Column(
                    children: snapshot.leaderboard
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: SpacingTokens.listItemGap,
                            ),
                            child: HubLeaderboardRow(entry: entry),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
            ),

            // ── Challenges ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  SpacingTokens.screenPadding,
                  SpacingTokens.sectionGap,
                  SpacingTokens.screenPadding,
                  120,
                ),
                child: AfriSectionCard(
                  title: 'Challenges',
                  trailingLabel: 'Open',
                  onTrailingTap: () => context.push('/fanzone/challenges'),
                  child: Column(
                    children: snapshot.challenges
                        .take(4)
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: SpacingTokens.listItemGap,
                            ),
                            child: HubChallengeRow(item: item),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSlip(BuildContext context, WidgetRef ref) async {
    await showPredictionSlipSheet(
      context,
      ref,
      onSubmitted: () => ref.read(fanzoneHubProvider.notifier).refresh(),
    );
  }

  void _showOverflow(BuildContext context, WidgetRef ref) {
    unawaited(
      showAfriActionSheet(
        context: context,
        title: 'Fanzone',
        actions: [
          AfriSheetAction(
            icon: AfriIcons.myPicks,
            label: 'My predictions',
            onTap: () => context.push('/fanzone/my'),
          ),
          AfriSheetAction(
            icon: AfriIcons.notifications,
            label: 'Alerts',
            onTap: () => context.push('/fanzone/notifications'),
          ),
          AfriSheetAction(
            icon: AfriIcons.wallet,
            label: 'FET wallet',
            onTap: () => context.push('/fanzone/wallet'),
          ),
          AfriSheetAction(
            icon: AfriIcons.offers,
            label: 'Offers',
            onTap: () => context.push('/fanzone/offers'),
          ),
          AfriSheetAction(
            icon: AfriIcons.rewards,
            label: 'Rewards store',
            onTap: () => context.push('/fanzone/rewards'),
          ),
          AfriSheetAction(
            icon: AfriIcons.history,
            label: 'Token history',
            onTap: () => context.push('/fanzone/history'),
          ),
          AfriSheetAction(
            icon: AfriIcons.friend,
            label: 'Friends',
            onTap: () => context.push('/fanzone/friends'),
          ),
          AfriSheetAction(
            icon: AfriIcons.versus,
            label: 'Challenge a friend',
            onTap: () => context.push('/fanzone/challenge'),
          ),
          AfriSheetAction(
            icon: AfriIcons.share,
            label: 'Share card',
            onTap: () => context.push('/fanzone/share'),
          ),
          AfriSheetAction(
            icon: AfriIcons.league,
            label: 'League hub',
            onTap: () => context.push('/fanzone/league'),
          ),
          AfriSheetAction(
            icon: AfriIcons.clubZone,
            label: 'Club zone',
            onTap: () => context.push('/fanzone/club-zone'),
          ),
        ],
      ),
    );
  }
}
