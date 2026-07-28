import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/prediction_models.dart';
import '../prediction_providers.dart';
import '../widgets/prediction_share_card.dart';

class ShareCardGeneratorScreen extends ConsumerStatefulWidget {
  const ShareCardGeneratorScreen({super.key});

  @override
  ConsumerState<ShareCardGeneratorScreen> createState() =>
      _ShareCardGeneratorScreenState();
}

class _ShareCardGeneratorScreenState
    extends ConsumerState<ShareCardGeneratorScreen> {
  List<UserPrediction> _history = const <UserPrediction>[];
  UserPrediction? _selected;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final history = await ref
          .read(predictionRepositoryProvider)
          .loadPredictionHistory(limit: 30);
      if (!mounted) {
        return;
      }
      setState(() {
        _history = history;
        _selected = history.isEmpty ? null : history.first;
        _isLoading = false;
        _error = null;
      });
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'ShareCardGeneratorScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = 'Share cards are temporarily unavailable.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          'Share card',
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
        ),
      ),
      scrollable: false,
      constrainContent: true,
      child: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                child: AfriStateView.offline(
                  title: 'Share cards unavailable',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _load,
                ),
              ),
            )
          : ShareCardGeneratorContent(
              history: _history,
              selected: selected,
              onRefresh: _load,
              onSelected: (prediction) => setState(() {
                _selected = prediction;
              }),
              onShare: (prediction) => PredictionShareService.share(
                data: PredictionShareData.fromPrediction(prediction),
                context: context,
              ),
              onCopy: (prediction) => PredictionShareService.copy(
                data: PredictionShareData.fromPrediction(prediction),
                context: context,
              ),
            ),
    );
  }
}

class ShareCardGeneratorContent extends StatelessWidget {
  const ShareCardGeneratorContent({
    super.key,
    required this.history,
    required this.selected,
    required this.onRefresh,
    required this.onSelected,
    required this.onShare,
    required this.onCopy,
  });

  final List<UserPrediction> history;
  final UserPrediction? selected;
  final Future<void> Function() onRefresh;
  final ValueChanged<UserPrediction> onSelected;
  final ValueChanged<UserPrediction> onShare;
  final ValueChanged<UserPrediction> onCopy;

  @override
  Widget build(BuildContext context) {
    final selectedPrediction = selected;
    if (selectedPrediction == null) {
      return Center(
        key: const ValueKey<String>('share-card-empty'),
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing6),
          child: AfriStateView.empty(
            title: 'Make a pick first',
            message: 'Share cards unlock after a matchday pick.',
            actionLabel: 'Back to picks',
            onAction: () => context.go('/fanzone?section=predictions'),
          ),
        ),
      );
    }

    return AfriRefreshIndicator(
      onRefresh: onRefresh,
      color: ColorTokens.clubAccent,
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        children: [
          PredictionShareCard(
            data: PredictionShareData.fromPrediction(selectedPrediction),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Row(
            children: [
              Expanded(
                child: AfriButton(
                  onTap: () => onShare(selectedPrediction),
                  label: 'Share',
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              Expanded(
                child: AfriButton(
                  onTap: () => onCopy(selectedPrediction),
                  label: 'Copy',
                  variant: AfriButtonVariant.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose pick', style: TypographyTokens.titleLarge()),
                const SizedBox(height: SpacingTokens.spacing3),
                ...history.map((prediction) {
                  final selectedCard = prediction.id == selectedPrediction.id;
                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: SpacingTokens.spacing3,
                    ),
                    child: AfriPressFeedback(
                      onTap: () => onSelected(prediction),
                      builder: (context, _) => GlassCard(
                        animate: false,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${prediction.homeTeamShort} vs ${prediction.awayTeamShort}',
                                    style: TypographyTokens.titleSmall(),
                                  ),
                                  const SizedBox(
                                    height: SpacingTokens.spacing1 / 2,
                                  ),
                                  Text(
                                    '${prediction.marketName} · ${prediction.selectedOutcome}',
                                    style: TypographyTokens.bodySmall(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: SpacingTokens.spacing3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: SpacingTokens.spacing2,
                                vertical: SpacingTokens.spacing1,
                              ),
                              decoration: BoxDecoration(
                                color: selectedCard
                                    ? ColorTokens.clubAccent.withValues(
                                        alpha: 0.16,
                                      )
                                    : ColorTokens.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(
                                  ShapeTokens.radiusFull,
                                ),
                              ),
                              child: Text(
                                selectedCard ? 'Selected' : 'Open',
                                style: TypographyTokens.labelSmall(
                                  selectedCard
                                      ? ColorTokens.clubAccent
                                      : ColorTokens.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
