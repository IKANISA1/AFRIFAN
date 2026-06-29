import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/prediction_models.dart';
import '../prediction_providers.dart';
import '../widgets/prediction_share_card.dart';
import 'package:core_utils/core_utils.dart';

class PredictionSettlementScreen extends ConsumerStatefulWidget {
  const PredictionSettlementScreen({super.key, required this.predictionId});

  final String predictionId;

  @override
  ConsumerState<PredictionSettlementScreen> createState() =>
      _PredictionSettlementScreenState();
}

class _PredictionSettlementScreenState
    extends ConsumerState<PredictionSettlementScreen> {
  PredictionDetail? _detail;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final detail = await ref
          .read(predictionRepositoryProvider)
          .loadPredictionDetail(widget.predictionId);

      if (!mounted) {
        return;
      }

      setState(() {
        _detail = detail;
        _error = detail == null ? 'Prediction not found.' : null;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'PredictionSettlementScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Could not load settlement right now.';
        _isLoading = false;
      });
    }
  }

  Color _accent(PredictionDetail detail) {
    return switch (detail.status) {
      PredictionStatus.won => ColorTokens.success,
      PredictionStatus.lost => ColorTokens.error,
      PredictionStatus.void_ => ColorTokens.warning,
      PredictionStatus.cancelled => ColorTokens.onSurfaceVariant,
      _ => ColorTokens.clubAccent,
    };
  }

  IconData _icon(PredictionDetail detail) {
    return switch (detail.status) {
      PredictionStatus.won => AfriIcons.rank,
      PredictionStatus.lost => AfriIcons.challenge,
      PredictionStatus.void_ => AfriIcons.statusEmpty,
      PredictionStatus.cancelled => AfriIcons.statusBlocked,
      _ => AfriIcons.statusWait,
    };
  }

  String _headline(PredictionDetail detail) {
    return switch (detail.status) {
      PredictionStatus.won => 'PREDICTION WON',
      PredictionStatus.lost => 'PREDICTION LOST',
      PredictionStatus.void_ => 'MARKET VOIDED',
      PredictionStatus.cancelled => 'PREDICTION CANCELLED',
      _ => 'SETTLEMENT PENDING',
    };
  }

  String _message(PredictionDetail detail) {
    if (detail.isWon) {
      return 'Official result confirmed. ${detail.fetEarned} FET has been credited to your account.';
    }
    if (detail.isLost) {
      final outcome = detail.correctOutcome?.trim() ?? '';
      if (outcome.isNotEmpty) {
        return 'This one did not land. Official outcome: ${outcome.toUpperCase()}.';
      }
      return 'This selection did not settle in your favour.';
    }
    if (detail.status == PredictionStatus.void_) {
      return 'This market was voided after review. FET balance stayed unchanged.';
    }
    if (detail.status == PredictionStatus.cancelled) {
      return 'This prediction was removed before the fixture locked.';
    }
    return 'The fixture result has not been fully settled yet. Check back after the official update.';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'TBD';
    }

    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final monthNames = <String>[
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
    return '${local.day} ${monthNames[local.month - 1]}  •  $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: GradientBackground(
        child: SafeArea(
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(SpacingTokens.spacing6),
                  child: AfriSkeletonList(),
                )
              : detail == null
              ? Padding(
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
                            title: 'Settlement unavailable',
                            message: _error ?? 'Prediction not found.',
                            actionLabel: 'Retry',
                            onAction: _loadData,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : AfriRefreshIndicator(
                  onRefresh: _loadData,
                  color: ColorTokens.clubAccent,
                  child: ListView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      SpacingTokens.spacing6,
                      SpacingTokens.spacing4,
                      SpacingTokens.spacing6,
                      SpacingTokens.spacing20,
                    ),
                    children: [
                      Row(
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
                              'SETTLEMENT',
                              style: TypographyTokens.headlineSmall().copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: SpacingTokens.spacing4),
                      AfriSurfaceCard(
                        child: Column(
                          children: [
                            Container(
                              width:
                                  SpacingTokens.spacing16 +
                                  SpacingTokens.spacing2,
                              height:
                                  SpacingTokens.spacing16 +
                                  SpacingTokens.spacing2,
                              decoration: BoxDecoration(
                                color: _accent(detail).withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                _icon(detail),
                                color: _accent(detail),
                                size:
                                    SpacingTokens.spacing8 +
                                    SpacingTokens.spacing1 / 2,
                              ),
                            ),
                            const SizedBox(height: SpacingTokens.spacing4),
                            Text(
                              _headline(detail),
                              textAlign: TextAlign.center,
                              style: TypographyTokens.headlineMedium().copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: SpacingTokens.spacing2),
                            Text(
                              '${detail.homeTeam.toUpperCase()}  •  ${detail.awayTeam.toUpperCase()}',
                              textAlign: TextAlign.center,
                              style:
                                  TypographyTokens.labelSmall(
                                    ColorTokens.onSurfaceVariant,
                                  ).copyWith(
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.0,
                                  ),
                            ),
                            const SizedBox(height: SpacingTokens.spacing3),
                            Text(
                              detail.hasScoreline
                                  ? '${detail.homeScore} - ${detail.awayScore}'
                                  : _formatDateTime(detail.kickoffAt),
                              style: TypographyTokens.displaySmall(
                                detail.hasScoreline
                                    ? ColorTokens.onSurface
                                    : ColorTokens.clubAccent,
                              ).copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: SpacingTokens.spacing3),
                            Text(
                              _message(detail),
                              textAlign: TextAlign.center,
                              style: TypographyTokens.bodyMedium(),
                            ),
                            const SizedBox(height: SpacingTokens.spacing4),
                            Row(
                              children: [
                                Expanded(
                                  child: _SettlementMetric(
                                    label: 'MARKET',
                                    value: detail.marketShortName.toUpperCase(),
                                  ),
                                ),
                                const SizedBox(width: SpacingTokens.spacing3),
                                Expanded(
                                  child: _SettlementMetric(
                                    label: 'PICK',
                                    value: detail.selectedOutcome.toUpperCase(),
                                    accent: true,
                                  ),
                                ),
                                const SizedBox(width: SpacingTokens.spacing3),
                                Expanded(
                                  child: _SettlementMetric(
                                    label: detail.isWon
                                        ? 'EARNED'
                                        : detail.isPending
                                        ? 'POTENTIAL'
                                        : 'FET',
                                    value: detail.isWon
                                        ? '+${detail.fetEarned}'
                                        : '+${detail.fetPotential}',
                                    accent: detail.isWon || detail.isPending,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.spacing4),
                      if (detail.isSettled)
                        PredictionShareCard(
                          data: PredictionShareData.fromDetail(detail),
                        ),
                      const SizedBox(height: SpacingTokens.spacing4),
                      GlassCard(
                        animate: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TIMELINE',
                              style:
                                  TypographyTokens.labelSmall(
                                    ColorTokens.onSurfaceVariant,
                                  ).copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                            ),
                            const SizedBox(height: SpacingTokens.spacing3),
                            _SettlementTimelineRow(
                              label: 'Placed',
                              value: _formatDateTime(detail.placedAt),
                            ),
                            const SizedBox(height: SpacingTokens.spacing2),
                            _SettlementTimelineRow(
                              label: 'Kickoff',
                              value: _formatDateTime(detail.kickoffAt),
                            ),
                            if (detail.settledAt != null) ...[
                              const SizedBox(height: SpacingTokens.spacing2),
                              _SettlementTimelineRow(
                                label: 'Settled',
                                value: _formatDateTime(detail.settledAt),
                              ),
                            ],
                            if ((detail.correctOutcome?.trim().isNotEmpty ??
                                false)) ...[
                              const SizedBox(height: SpacingTokens.spacing2),
                              _SettlementTimelineRow(
                                label: 'Official outcome',
                                value: detail.correctOutcome!.toUpperCase(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.spacing4),
                      if (detail.isSettled)
                        AfriButton(
                          label: 'SHARE RESULT',
                          onTap: () => PredictionShareService.share(
                            data: PredictionShareData.fromDetail(detail),
                            context: context,
                          ),
                        ),
                      if (detail.isSettled)
                        const SizedBox(height: SpacingTokens.spacing3),
                      AfriButton(
                        label: 'OPEN MATCH',
                        variant: AfriButtonVariant.secondary,
                        onTap: () =>
                            context.push('/fanzone/match/${detail.fixtureId}'),
                      ),
                      const SizedBox(height: SpacingTokens.spacing3),
                      AfriButton(
                        label: 'VIEW FULL DETAIL',
                        variant: AfriButtonVariant.secondary,
                        onTap: () => context.push('/fanzone/my/${detail.id}'),
                      ),
                      const SizedBox(height: SpacingTokens.spacing3),
                      AfriButton(
                        label: 'BROWSE FIXTURES',
                        variant: AfriButtonVariant.secondary,
                        onTap: () => context.go('/fanzone/fixtures'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _SettlementMetric extends StatelessWidget {
  const _SettlementMetric({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TypographyTokens.labelSmall(
              ColorTokens.onSurfaceVariant,
            ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 1.0),
          ),
          const SizedBox(height: SpacingTokens.spacing1),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TypographyTokens.titleMedium(
              accent ? ColorTokens.clubAccent : ColorTokens.onSurface,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SettlementTimelineRow extends StatelessWidget {
  const _SettlementTimelineRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TypographyTokens.labelMedium(ColorTokens.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: SpacingTokens.spacing3),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TypographyTokens.labelMedium(
              ColorTokens.onSurface,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
