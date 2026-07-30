import 'dart:async';

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
    AfriToast.success(context, 'Challenge joined successfully.');
  }

  Future<void> _cancelChallenge(Challenge challenge) async {
    if (!challenge.canCancel) return;

    final outcome = await ref
        .read(challengeDetailProvider(widget.id).notifier)
        .cancel();
    if (!mounted || !outcome.isSuccess) return;
    AfriToast.success(context, 'Challenge cancelled.');
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
              'CHALLENGE DETAIL',
              style: TypographyTokens.titleLarge(
                ColorTokens.chromeForeground,
              ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
            leading: AfriIconButton(
              icon: AfriIcons.back,
              tooltip: 'Back',
              onTap: _leaveDetail,
            ),
          ),
          scrollable: false,
          constrainContent: true,
          child: detailAsync.when(
            loading: () => Padding(
              padding: const EdgeInsets.all(SpacingTokens.screenPadding),
              child: AfriStateView.loading(
                title: 'Opening challenge',
                message:
                    'Checking the current pool, entries, and official result status.',
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
                      title: 'Challenge not found',
                      message:
                          'This pool may have ended, been removed, or no longer be available to your club.',
                      icon: AfriIcons.versus,
                      actionLabel: 'Back to challenges',
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
    final failure = ChallengeDetailFailure.fromError(error);
    final content = _ChallengeDetailFailureContent.fromFailure(
      failure,
      isOnline,
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

  Widget _buildDetail(
    ChallengeDetailState detail,
    ChallengeDetailPayload payload, {
    required bool isOnline,
    required bool configuredActionsEnabled,
    required bool actionsEnabled,
    required bool isRefreshing,
  }) {
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
                  ? 'Joining challenge'
                  : isCancelling
                  ? 'Cancelling challenge'
                  : 'Refreshing challenge',
              subtitle:
                  'Keeping the current pool and score choice visible while confirmation is pending.',
              tone: AfriStateBannerTone.info,
              compact: true,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          if (!configuredActionsEnabled) ...[
            const AfriStateBanner(
              icon: AfriIcons.lock,
              title: 'Challenge actions unavailable',
              subtitle:
                  'You can review this pool, but joining and cancellation are disabled for this build.',
              tone: AfriStateBannerTone.warning,
              compact: true,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
          ] else if (!isOnline) ...[
            const AfriStateBanner(
              icon: AfriIcons.offline,
              title: 'Showing saved challenge',
              subtitle:
                  'Reconnect and refresh before joining, changing a score, or cancelling this pool.',
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
                label: 'REFRESH CHALLENGE',
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
                _MetaChip(label: '${challenge.totalParticipants} joined'),
                _MetaChip(label: '${challenge.totalPoolFet} pts total'),
                _MetaChip(
                  label: challenge.status.name
                      .replaceAll('_', '')
                      .toUpperCase(),
                ),
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
                    'MY PICK',
                    style: TypographyTokens.labelSmall(
                      ColorTokens.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  ScorePredictionPill(
                    homeScore: myEntry.predictedHomeScore,
                    awayScore: myEntry.predictedAwayScore,
                    label: 'My entry',
                    accent: ColorTokens.clubAccent,
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  Text(
                    _entrySummary(myEntry),
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
                    'JOIN THIS CHALLENGE',
                    style: TypographyTokens.sectionTitle().copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  Text(
                    'Pick the exact score before the fixture locks.',
                    style: TypographyTokens.bodyMedium(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  Semantics(
                    selected: true,
                    label: 'Selected exact score $_homeScore to $_awayScore',
                    child: largeText
                        ? Column(
                            children: [
                              _ScoreAdjuster(
                                label:
                                    challenge.fixture?.homeTeamShort ?? 'HOME',
                                value: _homeScore,
                                enabled: actionsEnabled,
                                onChanged: (value) =>
                                    setState(() => _homeScore = value),
                              ),
                              const SizedBox(height: SpacingTokens.spacing3),
                              Text(
                                'VERSUS',
                                style: TypographyTokens.labelSmall(
                                  ColorTokens.clubAccent,
                                ).copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: SpacingTokens.spacing3),
                              _ScoreAdjuster(
                                label:
                                    challenge.fixture?.awayTeamShort ?? 'AWAY',
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
                                        'HOME',
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
                                        'AWAY',
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
                        ? 'JOINING CHALLENGE'
                        : 'JOIN WITH ${challenge.stakeFet} pts',
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
              label: isCancelling ? 'CANCELLING CHALLENGE' : 'CANCEL CHALLENGE',
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
                    'RESULTS',
                    style: TypographyTokens.sectionTitle().copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  _SettlementRow(
                    label: 'Official score',
                    value:
                        '${settlement.officialHomeScore ?? 0}-${settlement.officialAwayScore ?? 0}',
                  ),
                  _SettlementRow(
                    label: 'Winners',
                    value: '${settlement.winnersCount}',
                  ),
                  _SettlementRow(
                    label: 'Losers',
                    value: '${settlement.losersCount}',
                  ),
                  _SettlementRow(
                    label: 'Points / winner',
                    value: '${settlement.payoutPerWinnerFet} pts',
                  ),
                ],
              ),
            ),
          ],
          if (payload.entries.isNotEmpty) ...[
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              'ENTRIES',
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
                              label: '${entry.stakeFet} pts',
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
                              label: '${entry.stakeFet} pts',
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

  String _entrySummary(ChallengeEntry entry) {
    return switch (entry.status) {
      ChallengeEntryStatus.winner => 'Earned ${entry.payoutFet} pts',
      ChallengeEntryStatus.loser => 'No result credit',
      ChallengeEntryStatus.refunded => 'Returned ${entry.payoutFet} pts',
      ChallengeEntryStatus.cancelled => 'Entry cancelled',
      ChallengeEntryStatus.active => 'Waiting for official result review.',
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
              tooltip: 'Decrease $label',
            ),
            Semantics(
              label: '$label score $value',
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
              tooltip: 'Increase $label',
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
          entry.status.name.toUpperCase(),
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
    final content = _ChallengeDetailFailureContent.fromFailure(failure, true);
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
  ) {
    return switch (failure.kind) {
      ChallengeDetailFailureKind.offline => _ChallengeDetailFailureContent(
        title: isOnline ? 'Connection restored' : 'Challenge details offline',
        message: isOnline
            ? 'Refresh to check the current pool before joining or cancelling.'
            : 'Reconnect to check the current pool before joining or cancelling.',
        canRefresh: isOnline,
      ),
      ChallengeDetailFailureKind.permissionDenied =>
        const _ChallengeDetailFailureContent(
          title: 'Challenge access unavailable',
          message:
              'Your current account cannot review or change this challenge.',
          canRefresh: false,
        ),
      ChallengeDetailFailureKind.conflict => _ChallengeDetailFailureContent(
        title: 'Challenge data changed',
        message: 'Refresh before reviewing entries or changing this challenge.',
        canRefresh: isOnline,
      ),
      ChallengeDetailFailureKind.securityTimeout =>
        _ChallengeDetailFailureContent(
          title: 'Challenge security check timed out',
          message:
              'No challenge action was confirmed. Refresh before trying again.',
          canRefresh: isOnline,
        ),
      ChallengeDetailFailureKind.unknown => _ChallengeDetailFailureContent(
        title: 'Challenge unavailable',
        message:
            'The latest pool details could not be confirmed. Refresh to try again.',
        canRefresh: isOnline,
      ),
    };
  }
}
