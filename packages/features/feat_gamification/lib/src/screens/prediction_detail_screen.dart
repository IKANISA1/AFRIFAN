import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/prediction_models.dart';
import '../providers/prediction_detail_provider.dart';
import '../widgets/prediction_share_card.dart';

class PredictionDetailScreen extends ConsumerStatefulWidget {
  const PredictionDetailScreen({super.key, required this.predictionId});

  final String predictionId;

  @override
  ConsumerState<PredictionDetailScreen> createState() =>
      _PredictionDetailScreenState();
}

class _PredictionDetailScreenState
    extends ConsumerState<PredictionDetailScreen> {
  bool _isCancelling = false;

  Future<void> _cancelPrediction(PredictionDetail detail) async {
    if (!detail.isPending || _isCancelling) return;

    setState(() => _isCancelling = true);
    try {
      final result = await ref
          .read(predictionDetailProvider(widget.predictionId).notifier)
          .cancel();

      if (!mounted) return;
      if (result.isError) {
        AfriToast.error(context, result.message);
      } else {
        AfriToast.success(context, 'Pick cancelled.');
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final asyncDetail = ref.watch(
      predictionDetailProvider(widget.predictionId),
    );

    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: GradientBackground(
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
                  Row(
                    children: [
                      if (context.canPop())
                        AfriIconButton(
                          icon: AfriIcons.back,
                          onTap: () => context.pop(),
                          tooltip: 'Back',
                        ),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: AfriStateView.offline(
                        title: 'Activity unavailable',
                        message: 'Could not load activity detail right now.',
                        actionLabel: 'Retry',
                        onAction: () => ref
                            .read(
                              predictionDetailProvider(
                                widget.predictionId,
                              ).notifier,
                            )
                            .refresh(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            data: (detail) {
              if (detail == null) {
                return Padding(
                  padding: const EdgeInsets.all(SpacingTokens.spacing6),
                  child: Center(
                    child: AfriStateView.offline(
                      title: 'Activity not found',
                      message: 'This activity could not be located.',
                      actionLabel: 'Go back',
                      onAction: () => context.pop(),
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
                            if (context.canPop())
                              AfriIconButton(
                                icon: AfriIcons.back,
                                onTap: () => context.pop(),
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
                        child: Row(
                          children: [
                            _DetailMetric(
                                label: 'PICK TYPE',
                              value:
                                  (detail.marketShortName.isEmpty
                                          ? detail.marketName
                                          : detail.marketShortName)
                                      .toUpperCase(),
                            ),
                            const SizedBox(width: SpacingTokens.spacing3),
                            _DetailMetric(
                              label: 'SELECTION',
                              value: detail.selectedOutcome.toUpperCase(),
                              accent: true,
                            ),
                            const SizedBox(width: SpacingTokens.spacing3),
                            _DetailMetric(
                              label: detail.isWon ? 'EARNED' : 'POTENTIAL',
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
                                const SizedBox(height: SpacingTokens.spacing2),
                                _TimelineRow(
                                  label: 'Settled',
                                  value: _formatDateTime(detail.settledAt),
                                ),
                              ],
                              if ((detail.correctOutcome ?? '')
                                  .trim()
                                  .isNotEmpty) ...[
                                const SizedBox(height: SpacingTokens.spacing2),
                                _TimelineRow(
                                  label: 'Official outcome',
                                  value: detail.correctOutcome!.toUpperCase(),
                                ),
                              ],
                              if ((detail.slipId ?? '').isNotEmpty) ...[
                                const SizedBox(height: SpacingTokens.spacing2),
                                _TimelineRow(
                                  label: 'Round',
                                  value: detail.slipId!,
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
                                label: 'CANCEL PICK',
                                variant: AfriButtonVariant.secondary,
                                enabled: !_isCancelling,
                                isLoading: _isCancelling,
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
                              label: 'BROWSE FIXTURES',
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
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
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
