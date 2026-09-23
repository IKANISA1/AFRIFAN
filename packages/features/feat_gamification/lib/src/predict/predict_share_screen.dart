import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/share_card_controller.dart';
import '../models/prediction_models.dart';
import '../prediction_providers.dart';
import '../widgets/prediction_selection.dart';
import '../widgets/prediction_share_card.dart';

class PredictShareScreen extends ConsumerStatefulWidget {
  const PredictShareScreen({super.key, this.shareFocusNode});

  final FocusNode? shareFocusNode;

  @override
  ConsumerState<PredictShareScreen> createState() => _PredictShareScreenState();
}

class _PredictShareScreenState extends ConsumerState<PredictShareScreen> {
  late bool _wasOnline;

  @override
  void initState() {
    super.initState();
    _wasOnline = ConnectivityService.isOnline;
    ConnectivityService.onlineNotifier.addListener(_handleConnectivityChange);
  }

  @override
  void dispose() {
    ConnectivityService.onlineNotifier.removeListener(
      _handleConnectivityChange,
    );
    super.dispose();
  }

  void _handleConnectivityChange() {
    final isOnline = ConnectivityService.isOnline;
    final restored = !_wasOnline && isOnline;
    _wasOnline = isOnline;
    if (!mounted) return;
    setState(() {});
    if (restored) {
      unawaited(
        ref.read(shareCardControllerProvider.notifier).connectionRestored(),
      );
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/predict');
    }
  }

  Future<void> _share() async {
    final outcome = await ref
        .read(shareCardControllerProvider.notifier)
        .share();
    if (!mounted || !outcome.isSuccess) return;
    AfriToast.success(context, context.afriL10n.gameShareOptionsClosed);
  }

  Future<void> _copy() async {
    final outcome = await ref.read(shareCardControllerProvider.notifier).copy();
    if (!mounted || !outcome.isSuccess) return;
    AfriToast.success(context, context.afriL10n.gameShareCopied);
  }

