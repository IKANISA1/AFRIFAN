import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/partner_pool_models.dart';
import '../prediction_providers.dart';
import '../providers/fanzone_hub_provider.dart';
import '../widgets/fanzone_hub_widgets.dart';

/// Fanzone Hub — partner WDW pools, wallet, fixtures, leaderboard, and rewards.
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
      appBar: AfriAppBar(
        title: Text('Fanzone', style: TypographyTokens.headlineSmall()),
        actions: [
          AfriIconButton(
            icon: AfriIcons.more,
            onTap: () => _showOverflow(context),
            tooltip: 'More options',
          ),
        ],
      ),
      body: asyncHub.when(
        loading: () => _buildPendingContent(context, ref),
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

  Widget _buildPendingContent(BuildContext context, WidgetRef ref) {
    return GradientBackground(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SpacingTokens.screenPadding,
                SpacingTokens.spacing4,
                SpacingTokens.screenPadding,
                0,
              ),
              child: AfriStateView.loading(
                title: 'Opening Fanzone',
                message:
                    'Fixtures, wallet, predictions, and rewards are loading.',
                compact: true,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SpacingTokens.screenPadding,
                SpacingTokens.sectionGap,
                SpacingTokens.screenPadding,
                0,
              ),
              child: HubQuickRoutes(onMore: () => _showOverflow(context)),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                SpacingTokens.screenPadding,
                SpacingTokens.sectionGap,
                SpacingTokens.screenPadding,
                120,
              ),
              child: AfriSkeletonList(itemCount: 2),
            ),
          ),
        ],
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
      child: AfriRefreshIndicator(
        onRefresh: () => notifier.refresh(),
        color: ColorTokens.clubAccent,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // ── Degraded / partial error banner ──
            if (snapshot.status != FanzoneHubStatus.ok &&
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
                child: HubQuickRoutes(onMore: () => _showOverflow(context)),
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

            // ── Partner WDW pools ──
            if (snapshot.partnerPools.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.screenPadding,
                    SpacingTokens.sectionGap,
                    SpacingTokens.screenPadding,
                    0,
                  ),
                  child: AfriSectionCard(
                    title: 'Partner WDW Pools',
                    child: Column(
                      children: snapshot.partnerPools
                          .map(
                            (pool) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: SpacingTokens.listItemGap,
                              ),
                              child: HubPartnerPoolRow(
                                pool: pool,
                                onJoin: () => _showPartnerPoolJoinSheet(
                                  context,
                                  ref,
                                  pool,
                                ),
                              ),
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
                  child: snapshot.leaderboard.isEmpty
                      ? _sectionState(
                          title: 'Leaderboard unavailable',
                          message:
                              'Supporter rankings will appear after live updates resume.',
                        )
                      : Column(
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

            const SliverToBoxAdapter(
              child: SizedBox(
                height: SpacingTokens.spacing20 + SpacingTokens.spacing10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionState({required String title, required String message}) {
    return AfriStateView.offline(title: title, message: message, compact: true);
  }

  Future<void> _showPartnerPoolJoinSheet(
    BuildContext parentContext,
    WidgetRef ref,
    PartnerPredictionPool pool,
  ) {
    const outcomes = <PartnerPoolOutcome>[
      PartnerPoolOutcome.homeWin,
      PartnerPoolOutcome.draw,
      PartnerPoolOutcome.awayWin,
    ];

    var selectedOutcome = PartnerPoolOutcome.homeWin;
    var isSubmitting = false;

    return showAfriBottomSheet<void>(
      context: parentContext,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submit() async {
              if (isSubmitting) return;
              setSheetState(() => isSubmitting = true);

              final result = await ref
                  .read(partnerPoolRepositoryProvider)
                  .joinPool(
                    poolId: pool.id,
                    selectedOutcome: selectedOutcome.rpcValue,
                    idempotencyKey:
                        '${pool.id}-${selectedOutcome.rpcValue}-${DateTime.now().microsecondsSinceEpoch}',
                  );

              if (!sheetContext.mounted) return;

              if (result.status == 'error') {
                setSheetState(() => isSubmitting = false);
                AfriToast.error(
                  sheetContext,
                  'Pool entry could not be recorded.',
                );
                return;
              }

              closeAfriBottomSheet(sheetContext);
              await ref.read(fanzoneHubProvider.notifier).refresh();

              if (!parentContext.mounted) return;
              AfriToast.success(
                parentContext,
                '${selectedOutcome.label} joined for ${pool.fanEntryFet} FET.',
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(pool.title, style: TypographyTokens.sectionTitle()),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  '${pool.partnerName} funds ${pool.partnerStakeFet} FET. '
                  'Your fixed entry is ${pool.fanEntryFet} FET.',
                  style: TypographyTokens.bodyMedium(),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  pool.eligibilityLabel,
                  style: TypographyTokens.labelMedium(ColorTokens.clubAccent),
                ),
                const SizedBox(height: SpacingTokens.spacing5),
                ...outcomes.map(
                  (outcome) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: SpacingTokens.spacing3,
                    ),
                    child: PartnerPoolOutcomeOption(
                      outcome: outcome,
                      isSelected: selectedOutcome == outcome,
                      onTap: () =>
                          setSheetState(() => selectedOutcome = outcome),
                    ),
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                AfriButton(
                  label: 'Stake ${pool.fanEntryFet} FET',
                  icon: AfriIcons.predict,
                  isLoading: isSubmitting,
                  onTap: submit,
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showOverflow(BuildContext context) {
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
