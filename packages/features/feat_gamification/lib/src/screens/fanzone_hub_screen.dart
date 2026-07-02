import 'dart:async';

import 'package:core_auth/core_auth.dart';
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
  predictions('predictions', 'Pick', AfriIcons.predict),
  league('league', 'League', AfriIcons.league),
  wallet('wallet', 'Points', AfriIcons.wallet),
  supporters('supporters', 'Fans', AfriIcons.groups),
  rewards('rewards', 'Rewards', AfriIcons.rewards);

  const _FanzoneHubSection(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;

  static _FanzoneHubSection fromUri(Uri uri) {
    final raw = uri.queryParameters['section']?.trim().toLowerCase();
    var normalized = raw;
    if (raw == null || raw.isEmpty || raw == 'play') {
      normalized = 'predictions';
    } else if (raw == 'activity') {
      normalized = 'supporters';
    } else if (raw == 'points' || raw == 'pay') {
      normalized = 'wallet';
    }
    return _FanzoneHubSection.values.firstWhere(
      (section) => section.value == normalized,
      orElse: () => _FanzoneHubSection.values.first,
    );
  }
}

/// Fan Zone hub — TV-led games, supporter activity, and social points.
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
      body: AfriAsyncStateView<FanzoneHubSnapshot>(
        value: asyncHub,
        loading: (_) => _buildPendingContent(context, ref),
        error: (_, error, stackTrace) => Center(
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
        data: (context, snapshot) =>
            _buildContent(context, ref, snapshot, asyncHub.isRefreshing),
      ),
    );
  }

  Widget _buildPendingContent(BuildContext context, WidgetRef ref) {
    final selectedSection = _FanzoneHubSection.fromUri(
      GoRouterState.of(context).uri,
    );

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
                    'Picks, league, points, fans, and rewards are loading.',
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
              child: _buildSectionSelector(context, selectedSection),
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
    final selectedSection = _FanzoneHubSection.fromUri(
      GoRouterState.of(context).uri,
    );
    final profile = ref.watch(currentUserProvider);

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
                  child: AfriStateBanner(
                    icon: AfriIcons.statusWarning,
                    title: 'Live updates paused',
                    subtitle: snapshot.message!,
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
                child: _buildSectionSelector(context, selectedSection),
              ),
            ),

            if (_isSection(selectedSection, {'play', 'predictions'})) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.screenPadding,
                    SpacingTokens.sectionGap,
                    SpacingTokens.screenPadding,
                    0,
                  ),
                  child: AfriSectionCard(
                    title: 'TV game',
                    child: _HubActionList(
                      actions: [
                        _HubAction(
                          icon: AfriIcons.live,
                          title: 'Enter TV code',
                          subtitle:
                              'Join a live session and use this phone as the controller',
                          onTap: () => context.push('/fanzone/game'),
                        ),
                        _HubAction(
                          icon: AfriIcons.profile,
                          title: 'Supporters',
                          subtitle: 'Review joined rounds, cards, and results',
                          onTap: () =>
                              context.go('/fanzone?section=supporters'),
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
                    SpacingTokens.sectionGap,
                    SpacingTokens.screenPadding,
                    0,
                  ),
                  child: AfriSectionCard(
                    title: 'Matchday rounds',
                    trailingLabel: 'Picks',
                    onTrailingTap: () => context.push('/fanzone/my'),
                    child: snapshot.partnerPools.isEmpty
                        ? _sectionState(
                            title: 'No matchday rounds',
                            message:
                                'Club and partner rounds will appear when matchday opens.',
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
                    title: 'Leaderboard',
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
                    title: 'Points',
                    child: _HubActionList(
                      actions: [
                        _HubAction(
                          icon: AfriIcons.earn,
                          title: 'Points balance',
                          subtitle: 'Balance, earning, rewards, and activity',
                          onTap: () => context.push('/fanzone/wallet'),
                        ),
                        _HubAction(
                          icon: AfriIcons.history,
                          title: 'Activity',
                          subtitle: 'Open recent points movement',
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
                    title: 'Supporters',
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
                              title: 'Supporter clubs',
                              subtitle:
                                  'Fan clubs, chapters, and community groups',
                              onTap: () => _showSupporterSurfaceSheet(
                                context,
                                title: 'Supporter clubs',
                                message:
                                    'Fan clubs and chapters now live inside Supporters.',
                              ),
                            ),
                            _HubAction(
                              icon: AfriIcons.groups,
                              title: 'Member fans',
                              subtitle:
                                  'Open the supporter registry as a sheet',
                              onTap: () => _showSupporterSurfaceSheet(
                                context,
                                title: 'Member fans',
                                message:
                                    'The supporter registry is consolidated into Fan Zone Supporters.',
                              ),
                            ),
                            _HubAction(
                              icon: AfriIcons.contribute,
                              title: 'Support the club',
                              subtitle:
                                  'Projects and supporter contribution groups',
                              onTap: () => _showSupportTheClubSheet(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (selectedSection == _FanzoneHubSection.rewards)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.screenPadding,
                    SpacingTokens.sectionGap,
                    SpacingTokens.screenPadding,
                    0,
                  ),
                  child: AfriSectionCard(
                    title: 'Rewards',
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
                              title: 'Redeem rewards',
                              subtitle:
                                  'Use points for rewards and partner offers',
                              onTap: () =>
                                  context.go('/fanzone?section=wallet'),
                            ),
                            _HubAction(
                              icon: AfriIcons.badge,
                              title: 'Achievements',
                              subtitle: 'Badges and streak status',
                              onTap: () =>
                                  _showAchievementsSheet(context, snapshot),
                            ),
                            _HubAction(
                              icon: AfriIcons.share,
                              title: 'Share card',
                              subtitle: 'Create a supporter card to share',
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

  Widget _buildSectionSelector(
    BuildContext context,
    _FanzoneHubSection selectedSection,
  ) {
    return AfriSegmentedControl(
      items: _FanzoneHubSection.values
          .map(
            (section) =>
                AfriSegment(label: _sectionLabel(section), icon: section.icon),
          )
          .toList(growable: false),
      selectedIndex: _FanzoneHubSection.values.indexOf(selectedSection),
      onChanged: (index) {
        final section = _FanzoneHubSection.values[index];
        context.go('/fanzone?section=${section.value}');
      },
    );
  }

  bool _isSection(_FanzoneHubSection section, Set<String> values) {
    return values.contains(section.value);
  }

  String _sectionLabel(_FanzoneHubSection section) {
    return section.label;
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
                '${selectedOutcome.label} joined.',
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(pool.title, style: TypographyTokens.sectionTitle()),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  '${pool.partnerName} sponsors this matchday round. '
                  'Pick once before the round locks.',
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
                  label: 'Join round',
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
            label: 'Picks',
            onTap: () => context.go('/fanzone?section=predictions'),
          ),
          AfriSheetAction(
            icon: AfriIcons.league,
            label: 'League',
            onTap: () => context.go('/fanzone?section=league'),
          ),
          AfriSheetAction(
            icon: AfriIcons.wallet,
            label: 'Points',
            onTap: () => context.go('/fanzone?section=wallet'),
          ),
          AfriSheetAction(
            icon: AfriIcons.groups,
            label: 'Fans',
            onTap: () => context.go('/fanzone?section=supporters'),
          ),
          AfriSheetAction(
            icon: AfriIcons.rewards,
            label: 'Rewards',
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
            Text('Support the club', style: TypographyTokens.sectionTitle()),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              'Choose a contribution mode without leaving the Supporters hub.',
              style: TypographyTokens.bodyMedium(ColorTokens.onSurfaceVariant),
            ),
            const SizedBox(height: SpacingTokens.spacing5),
            AfriListRow(
              icon: AfriIcons.contribute,
              title: 'Projects',
              subtitle: 'Club initiatives and campaign needs',
              onTap: () {},
            ),
            const SizedBox(height: SpacingTokens.listItemGap),
            AfriListRow(
              icon: AfriIcons.groups,
              title: 'Groups',
              subtitle: 'Join supporter contribution groups',
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
            Text('Fan ID', style: TypographyTokens.sectionTitle()),
            const SizedBox(height: SpacingTokens.spacing2),
            AfriListRow(
              icon: AfriIcons.qrCode,
              title: fanId,
              subtitle: 'QR display and sharing stay inside this sheet.',
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
            Text('Achievements', style: TypographyTokens.sectionTitle()),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              'Badges, streaks, and reward momentum in one compact view.',
              style: TypographyTokens.bodyMedium(ColorTokens.onSurfaceVariant),
            ),
            const SizedBox(height: SpacingTokens.spacing5),
            AfriStatRow(
              stats: [
                AfriStat(
                  label: 'Streak',
                  value: '$streak',
                  icon: AfriIcons.streak,
                  accentColor: ColorTokens.clubAccent,
                ),
                AfriStat(
                  label: 'Accuracy',
                  value: '${winRate.toStringAsFixed(0)}%',
                  icon: AfriIcons.predict,
                  accentColor: ColorTokens.success,
                ),
                AfriStat(
                  label: 'Points',
                  value: '$balance',
                  icon: AfriIcons.earn,
                  accentColor: ColorTokens.primaryContainer,
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing5),
            AfriListRow(
              icon: AfriIcons.badge,
              title: 'Badges',
              subtitle: 'Earned from picks, attendance, and support actions',
              onTap: () {},
            ),
            const SizedBox(height: SpacingTokens.listItemGap),
            AfriListRow(
              icon: AfriIcons.streak,
              title: 'Streak',
              subtitle: streak == 0
                  ? 'Join your next round to start a streak'
                  : '$streak active play days',
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
      subtitle: 'Fan ID and QR display',
      trailing: const AfriStatusChip(label: 'QR', tone: AfriStatusTone.info),
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
          label: 'Streak',
          value: '$streak',
          icon: AfriIcons.streak,
          accentColor: ColorTokens.clubAccent,
          onTap: onTap,
        ),
        AfriStat(
          label: 'Accuracy',
          value: '${winRate.toStringAsFixed(0)}%',
          icon: AfriIcons.predict,
          accentColor: ColorTokens.success,
          onTap: onTap,
        ),
        AfriStat(
          label: 'Points',
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _HubActionList extends StatelessWidget {
  const _HubActionList({required this.actions});

  final List<_HubAction> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: actions
          .map(
            (action) => Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.listItemGap),
              child: AfriListRow(
                icon: action.icon,
                title: action.title,
                subtitle: action.subtitle,
                onTap: action.onTap,
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}
