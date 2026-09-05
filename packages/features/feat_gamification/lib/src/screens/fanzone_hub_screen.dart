import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/partner_pool_models.dart';
import '../prediction_providers.dart';
import '../providers/fanzone_hub_provider.dart';
import '../widgets/fanzone_hub_widgets.dart';

enum _FanzoneHubSection {
  predictions('predictions', AfriIcons.predict),
  league('league', AfriIcons.league),
  wallet('wallet', AfriIcons.wallet),
  supporters('supporters', AfriIcons.groups),
  rewards('rewards', AfriIcons.rewards);

  const _FanzoneHubSection(this.value, this.icon);

  final String value;
  final IconData icon;

  static _FanzoneHubSection fromUri(Uri uri, {required bool allowsRewards}) {
    final raw = uri.queryParameters['section']?.trim().toLowerCase();
    var normalized = raw;
    if (raw == null || raw.isEmpty || raw == 'play') {
      normalized = 'predictions';
    } else if (raw == 'activity') {
      normalized = 'supporters';
    } else if (raw == 'points' || raw == 'pay') {
      normalized = 'wallet';
    }
    final selected = _FanzoneHubSection.values.firstWhere(
      (section) => section.value == normalized,
      orElse: () => _FanzoneHubSection.values.first,
    );
    if (selected == _FanzoneHubSection.rewards && !allowsRewards) {
      return _FanzoneHubSection.wallet;
    }
    return selected;
  }
}

