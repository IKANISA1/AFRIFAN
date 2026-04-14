import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/prediction_slip_models.dart';
import '../prediction_slip_providers.dart';

class PredictionSlipBar extends ConsumerWidget {
  const PredictionSlipBar({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slip = ref.watch(predictionSlipProvider);
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
                      slip.accaMode && slip.items.length > 1
                          ? 'Acca ready · ${slip.totalPotential} FET potential'
                          : 'Earn up to ${slip.totalPotential} FET',
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
  FutureOr<void> Function(PredictionSlipSubmissionResult result)? onSubmitted,
}) {
  return showAfriBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _PredictionSlipSheet(onSubmitted: onSubmitted),
  );
}

class _PredictionSlipSheet extends ConsumerWidget {
  const _PredictionSlipSheet({this.onSubmitted});

  final FutureOr<void> Function(PredictionSlipSubmissionResult result)?
  onSubmitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slip = ref.watch(predictionSlipProvider);
    final controller = ref.read(predictionSlipProvider.notifier);

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
                'Add markets from fixtures and lock them in from here.',
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
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            slip.accaMode && slip.items.length > 1
                ? 'Combining ${slip.items.length} legs into one slip.'
                : 'Each prediction will be locked in separately.',
            style: TypographyTokens.bodySmall(),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
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
            label: slip.isSubmitting
                ? 'Submitting...'
                : slip.accaMode && slip.items.length > 1
                ? 'Lock In Acca'
                : 'Lock In Predictions',
            icon: Icons.verified_rounded,
            enabled: !slip.isSubmitting,
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final result = await controller.submit();
              if (!context.mounted) {
                return;
              }

              Navigator.of(context).pop();

              if (result.submittedCount > 0) {
                if (onSubmitted != null) {
                  await onSubmitted!.call(result);
                } else {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Locked ${result.submittedCount} predictions · ${result.totalPotential} FET potential',
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

class _SlipRow extends StatelessWidget {
  const _SlipRow({required this.item, required this.onRemove});

  final PredictionSlipSelection item;
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
