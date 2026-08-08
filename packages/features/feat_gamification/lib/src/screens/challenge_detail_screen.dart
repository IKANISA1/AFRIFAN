import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/challenge_detail_controller.dart';
import '../models/challenge_models.dart';
import '../widgets/challenge_card.dart';

class ChallengeDetailScreen extends ConsumerStatefulWidget {
  const ChallengeDetailScreen({
    super.key,
    required this.id,
    this.joinFocusNode,
  });

  final String id;
  final FocusNode? joinFocusNode;

  @override
  ConsumerState<ChallengeDetailScreen> createState() =>
      _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends ConsumerState<ChallengeDetailScreen> {
  int _homeScore = 1;
  int _awayScore = 0;
  bool? _lastOnline;

  Future<void> _joinChallenge(Challenge challenge) async {
    if (challenge.hasJoined || !challenge.canJoin) return;

    final outcome = await ref
        .read(challengeDetailProvider(widget.id).notifier)
        .join(_homeScore, _awayScore);
    if (!mounted || !outcome.isSuccess) return;
    AfriToast.success(context, context.afriL10n.detailJoinedSuccess);
  }

  Future<void> _cancelChallenge(Challenge challenge) async {
    if (!challenge.canCancel) return;

    final outcome = await ref
        .read(challengeDetailProvider(widget.id).notifier)
        .cancel();
    if (!mounted || !outcome.isSuccess) return;
    AfriToast.success(context, context.afriL10n.detailCancelledSuccess);
  }

  void _leaveDetail() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/challenge');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final detailAsync = ref.watch(challengeDetailProvider(widget.id));
    final configuredActionsEnabled = ref.watch(
      challengeDetailActionsEnabledProvider,
    );

    return ConnectivityBuilder(
      builder: (context, isOnline) {
        final previousOnline = _lastOnline;
        _lastOnline = isOnline;
        if (previousOnline == false && isOnline) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(
              ref.read(challengeDetailProvider(widget.id).notifier).refresh(),
            );
          });
        }
        final detail = detailAsync.valueOrNull;
        final actionsEnabled =
            configuredActionsEnabled &&
            isOnline &&
            detail?.actionsBlocked != true;

