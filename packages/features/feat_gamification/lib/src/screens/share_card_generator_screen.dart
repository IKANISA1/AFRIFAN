import 'package:core_theme/core_theme.dart';
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
    _load();
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
    } catch (_) {
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

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'SHARE CARD',
          style: TypographyTokens.monolithFont(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(AfriIcons.back),
        ),
      ),
      body: _isLoading
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
          : selected == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(SpacingTokens.spacing6),
                child: AfriEmptyView(
                  title: 'No settled predictions yet',
                  message:
                      'Once your predictions settle, you can generate branded share cards here.',
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: ColorTokens.clubAccent,
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                children: [
                  PredictionShareCard(
                    data: PredictionShareData.fromPrediction(selected),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  Row(
                    children: [
                      Expanded(
                        child: AfriButton(
                          onTap: () => PredictionShareService.share(
                            data: PredictionShareData.fromPrediction(selected),
                            context: context,
                          ),
                          label: 'Share',
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.spacing3),
                      Expanded(
                        child: AfriButton(
                          onTap: () => PredictionShareService.copy(
                            data: PredictionShareData.fromPrediction(selected),
                            context: context,
                          ),
                          label: 'Copy',
                          variant: AfriButtonVariant.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  ClayCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SELECT A PREDICTION',
                          style: TypographyTokens.titleLarge(),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        ..._history.map((prediction) {
                          final selectedCard = prediction.id == selected.id;
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: SpacingTokens.spacing3,
                            ),
                            child: AfriPressFeedback(
                              onTap: () =>
                                  setState(() => _selected = prediction),
                              builder: (context, _) => GlassCard(
                                animate: false,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${prediction.homeTeamShort} vs ${prediction.awayTeamShort}',
                                            style:
                                                TypographyTokens.titleSmall(),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${prediction.marketName} · ${prediction.selectedOutcome.toUpperCase()}',
                                            style: TypographyTokens.bodySmall(),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(
                                      width: SpacingTokens.spacing3,
                                    ),
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
                                          999,
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
            ),
    );
  }
}
