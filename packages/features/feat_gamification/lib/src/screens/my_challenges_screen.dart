import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
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
    final l10n = context.afriL10n;
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
              l10n.gameMyChallenges,
              style: TypographyTokens.titleLarge(
                ColorTokens.chromeForeground,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            leading: AfriIconButton(
              icon: AfriIcons.back,
              onTap: () => context.pop(),
              tooltip: l10n.gameBack,
            ),
            bottom: AfriTabBar.line(
              controller: _tabController,
              isScrollable: true,
              tabs: [
                Tab(text: l10n.gameOpen),
                Tab(text: l10n.gameLocked),
                Tab(text: l10n.gameSettled),
                Tab(text: l10n.gameRefunded),
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
                    title: l10n.gameLoadingChallenges,
                    message: l10n.gameLoadingChallengesDescription,
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
    final l10n = context.afriL10n;
    final content = _MyChallengesFailureContent.fromFailure(
      failure,
      isOnline,
      l10n,
    );
    final onAction = content.canRefresh ? () => unawaited(_refresh()) : null;
    return switch (failure.kind) {
      MyChallengesFailureKind.offline => AfriStateView.offline(
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
  }

  Widget _buildHistory(
    MyChallengesState state, {
    required bool isOnline,
    required bool configuredActionsEnabled,
  }) {
    final l10n = context.afriL10n;
    final actionsEnabled =
        configuredActionsEnabled && isOnline && !state.actionsBlocked;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final children = <Widget>[];

    if (state.phase == MyChallengesPhase.syncing) {
      children.add(
        AfriStateBanner(
          icon: AfriIcons.refresh,
          title: l10n.gameRefreshingChallengeHistory,
          subtitle: l10n.gameRefreshingChallengeHistoryDescription,
          tone: AfriStateBannerTone.info,
          compact: true,
        ),
      );
    } else if (!configuredActionsEnabled) {
      children.add(
        AfriStateBanner(
          icon: AfriIcons.lock,
          title: l10n.gameChallengeHistoryReadOnly,
          subtitle: l10n.gameChallengeHistoryReadOnlyDescription,
          tone: AfriStateBannerTone.warning,
          compact: true,
        ),
      );
    } else if (!isOnline) {
      children.add(
        AfriStateBanner(
          icon: AfriIcons.offline,
          title: l10n.gameShowingSavedChallengeHistory,
          subtitle: l10n.gameShowingSavedChallengeHistoryDescription,
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
            label: l10n.gameRefreshHistory,
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
          title: l10n.gameNoFilteredChallenges(
            _filterLabel(context, state.filter).toLowerCase(),
          ),
          message: _emptyMessage(context, state.filter),
          icon: AfriIcons.versus,
          actionLabel: state.filter == MyChallengeFilter.open && actionsEnabled
              ? l10n.gameCreateChallenge
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
                            _summaryFor(context, challenge),
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
      semanticsLabel: context.afriL10n.gameChallengeCardSemantics(
        fixture.homeTeamName,
        fixture.awayTeamName,
        _summaryFor(context, challenge),
      ),
      semanticsHint: enabled
          ? context.afriL10n.gameOpensChallenge
          : context.afriL10n.gameChallengeDetailsUnavailable,
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
            context.afriL10n.gameTeamsVersusMultiline(
              fixture.homeTeamName,
              fixture.awayTeamName,
            ),
            style: TypographyTokens.titleMedium().copyWith(
              fontWeight: FontWeight.w600,
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
                  label: context.afriL10n.gameMyPick,
                  accent: ColorTokens.primaryContainer,
                ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Text(
            _summaryFor(context, challenge),
            style: TypographyTokens.bodyMedium(),
          ),
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
    AfriLocalizations l10n,
  ) {
    return switch (failure.kind) {
      MyChallengesFailureKind.offline => _MyChallengesFailureContent(
        title: isOnline
            ? l10n.gameConnectionRestored
            : l10n.gameChallengeHistoryOffline,
        message: isOnline
            ? l10n.gameRefreshLatestChallengeStatus
            : l10n.gameReconnectChallengePools,
        canRefresh: isOnline,
      ),
      MyChallengesFailureKind.permissionDenied => _MyChallengesFailureContent(
        title: l10n.gameChallengeHistoryUnavailable,
        message: l10n.gameChallengeHistoryPermissionDenied,
        canRefresh: false,
      ),
      MyChallengesFailureKind.conflict => _MyChallengesFailureContent(
        title: l10n.gameChallengeHistoryChanged,
        message: l10n.gameChallengeHistoryChangedDescription,
        canRefresh: true,
      ),
      MyChallengesFailureKind.securityTimeout => _MyChallengesFailureContent(
        title: l10n.gameChallengeHistoryTimedOut,
        message: l10n.gameChallengeHistoryTimedOutDescription,
        canRefresh: true,
      ),
      MyChallengesFailureKind.unknown => _MyChallengesFailureContent(
        title: l10n.gameChallengeHistoryUnavailable,
        message: l10n.gameChallengeHistoryTryAgain,
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
    final content = _MyChallengesFailureContent.fromFailure(
      failure,
      true,
      context.afriL10n,
    );
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

String _filterLabel(BuildContext context, MyChallengeFilter filter) {
  final l10n = context.afriL10n;
  return switch (filter) {
    MyChallengeFilter.open => l10n.gameOpen,
    MyChallengeFilter.locked => l10n.gameLocked,
    MyChallengeFilter.settled => l10n.gameSettled,
    MyChallengeFilter.refunded => l10n.gameRefunded,
  };
}

String _emptyMessage(BuildContext context, MyChallengeFilter filter) {
  final l10n = context.afriL10n;
  return switch (filter) {
    MyChallengeFilter.open => l10n.gameOpenChallengesEmpty,
    MyChallengeFilter.locked => l10n.gameLockedChallengesEmpty,
    MyChallengeFilter.settled => l10n.gameSettledChallengesEmpty,
    MyChallengeFilter.refunded => l10n.gameRefundedChallengesEmpty,
  };
}

String _summaryFor(BuildContext context, Challenge challenge) {
  final l10n = context.afriL10n;
  final entry = challenge.myEntry;
  if (entry == null) {
    return l10n.gameTotalPoolPoints(challenge.totalPoolFet);
  }

  return switch (entry.status) {
    ChallengeEntryStatus.winner => l10n.gameEarnedPoints(entry.payoutFet),
    ChallengeEntryStatus.loser => l10n.gameNoResultCredit,
    ChallengeEntryStatus.refunded => l10n.gameReturnedPoints(entry.payoutFet),
    ChallengeEntryStatus.cancelled => l10n.gameCancelled,
    ChallengeEntryStatus.active => l10n.gameMyPickScore(
      entry.predictedHomeScore,
      entry.predictedAwayScore,
    ),
  };
}
