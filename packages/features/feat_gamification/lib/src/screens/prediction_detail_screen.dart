import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
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
      context.go('/predict?section=history');
    }
  }

  Future<void> _cancelPrediction(PredictionDetail detail) async {
    if (!detail.isPending) return;

    final outcome = await ref
        .read(predictionDetailProvider(widget.predictionId).notifier)
        .cancel();
    if (!mounted || !outcome.isSuccess) return;
    AfriToast.success(context, context.afriL10n.gamePredictionPickCancelled);
  }

  Future<void> _copySummary(PredictionDetail detail) async {
    final l10n = context.afriL10n;
    final score = detail.hasScoreline
        ? '${detail.homeScore}-${detail.awayScore}'
        : l10n.gamePredictionScorePending;
    final summary = l10n.gamePredictionSummaryClipboard(
      detail.homeTeam,
      detail.awayTeam,
      detail.marketName,
      detail.selectedOutcome,
      score,
    );
    await Clipboard.setData(ClipboardData(text: summary));
    if (!mounted) return;
    AfriToast.success(context, l10n.gamePredictionSummaryCopied);
  }

  Color _statusColor(PredictionDetail detail) {
    return switch (detail.status) {
      PredictionStatus.won => ColorTokens.success,
      PredictionStatus.lost => ColorTokens.error,
      PredictionStatus.cancelled => ColorTokens.onSurfaceVariant,
      PredictionStatus.void_ => ColorTokens.warning,
      _ => ColorTokens.primaryContainer,
    };
  }

  String _statusLabel(AfriLocalizations l10n, PredictionDetail detail) {
    return switch (detail.status) {
      PredictionStatus.won => l10n.gamePredictionStatusWon,
      PredictionStatus.lost => l10n.gamePredictionStatusLost,
      PredictionStatus.cancelled => l10n.gamePredictionStatusCancelled,
      PredictionStatus.void_ => l10n.gamePredictionStatusVoid,
      _ => l10n.gamePredictionStatusPending,
    };
  }

  String _formatDateTime(BuildContext context, DateTime? value) {
    if (value == null) return context.afriL10n.gamePredictionDateTbd;
    final local = value.toLocal();
    final date = '${local.day}/${local.month}/${local.year}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return context.afriL10n.gamePredictionDateTime(date, time);
  }

  String _settlementMessage(AfriLocalizations l10n, PredictionDetail detail) {
    if (detail.isWon) {
      return l10n.gamePredictionWonSettlement(detail.fetEarned);
    }
    if (detail.isLost) {
      return detail.correctOutcome == null || detail.correctOutcome!.isEmpty
          ? l10n.gamePredictionLostSettlement
          : l10n.gamePredictionOfficialOutcomeMessage(detail.correctOutcome!);
    }
    if (detail.status == PredictionStatus.cancelled) {
      return l10n.gamePredictionCancelledSettlement;
    }
    if (detail.status == PredictionStatus.void_) {
      return l10n.gamePredictionVoidSettlement;
    }
    return l10n.gamePredictionPendingSettlement;
  }

  Widget _buildFailureView(Object error, bool isOnline) {
    final failure = PredictionDetailFailure.fromError(error);
    final content = _PredictionDetailFailureContent.fromFailure(
      context.afriL10n,
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
        actionLabel: content.canRefresh ? context.afriL10n.gameRefresh : null,
        onAction: onAction,
      ),
      _ => AfriStateView.error(
        title: content.title,
        message: content.message,
        actionLabel: content.canRefresh ? context.afriL10n.gameRefresh : null,
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
        final l10n = context.afriL10n;
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
                        tooltip: l10n.gameBack,
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
                        title: l10n.gamePredictionActivityNotFound,
                        message: l10n.gamePredictionActivityNotFoundDescription,
                        icon: AfriIcons.versus,
                        actionLabel: l10n.gamePredictionBackToPredictions,
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
                  color: ColorTokens.primaryContainer,
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
                                  ? l10n.gamePredictionCancellingPick
                                  : l10n.gamePredictionRefreshingActivity,
                              subtitle: l10n.gamePredictionConfirmedPickVisible,
                              tone: AfriStateBannerTone.info,
                              compact: true,
                            ),
                          ),
                        ),
                      if (!configuredActionsEnabled)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              SpacingTokens.spacing6,
                              SpacingTokens.spacing4,
                              SpacingTokens.spacing6,
                              0,
                            ),
                            child: AfriStateBanner(
                              icon: AfriIcons.lock,
                              title: l10n.gamePredictionActionsUnavailable,
                              subtitle: l10n.gamePredictionCancellationDisabled,
                              tone: AfriStateBannerTone.warning,
                              compact: true,
                            ),
                          ),
                        )
                      else if (!isOnline)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              SpacingTokens.spacing6,
                              SpacingTokens.spacing4,
                              SpacingTokens.spacing6,
                              0,
                            ),
                            child: AfriStateBanner(
                              icon: AfriIcons.offline,
                              title: l10n.gamePredictionShowingSavedActivity,
                              subtitle:
                                  l10n.gamePredictionReconnectBeforeCancelling,
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
                                tooltip: l10n.gameBack,
                              ),
                              const SizedBox(width: SpacingTokens.spacing2),
                              Expanded(
                                child: Text(
                                  l10n.gamePredictionActivityDetailTitle,
                                  style: TypographyTokens.headlineSmall()
                                      .copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing:
                                            TypographyTokens.trackingNone,
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
                                        detail.competitionName,
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
                                        _statusLabel(l10n, detail),
                                        style: TypographyTokens.labelSmall(
                                          _statusColor(detail),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: SpacingTokens.spacing4),
                                Text(
                                  l10n.gamePredictionShortTeams(
                                    detail.homeTeamShort.toUpperCase(),
                                    detail.awayTeamShort.toUpperCase(),
                                  ),
                                  textAlign: TextAlign.center,
                                  style: TypographyTokens.titleLarge().copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: SpacingTokens.spacing3),
                                Text(
                                  detail.hasScoreline
                                      ? '${detail.homeScore} - ${detail.awayScore}'
                                      : _formatDateTime(
                                          context,
                                          detail.kickoffAt,
                                        ),
                                  style: TypographyTokens.metricValue(
                                    detail.hasScoreline
                                        ? ColorTokens.onSurface
                                        : ColorTokens.primaryContainer,
                                  ).copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: SpacingTokens.spacing2),
                                Text(
                                  detail.venueName?.trim().isNotEmpty == true
                                      ? detail.venueName!
                                      : l10n.gamePredictionVenueTbc,
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
                                      label: l10n.gamePredictionPickType,
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
                                      label: l10n.gamePredictionSelection,
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
                                          ? l10n.gamePredictionEarned
                                          : l10n.gamePredictionPotential,
                                      value: detail.isWon
                                          ? l10n.gamePredictionPositiveValue(
                                              detail.fetEarned,
                                            )
                                          : l10n.gamePredictionPositiveValue(
                                              detail.fetPotential,
                                            ),
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
                                            label: l10n.gamePredictionPickType,
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
                                            label: l10n.gamePredictionSelection,
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
                                          ? l10n.gamePredictionEarned
                                          : l10n.gamePredictionPotential,
                                      value: detail.isWon
                                          ? l10n.gamePredictionPositiveValue(
                                              detail.fetEarned,
                                            )
                                          : l10n.gamePredictionPositiveValue(
                                              detail.fetPotential,
                                            ),
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
                                  l10n.gamePredictionSettlement,
                                  style: TypographyTokens.labelMedium(
                                    ColorTokens.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: SpacingTokens.spacing2),
                                Text(
                                  _settlementMessage(l10n, detail),
                                  style: TypographyTokens.bodyMedium(),
                                ),
                                const SizedBox(height: SpacingTokens.spacing4),
                                _TimelineRow(
                                  label: l10n.gamePredictionPlaced,
                                  value: _formatDateTime(
                                    context,
                                    detail.placedAt,
                                  ),
                                ),
                                const SizedBox(height: SpacingTokens.spacing2),
                                _TimelineRow(
                                  label: l10n.gamePredictionKickoff,
                                  value: _formatDateTime(
                                    context,
                                    detail.kickoffAt,
                                  ),
                                ),
                                if (detail.settledAt != null) ...[
                                  const SizedBox(
                                    height: SpacingTokens.spacing2,
                                  ),
                                  _TimelineRow(
                                    label: l10n.gamePredictionSettled,
                                    value: _formatDateTime(
                                      context,
                                      detail.settledAt,
                                    ),
                                  ),
                                ],
                                if ((detail.correctOutcome ?? '')
                                    .trim()
                                    .isNotEmpty) ...[
                                  const SizedBox(
                                    height: SpacingTokens.spacing2,
                                  ),
                                  _TimelineRow(
                                    label: l10n.gamePredictionOfficialOutcome,
                                    value: detail.correctOutcome!,
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
                                  label: l10n.gamePredictionCancelPick,
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
                                    ? l10n.gamePredictionCopyResult
                                    : l10n.gamePredictionCopySummary,
                                variant: AfriButtonVariant.secondary,
                                onTap: () => _copySummary(detail),
                              ),
                              const SizedBox(height: SpacingTokens.spacing3),
                              AfriButton(
                                label: l10n.gamePredictionShareCard,
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
                                label: l10n.gamePredictionBrowseFixtures,
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
    final l10n = context.afriL10n;
    final content = _PredictionDetailFailureContent.fromFailure(
      l10n,
      failure,
      true,
    );
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
            label: l10n.gamePredictionRefreshActivity,
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
    AfriLocalizations l10n,
    PredictionDetailFailure failure,
    bool isOnline,
  ) {
    return switch (failure.kind) {
      PredictionDetailFailureKind.offline => _PredictionDetailFailureContent(
        title: isOnline
            ? l10n.gamePredictionConnectionRestored
            : l10n.gamePredictionDetailsOffline,
        message: isOnline
            ? l10n.gamePredictionRefreshBeforeCancelling
            : l10n.gamePredictionReconnectToConfirm,
        canRefresh: isOnline,
      ),
      PredictionDetailFailureKind.permissionDenied =>
        _PredictionDetailFailureContent(
          title: l10n.gamePredictionAccessUnavailable,
          message: l10n.gamePredictionAccessUnavailableDescription,
          canRefresh: false,
        ),
      PredictionDetailFailureKind.conflict => _PredictionDetailFailureContent(
        title: l10n.gamePredictionDataChanged,
        message: l10n.gamePredictionDataChangedDescription,
        canRefresh: isOnline,
      ),
      PredictionDetailFailureKind.securityTimeout =>
        _PredictionDetailFailureContent(
          title: l10n.gamePredictionSecurityTimeout,
          message: l10n.gamePredictionSecurityTimeoutDescription,
          canRefresh: isOnline,
        ),
      PredictionDetailFailureKind.unknown => _PredictionDetailFailureContent(
        title: l10n.gamePredictionUnavailable,
        message: l10n.gamePredictionUnavailableDescription,
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
    final l10n = context.afriL10n;
    return Semantics(
      selected: selected,
      label: selected
          ? l10n.gamePredictionSelectedMetricSemantics(label, value)
          : l10n.gamePredictionMetricSemantics(label, value),
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
                accent ? ColorTokens.primaryContainer : ColorTokens.onSurface,
              ).copyWith(fontWeight: FontWeight.w600),
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
            label,
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
            label,
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
