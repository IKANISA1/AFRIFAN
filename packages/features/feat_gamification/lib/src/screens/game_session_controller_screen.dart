import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/game_session_controller.dart';
import '../game_session_providers.dart';
import '../models/game_session_models.dart';

class GameSessionControllerScreen extends ConsumerStatefulWidget {
  const GameSessionControllerScreen({
    super.key,
    required this.sessionId,
    this.sessionPlayerId,
    this.phase = GameSessionControllerPhase.answering,
  });

  final String sessionId;
  final String? sessionPlayerId;
  final GameSessionControllerPhase phase;

  @override
  ConsumerState<GameSessionControllerScreen> createState() =>
      _GameSessionControllerScreenState();
}

class _GameSessionControllerScreenState
    extends ConsumerState<GameSessionControllerScreen> {
  late final TextEditingController _displayNameController;
  late final FocusNode _displayNameFocusNode;
  late bool _wasOnline;

  GameSessionControllerArgs get _providerArgs => GameSessionControllerArgs(
    sessionId: widget.sessionId,
    sessionPlayerId: widget.sessionPlayerId,
  );

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: 'Supporter');
    _displayNameFocusNode = FocusNode(debugLabel: 'game-display-name');
    _wasOnline = ConnectivityService.isOnline;
    ConnectivityService.onlineNotifier.addListener(_handleConnectivityChange);
  }

  @override
  void dispose() {
    ConnectivityService.onlineNotifier.removeListener(
      _handleConnectivityChange,
    );
    _displayNameController.dispose();
    _displayNameFocusNode.dispose();
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
        ref
            .read(gameSessionControllerStateProvider(_providerArgs).notifier)
            .connectionRestored(),
      );
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/fanzone');
    }
  }

  Future<void> _join() async {
    FocusScope.of(context).unfocus();
    await ref
        .read(gameSessionControllerStateProvider(_providerArgs).notifier)
        .join(_displayNameController.text);
  }

  Future<void> _submitAnswer(GameAnswerOption option) async {
    await ref
        .read(gameSessionControllerStateProvider(_providerArgs).notifier)
        .submitAnswer(option);
  }

  @override
  Widget build(BuildContext context) {
    final accessEnabled = ref.watch(gameSessionControllerAccessEnabledProvider);
    final asyncState = ref.watch(
      gameSessionControllerStateProvider(_providerArgs),
    );

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        title: Text(
          'Game Controller',
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: AfriIconButton(
          key: const ValueKey<String>('game-controller-back'),
          icon: AfriIcons.back,
          onTap: _close,
          tooltip: 'Back',
        ),
      ),
      scrollable: false,
      constrainContent: true,
      child: !accessEnabled
          ? _ControllerConsequence(
              title: 'Game controller unavailable',
              body: 'Live game control is not enabled for this build or club.',
              actionLabel: 'BACK TO FAN ZONE',
              onAction: _close,
            )
          : asyncState.when(
              loading: () {
                final previous = asyncState.valueOrNull;
                if (previous?.content != null) {
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
                if (state.content == null) {
                  return _ControllerConsequence(
                    title: 'Live session not found',
                    body: 'This game link is unavailable or no longer active.',
                    actionLabel: 'BACK TO FAN ZONE',
                    onAction: _close,
                  );
                }
                if (state.failure?.kind ==
                    GameSessionFailureKind.permissionDenied) {
                  return _ControllerConsequence(
                    title: 'Live session access denied',
                    body:
                        'This account cannot open the requested game controller.',
                    actionLabel: 'BACK TO FAN ZONE',
                    onAction: _close,
                  );
                }
                return _buildContent(state);
              },
            ),
    );
  }

  Widget _buildInitialFailure(Object error) {
    final failure = GameSessionFailure.fromError(error);
    return switch (failure.kind) {
      GameSessionFailureKind.offline => _ControllerConsequence(
        title: 'Controller offline',
        body:
            'Reconnect to load the live session. Answers are never queued offline.',
        actionLabel: 'BACK TO FAN ZONE',
        onAction: _close,
      ),
      GameSessionFailureKind.permissionDenied => _ControllerConsequence(
        title: 'Live session access denied',
        body: 'This account cannot open the requested game controller.',
        actionLabel: 'BACK TO FAN ZONE',
        onAction: _close,
      ),
      GameSessionFailureKind.securityTimeout => _ControllerConsequence(
        title: 'Session check timed out',
        body:
            'The controller could not confirm a safe live state. Try one bounded refresh.',
        actionLabel: 'TRY AGAIN',
        onAction: () => ref
            .read(gameSessionControllerStateProvider(_providerArgs).notifier)
            .refresh(),
      ),
      _ => _ControllerConsequence(
        title: 'Controller unavailable',
        body:
            'The live session could not be loaded. No private session details were shown.',
        actionLabel: 'TRY AGAIN',
        onAction: () => ref
            .read(gameSessionControllerStateProvider(_providerArgs).notifier)
            .refresh(),
      ),
    };
  }

  Widget _buildContent(GameSessionRouteState routeState) {
    final state = routeState.content!;
    final online = ConnectivityService.isOnline;
    final joined =
        state.sessionPlayerId != null && state.sessionPlayerId!.isNotEmpty;
    final blocked = routeState.actionsBlocked || !online;
    final status = _statusFor(routeState, online: online);

    return SafeArea(
      child: AfriRefreshIndicator(
        onRefresh: () => ref
            .read(gameSessionControllerStateProvider(_providerArgs).notifier)
            .refresh(),
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(SpacingTokens.screenPadding),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (status != null) ...[
              status,
              const SizedBox(height: SpacingTokens.spacing4),
            ],
            _SessionStatusCard(state: state),
            const SizedBox(height: SpacingTokens.sectionGap),
            _QuestionCard(state: state),
            const SizedBox(height: SpacingTokens.sectionGap),
            if (!joined) ...[
              _JoinSessionCard(
                controller: _displayNameController,
                focusNode: _displayNameFocusNode,
                enabled: !blocked,
                joining: routeState.mutation == GameSessionMutation.joining,
                errorText: routeState.validationMessage,
                onChanged: (_) => ref
                    .read(
                      gameSessionControllerStateProvider(
                        _providerArgs,
                      ).notifier,
                    )
                    .clearInputFeedback(),
                onJoin: _join,
              ),
              const SizedBox(height: SpacingTokens.sectionGap),
            ],
            _AnswerPad(
              state: state,
              enabled: !blocked && joined,
              submitting:
                  routeState.mutation == GameSessionMutation.submittingAnswer,
              onAnswerSelected: _submitAnswer,
            ),
            const SizedBox(height: SpacingTokens.sectionGap),
            _LeaderboardCard(state: state),
            const SizedBox(height: SpacingTokens.spacing10),
          ],
        ),
      ),
    );
  }

  Widget? _statusFor(GameSessionRouteState state, {required bool online}) {
    if (!online || state.failure?.kind == GameSessionFailureKind.offline) {
      return const _InlineStateBanner(
        title: 'Controller offline',
        message:
            'Last confirmed state is shown. Answers and joins stay blocked and are never queued.',
      );
    }
    if (state.phase == GameSessionRoutePhase.syncing) {
      return _InlineStateBanner(
        title: state.mutation == GameSessionMutation.joining
            ? 'Confirming membership'
            : 'Confirming answer',
        message:
            'Waiting for the live server. Do not close or repeat this action.',
        loading: true,
      );
    }
    return switch (state.failure?.kind) {
      GameSessionFailureKind.conflict => _InlineStateBanner(
        title: 'Live state changed',
        message:
            'Refresh the controller before joining or choosing another answer.',
        actionLabel: 'REFRESH',
        onAction: () => ref
            .read(gameSessionControllerStateProvider(_providerArgs).notifier)
            .refresh(),
      ),
      GameSessionFailureKind.securityTimeout => _InlineStateBanner(
        title: 'Confirmation uncertain',
        message:
            'The server did not confirm the last action. It remains blocked until an authoritative refresh resolves it.',
        actionLabel: 'REFRESH',
        onAction: () => ref
            .read(gameSessionControllerStateProvider(_providerArgs).notifier)
            .refresh(),
      ),
      GameSessionFailureKind.unknown => _InlineStateBanner(
        title: 'Live update unavailable',
        message:
            'The last confirmed state is preserved. Refresh before continuing.',
        actionLabel: 'REFRESH',
        onAction: () => ref
            .read(gameSessionControllerStateProvider(_providerArgs).notifier)
            .refresh(),
      ),
      _ when state.phase == GameSessionRoutePhase.degraded =>
        _InlineStateBanner(
          title: 'Using last confirmed state',
          message: 'Live controls stay blocked until the session is refreshed.',
          actionLabel: 'REFRESH',
          onAction: () => ref
              .read(gameSessionControllerStateProvider(_providerArgs).notifier)
              .refresh(),
        ),
      _ => null,
    };
  }
}