        return AfriScreenScaffold(
          backgroundColor: ColorTokens.background,
          appBar: AfriAppBar(
            backgroundColor: ColorTokens.transparent,
            title: Text(
              l10n.detailTitle,
              style: TypographyTokens.titleLarge(
                ColorTokens.chromeForeground,
              ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
            leading: AfriIconButton(
              icon: AfriIcons.back,
              tooltip: l10n.gameBack,
              onTap: _leaveDetail,
            ),
          ),
          scrollable: false,
          constrainContent: true,
          child: detailAsync.when(
            loading: () => Padding(
              padding: const EdgeInsets.all(SpacingTokens.screenPadding),
              child: AfriStateView.loading(
                title: l10n.detailOpening,
                message: l10n.detailOpeningBody,
              ),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(SpacingTokens.screenPadding),
              child: _buildFailureView(error, isOnline),
            ),
            data: (detail) {
              final payload = detail.payload;
              if (payload == null) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(SpacingTokens.screenPadding),
                  children: [
                    AfriStateView.empty(
                      key: const ValueKey<String>('challenge-detail-empty'),
                      title: l10n.detailNotFound,
                      message: l10n.detailNotFoundBody,
                      icon: AfriIcons.versus,
                      actionLabel: l10n.detailBack,
                      onAction: _leaveDetail,
                    ),
                  ],
                );
              }

              return _buildDetail(
                detail,
                payload,
                isOnline: isOnline,
                configuredActionsEnabled: configuredActionsEnabled,
                actionsEnabled: actionsEnabled,
                isRefreshing: detailAsync.isRefreshing,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFailureView(Object error, bool isOnline) {
    final l10n = context.afriL10n;
    final failure = ChallengeDetailFailure.fromError(error);
    final content = _ChallengeDetailFailureContent.fromFailure(
      failure,
      isOnline,
      l10n,
    );
    final onAction = content.canRefresh
        ? () => unawaited(
            ref.read(challengeDetailProvider(widget.id).notifier).refresh(),
          )
        : null;
    return switch (failure.kind) {
      ChallengeDetailFailureKind.offline => AfriStateView.offline(
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

  Widget _buildDetail(
    ChallengeDetailState detail,
    ChallengeDetailPayload payload, {
    required bool isOnline,
    required bool configuredActionsEnabled,
    required bool actionsEnabled,
    required bool isRefreshing,
  }) {
    final l10n = context.afriL10n;
    final challenge = payload.challenge;
    final myEntry = payload.userEntry;
    final settlement = payload.settlement;
    final isJoining = detail.mutation == ChallengeDetailMutation.joining;
    final isCancelling = detail.mutation == ChallengeDetailMutation.cancelling;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;

    return AfriRefreshIndicator(
      onRefresh: () =>
          ref.read(challengeDetailProvider(widget.id).notifier).refresh(),
      child: ListView(
        key: const ValueKey<String>('challenge-detail-scroll-view'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(SpacingTokens.screenPadding),
        children: [
          if (isRefreshing || detail.phase == ChallengeDetailPhase.syncing) ...[
            AfriStateBanner(
              icon: AfriIcons.refresh,
              title: isJoining
                  ? l10n.detailJoining
                  : isCancelling
                  ? l10n.detailCancelling
                  : l10n.detailRefreshing,
              subtitle: l10n.detailPendingBody,
              tone: AfriStateBannerTone.info,
              compact: true,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          if (!configuredActionsEnabled) ...[
            AfriStateBanner(
              icon: AfriIcons.lock,
              title: l10n.feedActionsUnavailable,
              subtitle: l10n.detailActionsUnavailableBody,
              tone: AfriStateBannerTone.warning,
              compact: true,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
          ] else if (!isOnline) ...[
            AfriStateBanner(
              icon: AfriIcons.offline,
              title: l10n.detailShowingSaved,
              subtitle: l10n.detailShowingSavedBody,
              tone: AfriStateBannerTone.warning,
              compact: true,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
          ] else if (detail.failure != null) ...[
            _RetainedFailureBanner(failure: detail.failure!),
            if (detail.failure!.kind !=
                    ChallengeDetailFailureKind.permissionDenied &&
                detail.failure!.kind != ChallengeDetailFailureKind.offline) ...[
              const SizedBox(height: SpacingTokens.spacing3),
              AfriButton(
                key: const ValueKey<String>('challenge-detail-refresh-action'),
                label: l10n.detailRefreshUpper,
                icon: AfriIcons.refresh,
                variant: AfriButtonVariant.outline,
                labelMaxLines: 2,
                onTap: () => ref
                    .read(challengeDetailProvider(widget.id).notifier)
                    .refresh(),
              ),
            ],
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          ChallengeCard(challenge: challenge, enabled: false),
          const SizedBox(height: SpacingTokens.spacing4),
          GlassCard(
            animate: false,
            child: Wrap(
              spacing: SpacingTokens.spacing2,
              runSpacing: SpacingTokens.spacing2,
              children: [
                StakeBadge(stakeFet: challenge.stakeFet),
                _MetaChip(
                  label: l10n.gameJoinedCount(challenge.totalParticipants),
                ),
                _MetaChip(
                  label: l10n.gameTotalPoolPoints(challenge.totalPoolFet),
                ),
                _MetaChip(label: _challengeStatusLabel(l10n, challenge.status)),
              ],
            ),
          ),
          if (myEntry != null) ...[
            const SizedBox(height: SpacingTokens.spacing4),
            GlassCard(
              animate: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.detailMyPickUpper,
                    style: TypographyTokens.labelSmall(
                      ColorTokens.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  ScorePredictionPill(
                    homeScore: myEntry.predictedHomeScore,
                    awayScore: myEntry.predictedAwayScore,
                    label: l10n.detailMyEntry,
                    accent: ColorTokens.clubAccent,
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  Text(
                    _entrySummary(l10n, myEntry),
                    style: TypographyTokens.bodyMedium(),
                  ),
                ],
              ),
            ),
          ],
          if (challenge.canJoin && !challenge.hasJoined) ...[
            const SizedBox(height: SpacingTokens.spacing4),
            GlassCard(
              animate: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.detailJoinUpper,
                    style: TypographyTokens.sectionTitle().copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  Text(
                    l10n.detailPickScoreBody,
                    style: TypographyTokens.bodyMedium(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  Semantics(
                    selected: true,
                    label: l10n.challengeSelectedScore(_homeScore, _awayScore),
                    child: largeText
                        ? Column(
                            children: [
                              _ScoreAdjuster(
                                label:
                                    challenge.fixture?.homeTeamShort ??
                                    l10n.searchHomeTeamFallback,
                                value: _homeScore,
                                enabled: actionsEnabled,
                                onChanged: (value) =>
                                    setState(() => _homeScore = value),
                              ),
                              const SizedBox(height: SpacingTokens.spacing3),
                              Text(
                                l10n.challengeVersusUpper,
                                style: TypographyTokens.labelSmall(
                                  ColorTokens.clubAccent,
                                ).copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: SpacingTokens.spacing3),
                              _ScoreAdjuster(
                                label:
                                    challenge.fixture?.awayTeamShort ??
                                    l10n.searchAwayTeamFallback,
                                value: _awayScore,
                                enabled: actionsEnabled,
                                onChanged: (value) =>
                                    setState(() => _awayScore = value),
                              ),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Align(
                                  child: _ScoreAdjuster(
                                    label:
                                        challenge.fixture?.homeTeamShort ??
                                        l10n.searchHomeTeamFallback,
                                    value: _homeScore,
                                    enabled: actionsEnabled,
                                    onChanged: (value) =>
                                        setState(() => _homeScore = value),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: SpacingTokens.spacing3,
                                  vertical: SpacingTokens.spacing4,
                                ),
                                child: Text(
                                  ':',
                                  style: TypographyTokens.metricValue(
                                    ColorTokens.clubAccent,
                                  ).copyWith(fontWeight: FontWeight.w900),
                                ),
                              ),
                              Expanded(
                                child: Align(
                                  child: _ScoreAdjuster(
                                    label:
                                        challenge.fixture?.awayTeamShort ??
                                        l10n.searchAwayTeamFallback,
                                    value: _awayScore,
                                    enabled: actionsEnabled,
                                    onChanged: (value) =>
                                        setState(() => _awayScore = value),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  AfriButton(
                    key: const ValueKey<String>('challenge-detail-join-action'),
                    label: isJoining
                        ? l10n.detailJoiningUpper
                        : l10n.detailJoinWithPoints(challenge.stakeFet),
                    icon: AfriIcons.checkGroup,
                    isLoading: isJoining,
                    enabled: actionsEnabled && !isJoining,
                    focusNode: widget.joinFocusNode,
                    labelMaxLines: 2,
                    onTap: () => _joinChallenge(challenge),
                  ),
                ],
              ),
            ),
          ],
          if (challenge.canCancel) ...[
            const SizedBox(height: SpacingTokens.spacing4),
            AfriButton(
              key: const ValueKey<String>('challenge-detail-cancel-action'),
              label: isCancelling
                  ? l10n.detailCancellingUpper
                  : l10n.detailCancelUpper,
              variant: AfriButtonVariant.outline,
              isLoading: isCancelling,
              enabled: actionsEnabled && !isCancelling,
              labelMaxLines: 2,
              onTap: () => _cancelChallenge(challenge),
            ),
          ],
          if (settlement != null) ...[
            const SizedBox(height: SpacingTokens.spacing4),
            GlassCard(
              animate: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.detailResults,
                    style: TypographyTokens.sectionTitle().copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  _SettlementRow(
                    label: l10n.detailOfficialScore,
                    value:
                        '${settlement.officialHomeScore ?? 0}-${settlement.officialAwayScore ?? 0}',
                  ),
                  _SettlementRow(
                    label: l10n.detailWinners,
                    value: '${settlement.winnersCount}',
                  ),
                  _SettlementRow(
                    label: l10n.detailLosers,
                    value: '${settlement.losersCount}',
                  ),
                  _SettlementRow(
                    label: l10n.detailPointsPerWinner,
                    value: l10n.challengeStakePoints(
                      settlement.payoutPerWinnerFet,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (payload.entries.isNotEmpty) ...[
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              l10n.detailEntries,
              style: TypographyTokens.sectionTitle().copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            ...payload.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
                child: GlassCard(
                  animate: false,
                  child: largeText
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _EntryIdentity(entry: entry),
                            const SizedBox(height: SpacingTokens.spacing3),
                            ScorePredictionPill(
                              homeScore: entry.predictedHomeScore,
                              awayScore: entry.predictedAwayScore,
                              label: l10n.challengeStakePoints(entry.stakeFet),
                              accent: _entryAccent(entry),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: _EntryIdentity(entry: entry)),
                            ScorePredictionPill(
                              homeScore: entry.predictedHomeScore,
                              awayScore: entry.predictedAwayScore,
                              label: l10n.challengeStakePoints(entry.stakeFet),
                              accent: _entryAccent(entry),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
          const SizedBox(height: SpacingTokens.spacing4),
        ],
      ),
    );
  }

  Color _entryAccent(ChallengeEntry entry) {
    return entry.isWinner
        ? ColorTokens.success
        : entry.isLoser
        ? ColorTokens.error
        : ColorTokens.clubAccent;
  }

  String _entrySummary(AfriLocalizations l10n, ChallengeEntry entry) {
    return switch (entry.status) {
      ChallengeEntryStatus.winner => l10n.gameEarnedPoints(entry.payoutFet),
      ChallengeEntryStatus.loser => l10n.gameNoResultCredit,
      ChallengeEntryStatus.refunded => l10n.gameReturnedPoints(entry.payoutFet),
      ChallengeEntryStatus.cancelled => l10n.detailEntryCancelled,
      ChallengeEntryStatus.active => l10n.detailWaitingResult,
    };
  }
}

class _ScoreAdjuster extends StatelessWidget {
  const _ScoreAdjuster({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
        ),
        const SizedBox(height: SpacingTokens.spacing2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AfriIconButton(
              icon: AfriIcons.remove,
              onTap: enabled && value > 0 ? () => onChanged(value - 1) : null,
              tooltip: context.afriL10n.challengeDecrease(label),
            ),
            Semantics(
              label: context.afriL10n.detailScoreSemantics(label, value),
              child: Text(
                '$value',
                style: TypographyTokens.headlineMedium().copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            AfriIconButton(
              icon: AfriIcons.add,
              onTap: enabled && value < 20 ? () => onChanged(value + 1) : null,
              tooltip: context.afriL10n.challengeIncrease(label),
            ),
          ],
        ),
      ],
    );
  }
}

class _EntryIdentity extends StatelessWidget {
  const _EntryIdentity({required this.entry});

  final ChallengeEntry entry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(entry.displayName, style: TypographyTokens.titleSmall()),
        const SizedBox(height: SpacingTokens.spacing1 / 2),
        Text(
          _entryStatusLabel(context.afriL10n, entry.status),
          style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: SpacingTokens.spacing2 - SpacingTokens.spacing1 / 2,
      ),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerLow,
        borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
      ),
      child: Text(
        label,
        style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
      ),
    );
  }
}

class _SettlementRow extends StatelessWidget {
  const _SettlementRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
      child: largeText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TypographyTokens.bodyMedium()),
                const SizedBox(height: SpacingTokens.spacing1),
                Text(value, style: TypographyTokens.titleSmall()),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Text(label, style: TypographyTokens.bodyMedium()),
                ),
                Text(value, style: TypographyTokens.titleSmall()),
              ],
            ),
    );
  }
}

class _RetainedFailureBanner extends StatelessWidget {
  const _RetainedFailureBanner({required this.failure});

  final ChallengeDetailFailure failure;

  @override
  Widget build(BuildContext context) {
    final content = _ChallengeDetailFailureContent.fromFailure(
      failure,
      true,
      context.afriL10n,
    );
    return AfriStateBanner(
      icon: failure.kind == ChallengeDetailFailureKind.permissionDenied
          ? AfriIcons.lock
          : failure.kind == ChallengeDetailFailureKind.offline
          ? AfriIcons.offline
          : AfriIcons.statusWarning,
      title: content.title,
      subtitle: content.message,
      tone: AfriStateBannerTone.warning,
      compact: true,
    );
  }
}

class _ChallengeDetailFailureContent {
  const _ChallengeDetailFailureContent({
    required this.title,
    required this.message,
    required this.canRefresh,
  });

  final String title;
  final String message;
  final bool canRefresh;

  factory _ChallengeDetailFailureContent.fromFailure(
    ChallengeDetailFailure failure,
    bool isOnline,
    AfriLocalizations l10n,
  ) {
    return switch (failure.kind) {
      ChallengeDetailFailureKind.offline => _ChallengeDetailFailureContent(
        title: isOnline ? l10n.detailConnectionRestored : l10n.detailOffline,
        message: isOnline
            ? l10n.detailRefreshBeforeAction
            : l10n.detailReconnectBeforeAction,
        canRefresh: isOnline,
      ),
      ChallengeDetailFailureKind.permissionDenied =>
        _ChallengeDetailFailureContent(
          title: l10n.detailAccessUnavailable,
          message: l10n.detailAccessUnavailableBody,
          canRefresh: false,
        ),
      ChallengeDetailFailureKind.conflict => _ChallengeDetailFailureContent(
        title: l10n.feedDataChanged,
        message: l10n.detailDataChangedBody,
        canRefresh: isOnline,
      ),
      ChallengeDetailFailureKind.securityTimeout =>
        _ChallengeDetailFailureContent(
          title: l10n.challengeSecurityTimedOut,
          message: l10n.detailSecurityTimedOutBody,
          canRefresh: isOnline,
        ),
      ChallengeDetailFailureKind.unknown => _ChallengeDetailFailureContent(
        title: l10n.detailUnavailable,
        message: l10n.detailUnavailableBody,
        canRefresh: isOnline,
      ),
    };
  }
}

String _challengeStatusLabel(AfriLocalizations l10n, ChallengeStatus status) {
  return switch (status) {
    ChallengeStatus.open => l10n.gameOpenUpper,
    ChallengeStatus.locked => l10n.gameLockedUpper,
    ChallengeStatus.settled => l10n.gameSettledUpper,
    ChallengeStatus.void_ => l10n.gameVoid,
    ChallengeStatus.cancelled => l10n.gameCancelled,
  };
}

String _entryStatusLabel(AfriLocalizations l10n, ChallengeEntryStatus status) {
  return switch (status) {
    ChallengeEntryStatus.active => l10n.detailEntryActive,
    ChallengeEntryStatus.winner => l10n.detailEntryWinner,
    ChallengeEntryStatus.loser => l10n.detailEntryLoser,
    ChallengeEntryStatus.refunded => l10n.detailEntryRefunded,
    ChallengeEntryStatus.cancelled => l10n.detailEntryCancelledStatus,
  };
}
