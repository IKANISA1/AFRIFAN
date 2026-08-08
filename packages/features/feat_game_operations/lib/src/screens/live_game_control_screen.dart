import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/game_operations_controllers.dart';
import '../game_operations_providers.dart';
import '../models/game_operations_models.dart';
import '../widgets/game_operations_ui.dart';

class LiveGameControlScreen extends ConsumerWidget {
  const LiveGameControlScreen({
    required this.sessionId,
    this.autofocusPrimaryAction = false,
    super.key,
  });

  final String sessionId;

  @visibleForTesting
  final bool autofocusPrimaryAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(liveGameControlControllerProvider(sessionId));
    final controller = ref.read(
      liveGameControlControllerProvider(sessionId).notifier,
    );
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: gameOperationsAppBar(
        context,
        context.afriL10n.gameLiveControlTitle,
        fallbackPath: '/game-operations/sessions',
        titleRevision:
            '${state.status.name}-${state.failure?.kind.name ?? 'none'}-'
            '${state.mutating}-${state.refreshRequired}',
      ),
      scrollable: false,
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.screenPadding),
        child: _body(context, state, controller),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    LiveGameControlState state,
    LiveGameControlController controller,
  ) {
    if (state.status == GameOperationsLoadStatus.loading &&
        state.session == null) {
      return AfriStateView.loading(
        title: context.afriL10n.gameSyncing,
        message: context.afriL10n.gameManagedGamesSubtitle,
      );
    }
    if (state.session == null) {
      return gameOperationsFailureView(
        context,
        state.failure,
        controller.load,
        offlineDescription:
            context.afriL10n.gameOrganizerOperationsOfflineDescription,
      );
    }
    final session = state.session!;
    return AfriRefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        key: const ValueKey<String>('live-game-control'),
        children: [
          if (state.status == GameOperationsLoadStatus.loading) ...[
            AfriInlineValidation(
              key: const ValueKey<String>('control-syncing-warning'),
              message: context.afriL10n.gameManagedGamesRefreshing,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          Text(
            session.title,
            style: TypographyTokens.headlineSmall(
              context.afriSemanticColors.primaryText,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          AfriStatusChip(
            label: localizedGamePhase(context.afriL10n, session.phase),
          ),
          const SizedBox(height: SpacingTokens.spacing5),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth =
                  (constraints.maxWidth - SpacingTokens.spacing3) / 2;
              return Wrap(
                spacing: SpacingTokens.spacing3,
                runSpacing: SpacingTokens.spacing3,
                children: [
                  SizedBox(
                    width: tileWidth,
                    child: AfriMetricTile(
                      label: context.afriL10n.gameParticipantCount,
                      value: '${session.participantCount}',
                      icon: AfriIcons.users,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: AfriMetricTile(
                      label: context.afriL10n.gameDisplayCount,
                      value: '${session.assignedDisplays.length}',
                      icon: AfriIcons.live,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: AfriMetricTile(
                      label: context.afriL10n.gameEventSequence,
                      value: '${session.eventSequence}',
                      icon: AfriIcons.refresh,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: SpacingTokens.spacing5),
          AfriSectionHeader(title: context.afriL10n.gameCurrentQuestionControl),
          const SizedBox(height: SpacingTokens.spacing3),
          _QuestionCard(question: session.currentQuestion),
          const SizedBox(height: SpacingTokens.spacing5),
          AfriSectionHeader(title: context.afriL10n.gameControlActions),
          const SizedBox(height: SpacingTokens.spacing3),
          if (_normalAction(session) == null &&
              _exceptionActions(session).isEmpty)
            Text(
              context.afriL10n.gameNoControlActions,
              style: TypographyTokens.bodyMedium(
                context.afriSemanticColors.secondaryText,
              ),
            )
          else ...[
            if (_normalAction(session) case final action?) ...[
              Text(
                context.afriL10n.gameNextAction,
                style: TypographyTokens.labelLarge(
                  context.afriSemanticColors.secondaryText,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              AfriButton(
                key: ValueKey<String>('control-next-${action.id}'),
                label: _actionLabel(context, action),
                isLoading: state.mutating,
                enabled: state.canOperate,
                autofocus: autofocusPrimaryAction,
                onTap: () => controller.transition(action.transitionPhase!),
              ),
            ],
            if (_exceptionActions(session).isNotEmpty) ...[
              const SizedBox(height: SpacingTokens.spacing4),
              Text(
                context.afriL10n.gameExceptionActions,
                style: TypographyTokens.labelLarge(
                  context.afriSemanticColors.secondaryText,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Wrap(
                spacing: SpacingTokens.spacing3,
                runSpacing: SpacingTokens.spacing3,
                children: _exceptionActions(session)
                    .map(
                      (action) => AfriButton(
                        key: ValueKey<String>('control-exception-${action.id}'),
                        label: _actionLabel(context, action),
                        fullWidth: false,
                        variant: action.isDestructive
                            ? AfriButtonVariant.destructive
                            : AfriButtonVariant.outline,
                        isLoading: state.mutating,
                        enabled: state.canOperate,
                        onTap: () =>
                            _runException(context, controller, session, action),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
          if (state.failure != null) ...[
            const SizedBox(height: SpacingTokens.spacing4),
            AfriInlineValidation(
              key: const ValueKey<String>('control-failure-warning'),
              tone: AfriInlineValidationTone.error,
              message: gameOperationsFailureDescription(
                context.afriL10n,
                state.failure!,
                offlineDescription:
                    context.afriL10n.gameOrganizerOperationsOfflineDescription,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            AfriButton(
              key: const ValueKey<String>('control-refresh-after-failure'),
              label: context.afriL10n.gameRefresh,
              icon: AfriIcons.refresh,
              variant: AfriButtonVariant.outline,
              onTap: controller.load,
            ),
          ],
        ],
      ),
    );
  }

  _ControlAction? _normalAction(ManagedGameSession session) {
    final expected = switch (session.phase) {
      'draft' => 'validated',
      'validated' => 'published',
      'published' => 'scheduled',
      'scheduled' => 'activated_lobby',
      'activated_lobby' => 'question_open',
      'question_open' => 'reveal',
      'reveal' => session.nextQuestion == null ? 'completed' : 'question_open',
      _ => null,
    };
    if (expected == null || !session.allowedActions.contains(expected)) {
      return null;
    }
    return _ControlAction.normal(expected);
  }

  List<_ControlAction> _exceptionActions(ManagedGameSession session) {
    final actions = <_ControlAction>[];
    for (final allowed in session.allowedActions) {
      if (allowed == _normalAction(session)?.id) continue;
      if (allowed == 'skip_question' && session.nextQuestion != null) {
        actions.add(const _ControlAction.reasoned('skip_question'));
      } else if (allowed == 'end_early' ||
          (allowed == 'completed' && session.phase == 'paused') ||
          (allowed == 'completed' &&
              session.phase == 'reveal' &&
              session.nextQuestion != null)) {
        actions.add(const _ControlAction.reasoned('end_early'));
      } else if (allowed == 'paused') {
        actions.add(const _ControlAction.confirmed('paused'));
      } else if (allowed == 'cancelled') {
        actions.add(const _ControlAction.confirmed('cancelled'));
      } else if (session.phase == 'paused' &&
          allowed != 'completed' &&
          allowed != 'cancelled') {
        actions.add(_ControlAction.resume(allowed));
      }
    }
    return List<_ControlAction>.unmodifiable(actions);
  }

  String _actionLabel(BuildContext context, _ControlAction action) {
    final l10n = context.afriL10n;
    return switch (action.id) {
      'validated' => l10n.gameValidateSessionAction,
      'published' => l10n.gamePublishSessionAction,
      'scheduled' => l10n.gameScheduleSessionAction,
      'activated_lobby' => l10n.gameOpenLobbyAction,
      'question_open' => l10n.gameOpenQuestionAction,
      'reveal' => l10n.gameRevealAnswerAction,
      'completed' => l10n.gameCompleteSessionAction,
      'paused' => l10n.gamePauseAction,
      'resume' => l10n.gameResumeAction,
      'skip_question' => l10n.gameSkipQuestionAction,
      'end_early' => l10n.gameEndEarlyAction,
      'cancelled' => l10n.gameCancelSessionAction,
      _ => localizedGamePhase(l10n, action.id),
    };
  }

  Future<void> _runException(
    BuildContext context,
    LiveGameControlController controller,
    ManagedGameSession session,
    _ControlAction action,
  ) async {
    if (action.requiresReason) {
      final reason = await _requestReason(context);
      if (reason == null || !context.mounted) return;
      if (action.id == 'skip_question') {
        final nextQuestion = session.nextQuestion;
        if (nextQuestion == null) return;
        await controller.skipQuestion(
          nextSessionQuestionId: nextQuestion.id,
          reason: reason,
        );
      } else {
        await controller.endEarly(reason: reason);
      }
      return;
    }
    final confirmed = await _confirmException(context);
    if (!confirmed || !context.mounted) return;
    await controller.transition(action.transitionPhase!);
  }

  Future<bool> _confirmException(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AfriAlertDialog(
        title: Text(context.afriL10n.gameExceptionConfirmTitle),
        content: Text(context.afriL10n.gameExceptionConfirmDescription),
        actions: [
          AfriButton(
            label: context.afriL10n.gameCancel,
            fullWidth: false,
            variant: AfriButtonVariant.ghost,
            onTap: () => Navigator.of(dialogContext).pop(false),
          ),
          AfriButton(
            key: const ValueKey<String>('control-exception-confirm'),
            label: context.afriL10n.gameConfirmAction,
            fullWidth: false,
            variant: AfriButtonVariant.destructive,
            onTap: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<String?> _requestReason(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (_) => const _ReasonExceptionDialog(),
    );
  }
}

class _ReasonExceptionDialog extends StatefulWidget {
  const _ReasonExceptionDialog();

  @override
  State<_ReasonExceptionDialog> createState() => _ReasonExceptionDialogState();
}

class _ReasonExceptionDialogState extends State<_ReasonExceptionDialog> {
  final _reasonController = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AfriAlertDialog(
      scrollable: true,
      title: Text(context.afriL10n.gameExceptionConfirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.afriL10n.gameExceptionConfirmDescription),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriInputField(
            key: const ValueKey<String>('control-exception-reason'),
            controller: _reasonController,
            label: context.afriL10n.gameExceptionReason,
            hint: context.afriL10n.gameExceptionReasonHint,
            minLines: 2,
            maxLines: 3,
            maxLength: 234,
            textCapitalization: TextCapitalization.sentences,
            errorText: _showError
                ? context.afriL10n.gameExceptionReasonInvalid
                : null,
          ),
        ],
      ),
      actions: [
        AfriButton(
          label: context.afriL10n.gameCancel,
          fullWidth: false,
          variant: AfriButtonVariant.ghost,
          onTap: () => Navigator.of(context).pop(),
        ),
        AfriButton(
          key: const ValueKey<String>('control-exception-confirm'),
          label: context.afriL10n.gameConfirmAction,
          fullWidth: false,
          variant: AfriButtonVariant.destructive,
          onTap: () {
            final reason = _reasonController.text.trim();
            if (reason.length < 3 || reason.length > 234) {
              setState(() => _showError = true);
              return;
            }
            Navigator.of(context).pop(reason);
          },
        ),
      ],
    );
  }
}

class _ControlAction {
  const _ControlAction._({
    required this.id,
    required this.transitionPhase,
    required this.requiresReason,
    required this.isDestructive,
  });

  const _ControlAction.normal(String phase)
    : this._(
        id: phase,
        transitionPhase: phase,
        requiresReason: false,
        isDestructive: false,
      );

  const _ControlAction.confirmed(String phase)
    : this._(
        id: phase,
        transitionPhase: phase,
        requiresReason: false,
        isDestructive: phase == 'cancelled',
      );

  const _ControlAction.reasoned(String action)
    : this._(
        id: action,
        transitionPhase: null,
        requiresReason: true,
        isDestructive: true,
      );

  const _ControlAction.resume(String phase)
    : this._(
        id: 'resume',
        transitionPhase: phase,
        requiresReason: false,
        isDestructive: false,
      );

  final String id;
  final String? transitionPhase;
  final bool requiresReason;
  final bool isDestructive;
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question});

  final ManagedQuestionControl? question;

  @override
  Widget build(BuildContext context) {
    if (question == null) {
      return AfriSurfaceCard(
        child: Text(
          context.afriL10n.gameNoCurrentQuestion,
          style: TypographyTokens.bodyMedium(
            context.afriSemanticColors.secondaryText,
          ),
        ),
      );
    }
    return AfriSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AfriStatusChip(label: '${question!.ordinal}'),
          const SizedBox(height: SpacingTokens.spacing3),
          Text(
            question!.prompt,
            style: TypographyTokens.titleMedium(
              context.afriSemanticColors.primaryText,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          ...question!.options.map((option) {
            final label = option['label']?.toString().trim();
            return Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
              child: Text(
                label == null || label.isEmpty
                    ? context.afriL10n.gameOperationsUnavailable
                    : label,
                style: TypographyTokens.bodyMedium(
                  context.afriSemanticColors.secondaryText,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
