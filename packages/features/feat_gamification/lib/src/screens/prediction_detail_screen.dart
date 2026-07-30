import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/prediction_models.dart';
import '../providers/prediction_detail_provider.dart';
import '../widgets/prediction_share_card.dart';

class PredictionDetailScreen extends ConsumerStatefulWidget {
  const PredictionDetailScreen({
    super.key,
    required this.predictionId,
    this.browseFocusNode,
  });

  final String predictionId;
  final FocusNode? browseFocusNode;

  @override
  ConsumerState<PredictionDetailScreen> createState() =>
      _PredictionDetailScreenState();
}

class _PredictionDetailScreenState
    extends ConsumerState<PredictionDetailScreen> {
  bool? _lastOnline;

  void _leaveDetail() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/fanzone?section=predictions');
    }
  }

  Future<void> _cancelPrediction(PredictionDetail detail) async {
    if (!detail.isPending) return;

    final outcome = await ref
        .read(predictionDetailProvider(widget.predictionId).notifier)
        .cancel();
    if (!mounted || !outcome.isSuccess) return;
    AfriToast.success(context, 'Pick cancelled.');
  }

  Future<void> _copySummary(PredictionDetail detail) async {
    final score = detail.hasScoreline
        ? '${detail.homeScore}-${detail.awayScore}'
        : 'pending';
    final summary =
        '${detail.homeTeam} vs ${detail.awayTeam} · ${detail.marketName} · '
        '${detail.selectedOutcome} · $score';
    await Clipboard.setData(ClipboardData(text: summary));
    if (!mounted) return;
    AfriToast.success(context, 'Activity summary copied to clipboard.');
  }

  Color _statusColor(PredictionDetail detail) {
    return switch (detail.status) {
      PredictionStatus.won => ColorTokens.success,
      PredictionStatus.lost => ColorTokens.error,
      PredictionStatus.cancelled => ColorTokens.onSurfaceVariant,
      PredictionStatus.void_ => ColorTokens.warning,
      _ => ColorTokens.clubAccent,
    };
  }

  String _statusLabel(PredictionDetail detail) {
    return switch (detail.status) {
      PredictionStatus.won => 'WON',
      PredictionStatus.lost => 'LOST',
      PredictionStatus.cancelled => 'CANCELLED',
      PredictionStatus.void_ => 'VOID',
      _ => 'PENDING',
    };
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'TBD';
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} • $hh:$mm';
  }

  String _settlementMessage(PredictionDetail detail) {
    if (detail.isWon) {
      return 'This pick settled successfully and credited ${detail.fetEarned} points.';
    }
    if (detail.isLost) {
      return detail.correctOutcome == null || detail.correctOutcome!.isEmpty
          ? 'This pick did not settle in your favour.'
          : 'Official outcome: ${detail.correctOutcome!.toUpperCase()}.';
    }
    if (detail.status == PredictionStatus.cancelled) {
      return 'This pick was cancelled before the fixture locked.';
    }
    if (detail.status == PredictionStatus.void_) {
      return 'This pick was voided and no points were awarded.';
    }
    return 'This pick is locked and will settle when official results arrive.';
  }

  Widget _buildFailureView(Object error, bool isOnline) {
    final failure = PredictionDetailFailure.fromError(error);
    final content = _PredictionDetailFailureContent.fromFailure(
      failure,
      isOnline,
    );
    final onAction = content.canRefresh
        ? () => unawaited(
            ref
                .read(predictionDetailProvider(widget.predictionId).notifier)
                .refresh(),
          )
        : null;
    return switch (failure.kind) {
      PredictionDetailFailureKind.offline => AfriStateView.offline(
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

  @override
  Widget build(BuildContext context) {
    final asyncDetail = ref.watch(
      predictionDetailProvider(widget.predictionId),
    );
    final configuredActionsEnabled = ref.watch(
      predictionDetailActionsEnabledProvider,
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
                  .read(predictionDetailProvider(widget.predictionId).notifier)
                  .refresh(),
            );
          });
        }
        final current = asyncDetail.valueOrNull;
        final actionsEnabled =
            configuredActionsEnabled &&
            isOnline &&
            current?.actionsBlocked != true;

        return AfriScreenScaffold(
          backgroundColor: ColorTokens.background,
          showAppBar: false,
          showBackButton: false,
          scrollable: false,
          constrainContent: true,
          bodyWrapper: (child) => GradientBackground(child: child),
          child: SafeArea(
            child: asyncDetail.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(SpacingTokens.spacing6),
                child: AfriSkeletonList(),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AfriIconButton(
                        icon: AfriIcons.back,
                        onTap: _leaveDetail,
                        tooltip: 'Back',
                      ),
                    ),
                    Expanded(
                      child: Center(child: _buildFailureView(error, isOnline)),
                    ),
                  ],
                ),
              ),
              data: (routeState) {
                final detail = routeState.detail;
                if (detail == null) {
                  return Padding(
                    padding: const EdgeInsets.all(SpacingTokens.spacing6),
                    child: Center(
                      child: AfriStateView.empty(
                        title: 'Activity not found',
                        message:
                            'This pick may have ended, been removed, or no longer be available to your account.',
                        icon: AfriIcons.versus,
                        actionLabel: 'Back to predictions',
                        onAction: _leaveDetail,
                      ),
                    ),
                  );
                }
                return AfriRefreshIndicator(
                  onRefresh: () => ref
                      .read(
                        predictionDetailProvider(widget.predictionId).notifier,
                      )
                      .refresh(),
                  color: ColorTokens.clubAccent,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      if (asyncDetail.isRefreshing ||
                          routeState.phase == PredictionDetailPhase.syncing)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              SpacingTokens.spacing6,
                              SpacingTokens.spacing4,
                              SpacingTokens.spacing6,
                              0,
                            ),
                            child: AfriStateBanner(
                              icon: AfriIcons.refresh,
                              title:
                                  routeState.mutation ==
                                      PredictionDetailMutation.cancelling
                                  ? 'Cancelling pick'
                                  : 'Refreshing activity',
                              subtitle:
                                  'Keeping the confirmed pick visible while the latest status is checked.',
                              tone: AfriStateBannerTone.info,
                              compact: true,
                            ),
                          ),
                        ),
                      if (!configuredActionsEnabled)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              SpacingTokens.spacing6,
                              SpacingTokens.spacing4,
                              SpacingTokens.spacing6,
                              0,
                            ),
                            child: AfriStateBanner(
                              icon: AfriIcons.lock,
                              title: 'Activity actions unavailable',
                              subtitle:
                                  'You can review this pick, but cancellation is disabled for this build.',
                              tone: AfriStateBannerTone.warning,
                              compact: true,
                            ),
                          ),
                        )
                      else if (!isOnline)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              SpacingTokens.spacing6,
                              SpacingTokens.spacing4,
                              SpacingTokens.spacing6,
                              0,
                            ),
                            child: AfriStateBanner(
                              icon: AfriIcons.offline,
                              title: 'Showing saved activity',
                              subtitle:
                                  'Reconnect and refresh before cancelling this pick.',
                              tone: AfriStateBannerTone.warning,
                              compact: true,
                            ),
                          ),
                        )
                      else if (routeState.failure != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              SpacingTokens.spacing6,
                              SpacingTokens.spacing4,
                              SpacingTokens.spacing6,
                              0,
                            ),
                            child: _RetainedPredictionFailureBanner(
                              failure: routeState.failure!,
                              onRefresh:
                                  routeState.failure!.kind ==
                                      PredictionDetailFailureKind
                                          .permissionDenied
                                  ? null
                                  : () => unawaited(
                                      ref
                                          .read(
                                            predictionDetailProvider(
                                              widget.predictionId,
                                            ).notifier,
                                          )
                                          .refresh(),
                                    ),
                            ),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            SpacingTokens.spacing4,
                            SpacingTokens.spacing4,
                            SpacingTokens.spacing6,
                            0,
                          ),
                          child: Row(
                            children: [
                              AfriIconButton(
                                icon: AfriIcons.back,
                                onTap: _leaveDetail,
                                tooltip: 'Back',
                              ),
                              const SizedBox(width: SpacingTokens.spacing2),
                              Expanded(
                                child: Text(
                                  'ACTIVITY DETAIL',
                                  style: TypographyTokens.headlineSmall()
                                      .copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.6,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(SpacingTokens.spacing6),
                          child: AfriSurfaceCard(
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        detail.competitionName.toUpperCase(),
                                        style: TypographyTokens.labelMedium(
                                          ColorTokens.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: SpacingTokens.spacing3,
                                        vertical: SpacingTokens.spacing1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _statusColor(
                                          detail,
                                        ).withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(
                                          ShapeTokens.radiusFull,
                                        ),
                                      ),
                                      child: Text(
                                        _statusLabel(detail),
                                        style: TypographyTokens.labelSmall(
                                          _statusColor(detail),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: SpacingTokens.spacing4),
                                Text(
                                  '${detail.homeTeamShort.toUpperCase()}  •  ${detail.awayTeamShort.toUpperCase()}',
                                  textAlign: TextAlign.center,
                                  style: TypographyTokens.titleLarge().copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: SpacingTokens.spacing3),
                                Text(
                                  detail.hasScoreline
                                      ? '${detail.homeScore} - ${detail.awayScore}'
                                      : _formatDateTime(detail.kickoffAt),
                                  style: TypographyTokens.metricValue(
                                    detail.hasScoreline
                                        ? ColorTokens.onSurface
                                        : ColorTokens.clubAccent,
                                  ).copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: SpacingTokens.spacing2),
                                Text(
                                  detail.venueName?.trim().isNotEmpty == true
                                      ? detail.venueName!.toUpperCase()
                                      : 'VENUE TBC',
                                  style: TypographyTokens.bodySmall(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: SpacingTokens.spacing6,
                          ),
                          child:
                              MediaQuery.textScalerOf(context).scale(1) >= 1.5
                              ? Column(
                                  children: [
                                    _DetailMetric(
                                      label: 'PICK TYPE',
                                      value:
                                          (detail.marketShortName.isEmpty
                                                  ? detail.marketName
                                                  : detail.marketShortName)
                                              .toUpperCase(),
                                    ),
                                    const SizedBox(
                                      height: SpacingTokens.spacing3,
                                    ),
                                    _DetailMetric(
                                      label: 'SELECTION',
                                      value: detail.selectedOutcome
                                          .toUpperCase(),
                                      accent: true,
                                      selected: true,
                                    ),
                                    const SizedBox(
                                      height: SpacingTokens.spacing3,
                                    ),
                                    _DetailMetric(
                                      label: detail.isWon
                                          ? 'EARNED'
                                          : 'POTENTIAL',
                                      value: detail.isWon
                                          ? '+${detail.fetEarned}'
                                          : '+${detail.fetPotential}',
                                      accent: true,
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _DetailMetric(
                                            label: 'PICK TYPE',
                                            value:
                                                (detail.marketShortName.isEmpty
                                                        ? detail.marketName
                                                        : detail
                                                              .marketShortName)
                                                    .toUpperCase(),
                                          ),
                                        ),
                                        const SizedBox(
                                          width: SpacingTokens.spacing3,
                                        ),
                                        Expanded(
                                          child: _DetailMetric(
                                            label: 'SELECTION',
                                            value: detail.selectedOutcome
                                                .toUpperCase(),
                                            accent: true,
                                            selected: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                      height: SpacingTokens.spacing3,
                                    ),
                                    _DetailMetric(
                                      label: detail.isWon
                                          ? 'EARNED'
                                          : 'POTENTIAL',
                                      value: detail.isWon
                                          ? '+${detail.fetEarned}'
                                          : '+${detail.fetPotential}',
                                      accent: true,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(SpacingTokens.spacing6),
                          child: GlassCard(
                            animate: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SETTLEMENT',
                                  style: TypographyTokens.labelMedium(
                                    ColorTokens.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: SpacingTokens.spacing2),
                                Text(
                                  _settlementMessage(detail),
                                  style: TypographyTokens.bodyMedium(),
                                ),
                                const SizedBox(height: SpacingTokens.spacing4),
                                _TimelineRow(
                                  label: 'Placed',
                                  value: _formatDateTime(detail.placedAt),
                                ),
                                const SizedBox(height: SpacingTokens.spacing2),
                                _TimelineRow(
                                  label: 'Kickoff',
                                  value: _formatDateTime(detail.kickoffAt),
                                ),
                                if (detail.settledAt != null) ...[
                                  const SizedBox(
                                    height: SpacingTokens.spacing2,
                                  ),
                                  _TimelineRow(
                                    label: 'Settled',
                                    value: _formatDateTime(detail.settledAt),
                                  ),
                                ],
                                if ((detail.correctOutcome ?? '')
                                    .trim()
                                    .isNotEmpty) ...[
                                  const SizedBox(
                                    height: SpacingTokens.spacing2,
                                  ),
                                  _TimelineRow(
                                    label: 'Official outcome',
                                    value: detail.correctOutcome!.toUpperCase(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            SpacingTokens.spacing6,
                            0,
                            SpacingTokens.spacing6,
                            SpacingTokens.spacing6,
                          ),
                          child: PredictionShareCard(
                            data: PredictionShareData.fromDetail(detail),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            SpacingTokens.spacing6,
                            0,
                            SpacingTokens.spacing6,
                            SpacingTokens.spacing20,
                          ),
                          child: Column(
                            children: [
                              if (detail.isPending)
                                AfriButton(
                                  key: const ValueKey<String>(
                                    'prediction-detail-cancel-action',
                                  ),
                                  label: 'CANCEL PICK',
                                  variant: AfriButtonVariant.secondary,
                                  enabled: actionsEnabled,
                                  isLoading:
                                      routeState.mutation ==
                                      PredictionDetailMutation.cancelling,
                                  onTap: () => _cancelPrediction(detail),
                                ),
                              if (detail.isPending)
                                const SizedBox(height: SpacingTokens.spacing3),
                              AfriButton(
                                label: detail.isSettled
                                    ? 'COPY RESULT'
                                    : 'COPY SUMMARY',
                                variant: AfriButtonVariant.secondary,
                                onTap: () => _copySummary(detail),
                              ),
                              const SizedBox(height: SpacingTokens.spacing3),
                              AfriButton(
                                label: 'SHARE CARD',
                                variant: AfriButtonVariant.secondary,
                                onTap: () => PredictionShareService.share(
                                  data: PredictionShareData.fromDetail(detail),
                                  context: context,
                                ),
                              ),
                              const SizedBox(height: SpacingTokens.spacing3),
                              AfriButton(
                                key: const ValueKey<String>(
                                  'prediction-detail-browse-action',
                                ),
                                label: 'BROWSE FIXTURES',
                                focusNode: widget.browseFocusNode,
                                onTap: () => context.go('/fanzone/fixtures'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _RetainedPredictionFailureBanner extends StatelessWidget {
  const _RetainedPredictionFailureBanner({
    required this.failure,
    this.onRefresh,
  });

  final PredictionDetailFailure failure;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final content = _PredictionDetailFailureContent.fromFailure(failure, true);
    return Column(
      children: [
        AfriStateBanner(
          icon: failure.kind == PredictionDetailFailureKind.permissionDenied
              ? AfriIcons.lock
              : failure.kind == PredictionDetailFailureKind.offline
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
            key: const ValueKey<String>('prediction-detail-refresh-action'),
            label: 'REFRESH ACTIVITY',
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

class _PredictionDetailFailureContent {
  const _PredictionDetailFailureContent({
    required this.title,
    required this.message,
    required this.canRefresh,
  });

  final String title;
  final String message;
  final bool canRefresh;

  factory _PredictionDetailFailureContent.fromFailure(
    PredictionDetailFailure failure,
    bool isOnline,
  ) {
    return switch (failure.kind) {
      PredictionDetailFailureKind.offline => _PredictionDetailFailureContent(
        title: isOnline ? 'Connection restored' : 'Activity details offline',
        message: isOnline
            ? 'Refresh to confirm the current pick before cancelling it.'
            : 'Reconnect to confirm the current pick before cancelling it.',
        canRefresh: isOnline,
      ),
      PredictionDetailFailureKind.permissionDenied =>
        const _PredictionDetailFailureContent(
          title: 'Activity access unavailable',
          message:
              'Your current account cannot review or change this activity.',
          canRefresh: false,
        ),
      PredictionDetailFailureKind.conflict => _PredictionDetailFailureContent(
        title: 'Activity data changed',
        message: 'Refresh before reviewing the result or cancelling this pick.',
        canRefresh: isOnline,
      ),
      PredictionDetailFailureKind.securityTimeout =>
        _PredictionDetailFailureContent(
          title: 'Activity security check timed out',
          message:
              'No cancellation was confirmed. Refresh before trying again.',
          canRefresh: isOnline,
        ),
      PredictionDetailFailureKind.unknown => _PredictionDetailFailureContent(
        title: 'Activity unavailable',
        message:
            'The latest pick details could not be confirmed. Refresh to try again.',
        canRefresh: isOnline,
      ),
    };
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
    required this.label,
    required this.value,
    this.accent = false,
    this.selected = false,
  });

  final String label;
  final String value;
  final bool accent;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      label: selected ? 'Selected $label $value' : '$label $value',
      child: GlassCard(
        animate: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TypographyTokens.labelMedium(ColorTokens.onSurfaceVariant),
            ),
            const SizedBox(height: SpacingTokens.spacing1),
            Text(
              value,
              style: TypographyTokens.titleLarge(
                accent ? ColorTokens.clubAccent : ColorTokens.onSurface,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    if (largeText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TypographyTokens.labelMedium(ColorTokens.onSurfaceVariant),
          ),
          const SizedBox(height: SpacingTokens.spacing1),
          Text(value, style: TypographyTokens.bodyMedium()),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: TypographyTokens.labelMedium(ColorTokens.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: SpacingTokens.spacing3),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TypographyTokens.bodyMedium(),
          ),
        ),
      ],
    );
  }
}