/// Fan Zone hub — football predictions, supporter activity, and social points.
///
/// Uses [FanzoneHubNotifier] via Riverpod for async state management instead
/// of manual setState, enabling proper caching and DevTools integration.
class FanzoneHubScreen extends ConsumerWidget {
  const FanzoneHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.afriL10n;
    final asyncHub = ref.watch(fanzoneHubProvider);
    final notifier = ref.read(fanzoneHubProvider.notifier);

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      showAppBar: false,
      scrollable: false,
      constrainContent: false,
      bottomNavigationAware: true,
      child: AfriAsyncStateView<FanzoneHubSnapshot>(
        value: asyncHub,
        loading: (_) => _buildPendingContent(context, ref),
        error: (_, error, stackTrace) {
          final failure = _FanzoneFailureContent.fromError(error, l10n);
          return ConnectivityBuilder(
            builder: (context, isOnline) => Center(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.screenPadding),
                child: AfriStateView.offline(
                  title: isOnline
                      ? failure.title
                      : l10n.gameFanZoneUnavailableTitle,
                  message: isOnline
                      ? failure.message
                      : l10n.gameConnectToFanZone,
                  actionLabel: isOnline
                      ? failure.actionLabel
                      : l10n.connectionRequired,
                  onAction: isOnline && failure.actionLabel != null
                      ? () => notifier.refresh()
                      : null,
                ),
              ),
            ),
          );
        },
        data: (context, snapshot) =>
            _buildContent(context, ref, snapshot, asyncHub.isRefreshing),
      ),
    );
  }

  Widget _buildPendingContent(BuildContext context, WidgetRef ref) {
    final storePolicy = ref.watch(storeReleasePolicyProvider);
    final selectedSection = _FanzoneHubSection.fromUri(
      GoRouterState.of(context).uri,
      allowsRewards: storePolicy.allowsRewardRedemption,
    );

    return GradientBackground(
      routePath: '/fanzone',
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.screenPadding),
                child: AfriTopCommandBar(
                  searchHint: context.afriL10n.homeSearchHint,
                  onSearchTap: () => context.push('/search'),
                  onAvatarTap: () => context.go('/settings'),
                  actions: [
                    AfriTopCommandAction(
                      icon: AfriIcons.more,
                      label: context.afriL10n.gameMoreOptions,
                      onTap: () => _showOverflow(context, storePolicy),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SpacingTokens.screenPadding,
                SpacingTokens.spacing4,
                SpacingTokens.screenPadding,
                0,
              ),
              child: AfriStateView.loading(
                title: context.afriL10n.gameOpeningFanZone,
                message: context.afriL10n.fanZoneLoading,
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
              child: _buildSectionSelector(
                context,
                selectedSection,
                storePolicy,
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                SpacingTokens.screenPadding,
                SpacingTokens.sectionGap,
                SpacingTokens.screenPadding,
                SpacingTokens.spacing20,
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
    final l10n = context.afriL10n;
    final notifier = ref.read(fanzoneHubProvider.notifier);
    final storePolicy = ref.watch(storeReleasePolicyProvider);
    final selectedSection = _FanzoneHubSection.fromUri(
      GoRouterState.of(context).uri,
      allowsRewards: storePolicy.allowsRewardRedemption,
    );
    final profile = ref.watch(currentUserProvider);

    return GradientBackground(
      routePath: '/fanzone',
      child: AfriRefreshIndicator(
        onRefresh: () => notifier.refresh(),
        color: ColorTokens.primaryContainer,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(SpacingTokens.screenPadding),
                  child: AfriTopCommandBar(
                    searchHint: context.afriL10n.homeSearchHint,
                    onSearchTap: () => context.push('/search'),
                    onAvatarTap: () => context.go('/settings'),
                    actions: [
                      AfriTopCommandAction(
                        icon: AfriIcons.more,
                        label: context.afriL10n.gameMoreOptions,
                        onTap: () => _showOverflow(context, storePolicy),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isRefreshing)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.screenPadding,
                    SpacingTokens.spacing4,
                    SpacingTokens.screenPadding,
                    0,
                  ),
                  child: AfriStateBanner(
                    icon: AfriIcons.refresh,
                    title: l10n.gameRefreshingFanZone,
                    subtitle: l10n.gameRefreshingFanZoneDescription,
                    tone: AfriStateBannerTone.info,
                    compact: true,
                  ),
                ),
              ),

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
                  child: AfriStateBanner(
                    icon: AfriIcons.statusWarning,
                    title: l10n.homeUpdatesPausedTitle,
                    subtitle: _snapshotMessage(l10n, snapshot.message!),
                    tone: AfriStateBannerTone.warning,
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

            // ── Hub sections ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  SpacingTokens.screenPadding,
                  SpacingTokens.spacing4,
                  SpacingTokens.screenPadding,
                  0,
                ),
                child: _buildSectionSelector(
                  context,
                  selectedSection,
                  storePolicy,
                ),
              ),
            ),

            if (_isSection(selectedSection, {'play', 'predictions'})) ...[
              if (storePolicy.allowsStakedCompetitions)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SpacingTokens.screenPadding,
                      SpacingTokens.sectionGap,
                      SpacingTokens.screenPadding,
                      0,
                    ),
                    child: AfriSectionCard(
                      title: l10n.gameMatchdayRounds,
                      trailingLabel: l10n.gamePicksLabel,
                      onTrailingTap: () => context.push('/fanzone/my'),
                      child: snapshot.partnerPools.isEmpty
                          ? _sectionState(
                              title: l10n.gameNoMatchdayRounds,
                              message: context.afriL10n.fanZoneRoundsEmpty,
                            )
                          : Column(
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.screenPadding,
                    SpacingTokens.sectionGap,
                    SpacingTokens.screenPadding,
                    0,
                  ),
                  child: AfriSectionCard(
                    title: l10n.gameMatchdayRounds,
                    child: _HubActionList(
                      actions: [
                        if (storePolicy.allowsStakedCompetitions)
                          _HubAction(
                            icon: AfriIcons.profile,
                            title: l10n.gameSupporters,
                            subtitle: l10n.gameReviewJoinedRounds,
                            onTap: () =>
                                context.go('/fanzone?section=supporters'),
                          ),
                        _HubAction.featureGated(
                          featureKey: 'venue_checkin',
                          icon: AfriIcons.qrScan,
                          title: l10n.gameVenueCheckIn,
                          subtitle: context.afriL10n.fanZoneVenueCode,
                          onTap: () => context.push('/fanzone/venue'),
                        ),
                        _HubAction.featureGated(
                          featureKey: 'venue_checkin',
                          icon: AfriIcons.cart,
                          title: l10n.gameVenueOrder,
                          subtitle: l10n.gameVenueOrderDescription,
                          onTap: () => context.push('/fanzone/venue/order'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            if (selectedSection == _FanzoneHubSection.league) ...[
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
                      title: l10n.gameLiveNow,
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
                          title: l10n.gameToday,
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
                      title: l10n.gameThisWeek,
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
                    title: l10n.gameLeaderboardTitle,
                    child: snapshot.leaderboard.isEmpty
                        ? _sectionState(
                            title: l10n.gameLeaderboardUnavailable,
                            message: context.afriL10n.fanZoneRankingsEmpty,
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
            ],

            if (selectedSection == _FanzoneHubSection.wallet)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.screenPadding,
                    SpacingTokens.sectionGap,
                    SpacingTokens.screenPadding,
                    0,
                  ),
                  child: AfriSectionCard(
                    title: l10n.gamePointsLabel,
                    child: _HubActionList(
                      actions: [
                        _HubAction(
                          icon: AfriIcons.earn,
                          title: l10n.gamePointsBalanceTitle,
                          subtitle: l10n.gamePointsBalanceDescription,
                          onTap: () => context.push('/fanzone/wallet'),
                        ),
                        _HubAction(
                          icon: AfriIcons.history,
                          title: l10n.gameActivity,
                          subtitle: l10n.gameOpenPointsActivity,
                          onTap: () =>
                              context.push('/fanzone/wallet?section=history'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (selectedSection == _FanzoneHubSection.supporters)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.screenPadding,
                    SpacingTokens.sectionGap,
                    SpacingTokens.screenPadding,
                    0,
                  ),
                  child: AfriSectionCard(
                    title: l10n.gameSupporters,
                    child: Column(
                      children: [
                        _FanIdSummaryCard(
                          fanId: _fanIdLabel(profile),
                          onTap: () =>
                              _showFanIdSheet(context, _fanIdLabel(profile)),
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        _HubActionList(
                          actions: [
                            _HubAction(
                              icon: AfriIcons.clubZone,
                              title: l10n.gameSupporterClubs,
                              subtitle: l10n.gameSupporterClubsDescription,
                              onTap: () => _showSupporterSurfaceSheet(
                                context,
                                title: l10n.gameSupporterClubs,
                                message: context.afriL10n.fanZoneClubsMoved,
                              ),
                            ),
                            _HubAction(
                              icon: AfriIcons.groups,
                              title: l10n.gameMemberFans,
                              subtitle: l10n.gameMemberFansDescription,
                              onTap: () => _showSupporterSurfaceSheet(
                                context,
                                title: l10n.gameMemberFans,
                                message: context.afriL10n.fanZoneRegistryMoved,
                              ),
                            ),
                            _HubAction(
                              icon: AfriIcons.contribute,
                              title: l10n.searchContributionsTitle,
                              subtitle: l10n.gameSupportClubDescription,
                              onTap: () => _showSupportTheClubSheet(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (storePolicy.allowsRewardRedemption &&
                selectedSection == _FanzoneHubSection.rewards)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.screenPadding,
                    SpacingTokens.sectionGap,
                    SpacingTokens.screenPadding,
                    0,
                  ),
                  child: AfriSectionCard(
                    title: l10n.gameRewardsLabel,
                    child: Column(
                      children: [
                        _AchievementRail(
                          streak: snapshot.dashboard?.currentStreak ?? 0,
                          winRate: snapshot.dashboard?.winRate ?? 0,
                          balance: snapshot.wallet?.balance ?? 0,
                          onTap: () =>
                              _showAchievementsSheet(context, snapshot),
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        _HubActionList(
                          actions: [
                            _HubAction(
                              icon: AfriIcons.rewards,
                              title: l10n.gameRedeemRewards,
                              subtitle: l10n.gameRedeemRewardsDescription,
                              onTap: () =>
                                  context.go('/fanzone?section=wallet'),
                            ),
                            _HubAction(
                              icon: AfriIcons.badge,
                              title: l10n.gameAchievements,
                              subtitle: l10n.gameAchievementsDescription,
                              onTap: () =>
                                  _showAchievementsSheet(context, snapshot),
                            ),
                            _HubAction(
                              icon: AfriIcons.share,
                              title: l10n.gameShareCard,
                              subtitle: l10n.gameShareCardDescription,
                              onTap: () => context.push('/fanzone/share'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SliverToBoxAdapter(
              child: SizedBox(height: SpacingTokens.spacing20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionState({required String title, required String message}) {
    return AfriStateView.offline(title: title, message: message, compact: true);
  }

  Widget _buildSectionSelector(
    BuildContext context,
    _FanzoneHubSection selectedSection,
    StoreReleasePolicy storePolicy,
  ) {
    final sections = _FanzoneHubSection.values
        .where(
          (section) =>
              section != _FanzoneHubSection.rewards ||
              storePolicy.allowsRewardRedemption,
        )
        .toList(growable: false);
    return AfriSegmentedControl(
      items: sections
          .map(
            (section) => AfriSegment(
              label: _sectionLabel(context, section),
              icon: section.icon,
            ),
          )
          .toList(growable: false),
      selectedIndex: sections.indexOf(selectedSection),
      onChanged: (index) {
        final section = sections[index];
        unawaited(
          FirebaseAnalyticsService.logFanzoneEngagement(
            surface: section.value,
            action: 'open',
          ),
        );
        context.go('/fanzone?section=${section.value}');
      },
    );
  }

  bool _isSection(_FanzoneHubSection section, Set<String> values) {
    return values.contains(section.value);
  }

  String _sectionLabel(BuildContext context, _FanzoneHubSection section) {
    final l10n = context.afriL10n;
    return switch (section) {
      _FanzoneHubSection.predictions => l10n.gamePickSectionLabel,
      _FanzoneHubSection.league => l10n.gameLeague,
      _FanzoneHubSection.wallet => l10n.gamePointsLabel,
      _FanzoneHubSection.supporters => l10n.gameFans,
      _FanzoneHubSection.rewards => l10n.gameRewardsLabel,
    };
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
              if (!ConnectivityService.isOnline) {
                AfriToast.error(
                  sheetContext,
                  sheetContext.afriL10n.gameConnectBeforeJoiningRound,
                );
                return;
              }
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
                  sheetContext.afriL10n.gamePoolEntryFailed,
                );
                return;
              }

              closeAfriBottomSheet(sheetContext);
              await ref.read(fanzoneHubProvider.notifier).refresh();

              if (!parentContext.mounted) return;
              AfriToast.success(
                parentContext,
                parentContext.afriL10n.gameOutcomeJoined(
                  partnerPoolOutcomeLabel(
                    parentContext.afriL10n,
                    selectedOutcome,
                  ),
                ),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(pool.title, style: TypographyTokens.sectionTitle()),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  sheetContext.afriL10n.gamePartnerSponsorsRound(
                    pool.partnerName,
                  ),
                  style: TypographyTokens.bodyMedium(),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  partnerPoolEligibilityLabel(
                    parentContext.afriL10n,
                    pool.eligibilityMode,
                  ),
                  style: TypographyTokens.labelMedium(
                    ColorTokens.primaryContainer,
                  ),
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
                ConnectivityBuilder(
                  builder: (context, isOnline) => AfriButton(
                    label: isOnline
                        ? context.afriL10n.gameJoinRound
                        : context.afriL10n.connectionRequired,
                    icon: AfriIcons.predict,
                    isLoading: isSubmitting,
                    onTap: submit,
                    enabled: isOnline && !isSubmitting,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showOverflow(BuildContext context, StoreReleasePolicy storePolicy) {
    unawaited(
      showAfriActionSheet(
        context: context,
        title: context.afriL10n.navFanZone,
        actions: [
          AfriSheetAction(
            icon: AfriIcons.myPicks,
            label: context.afriL10n.gamePicksLabel,
            onTap: () => context.go('/fanzone?section=predictions'),
          ),
          AfriSheetAction(
            icon: AfriIcons.league,
            label: context.afriL10n.gameLeague,
            onTap: () => context.go('/fanzone?section=league'),
          ),
          AfriSheetAction(
            icon: AfriIcons.wallet,
            label: context.afriL10n.gamePointsLabel,
            onTap: () => context.go('/fanzone?section=wallet'),
          ),
          AfriSheetAction(
            icon: AfriIcons.groups,
            label: context.afriL10n.gameFans,
            onTap: () => context.go('/fanzone?section=supporters'),
          ),
          if (storePolicy.allowsRewardRedemption)
            AfriSheetAction(
              icon: AfriIcons.rewards,
              label: context.afriL10n.gameRewardsLabel,
              onTap: () => context.go('/fanzone?section=rewards'),
            ),
        ],
      ),
    );
  }

  void _showSupportTheClubSheet(BuildContext context) {
    unawaited(
      showAfriBottomSheet<void>(
        context: context,
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.afriL10n.searchContributionsTitle,
              style: TypographyTokens.sectionTitle(),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              context.afriL10n.fanZoneContributionMode,
              style: TypographyTokens.bodyMedium(ColorTokens.onSurfaceVariant),
            ),
            const SizedBox(height: SpacingTokens.spacing5),
            AfriListRow(
              icon: AfriIcons.contribute,
              title: context.afriL10n.gameProjects,
              subtitle: context.afriL10n.gameProjectsDescription,
              onTap: () {},
            ),
            const SizedBox(height: SpacingTokens.listItemGap),
            AfriListRow(
              icon: AfriIcons.groups,
              title: context.afriL10n.gameGroups,
              subtitle: context.afriL10n.gameGroupsDescription,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  void _showFanIdSheet(BuildContext context, String fanId) {
    unawaited(
      showAfriBottomSheet<void>(
        context: context,
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.afriL10n.gameFanIdTitle,
              style: TypographyTokens.sectionTitle(),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            AfriListRow(
              icon: AfriIcons.qrCode,
              title: fanId,
              subtitle: context.afriL10n.gameQrSheetDescription,
            ),
          ],
        ),
      ),
    );
  }

  void _showSupporterSurfaceSheet(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    unawaited(
      showAfriBottomSheet<void>(
        context: context,
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: TypographyTokens.sectionTitle()),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              message,
              style: TypographyTokens.bodyMedium(ColorTokens.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  void _showAchievementsSheet(
    BuildContext context,
    FanzoneHubSnapshot snapshot,
  ) {
    final streak = snapshot.dashboard?.currentStreak ?? 0;
    final winRate = snapshot.dashboard?.winRate ?? 0;
    final balance = snapshot.wallet?.balance ?? 0;

    unawaited(
      showAfriBottomSheet<void>(
        context: context,
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.afriL10n.gameAchievements,
              style: TypographyTokens.sectionTitle(),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              context.afriL10n.fanZoneRewardsSummary,
              style: TypographyTokens.bodyMedium(ColorTokens.onSurfaceVariant),
            ),
            const SizedBox(height: SpacingTokens.spacing5),
            AfriStatRow(
              stats: [
                AfriStat(
                  label: context.afriL10n.gameStreakLabel,
                  value: '$streak',
                  icon: AfriIcons.streak,
                  accentColor: ColorTokens.primaryContainer,
                ),
                AfriStat(
                  label: context.afriL10n.gameAccuracyLabel,
                  value: '${winRate.toStringAsFixed(0)}%',
                  icon: AfriIcons.predict,
                  accentColor: ColorTokens.success,
                ),
                AfriStat(
                  label: context.afriL10n.gamePointsLabel,
                  value: '$balance',
                  icon: AfriIcons.earn,
                  accentColor: ColorTokens.primaryContainer,
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing5),
            AfriListRow(
              icon: AfriIcons.badge,
              title: context.afriL10n.gameBadgesLabel,
              subtitle: context.afriL10n.gameBadgesEarnedDescription,
              onTap: () {},
            ),
            const SizedBox(height: SpacingTokens.listItemGap),
            AfriListRow(
              icon: AfriIcons.streak,
              title: context.afriL10n.gameStreakLabel,
              subtitle: streak == 0
                  ? context.afriL10n.gameStartStreak
                  : context.afriL10n.gameActivePlayDays(streak),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

String _fanIdLabel(UserProfile? profile) {
  final publicUserId = profile?.publicUserId?.trim();
  if (publicUserId != null && publicUserId.isNotEmpty) {
    return '#${AliasGenerator.format(publicUserId)}';
  }
  return '#------';
}

class _FanIdSummaryCard extends StatelessWidget {
  const _FanIdSummaryCard({required this.fanId, required this.onTap});

  final String fanId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AfriListRow(
      icon: AfriIcons.qrCode,
      title: fanId,
      subtitle: context.afriL10n.gameFanIdQrDisplay,
      trailing: AfriStatusChip(
        label: context.afriL10n.gameQr,
        tone: AfriStatusTone.info,
      ),
      onTap: onTap,
    );
  }
}

class _AchievementRail extends StatelessWidget {
  const _AchievementRail({
    required this.streak,
    required this.winRate,
    required this.balance,
    required this.onTap,
  });

  final int streak;
  final double winRate;
  final int balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AfriStatRow(
      stats: [
        AfriStat(
          label: context.afriL10n.gameStreakLabel,
          value: '$streak',
          icon: AfriIcons.streak,
          accentColor: ColorTokens.primaryContainer,
          onTap: onTap,
        ),
        AfriStat(
          label: context.afriL10n.gameAccuracyLabel,
          value: '${winRate.toStringAsFixed(0)}%',
          icon: AfriIcons.predict,
          accentColor: ColorTokens.success,
          onTap: onTap,
        ),
        AfriStat(
          label: context.afriL10n.gamePointsLabel,
          value: '$balance',
          icon: AfriIcons.earn,
          accentColor: ColorTokens.primaryContainer,
          onTap: onTap,
        ),
      ],
    );
  }
}

class _HubAction {
  const _HubAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  }) : featureKey = null;

  const _HubAction.featureGated({
    required String this.featureKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? featureKey;
}

class _HubActionList extends ConsumerWidget {
  const _HubActionList({required this.actions});

  final List<_HubAction> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featureConfig = ref.watch(featureConfigServiceProvider);
    return AfriListGroup(
      children: actions
          .map((action) {
            final featureKey = action.featureKey;
            final access = featureKey == null
                ? null
                : featureConfig.getFeatureAccess(featureKey);
            if (access != null && !access.isVisible) {
              return const SizedBox.shrink();
            }
            final enabled = access?.isAvailable ?? true;
            final row = AfriListRow(
              icon: action.icon,
              title: action.title,
              subtitle: enabled
                  ? action.subtitle
                  : context.afriL10n.gameActionUnavailable(action.subtitle),
              trailing: enabled
                  ? null
                  : AfriInfoChip(
                      label: context.afriL10n.settingsUnavailable,
                      color: ColorTokens.warning,
                    ),
              onTap: enabled ? action.onTap : null,
              enabled: enabled,
            );
            return row;
          })
          .toList(growable: false),
    );
  }
}

class _FanzoneFailureContent {
  const _FanzoneFailureContent({
    required this.title,
    required this.message,
    required this.actionLabel,
  });

  final String title;
  final String message;
  final String? actionLabel;

  factory _FanzoneFailureContent.fromError(
    Object error,
    AfriLocalizations l10n,
  ) {
    final failure = FanzoneHubFailure.fromError(error);
    return switch (failure.kind) {
      FanzoneHubFailureKind.permissionDenied => _FanzoneFailureContent(
        title: l10n.gameFanZoneAccessUnavailable,
        message: l10n.gameFanZoneAccessUnavailableDescription,
        actionLabel: null,
      ),
      FanzoneHubFailureKind.conflict => _FanzoneFailureContent(
        title: l10n.gameFanZoneChanged,
        message: l10n.gameFanZoneChangedDescription,
        actionLabel: l10n.gameRefresh,
      ),
      FanzoneHubFailureKind.securityTimeout => _FanzoneFailureContent(
        title: l10n.gameFanZoneSecurityTimedOut,
        message: l10n.gameFanZoneSecurityTimedOutDescription,
        actionLabel: l10n.gameRefresh,
      ),
      FanzoneHubFailureKind.unknown => _FanzoneFailureContent(
        title: l10n.gameFanZoneUnavailableTitle,
        message: l10n.gameFanZoneTemporarilyUnavailable,
        actionLabel: l10n.gameRetry,
      ),
    };
  }
}

String _snapshotMessage(AfriLocalizations l10n, String message) {
  return switch (message) {
    FanzoneHubSnapshotMessage.savedContent => l10n.gameSavedFanZoneContent,
    FanzoneHubSnapshotMessage.connectionRequired => l10n.gameConnectToFanZone,
    _ => message,
  };
}