  @override
  Widget build(BuildContext context) {
    final accessEnabled = ref.watch(shareCardActionsEnabledProvider);
    final asyncState = ref.watch(shareCardControllerProvider);

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          context.afriL10n.gameShareCard,
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: AfriIconButton(
          key: const ValueKey<String>('share-card-back'),
          icon: AfriIcons.back,
          onTap: _close,
          tooltip: context.afriL10n.gameBack,
        ),
      ),
      scrollable: false,
      constrainContent: true,
      child: !accessEnabled
          ? _ShareCardConsequence(
              title: context.afriL10n.gameShareActionsUnavailable,
              body: context.afriL10n.gameShareActionsUnavailableDescription,
              actionLabel: context.afriL10n.gameBackToPredict,
              onAction: _close,
            )
          : asyncState.when(
              loading: () {
                final previous = asyncState.valueOrNull;
                if (previous?.history.isNotEmpty == true) {
                  return _buildContent(previous!);
                }
                return const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(SpacingTokens.spacing6),
                    child: AfriSkeletonList(),
                  ),
                );
              },
              error: (error, _) => _buildInitialFailure(error),
              data: (state) {
                if (state.failure?.kind ==
                    ShareCardFailureKind.permissionDenied) {
                  return _ShareCardConsequence(
                    title: context.afriL10n.gamePredictionAccessDenied,
                    body:
                        context.afriL10n.gamePredictionAccessDeniedDescription,
                    actionLabel: context.afriL10n.gameBackToPredict,
                    onAction: _close,
                  );
                }
                if (state.isEmpty) {
                  return _ShareCardConsequence(
                    key: const ValueKey<String>('share-card-empty'),
                    title: context.afriL10n.gameMakePickFirst,
                    body: context.afriL10n.gameShareCardsUnlock,
                    actionLabel: context.afriL10n.gameBackToPicksUpper,
                    onAction: () => context.go('/predict?section=history'),
                  );
                }
                return _buildContent(state);
              },
            ),
    );
  }

  Widget _buildInitialFailure(Object error) {
    final failure = ShareCardFailure.fromError(error);
    return switch (failure.kind) {
      ShareCardFailureKind.offline => _ShareCardConsequence(
        title: context.afriL10n.gameShareCardsOffline,
        body: context.afriL10n.gameShareCardsOfflineDescription,
        actionLabel: context.afriL10n.gameBackToPredict,
        onAction: _close,
      ),
      ShareCardFailureKind.permissionDenied => _ShareCardConsequence(
        title: context.afriL10n.gamePredictionAccessDenied,
        body: context.afriL10n.gamePredictionAccessDeniedDescription,
        actionLabel: context.afriL10n.gameBackToPredict,
        onAction: _close,
      ),
      ShareCardFailureKind.securityTimeout => _ShareCardConsequence(
        title: context.afriL10n.gameHistoryCheckTimedOut,
        body: context.afriL10n.gameHistoryCheckTimedOutDescription,
        actionLabel: context.afriL10n.gameTryAgainUpper,
        onAction: () =>
            ref.read(shareCardControllerProvider.notifier).refresh(),
      ),
      _ => _ShareCardConsequence(
        title: context.afriL10n.gameShareCardsUnavailable,
        body: context.afriL10n.gameShareCardsUnavailableDescription,
        actionLabel: context.afriL10n.gameTryAgainUpper,
        onAction: () =>
            ref.read(shareCardControllerProvider.notifier).refresh(),
      ),
    };
  }

  Widget _buildContent(ShareCardRouteState routeState) {
    final isOnline = ConnectivityService.isOnline;
    final selected = routeState.selected;
    if (selected == null) {
      return _ShareCardConsequence(
        key: const ValueKey<String>('share-card-empty'),
        title: context.afriL10n.gameMakePickFirst,
        body: context.afriL10n.gameShareCardsUnlock,
        actionLabel: context.afriL10n.gameBackToPicksUpper,
        onAction: () => context.go('/predict?section=history'),
      );
    }
    final actionsEnabled =
        isOnline &&
        routeState.phase == ShareCardPhase.ready &&
        routeState.mutation == ShareCardMutation.idle &&
        routeState.failure == null &&
        !routeState.uncertainMutation;

    return ShareCardGeneratorContent(
      history: routeState.history,
      selected: selected,
      status: _statusFor(routeState, online: isOnline),
      actionsEnabled: actionsEnabled,
      shareFocusNode: widget.shareFocusNode,
      sharing: routeState.mutation == ShareCardMutation.sharing,
      copying: routeState.mutation == ShareCardMutation.copying,
      onRefresh: () => ref.read(shareCardControllerProvider.notifier).refresh(),
      onSelected: (prediction) =>
          ref.read(shareCardControllerProvider.notifier).select(prediction.id),
      onShare: (_) => _share(),
      onCopy: (_) => _copy(),
    );
  }

  Widget? _statusFor(ShareCardRouteState state, {required bool online}) {
    final l10n = context.afriL10n;
    if (!online || state.failure?.kind == ShareCardFailureKind.offline) {
      return AfriStateBanner(
        icon: AfriIcons.offline,
        title: l10n.gameShowingSavedShareCard,
        subtitle: l10n.gameShowingSavedShareCardDescription,
        tone: AfriStateBannerTone.warning,
      );
    }
    if (state.phase == ShareCardPhase.syncing) {
      return AfriStateBanner(
        icon: AfriIcons.refresh,
        title: state.mutation == ShareCardMutation.copying
            ? l10n.gameCopyingShareText
            : l10n.gameOpeningShareOptions,
        subtitle: l10n.gameShareAwaitPlatformConfirmation,
        tone: AfriStateBannerTone.info,
      );
    }
    return switch (state.failure?.kind) {
      ShareCardFailureKind.conflict => AfriStateBanner(
        icon: AfriIcons.warning,
        title: l10n.gameShareActionPaused,
        subtitle: l10n.gameShareActionPausedDescription,
        tone: AfriStateBannerTone.warning,
        onTap: () => ref
            .read(shareCardControllerProvider.notifier)
            .acknowledgeActionFailure(),
      ),
      ShareCardFailureKind.securityTimeout => AfriStateBanner(
        icon: AfriIcons.warning,
        title: l10n.gameShareConfirmationUncertain,
        subtitle: l10n.gameShareConfirmationUncertainDescription,
        tone: AfriStateBannerTone.danger,
        onTap: () => ref
            .read(shareCardControllerProvider.notifier)
            .acknowledgeActionFailure(),
      ),
      ShareCardFailureKind.unknown => AfriStateBanner(
        icon: AfriIcons.warning,
        title: l10n.gameShareActionUnavailable,
        subtitle: l10n.gameShareActionUnavailableDescription,
        tone: AfriStateBannerTone.warning,
        onTap: () => ref
            .read(shareCardControllerProvider.notifier)
            .acknowledgeActionFailure(),
      ),
      _ when state.phase == ShareCardPhase.degraded => AfriStateBanner(
        icon: AfriIcons.warning,
        title: l10n.gameUsingSavedPredictionHistory,
        subtitle: l10n.gameUsingSavedPredictionHistoryDescription,
        tone: AfriStateBannerTone.warning,
        onTap: () => ref.read(shareCardControllerProvider.notifier).refresh(),
      ),
      _ => null,
    };
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
    this.status,
    this.actionsEnabled = true,
    this.sharing = false,
    this.copying = false,
    this.shareFocusNode,
  });

  final List<UserPrediction> history;
  final UserPrediction? selected;
  final Future<void> Function() onRefresh;
  final ValueChanged<UserPrediction> onSelected;
  final Future<void> Function(UserPrediction) onShare;
  final Future<void> Function(UserPrediction) onCopy;
  final Widget? status;
  final bool actionsEnabled;
  final bool sharing;
  final bool copying;
  final FocusNode? shareFocusNode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final selectedPrediction = selected;
    if (selectedPrediction == null) {
      return Center(
        key: const ValueKey<String>('share-card-empty'),
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing6),
          child: AfriStateView.empty(
            title: l10n.gameMakePickFirst,
            message: l10n.gameShareCardsUnlock,
            actionLabel: l10n.gameBackToPicks,
            onAction: () => context.go('/predict?section=history'),
          ),
        ),
      );
    }

    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final actions = <Widget>[
      AfriButton(
        key: const ValueKey<String>('share-card-share-action'),
        focusNode: shareFocusNode,
        onTap: () => unawaited(onShare(selectedPrediction)),
        label: l10n.gameShareUpper,
        enabled: actionsEnabled,
        isLoading: sharing,
      ),
      AfriButton(
        key: const ValueKey<String>('share-card-copy-action'),
        onTap: () => unawaited(onCopy(selectedPrediction)),
        label: l10n.gameCopyUpper,
        enabled: actionsEnabled,
        isLoading: copying,
        variant: AfriButtonVariant.secondary,
      ),
    ];

    return AfriRefreshIndicator(
      onRefresh: onRefresh,
      color: context.afriSemanticColors.accent,
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        children: [
          if (status != null) ...[
            status!,
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          PredictionShareCard(
            data: PredictionShareData.fromPrediction(selectedPrediction),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          if (largeText)
            Column(
              children: [
                actions.first,
                const SizedBox(height: SpacingTokens.spacing3),
                actions.last,
              ],
            )
          else
            Row(
              children: [
                Expanded(child: actions.first),
                const SizedBox(width: SpacingTokens.spacing3),
                Expanded(child: actions.last),
              ],
            ),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.gameChoosePick, style: TypographyTokens.titleLarge()),
                const SizedBox(height: SpacingTokens.spacing3),
                ...history.map((prediction) {
                  final selectedCard = prediction.id == selectedPrediction.id;
                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: SpacingTokens.spacing3,
                    ),
                    child: AfriPressFeedback(
                      key: ValueKey<String>(
                        'share-card-prediction-${prediction.id}',
                      ),
                      onTap: () => onSelected(prediction),
                      selected: selectedCard,
                      semanticsLabel: l10n.gameSharePredictionSemantics(
                        prediction.homeTeamShort,
                        prediction.awayTeamShort,
                        prediction.marketName,
                        prediction.selectedOutcome,
                      ),
                      semanticsHint: selectedCard
                          ? l10n.gameCurrentlySelectedShareCard
                          : l10n.gameSelectThisShareCard,
                      builder: (context, pressState) => GlassCard(
                        animate: false,
                        borderColor: pressState.isFocused
                            ? context.afriSemanticColors.accent
                            : null,
                        child: largeText
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _PredictionLabel(prediction: prediction),
                                  const SizedBox(
                                    height: SpacingTokens.spacing3,
                                  ),
                                  _SelectionChip(selected: selectedCard),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: _PredictionLabel(
                                      prediction: prediction,
                                    ),
                                  ),
                                  const SizedBox(width: SpacingTokens.spacing3),
                                  _SelectionChip(selected: selectedCard),
                                ],
                              ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing10),
        ],
      ),
    );
  }
}