class _SessionStatusCard extends StatelessWidget {
  const _SessionStatusCard({required this.state});

  final GameSessionControllerState state;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: true,
      label: 'Current live session ${state.joinCode}',
      child: AfriSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LIVE SESSION',
              style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              state.joinCode,
              style: TypographyTokens.displaySmall(
                context.afriSemanticColors.accent,
              ).copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            Text(state.statusMessage, style: TypographyTokens.bodyMedium()),
            const SizedBox(height: SpacingTokens.spacing4),
            Wrap(
              spacing: SpacingTokens.spacing2,
              runSpacing: SpacingTokens.spacing2,
              children: [
                AfriInfoChip(label: state.playerName, icon: AfriIcons.profile),
                AfriInfoChip(label: state.teamName, icon: AfriIcons.clubZone),
                AfriInfoChip(
                  label: _phaseLabel(state.phase),
                  icon: AfriIcons.live,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.state});

  final GameSessionControllerState state;

  @override
  Widget build(BuildContext context) {
    return AfriSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.questionLabel.toUpperCase(),
            style: TypographyTokens.labelSmall(
              context.afriSemanticColors.accent,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Text(
            state.prompt,
            style: TypographyTokens.titleLarge().copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerPad extends StatelessWidget {
  const _AnswerPad({
    required this.state,
    required this.enabled,
    required this.submitting,
    required this.onAnswerSelected,
  });

  final GameSessionControllerState state;
  final bool enabled;
  final bool submitting;
  final ValueChanged<GameAnswerOption> onAnswerSelected;

  bool get _canAnswer =>
      enabled &&
      state.phase == GameSessionControllerPhase.answering &&
      state.canSubmitAnswer &&
      !submitting;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final useSingleColumn = textScaler.scale(16) >= 25;
    final options = state.options;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AfriSectionHeader(title: 'Answer pad'),
        const SizedBox(height: SpacingTokens.spacing4),
        if (options.isEmpty)
          const AfriSurfaceCard(
            child: Text(
              'Waiting for the host to publish answer choices on the TV.',
            ),
          )
        else if (useSingleColumn)
          ...options.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
              child: SizedBox(
                height: 64,
                child: _AnswerButton(
                  option: option,
                  selected: option.key == state.selectedOptionKey,
                  enabled: _canAnswer,
                  submitting:
                      submitting && option.key == state.selectedOptionKey,
                  onTap: () => onAnswerSelected(option),
                ),
              ),
            ),
          )
        else
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: SpacingTokens.spacing3,
            crossAxisSpacing: SpacingTokens.spacing3,
            childAspectRatio: 1.9,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            children: options
                .map(
                  (option) => _AnswerButton(
                    option: option,
                    selected: option.key == state.selectedOptionKey,
                    enabled: _canAnswer,
                    submitting: submitting,
                    onTap: () => onAnswerSelected(option),
                  ),
                )
                .toList(growable: false),
          ),
        const SizedBox(height: SpacingTokens.spacing3),
        Text(
          _canAnswer
              ? 'Choose once. The server confirms the first accepted answer.'
              : 'Only confirmed server state can unlock another answer.',
          style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _JoinSessionCard extends StatelessWidget {
  const _JoinSessionCard({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.joining,
    required this.errorText,
    required this.onChanged,
    required this.onJoin,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool joining;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return AfriSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'JOIN THIS SESSION',
            style: TypographyTokens.labelSmall(
              context.afriSemanticColors.accent,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Text(
            'Confirm the name shown on the TV leaderboard.',
            style: TypographyTokens.bodyMedium(),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriInputField(
            key: const ValueKey<String>('game-controller-display-name'),
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            maxLength: 48,
            label: 'Display name',
            helperText: '2 to 48 characters',
            errorText: errorText,
            textInputAction: TextInputAction.done,
            onChanged: onChanged,
            onSubmitted: (_) {
              if (enabled && !joining) onJoin();
            },
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriButton(
            key: const ValueKey<String>('game-controller-join'),
            label: 'Join session',
            icon: AfriIcons.live,
            isLoading: joining,
            enabled: enabled,
            onTap: onJoin,
          ),
        ],
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.submitting,
    required this.onTap,
  });

  final GameAnswerOption option;
  final bool selected;
  final bool enabled;
  final bool submitting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      key: ValueKey<String>('game-controller-answer-${option.key}'),
      onTap: enabled ? onTap : null,
      selected: selected,
      semanticsLabel: 'Answer ${option.label}',
      semanticsHint: enabled ? 'Submit answer' : 'Answer locked',
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing3,
          vertical: SpacingTokens.spacing2,
        ),
        decoration: BoxDecoration(
          color: selected
              ? context.afriSemanticColors.accentSoft
              : ColorTokens.surfaceContainerLow,
          borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
          border: selected
              ? BorderTokens.all(color: context.afriSemanticColors.accent)
              : BorderTokens.ghost(),
        ),
        child: submitting
            ? const AfriLoadingIndicator(size: SpacingTokens.spacing5)
            : Text(
                option.label,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TypographyTokens.titleMedium().copyWith(
                  fontWeight: FontWeight.w800,
                  color: enabled || selected
                      ? ColorTokens.onSurface
                      : ColorTokens.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}

class _InlineStateBanner extends StatelessWidget {
  const _InlineStateBanner({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.loading = false,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return AfriSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (loading)
                const AfriLoadingIndicator(size: SpacingTokens.spacing5)
              else
                Icon(
                  AfriIcons.live,
                  size: SpacingTokens.spacing5,
                  color: context.afriSemanticColors.accent,
                ),
              const SizedBox(width: SpacingTokens.spacing3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TypographyTokens.titleSmall().copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing1),
                    Text(
                      message,
                      style: TypographyTokens.bodySmall(
                        ColorTokens.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: SpacingTokens.spacing3),
            AfriTextButton(
              key: const ValueKey<String>('game-controller-recovery'),
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({required this.state});

  final GameSessionControllerState state;

  @override
  Widget build(BuildContext context) {
    return AfriSectionCard(
      title: 'Team standings',
      child: state.leaderboard.isEmpty
          ? Text(
              'Standings appear after the TV host opens the round.',
              style: TypographyTokens.bodyMedium(ColorTokens.onSurfaceVariant),
            )
          : Column(
              children: state.leaderboard
                  .map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(
                        bottom: SpacingTokens.listItemGap,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: SpacingTokens.spacing4,
                            backgroundColor:
                                context.afriSemanticColors.accentSoft,
                            child: Text('${row.rank}'),
                          ),
                          const SizedBox(width: SpacingTokens.spacing3),
                          Expanded(
                            child: Text(
                              row.teamName,
                              style: TypographyTokens.titleSmall(),
                            ),
                          ),
                          Text(
                            '${row.score}',
                            style: TypographyTokens.titleMedium(
                              context.afriSemanticColors.accent,
                            ).copyWith(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _ControllerConsequence extends StatelessWidget {
  const _ControllerConsequence({
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
          padding: const EdgeInsets.all(SpacingTokens.screenPadding),
          child: AfriSurfaceCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.afriSemanticColors.accentSoft,
                    borderRadius: ShapeTokens.buttonRadius,
                  ),
                  child: Icon(
                    AfriIcons.live,
                    color: context.afriSemanticColors.accent,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TypographyTokens.titleLarge().copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: TypographyTokens.bodyMedium(
                    ColorTokens.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing5),
                AfriButton(label: actionLabel, onTap: onAction),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _phaseLabel(GameSessionControllerPhase phase) {
  return switch (phase) {
    GameSessionControllerPhase.join => 'Join',
    GameSessionControllerPhase.waiting => 'Waiting',
    GameSessionControllerPhase.answering => 'Answering',
    GameSessionControllerPhase.locked => 'Locked',
    GameSessionControllerPhase.reveal => 'Reveal',
    GameSessionControllerPhase.leaderboard => 'Standings',
    GameSessionControllerPhase.reconnecting => 'Reconnecting',
  };
}
