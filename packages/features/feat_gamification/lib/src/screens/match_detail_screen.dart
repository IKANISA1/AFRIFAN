import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/partner_pool_models.dart';
import '../models/prediction_models.dart';
import '../providers/match_detail_provider.dart';
import '../widgets/fanzone_hub_widgets.dart';
import '../widgets/h2h_tab_body.dart';
import '../widgets/lineups_tab_body.dart';
import '../widgets/match_detail_widgets.dart';
import '../widgets/stats_panel.dart';

class MatchDetailScreen extends ConsumerStatefulWidget {
  const MatchDetailScreen({
    super.key,
    required this.fixtureId,
    this.joinFocusNode,
  });

  final String fixtureId;
  final FocusNode? joinFocusNode;

  @override
  ConsumerState<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends ConsumerState<MatchDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool? _lastOnline;

  static const _tabLabels = <String>['Pools', 'Stats', 'H2H', 'Lineups'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _leaveDetail() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/fanzone');
    }
  }

  List<LineupPlayer> _toLineupPlayers(MatchCenterLineup? lineup) {
    if (lineup == null) {
      return const <LineupPlayer>[];
    }
    final ordered = <MatchCenterLineupPlayer>[
      ...lineup.starters,
      ...lineup.substitutes,
    ];
    return ordered
        .map(
          (row) => LineupPlayer(
            name: row.name,
            number: row.number,
            position: row.position,
            isStarter: row.isStarter,
          ),
        )
        .toList(growable: false);
  }

  String _formatKickoff(FixtureSummary fixture) {
    final kickoff = fixture.kickoffAt;
    if (kickoff == null) {
      return 'Kickoff TBD';
    }
    final local = kickoff.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    const dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const monthNames = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${dayNames[local.weekday - 1]} ${local.day} ${monthNames[local.month - 1]} · $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final asyncDetail = ref.watch(matchDetailProvider(widget.fixtureId));
    final configuredActionsEnabled = ref.watch(
      matchDetailActionsEnabledProvider,
    );

    return ConnectivityBuilder(
      builder: (context, isOnline) {
        final previousOnline = _lastOnline;
        _lastOnline = isOnline;
        if (previousOnline == false && isOnline) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(
              ref
                  .read(matchDetailProvider(widget.fixtureId).notifier)
                  .refresh(),
            );
          });
        }
        return asyncDetail.when(
          loading: () => _buildLoading(),
          error: (error, _) => _buildFailure(error, isOnline),
          data: (routeState) {
            final fixture = routeState.fixture;
            if (fixture == null) {
              return _buildEmpty();
            }
            final actionsEnabled =
                configuredActionsEnabled &&
                isOnline &&
                !routeState.actionsBlocked;
            return _buildContent(
              fixture: fixture,
              routeState: routeState,
              actionsEnabled: actionsEnabled,
              configuredActionsEnabled: configuredActionsEnabled,
              isOnline: isOnline,
              isRefreshing: asyncDetail.isRefreshing,
            );
          },
        );
      },
    );
  }

  Widget _buildLoading() {
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: _leaveDetail,
          tooltip: 'Back',
        ),
      ),
      scrollable: false,
      constrainContent: true,
      child: const Padding(
        padding: EdgeInsets.all(SpacingTokens.spacing6),
        child: AfriSkeletonList(),
      ),
    );
  }

  Widget _buildEmpty() {
    return _buildStateScaffold(
      AfriStateView.empty(
        title: 'Match not found',
        message:
            'This fixture may have ended, been removed, or no longer be available.',
        icon: AfriIcons.versus,
        actionLabel: 'Back to Fan Zone',
        onAction: _leaveDetail,
      ),
    );
  }

  Widget _buildFailure(Object error, bool isOnline) {
    final failure = MatchDetailFailure.fromError(error);
    final content = _MatchDetailFailureContent.fromFailure(failure, isOnline);
    final onAction = content.canRefresh
        ? () => unawaited(
            ref.read(matchDetailProvider(widget.fixtureId).notifier).refresh(),
          )
        : null;
    final view = switch (failure.kind) {
      MatchDetailFailureKind.offline => AfriStateView.offline(
        title: content.title,
        message: content.message,
        actionLabel: content.canRefresh ? 'Refresh' : null,
        onAction: onAction,
      ),
      _ => AfriStateView.error(
        title: content.title,
        message: content.message,
        actionLabel: content.canRefresh ? 'Refresh' : null,
        onAction: onAction,
      ),
    };
    return _buildStateScaffold(view);
  }

  Widget _buildStateScaffold(Widget stateView) {
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: _leaveDetail,
          tooltip: 'Back',
        ),
        title: Text(
          'Match',
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
      scrollable: false,
      constrainContent: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing6),
          child: stateView,
        ),
      ),
    );
  }

  Widget _buildContent({
    required FixtureSummary fixture,
    required MatchDetailState routeState,
    required bool actionsEnabled,
    required bool configuredActionsEnabled,
    required bool isOnline,
    required bool isRefreshing,
  }) {
    final usesAccessibleChrome =
        MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final matchCenter = routeState.matchCenter;
    final stats =
        matchCenter?.stats
            .map(
              (stat) => MatchStatRow(
                label: stat.label,
                leftValue: stat.leftValue,
                rightValue: stat.rightValue,
                leftDisplay: stat.leftDisplay,
                rightDisplay: stat.rightDisplay,
              ),
            )
            .toList(growable: false) ??
        const <MatchStatRow>[];
    final h2hEncounters =
        matchCenter?.h2h
            .map(
              (row) => H2hEncounter(
                homeTeam: row.homeTeam,
                awayTeam: row.awayTeam,
                homeScore: row.homeScore,
                awayScore: row.awayScore,
                date: row.date,
                competition: row.competition,
              ),
            )
            .toList(growable: false) ??
        const <H2hEncounter>[];
    final homeLineup = _toLineupPlayers(matchCenter?.homeLineup);
    final awayLineup = _toLineupPlayers(matchCenter?.awayLineup);

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          usesAccessibleChrome
              ? 'Match'
              : '${fixture.homeTeamShort} vs ${fixture.awayTeamShort}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              (usesAccessibleChrome
                      ? TypographyTokens.titleMedium()
                      : TypographyTokens.titleLarge())
                  .copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: _leaveDetail,
          tooltip: 'Back',
        ),
        actions: usesAccessibleChrome
            ? null
            : [
                AfriIconButton(
                  icon: AfriIcons.predict,
                  onTap: () => context.go('/fanzone'),
                  tooltip: 'Partner pools',
                ),
              ],
        bottom: AfriTabBar.line(
          controller: _tabController,
          isScrollable: usesAccessibleChrome,
          tabs: _tabLabels
              .map((label) => Tab(text: label))
              .toList(growable: false),
        ),
      ),
      scrollable: false,
      constrainContent: false,
      child: Column(
        children: [
          if (isRefreshing || routeState.phase == MatchDetailPhase.syncing)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SpacingTokens.spacing6,
                SpacingTokens.spacing3,
                SpacingTokens.spacing6,
                0,
              ),
              child: AfriStateBanner(
                icon: AfriIcons.refresh,
                title: routeState.mutation == MatchDetailMutation.joiningPool
                    ? 'Joining partner pool'
                    : 'Refreshing match',
                subtitle:
                    'Keeping the confirmed match visible while the latest state is checked.',
                tone: AfriStateBannerTone.info,
                compact: true,
              ),
            ),
          if (!configuredActionsEnabled)
            const Padding(
              padding: EdgeInsets.fromLTRB(
                SpacingTokens.spacing6,
                SpacingTokens.spacing3,
                SpacingTokens.spacing6,
                0,
              ),
              child: AfriStateBanner(
                icon: AfriIcons.lock,
                title: 'Match actions unavailable',
                subtitle:
                    'You can review this match, but joining partner pools is disabled for this build.',
                tone: AfriStateBannerTone.warning,
                compact: true,
              ),
            )
          else if (!isOnline)
            const Padding(
              padding: EdgeInsets.fromLTRB(
                SpacingTokens.spacing6,
                SpacingTokens.spacing3,
                SpacingTokens.spacing6,
                0,
              ),
              child: AfriStateBanner(
                icon: AfriIcons.offline,
                title: 'Showing saved match',
                subtitle:
                    'Reconnect and refresh before joining a partner pool.',
                tone: AfriStateBannerTone.warning,
                compact: true,
              ),
            )
          else if (routeState.failure != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SpacingTokens.spacing6,
                SpacingTokens.spacing3,
                SpacingTokens.spacing6,
                0,
              ),
              child: _RetainedMatchDetailFailureBanner(
                failure: routeState.failure!,
                onRefresh:
                    routeState.failure!.kind ==
                        MatchDetailFailureKind.permissionDenied
                    ? null
                    : () => unawaited(
                        ref
                            .read(
                              matchDetailProvider(widget.fixtureId).notifier,
                            )
                            .refresh(),
                      ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SpacingTokens.spacing6,
              SpacingTokens.spacing4,
              SpacingTokens.spacing6,
              0,
            ),
            child: AfriSurfaceCard(
              child: Column(
                children: [
                  Text(
                    fixture.competitionName,
                    style: TypographyTokens.labelMedium(
                      ColorTokens.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          fixture.homeTeamShort.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TypographyTokens.titleLarge(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: SpacingTokens.spacing3,
                        ),
                        child: Text(
                          fixture.isLive &&
                                  fixture.homeScore != null &&
                                  fixture.awayScore != null
                              ? '${fixture.homeScore} - ${fixture.awayScore}'
                              : 'VS',
                          style: TypographyTokens.titleLarge(
                            ColorTokens.clubAccent,
                          ).copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          fixture.awayTeamShort.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TypographyTokens.titleLarge(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  Text(
                    _formatKickoff(fixture),
                    style: TypographyTokens.bodySmall(
                      ColorTokens.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (fixture.venueName != null &&
                      fixture.venueName!.isNotEmpty) ...[
                    const SizedBox(height: SpacingTokens.spacing1 / 2),
                    Text(
                      fixture.venueName!,
                      style: TypographyTokens.bodySmall(
                        ColorTokens.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (fixture.competitionSlug.isNotEmpty ||
                      fixture.homeTeamSlug.isNotEmpty ||
                      fixture.awayTeamSlug.isNotEmpty) ...[
                    const SizedBox(height: SpacingTokens.spacing4),
                    Wrap(
                      spacing: SpacingTokens.spacing2,
                      runSpacing: SpacingTokens.spacing2,
                      alignment: WrapAlignment.center,
                      children: [
                        if (fixture.competitionSlug.isNotEmpty)
                          MatchMetaLink(
                            label: 'League',
                            onTap: () {
                              unawaited(
                                context.push(
                                  '/fanzone/league/${fixture.competitionSlug}',
                                ),
                              );
                            },
                          ),
                        if (fixture.homeTeamSlug.isNotEmpty)
                          MatchMetaLink(
                            label: fixture.homeTeamShort,
                            onTap: () {
                              unawaited(
                                context.push(
                                  '/fanzone/team/${fixture.homeTeamSlug}',
                                ),
                              );
                            },
                          ),
                        if (fixture.awayTeamSlug.isNotEmpty)
                          MatchMetaLink(
                            label: fixture.awayTeamShort,
                            onTap: () {
                              unawaited(
                                context.push(
                                  '/fanzone/team/${fixture.awayTeamSlug}',
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _MatchPartnerPoolsTabBody(
                  fixture: fixture,
                  pools: routeState.partnerPools,
                  onJoin: actionsEnabled
                      ? (pool) => _showPartnerPoolJoinSheet(pool)
                      : null,
                ),
                MatchStatsTabBody(fixture: fixture, stats: stats),
                H2hTabBody(
                  homeTeamName: fixture.homeTeamName,
                  awayTeamName: fixture.awayTeamName,
                  homeTeamShort: fixture.homeTeamShort,
                  awayTeamShort: fixture.awayTeamShort,
                  encounters: h2hEncounters,
                ),
                LineupsTabBody(
                  homeTeamName: fixture.homeTeamName,
                  awayTeamName: fixture.awayTeamName,
                  homeTeamShort: fixture.homeTeamShort,
                  awayTeamShort: fixture.awayTeamShort,
                  homeLineup: homeLineup,
                  awayLineup: awayLineup,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPartnerPoolJoinSheet(PartnerPredictionPool pool) {
    const outcomes = <PartnerPoolOutcome>[
      PartnerPoolOutcome.homeWin,
      PartnerPoolOutcome.draw,
      PartnerPoolOutcome.awayWin,
    ];

    var selectedOutcome = PartnerPoolOutcome.homeWin;
    var isSubmitting = false;

    return showAfriBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setSheetState) {
            Future<void> submit() async {
              if (isSubmitting) return;
              setSheetState(() => isSubmitting = true);

              final outcome = await ref
                  .read(matchDetailProvider(widget.fixtureId).notifier)
                  .joinPool(pool: pool, selectedOutcome: selectedOutcome);

              if (!sheetContext.mounted) return;

              if (!outcome.isSuccess) {
                setSheetState(() => isSubmitting = false);
                AfriToast.error(
                  sheetContext,
                  _poolJoinFailureMessage(outcome.failure),
                );
                return;
              }

              closeAfriBottomSheet(sheetContext);
              if (!mounted) return;
              AfriToast.success(context, '${selectedOutcome.label} joined.');
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
                  key: const ValueKey<String>('match-detail-join-submit'),
                  label: 'Join round',
                  icon: AfriIcons.predict,
                  focusNode: widget.joinFocusNode,
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

  String _poolJoinFailureMessage(MatchDetailFailure? failure) {
    return switch (failure?.kind) {
      MatchDetailFailureKind.offline =>
        'Reconnect and refresh before joining this pool.',
      MatchDetailFailureKind.permissionDenied =>
        'Your account cannot join this partner pool.',
      MatchDetailFailureKind.conflict =>
        'This pool changed or locked. Refresh before trying again.',
      MatchDetailFailureKind.securityTimeout =>
        'No entry was confirmed. Refresh before trying again.',
      _ => 'Pool entry could not be confirmed.',
    };
  }
}

class _RetainedMatchDetailFailureBanner extends StatelessWidget {
  const _RetainedMatchDetailFailureBanner({
    required this.failure,
    this.onRefresh,
  });

  final MatchDetailFailure failure;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final content = _MatchDetailFailureContent.fromFailure(failure, true);
    return Column(
      children: [
        AfriStateBanner(
          icon: failure.kind == MatchDetailFailureKind.permissionDenied
              ? AfriIcons.lock
              : failure.kind == MatchDetailFailureKind.offline
              ? AfriIcons.offline
              : AfriIcons.statusWarning,
          title: content.title,
          subtitle: content.message,
          tone: AfriStateBannerTone.warning,
          compact: true,
        ),
        if (onRefresh != null) ...[
          const SizedBox(height: SpacingTokens.spacing3),
          AfriButton(
            key: const ValueKey<String>('match-detail-refresh-action'),
            label: 'REFRESH MATCH',
            icon: AfriIcons.refresh,
            variant: AfriButtonVariant.outline,
            labelMaxLines: 2,
            onTap: onRefresh!,
          ),
        ],
      ],
    );
  }
}

class _MatchDetailFailureContent {
  const _MatchDetailFailureContent({
    required this.title,
    required this.message,
    required this.canRefresh,
  });

  final String title;
  final String message;
  final bool canRefresh;

  factory _MatchDetailFailureContent.fromFailure(
    MatchDetailFailure failure,
    bool isOnline,
  ) {
    return switch (failure.kind) {
      MatchDetailFailureKind.offline => _MatchDetailFailureContent(
        title: isOnline ? 'Connection restored' : 'Match details offline',
        message: isOnline
            ? 'Refresh to confirm the current match before joining a pool.'
            : 'Reconnect to confirm the current match before joining a pool.',
        canRefresh: isOnline,
      ),
      MatchDetailFailureKind.permissionDenied =>
        const _MatchDetailFailureContent(
          title: 'Match access unavailable',
          message: 'Your current account cannot review this match.',
          canRefresh: false,
        ),
      MatchDetailFailureKind.conflict => _MatchDetailFailureContent(
        title: 'Match data changed',
        message: 'Refresh before joining a pool or reviewing current status.',
        canRefresh: isOnline,
      ),
      MatchDetailFailureKind.securityTimeout => _MatchDetailFailureContent(
        title: 'Match security check timed out',
        message: 'No pool entry was confirmed. Refresh before trying again.',
        canRefresh: isOnline,
      ),
      MatchDetailFailureKind.unknown => _MatchDetailFailureContent(
        title: 'Match unavailable',
        message:
            'The latest match details could not be confirmed. Refresh to try again.',
        canRefresh: isOnline,
      ),
    };
  }
}

class _MatchPartnerPoolsTabBody extends StatelessWidget {
  const _MatchPartnerPoolsTabBody({
    required this.fixture,
    required this.pools,
    this.onJoin,
  });

  final FixtureSummary fixture;
  final List<PartnerPredictionPool> pools;
  final ValueChanged<PartnerPredictionPool>? onJoin;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      children: [
        AfriSectionCard(
          title: 'Partner WDW Pools',
          child: pools.isEmpty
              ? AfriEmptyView(
                  compact: true,
                  title: 'No partner pool for this match',
                  message:
                      'Football predictions open only when a partner creates a fixed-entry WDW pool for this fixture.',
                  icon: AfriIcons.predict,
                  actionLabel: 'View Fan Zone',
                  onAction: () => context.go('/fanzone'),
                )
              : Column(
                  children: pools
                      .map(
                        (pool) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: SpacingTokens.listItemGap,
                          ),
                          child: HubPartnerPoolRow(
                            pool: pool,
                            onJoin: onJoin == null ? null : () => onJoin!(pool),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        AfriSurfaceCard(
          child: Row(
            children: [
              Icon(
                AfriIcons.statusInfo,
                size: SpacingTokens.spacing4,
                color: ColorTokens.onSurfaceVariant,
              ),
              const SizedBox(width: SpacingTokens.spacing2),
              Expanded(
                child: Text(
                  '${fixture.homeTeamShort} vs ${fixture.awayTeamShort} uses partner-funded WDW pools only.',
                  style: TypographyTokens.bodySmall(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
