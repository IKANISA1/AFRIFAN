import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fanzone_slip_providers.dart';
import '../models/fanzone_slip_models.dart';
import '../models/prediction_models.dart';
import '../prediction_result_copy.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/prediction_share_card.dart';

class PredictionSlipBar extends ConsumerWidget {
  const PredictionSlipBar({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slip = ref.watch(fanzoneSlipProvider);
    if (slip.items.isEmpty) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        SpacingTokens.spacing6,
        0,
        SpacingTokens.spacing6,
        SpacingTokens.spacing4,
      ),
      child: AfriPressFeedback(
        onTap: onTap,
        semanticsLabel: context.afriL10n.gamePickRound,
        tooltip: context.afriL10n.gamePickRound,
        excludeChildSemantics: true,
        builder: (context, state) => AfriSurfaceCard(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing4,
            vertical: SpacingTokens.spacing3,
          ),
          child: Row(
            children: [
              Container(
                width: SpacingTokens.spacing10,
                height: SpacingTokens.spacing10,
                decoration: BoxDecoration(
                  color: ColorTokens.clubAccent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
                ),
                alignment: Alignment.center,
                child: Text(
                  slip.items.length.toString(),
                  style: TypographyTokens.titleMedium(
                    ColorTokens.clubAccent,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.afriL10n.gameActivePicks(slip.items.length),
                      style: TypographyTokens.titleSmall(),
                    ),
                    Text(
                      context.afriL10n.gameEarnUpToPoints(slip.totalPotential),
                      style: TypographyTokens.bodySmall(),
                    ),
                  ],
                ),
              ),
              Icon(
                AfriIcons.up,
                color: state.isPressed
                    ? ColorTokens.clubAccent
                    : ColorTokens.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showPredictionSlipSheet(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? onSubmitted,
}) {
  final hostContext = context;
  return showAfriBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _PredictionSlipSheet(
      hostContext: hostContext,
      onSubmitted: onSubmitted,
    ),
  );
}

class _PredictionSlipSheet extends ConsumerWidget {
  const _PredictionSlipSheet({required this.hostContext, this.onSubmitted});

  final BuildContext hostContext;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slip = ref.watch(fanzoneSlipProvider);
    final controller = ref.read(fanzoneSlipProvider.notifier);

    if (slip.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: SpacingTokens.spacing4),
        child: AfriSurfaceCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AfriIcons.myPicks,
                size: SpacingTokens.spacing8,
                color: ColorTokens.onSurfaceVariant,
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              Text(
                context.afriL10n.gamePickRoundEmpty,
                style: TypographyTokens.titleMedium(),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                context.afriL10n.gamePickRoundEmptyDescription,
                textAlign: TextAlign.center,
                style: TypographyTokens.bodySmall(),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.afriL10n.gamePickRoundUpper,
                  style: TypographyTokens.headlineSmall().copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              AfriSwitch(
                value: slip.accaMode,
                onChanged: controller.toggleAcca,
              ),
              const SizedBox(width: SpacingTokens.spacing2),
              Text(
                context.afriL10n.gameAcca,
                style: TypographyTokens.bodySmall(),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          ...slip.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
              child: _SlipRow(
                item: item,
                onRemove: () =>
                    controller.removeSelection(item.fixtureMarketId),
              ),
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            context.afriL10n.gamePotentialPoints(slip.totalPotential),
            style: TypographyTokens.titleLarge(
              ColorTokens.clubAccent,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriButton(
            label: slip.isSubmitting
                ? context.afriL10n.gameSubmitting
                : context.afriL10n.gameLockInPicks,
            icon: AfriIcons.verified,
            enabled: !slip.isSubmitting,
            onTap: () async {
              // B-1: Confirmation gate before prediction submission.
              // Show a summary sheet and only proceed if the user confirms.
              final confirmed = await _showPreSubmitConfirmation(
                context,
                items: slip.items,
                accaMode: slip.accaMode,
                totalPotential: slip.totalPotential,
              );
              if (!confirmed || !context.mounted) return;

              // Capture slip info before submit clears it.
              final slipItems = List<FanzoneSlipSelection>.from(slip.items);
              final result = await controller.submit();
              if (!context.mounted) return;
              context.pop();

              if (result.submittedCount > 0) {
                onSubmitted?.call();
                unawaited(HapticFeedback.mediumImpact());

                // ── Confetti burst ──
                if (hostContext.mounted) {
                  showConfettiOverlay(hostContext);
                }

                // ── Share card modal (replaces old confirmation sheet) ──
                if (hostContext.mounted) {
                  await Future<void>.delayed(AfriMotion.feedbackDelay);
                  if (hostContext.mounted) {
                    await _showShareCardModal(
                      hostContext,
                      result: result,
                      slipItems: slipItems,
                    );
                  }
                }

                if (result.hasFailures && hostContext.mounted) {
                  AfriToast.error(
                    hostContext,
                    result.messages.isNotEmpty
                        ? hostContext.localizePredictionResultMessage(
                            result.messages.first,
                          )
                        : hostContext.afriL10n.gameSomeSelectionsFailed,
                  );
                }
              } else if (hostContext.mounted) {
                AfriToast.error(
                  hostContext,
                  result.messages.isNotEmpty
                      ? hostContext.localizePredictionResultMessage(
                          result.messages.first,
                        )
                      : hostContext.afriL10n.gameCouldNotSubmitPicks,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

// ── Pre-submission confirmation sheet (B-1 fix) ────────────────────────

/// Shows a confirmation bottom sheet summarising the pick round before
/// submission. Returns `true` if the user confirms, `false` if they cancel.
Future<bool> _showPreSubmitConfirmation(
  BuildContext context, {
  required List<FanzoneSlipSelection> items,
  required bool accaMode,
  required int totalPotential,
}) async {
  final result = await showAfriBottomSheet<bool>(
    context: context,
    builder: (context) => Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.afriL10n.gameConfirmPicks,
            style: TypographyTokens.headlineSmall().copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            accaMode && items.length > 1
                ? context.afriL10n.gameLockingCombo(items.length)
                : context.afriL10n.gameLockingPicks(items.length),
            style: TypographyTokens.bodyMedium(),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
              child: GlassCard(
                animate: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fixtureLabel,
                      style: TypographyTokens.titleSmall(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing1),
                    Row(
                      children: [
                        Text(
                          item.marketName.toUpperCase(),
                          style: TypographyTokens.labelSmall(
                            ColorTokens.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          context.afriL10n.gameOutcomePotential(
                            item.outcomeLabel,
                            item.fetPotential,
                          ),
                          style: TypographyTokens.labelSmall(
                            ColorTokens.clubAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          AfriSurfaceCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.afriL10n.gameTotalPotential,
                        style: TypographyTokens.labelSmall(
                          ColorTokens.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.spacing1),
                      Text(
                        context.afriL10n.gamePoints(totalPotential),
                        style: TypographyTokens.metricValue(
                          ColorTokens.clubAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing5),
          AfriButton(
            label: context.afriL10n.gameConfirmPicks,
            icon: AfriIcons.verified,
            onTap: () => context.pop(true),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          AfriButton(
            label: context.afriL10n.gameGoBack,
            variant: AfriButtonVariant.secondary,
            onTap: () => context.pop(false),
          ),
        ],
      ),
    ),
  );
  return result == true;
}

// ── Post-submission share card modal ───────────────────────────────────

Future<void> _showShareCardModal(
  BuildContext context, {
  required FanzoneSlipSubmissionResult result,
  required List<FanzoneSlipSelection> slipItems,
}) {
  return showAfriBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _ShareCardModalSheet(result: result, slipItems: slipItems),
  );
}

class _ShareCardModalSheet extends StatelessWidget {
  const _ShareCardModalSheet({required this.result, required this.slipItems});

  final FanzoneSlipSubmissionResult result;
  final List<FanzoneSlipSelection> slipItems;

  @override
  Widget build(BuildContext context) {
    final headline = context.afriL10n.gamePredictionsLocked(
      result.submittedCount,
    );

    // Build share data from the first slip item.
    final first = slipItems.isNotEmpty ? slipItems.first : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Success header ──
          AfriSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: SpacingTokens.spacing12 + SpacingTokens.spacing1,
                  height: SpacingTokens.spacing12 + SpacingTokens.spacing1,
                  decoration: BoxDecoration(
                    color: ColorTokens.success.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    AfriIcons.verified,
                    color: ColorTokens.success,
                    size: SpacingTokens.spacing7,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                Text(
                  headline.toUpperCase(),
                  style: TypographyTokens.headlineMedium().copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  context.afriL10n.gamePotentialPoints(result.totalPotential),
                  style: TypographyTokens.bodyLarge(),
                ),
                if ((result.slipId ?? '').isNotEmpty) ...[
                  const SizedBox(height: SpacingTokens.spacing2),
                  Text(
                    context.afriL10n.gameRoundId(result.slipId!),
                    style: TypographyTokens.bodySmall(),
                  ),
                ],
              ],
            ),
          ),
          // ── Share card preview ──
          if (first != null) ...[
            const SizedBox(height: SpacingTokens.spacing4),
            PredictionShareCard(
              data: PredictionShareData(
                competitionName: first.competitionName ?? '',
                homeTeam: first.fixtureLabel.split(' vs ').first,
                homeTeamShort: first.fixtureLabel.split(' vs ').first,
                awayTeam: first.fixtureLabel.split(' vs ').last,
                awayTeamShort: first.fixtureLabel.split(' vs ').last,
                marketName: first.marketName,
                selectedOutcome: first.outcomeLabel,
                status: PredictionStatus.pending,
                fetPotential: result.totalPotential,
                fetEarned: 0,
              ),
            ),
          ],
          const SizedBox(height: SpacingTokens.spacing4),
          // ── Action buttons ──
          if (first != null)
            Row(
              children: [
                Expanded(
                  child: AfriButton(
                    onTap: () {
                      unawaited(
                        PredictionShareService.share(
                          data: PredictionShareData(
                            competitionName: first.competitionName ?? '',
                            homeTeam: first.fixtureLabel.split(' vs ').first,
                            homeTeamShort: first.fixtureLabel
                                .split(' vs ')
                                .first,
                            awayTeam: first.fixtureLabel.split(' vs ').last,
                            awayTeamShort: first.fixtureLabel
                                .split(' vs ')
                                .last,
                            marketName: first.marketName,
                            selectedOutcome: first.outcomeLabel,
                            status: PredictionStatus.pending,
                            fetPotential: result.totalPotential,
                            fetEarned: 0,
                          ),
                          context: context,
                        ),
                      );
                    },
                    label: context.afriL10n.gameShareUpper,
                    icon: AfriIcons.share,
                  ),
                ),
                const SizedBox(width: SpacingTokens.spacing3),
                Expanded(
                  child: AfriButton(
                    onTap: () {
                      unawaited(
                        PredictionShareService.copy(
                          data: PredictionShareData(
                            competitionName: first.competitionName ?? '',
                            homeTeam: first.fixtureLabel.split(' vs ').first,
                            homeTeamShort: first.fixtureLabel
                                .split(' vs ')
                                .first,
                            awayTeam: first.fixtureLabel.split(' vs ').last,
                            awayTeamShort: first.fixtureLabel
                                .split(' vs ')
                                .last,
                            marketName: first.marketName,
                            selectedOutcome: first.outcomeLabel,
                            status: PredictionStatus.pending,
                            fetPotential: result.totalPotential,
                            fetEarned: 0,
                          ),
                          context: context,
                        ),
                      );
                    },
                    label: context.afriL10n.gameCopyUpper,
                    icon: AfriIcons.copy,
                    variant: AfriButtonVariant.secondary,
                  ),
                ),
              ],
            ),
          const SizedBox(height: SpacingTokens.spacing3),
          AfriButton(
            label: context.afriL10n.gameViewMyPredictions,
            icon: AfriIcons.myPicks,
            variant: AfriButtonVariant.secondary,
            onTap: () {
              final router = GoRouter.of(context);
              context.pop();
              unawaited(router.push('/fanzone/my'));
            },
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          AfriButton(
            label: context.afriL10n.gameKeepBrowsing,
            variant: AfriButtonVariant.secondary,
            onTap: () => context.pop(),
          ),
        ],
      ),
    );
  }
}

// ── Preserved: public showPredictionConfirmationSheet (backward compat) ──

Future<void> showPredictionConfirmationSheet(
  BuildContext context,
  FanzoneSlipSubmissionResult result,
) {
  return showAfriBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ShareCardModalSheet(
      result: result,
      slipItems: const <FanzoneSlipSelection>[],
    ),
  );
}

// ── Slip row / chip ────────────────────────────────────────────────────

class _SlipRow extends StatelessWidget {
  const _SlipRow({required this.item, required this.onRemove});

  final FanzoneSlipSelection item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.fixtureLabel, style: TypographyTokens.titleSmall()),
                const SizedBox(height: SpacingTokens.spacing1),
                Text(
                  item.marketName.toUpperCase(),
                  style: TypographyTokens.labelMedium(
                    ColorTokens.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Wrap(
                  spacing: SpacingTokens.spacing2,
                  runSpacing: SpacingTokens.spacing2,
                  children: [
                    _SlipChip(label: item.outcomeLabel),
                    _SlipChip(
                      label: context.afriL10n.gamePoints(item.fetPotential),
                    ),
                  ],
                ),
              ],
            ),
          ),
          AfriIconButton(
            icon: AfriIcons.close,
            onTap: onRemove,
            tooltip: context.afriL10n.gameRemovePick,
          ),
        ],
      ),
    );
  }
}

class _SlipChip extends StatelessWidget {
  const _SlipChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing2,
        vertical: SpacingTokens.spacing1,
      ),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
      ),
      child: Text(
        label.toUpperCase(),
        style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
      ),
    );
  }
}
