import 'dart:async';

import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/partner_pool_models.dart';
import '../models/prediction_models.dart';
import '../providers/match_detail_provider.dart';
import '../widgets/h2h_tab_body.dart';
import '../widgets/lineups_tab_body.dart';
import '../widgets/match_detail_widgets.dart';
import '../widgets/partner_pool_widgets.dart';
import '../widgets/stats_panel.dart';

class PredictMatchScreen extends ConsumerStatefulWidget {
  const PredictMatchScreen({
    super.key,
    required this.fixtureId,
    this.joinFocusNode,
  });

  final String fixtureId;
  final FocusNode? joinFocusNode;

  @override
  ConsumerState<PredictMatchScreen> createState() => _PredictMatchScreenState();
}

class _PredictMatchScreenState extends ConsumerState<PredictMatchScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final bool _allowsStakedCompetitions;
  bool? _lastOnline;

  @override
  void initState() {
    super.initState();
    _allowsStakedCompetitions = ref
        .read(storeReleasePolicyProvider)
        .allowsStakedCompetitions;
    _tabController = TabController(
      length: _allowsStakedCompetitions ? 4 : 3,
      vsync: this,
    );
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
      context.go('/predict');
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

  List<String> _tabLabels(AfriLocalizations l10n) => <String>[
    if (_allowsStakedCompetitions) l10n.gamePoolsTab,
    l10n.gameStatsTab,
    l10n.gameH2hTab,
    l10n.gameLineupsTab,
  ];

  String _formatKickoff(AfriLocalizations l10n, FixtureSummary fixture) {
    final kickoff = fixture.kickoffAt;
    if (kickoff == null) {
      return l10n.gameKickoffTbd;
    }
    final local = kickoff.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final dayNames = [
      l10n.gameWeekdayMon,
      l10n.gameWeekdayTue,
      l10n.gameWeekdayWed,
      l10n.gameWeekdayThu,
      l10n.gameWeekdayFri,
      l10n.gameWeekdaySat,
      l10n.gameWeekdaySun,
    ];
    final monthNames = [
      l10n.gameMonthJan,
      l10n.gameMonthFeb,
      l10n.gameMonthMar,
      l10n.gameMonthApr,
      l10n.gameMonthMay,
      l10n.gameMonthJun,
      l10n.gameMonthJul,
      l10n.gameMonthAug,
      l10n.gameMonthSep,
      l10n.gameMonthOct,
      l10n.gameMonthNov,
      l10n.gameMonthDec,
    ];
    return l10n.gameMatchKickoffDateTime(
      dayNames[local.weekday - 1],
      local.day,
      monthNames[local.month - 1],
      '$hour:$minute',
    );
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
    final l10n = context.afriL10n;
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: _leaveDetail,
          tooltip: l10n.gameBack,
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
    final l10n = context.afriL10n;
    return _buildStateScaffold(
      AfriStateView.empty(
        title: l10n.gameMatchNotFound,
        message: l10n.gameMatchNotFoundDescription,
        icon: AfriIcons.versus,
        actionLabel: l10n.homeOpenPredict,
        onAction: _leaveDetail,
      ),
    );
  }

  Widget _buildFailure(Object error, bool isOnline) {
    final l10n = context.afriL10n;
    final failure = MatchDetailFailure.fromError(error);
    final content = _MatchDetailFailureContent.fromFailure(
      l10n,
      failure,
      isOnline,
    );
    final onAction = content.canRefresh
        ? () => unawaited(
            ref.read(matchDetailProvider(widget.fixtureId).notifier).refresh(),
          )
        : null;
    final view = switch (failure.kind) {
      MatchDetailFailureKind.offline => AfriStateView.offline(
        title: content.title,
        message: content.message,
        actionLabel: content.canRefresh ? l10n.gameRefresh : null,
        onAction: onAction,
      ),
      _ => AfriStateView.error(
        title: content.title,
        message: content.message,
        actionLabel: content.canRefresh ? l10n.gameRefresh : null,
        onAction: onAction,
      ),
    };
    return _buildStateScaffold(view);
  }

  Widget _buildStateScaffold(Widget stateView) {
    final l10n = context.afriL10n;
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: _leaveDetail,
          tooltip: l10n.gameBack,
        ),
        title: Text(
          l10n.gameMatchTitle,
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: TypographyTokens.trackingNone,
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
    final l10n = context.afriL10n;
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
              ? l10n.gameMatchTitle
              : l10n.gameMatchTeamsVs(
                  fixture.homeTeamShort,
                  fixture.awayTeamShort,
                ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              (usesAccessibleChrome
                      ? TypographyTokens.titleMedium()
                      : TypographyTokens.titleLarge())
                  .copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: TypographyTokens.trackingNone,
                  ),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: _leaveDetail,
          tooltip: l10n.gameBack,
        ),
        actions: usesAccessibleChrome || !_allowsStakedCompetitions
            ? null
            : [
                AfriIconButton(
                  icon: AfriIcons.predict,
                  onTap: () => context.go('/predict'),
                  tooltip: l10n.gamePartnerPoolsTooltip,
                ),
              ],
        bottom: AfriTabBar.line(
          controller: _tabController,
          isScrollable: usesAccessibleChrome,
          tabs: _tabLabels(
            l10n,
          ).map((label) => Tab(text: label)).toList(growable: false),
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
                    ? l10n.gameJoiningPartnerPool
                    : l10n.gameRefreshingMatch,
                subtitle: l10n.gameConfirmedMatchVisible,
                tone: AfriStateBannerTone.info,
                compact: true,
              ),
            ),
          if (_allowsStakedCompetitions && !configuredActionsEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SpacingTokens.spacing6,
                SpacingTokens.spacing3,
                SpacingTokens.spacing6,
                0,
              ),
              child: AfriStateBanner(
                icon: AfriIcons.lock,
                title: l10n.gameMatchActionsUnavailable,
                subtitle: l10n.gameMatchActionsUnavailableDescription,
                tone: AfriStateBannerTone.warning,
                compact: true,
              ),
            )
          else if (_allowsStakedCompetitions && !isOnline)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SpacingTokens.spacing6,
                SpacingTokens.spacing3,
                SpacingTokens.spacing6,
                0,
              ),
              child: AfriStateBanner(
                icon: AfriIcons.offline,
                title: l10n.gameShowingSavedMatch,
                subtitle: l10n.gameReconnectBeforePartnerPool,
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
                  AfriFixtureTeams(
                    homeTeam: fixture.homeTeamName,
                    awayTeam: fixture.awayTeamName,
                    score:
                        fixture.isLive &&
                            fixture.homeScore != null &&
                            fixture.awayScore != null
                        ? '${fixture.homeScore}–${fixture.awayScore}'
                        : null,
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  Text(
                    _formatKickoff(l10n, fixture),
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
                            label: l10n.gameLeague,
                            onTap: () {
                              unawaited(context.push('/club/fixtures'));
                            },
                          ),
                        if (fixture.homeTeamSlug.isNotEmpty)
                          MatchMetaLink(
                            label: teamInitials(fixture.homeTeamName),
                            onTap: () {
                              unawaited(context.push('/club/fixtures'));
                            },
                          ),
                        if (fixture.awayTeamSlug.isNotEmpty)
                          MatchMetaLink(
                            label: teamInitials(fixture.awayTeamName),
                            onTap: () {
                              unawaited(context.push('/club/fixtures'));
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
                if (_allowsStakedCompetitions)
                  _MatchPartnerPoolsTabBody(
                    fixture: fixture,
                    pools: routeState.partnerPools,
                    onJoin: null,
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
    final l10n = context.afriL10n;
    final content = _MatchDetailFailureContent.fromFailure(l10n, failure, true);
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
            label: l10n.gameRefreshMatch,
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
    AfriLocalizations l10n,
    MatchDetailFailure failure,
    bool isOnline,
  ) {
    return switch (failure.kind) {
      MatchDetailFailureKind.offline => _MatchDetailFailureContent(
        title: isOnline
            ? l10n.gameMatchConnectionRestored
            : l10n.gameMatchDetailsOffline,
        message: isOnline
            ? l10n.gameRefreshBeforeJoiningPool
            : l10n.gameReconnectBeforeJoiningPool,
        canRefresh: isOnline,
      ),
      MatchDetailFailureKind.permissionDenied => _MatchDetailFailureContent(
        title: l10n.gameMatchAccessUnavailable,
        message: l10n.gameMatchAccessUnavailableDescription,
        canRefresh: false,
      ),
      MatchDetailFailureKind.conflict => _MatchDetailFailureContent(
        title: l10n.gameMatchDataChanged,
        message: l10n.gameMatchDataChangedDescription,
        canRefresh: isOnline,
      ),
      MatchDetailFailureKind.securityTimeout => _MatchDetailFailureContent(
        title: l10n.gameMatchSecurityTimeout,
        message: l10n.gameMatchSecurityTimeoutDescription,
        canRefresh: isOnline,
      ),
      MatchDetailFailureKind.unknown => _MatchDetailFailureContent(
        title: l10n.gameMatchUnavailable,
        message: l10n.gameMatchUnavailableDescription,
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
    final l10n = context.afriL10n;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.predictLegacyPoolsTitle,
            style: TypographyTokens.sectionTitle(),
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        if (pools.isEmpty)
          AfriEmptyView(
            compact: true,
            title: l10n.gameNoPartnerPool,
            message: l10n.gameNoPartnerPoolDescription,
            icon: AfriIcons.predict,
            actionLabel: l10n.homeOpenPredict,
            onAction: () => context.go('/predict'),
          )
        else
          for (final pool in pools)
            Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.listItemGap),
              child: HubPartnerPoolRow(
                pool: pool,
                onJoin: onJoin == null ? null : () => onJoin!(pool),
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
                  l10n.predictLegacyEntryClosed,
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