class _PredictionLabel extends StatelessWidget {
  const _PredictionLabel({required this.prediction});

  final UserPrediction prediction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AfriFixtureTeams(
          homeTeam: prediction.homeTeam,
          awayTeam: prediction.awayTeam,
        ),
        const SizedBox(height: SpacingTokens.spacing2),
        Text(prediction.marketName, style: TypographyTokens.bodySmall()),
        const SizedBox(height: SpacingTokens.spacing1),
        PredictionSelection(
          selection: prediction.selectedOutcome,
          homeTeam: prediction.homeTeam,
          awayTeam: prediction.awayTeam,
          style: TypographyTokens.bodySmall(),
        ),
      ],
    );
  }
}

class _SelectionChip extends StatelessWidget {
  const _SelectionChip({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final accent = context.afriSemanticColors.accent;
    final accessibleAccent = ColorTokens.accessibleMetricColor(accent);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing2,
        vertical: SpacingTokens.spacing1,
      ),
      decoration: BoxDecoration(
        color: selected
            ? accent.withValues(alpha: 0.16)
            : ColorTokens.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
      ),
      child: Text(
        selected ? l10n.gameSelected : l10n.gameOpen,
        style: TypographyTokens.labelSmall(
          selected ? accessibleAccent : ColorTokens.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ShareCardConsequence extends StatelessWidget {
  const _ShareCardConsequence({
    super.key,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SpacingTokens.spacing6),
          child: AfriStateView.error(
            title: title,
            message: body,
            actionLabel: actionLabel,
            onAction: onAction,
          ),
        ),
      ),
    );
  }
}
