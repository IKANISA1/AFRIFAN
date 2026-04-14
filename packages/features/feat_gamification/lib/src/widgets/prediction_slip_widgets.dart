import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fanzone_slip_providers.dart';
import '../models/fanzone_slip_models.dart';

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
        semanticsLabel: 'Prediction slip',
        tooltip: 'Prediction slip',
        excludeChildSemantics: true,
        builder: (context, state) => ClayCard(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing4,
            vertical: SpacingTokens.spacing3,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ColorTokens.clubAccent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  slip.items.length.toString(),
                  style: TypographyTokens.monolithFont(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: ColorTokens.clubAccent,
                  ),
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      slip.items.length == 1
                          ? '1 prediction active'
                          : '${slip.items.length} predictions active',
                      style: TypographyTokens.titleSmall(),
                    ),
                    Text(
                      'Earn up to ${slip.totalPotential} FET',
                      style: TypographyTokens.bodySmall(),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_up_rounded,
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
        child: ClayCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 32,
                color: ColorTokens.onSurfaceVariant,
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              Text(
                'Prediction slip is empty',
                style: TypographyTokens.titleMedium(),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                'Add markets from any fixture and lock them in from here.',
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
                  'PREDICTION SLIP',
                  style: TypographyTokens.monolithFont(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              Switch.adaptive(
                value: slip.accaMode,
                onChanged: controller.toggleAcca,
              ),
              const SizedBox(width: SpacingTokens.spacing2),
              Text('Acca', style: TypographyTokens.bodySmall()),
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
            'Potential return: ${slip.totalPotential} FET',
            style: TypographyTokens.monolithFont(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: ColorTokens.clubAccent,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriButton(
            label: slip.isSubmitting ? 'Submitting...' : 'Lock In Predictions',
            icon: Icons.verified_rounded,
            enabled: !slip.isSubmitting,
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final result = await controller.submit();
              if (!context.mounted) return;
              Navigator.of(context).pop();

              if (result.submittedCount > 0) {
                onSubmitted?.call();
                if (hostContext.mounted) {
                  await Future<void>.delayed(Duration.zero);
                  if (hostContext.mounted) {
                    await showPredictionConfirmationSheet(hostContext, result);
                  }
                }
                if (result.hasFailures && messenger.mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        result.messages.isNotEmpty
                            ? result.messages.first
                            : 'Some selections could not be submitted.',
                      ),
                    ),
                  );
                }
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      result.messages.isNotEmpty
                          ? result.messages.first
                          : 'Could not submit your predictions.',
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

Future<void> showPredictionConfirmationSheet(
  BuildContext context,
  FanzoneSlipSubmissionResult result,
) {
  return showAfriBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _PredictionConfirmationSheet(result: result),
  );
}

class _PredictionConfirmationSheet extends StatelessWidget {
  const _PredictionConfirmationSheet({required this.result});

  final FanzoneSlipSubmissionResult result;

  @override
  Widget build(BuildContext context) {
    final headline = result.submittedCount == 1
        ? 'Prediction Locked'
        : '${result.submittedCount} Predictions Locked';

    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClayCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: ColorTokens.success.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.verified_rounded,
                    color: ColorTokens.success,
                    size: 28,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                Text(
                  headline.toUpperCase(),
                  style: TypographyTokens.monolithFont(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  'Potential earn: ${result.totalPotential} FET',
                  style: TypographyTokens.bodyLarge(),
                ),
                if ((result.slipId ?? '').isNotEmpty) ...[
                  const SizedBox(height: SpacingTokens.spacing2),
                  Text(
                    'Slip ID: ${result.slipId}',
                    style: TypographyTokens.bodySmall(),
                  ),
                ],
                if (result.messages.isNotEmpty) ...[
                  const SizedBox(height: SpacingTokens.spacing3),
                  Text(
                    result.messages.first,
                    style: TypographyTokens.bodySmall(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriButton(
            label: 'VIEW MY PREDICTIONS',
            icon: Icons.receipt_long_rounded,
            onTap: () {
              Navigator.of(context).pop();
              context.push('/fanzone/my');
            },
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          AfriButton(
            label: 'KEEP BROWSING',
            variant: AfriButtonVariant.secondary,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

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
                    _SlipChip(label: '+${item.fetPotential} FET'),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Remove prediction',
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
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
      ),
    );
  }
}
