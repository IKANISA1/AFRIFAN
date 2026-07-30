import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/challenge_my_controller.dart';
import '../models/challenge_models.dart';
import '../widgets/challenge_card.dart';

class MyChallengesScreen extends ConsumerStatefulWidget {
  const MyChallengesScreen({super.key, this.cardFocusNode});

  final FocusNode? cardFocusNode;

  @override
  ConsumerState<MyChallengesScreen> createState() => _MyChallengesScreenState();
}

class _MyChallengesScreenState extends ConsumerState<MyChallengesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool? _lastOnline;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      return;
    }

    unawaited(
      ref
          .read(myChallengesProvider.notifier)
          .select(MyChallengeFilter.values[_tabController.index]),
    );
  }

  Future<void> _refresh() => ref.read(myChallengesProvider.notifier).refresh();

  @override
  Widget build(BuildContext context) {
    final challengesAsync = ref.watch(myChallengesProvider);
    final configuredActionsEnabled = ref.watch(
      myChallengesActionsEnabledProvider,
    );

    return ConnectivityBuilder(
      builder: (context, isOnline) {
        final previousOnline = _lastOnline;
        _lastOnline = isOnline;
        if (previousOnline == false && isOnline) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(_refresh());
          });
        }

        return AfriScreenScaffold(
          backgroundColor: ColorTokens.background,
          appBar: AfriAppBar(
            backgroundColor: ColorTokens.transparent,
            title: Text(
              'MY CHALLENGES',
              style: TypographyTokens.titleLarge(
                ColorTokens.chromeForeground,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            leading: AfriIconButton(
              icon: AfriIcons.back,
              onTap: () => context.pop(),
              tooltip: 'Back',
            ),
            bottom: AfriTabBar.line(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Open'),
                Tab(text: 'Locked'),
                Tab(text: 'Settled'),
                Tab(text: 'Refunded'),
              ],
            ),
          ),
          scrollable: false,
          constrainContent: true,
          child: AfriRefreshIndicator(
            onRefresh: _refresh,
            child: challengesAsync.when(
              loading: () => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(SpacingTokens.screenPadding),
                children: [
                  AfriStateView.loading(
                    title: 'Loading your challenges',
                    message:
                        'Checking the pools you created or joined for this status.',
                  ),
                ],
              ),
              error: (error, _) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(SpacingTokens.screenPadding),
                children: [_buildFailureView(error, isOnline)],
              ),
              data: (state) => _buildHistory(
                state,
                isOnline: isOnline,
                configuredActionsEnabled: configuredActionsEnabled,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFailureView(Object error, bool isOnline) {
    final failure = MyChallengesFailure.fromError(error);
    final content = _MyChallengesFailureContent.fromFailure(failure, isOnline);
    final onAction = content.canRefresh ? () => unawaited(_refresh()) : null;
    return switch (failure.kind) {
      MyChallengesFailureKind.offline => AfriStateView.offline(
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
  }

  Widget _buildHistory(
    MyChallengesState state, {
    required bool isOnline,
    required bool configuredActionsEnabled,
  }) {
    final actionsEnabled =
        configuredActionsEnabled && isOnline && !state.actionsBlocked;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final children = <Widget>[];

    if (state.phase == MyChallengesPhase.syncing) {
      children.add(
        const AfriStateBanner(
          icon: AfriIcons.refresh,
          title: 'Refreshing challenge history',
          subtitle:
              'Keeping your confirmed pools visible while the latest status is checked.',
          tone: AfriStateBannerTone.info,
          compact: true,
        ),
      );
    } else if (!configuredActionsEnabled) {
      children.add(
        const AfriStateBanner(
          icon: AfriIcons.lock,
          title: 'Challenge history is read-only',
          subtitle:
              'Your confirmed pools remain visible, but opening challenge details is disabled for this build.',
          tone: AfriStateBannerTone.warning,
          compact: true,
        ),
      );
    } else if (!isOnline) {
      children.add(
        const AfriStateBanner(
          icon: AfriIcons.offline,
          title: 'Showing saved challenge history',
          subtitle:
              'Reconnect and refresh before opening a pool or checking a newer status.',
          tone: AfriStateBannerTone.warning,
          compact: true,
        ),
      );
    } else if (state.failure != null) {
      children.add(_RetainedMyChallengesFailure(failure: state.failure!));
      if (state.failure!.kind != MyChallengesFailureKind.permissionDenied) {
        children.add(const SizedBox(height: SpacingTokens.spacing3));
        children.add(
          AfriButton(
            key: const ValueKey<String>('my-challenges-refresh-action'),
            label: 'REFRESH HISTORY',
            icon: AfriIcons.refresh,
            variant: AfriButtonVariant.outline,
            labelMaxLines: 2,
            onTap: _refresh,
          ),
        );
      }
    }

    if (children.isNotEmpty) {
      children.add(const SizedBox(height: SpacingTokens.spacing4));
    }

    if (state.items.isEmpty) {
      children.add(
        AfriStateView.empty(
          title: 'No ${state.filter.label.toLowerCase()} challenges',
          message: _emptyMessage(state.filter),
          icon: AfriIcons.versus,
          actionLabel: state.filter == MyChallengeFilter.open && actionsEnabled
              ? 'Create challenge'
              : null,
          onAction: state.filter == MyChallengeFilter.open && actionsEnabled
              ? () => context.push('/challenge/create')
              : null,
        ),
      );
    } else {
      for (var index = 0; index < state.items.length; index++) {
        final challenge = state.items[index];
        final focusNode = index == 0 ? widget.cardFocusNode : null;
        children.add(
          KeyedSubtree(
            key: ValueKey<String>('my-challenge-card-${challenge.id}'),
            child: largeText
                ? _LargeTextChallengeHistoryCard(
                    challenge: challenge,
                    enabled: actionsEnabled,
                    focusNode: focusNode,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ChallengeCard(
                        challenge: challenge,
                        compact: true,
                        enabled: actionsEnabled,
                        focusNode: focusNode,
                      ),
                      if (challenge.myEntry != null)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: SpacingTokens.spacing2,
                            left: SpacingTokens.spacing2,
                          ),
                          child: Text(
                            _summaryFor(challenge),
                            style: TypographyTokens.labelSmall(
                              ColorTokens.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        );
        if (index < state.items.length - 1) {
          children.add(const SizedBox(height: SpacingTokens.spacing4));
        }
      }
    }

    return ListView(
      key: const ValueKey<String>('my-challenges-scroll-view'),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.all(SpacingTokens.screenPadding),
      children: children,
    );
  }
}

class _LargeTextChallengeHistoryCard extends StatelessWidget {
  const _LargeTextChallengeHistoryCard({
    required this.challenge,
    required this.enabled,
    this.focusNode,
  });

  final Challenge challenge;
  final bool enabled;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final fixture = challenge.fixture;
    if (fixture == null) return const SizedBox.shrink();
    final entry = challenge.myEntry;
    return AfriSurfaceCard(
      enabled: enabled,
      focusNode: focusNode,
      semanticsLabel:
          '${fixture.homeTeamName} versus ${fixture.awayTeamName}. '
          '${_summaryFor(challenge)}. Open challenge details.',
      semanticsHint: enabled
          ? 'Opens this challenge'
          : 'Challenge details are unavailable',
      onTap: () => context.push('/challenge/${challenge.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fixture.competitionName,
            style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            '${fixture.homeTeamName}\nversus\n${fixture.awayTeamName}',
            style: TypographyTokens.titleMedium().copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Wrap(
            spacing: SpacingTokens.spacing2,
            runSpacing: SpacingTokens.spacing2,
            children: [
              ChallengeStatusChip(status: challenge.status),
              StakeBadge(stakeFet: challenge.stakeFet),
              if (entry != null)
                ScorePredictionPill(
                  homeScore: entry.predictedHomeScore,
                  awayScore: entry.predictedAwayScore,
                  label: 'My pick',
                  accent: ColorTokens.clubAccent,
                ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Text(_summaryFor(challenge), style: TypographyTokens.bodyMedium()),
        ],
      ),
    );
  }
}

class _MyChallengesFailureContent {
  const _MyChallengesFailureContent({
    required this.title,
    required this.message,
    required this.canRefresh,
  });

  final String title;
  final String message;
  final bool canRefresh;

  factory _MyChallengesFailureContent.fromFailure(
    MyChallengesFailure failure,
    bool isOnline,
  ) {
    return switch (failure.kind) {
      MyChallengesFailureKind.offline => _MyChallengesFailureContent(
        title: isOnline ? 'Connection restored' : 'Challenge history offline',
        message: isOnline
            ? 'Refresh to check the latest status of your challenges.'
            : 'Reconnect to load the pools you created or joined.',
        canRefresh: isOnline,
      ),
      MyChallengesFailureKind.permissionDenied =>
        const _MyChallengesFailureContent(
          title: 'Challenge history unavailable',
          message:
              'Your current club access does not allow this challenge history.',
          canRefresh: false,
        ),
      MyChallengesFailureKind.conflict => const _MyChallengesFailureContent(
        title: 'Challenge history changed',
        message:
            'Refresh and review the latest pool status before opening a challenge.',
        canRefresh: true,
      ),
      MyChallengesFailureKind.securityTimeout =>
        const _MyChallengesFailureContent(
          title: 'Challenge history check timed out',
          message:
              'No status was confirmed. Refresh before opening a challenge.',
          canRefresh: true,
        ),
      MyChallengesFailureKind.unknown => const _MyChallengesFailureContent(
        title: 'Challenge history unavailable',
        message: 'Refresh and try again when your challenge history is ready.',
        canRefresh: true,
      ),
    };
  }
}

class _RetainedMyChallengesFailure extends StatelessWidget {
  const _RetainedMyChallengesFailure({required this.failure});

  final MyChallengesFailure failure;

  @override
  Widget build(BuildContext context) {
    final content = _MyChallengesFailureContent.fromFailure(failure, true);
    return AfriStateBanner(
      icon: failure.kind == MyChallengesFailureKind.permissionDenied
          ? AfriIcons.lock
          : AfriIcons.warning,
      title: content.title,
      subtitle: content.message,
      tone: AfriStateBannerTone.warning,
      compact: true,
    );
  }
}

String _emptyMessage(MyChallengeFilter filter) {
  return switch (filter) {
    MyChallengeFilter.open =>
      'Create or join a pool to see an active exact-score challenge here.',
    MyChallengeFilter.locked =>
      'No joined challenge is currently waiting for a final score.',
    MyChallengeFilter.settled =>
      'Completed challenge results and points will appear here.',
    MyChallengeFilter.refunded =>
      'Cancelled or refunded challenges will appear here.',
  };
}

String _summaryFor(Challenge challenge) {
  final entry = challenge.myEntry;
  if (entry == null) {
    return '${challenge.totalPoolFet} pts total';
  }

  return switch (entry.status) {
    ChallengeEntryStatus.winner => 'Earned ${entry.payoutFet} pts',
    ChallengeEntryStatus.loser => 'No result credit',
    ChallengeEntryStatus.refunded => 'Returned ${entry.payoutFet} pts',
    ChallengeEntryStatus.cancelled => 'Cancelled',
    ChallengeEntryStatus.active =>
      'My pick ${entry.predictedHomeScore}-${entry.predictedAwayScore}',
  };
}
