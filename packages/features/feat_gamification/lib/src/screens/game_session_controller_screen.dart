import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  final Map<String, String> _submittedAnswersByQuestionId = {};
  String? _sessionPlayerId;
  bool _joining = false;
  String? _submittingOptionKey;

  GameSessionControllerArgs get _providerArgs => GameSessionControllerArgs(
    sessionId: widget.sessionId,
    sessionPlayerId: _sessionPlayerId,
  );

  @override
  void initState() {
    super.initState();
    _sessionPlayerId = widget.sessionPlayerId;
    _displayNameController = TextEditingController(text: 'Supporter');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(
      gameSessionControllerStateProvider(_providerArgs),
    );
    final loadedState =
        asyncState.valueOrNull ??
        GameSessionControllerState.demo(
          widget.sessionId,
          asyncState.hasError
              ? GameSessionControllerPhase.reconnecting
              : widget.phase,
          sessionPlayerId: _sessionPlayerId,
        );
    final state = _withLocalSubmittedAnswerLock(loadedState);
    final hasJoined = _sessionPlayerId != null && _sessionPlayerId!.isNotEmpty;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        title: Text(
          'Game Controller',
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
      body: SafeArea(
        child: AfriRefreshIndicator(
          onRefresh: () => ref.refresh(
            gameSessionControllerStateProvider(_providerArgs).future,
          ),
          child: ListView(
            padding: const EdgeInsets.all(SpacingTokens.screenPadding),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (asyncState.isLoading)
                const _InlineStateBanner(
                  message: 'Refreshing latest server state.',
                )
              else if (asyncState.hasError)
                _InlineStateBanner(
                  message:
                      'Could not reach the live session. Showing the last safe controller layout.',
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(
                    gameSessionControllerStateProvider(_providerArgs),
                  ),
                ),
              if (asyncState.isLoading || asyncState.hasError)
                const SizedBox(height: SpacingTokens.spacing4),
              _SessionStatusCard(state: state),
              const SizedBox(height: SpacingTokens.sectionGap),
              _QuestionCard(state: state),
              const SizedBox(height: SpacingTokens.sectionGap),
              if (!hasJoined) ...[
                _JoinSessionCard(
                  controller: _displayNameController,
                  joining: _joining,
                  onJoin: _joinSession,
                ),
                const SizedBox(height: SpacingTokens.sectionGap),
              ],
              _AnswerPad(
                state: state,
                submittingOptionKey: _submittingOptionKey,
                onAnswerSelected: _submitAnswer,
              ),
              const SizedBox(height: SpacingTokens.sectionGap),
              _LeaderboardCard(state: state),
              const SizedBox(height: SpacingTokens.spacing10),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _joinSession() async {
    if (_joining) {
      return;
    }

    setState(() {
      _joining = true;
    });

    try {
      final repository = ref.read(gameSessionRepositoryProvider);
      final result = await repository.joinSession(
        sessionId: widget.sessionId,
        displayName: _displayNameController.text,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _sessionPlayerId = result.sessionPlayerId;
      });
      ref.invalidate(gameSessionControllerStateProvider(_providerArgs));
      await ref.read(gameSessionControllerStateProvider(_providerArgs).future);
      if (!mounted) {
        return;
      }
      AfriToast.success(context, 'Joined as ${result.displayName}.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      AfriToast.error(context, 'Could not join. Check the link and try again.');
    } finally {
      if (mounted) {
        setState(() {
          _joining = false;
        });
      }
    }
  }

  Future<void> _submitAnswer(
    GameSessionControllerState state,
    GameAnswerOption option,
  ) async {
    if (!state.canSubmitAnswer || _submittingOptionKey != null) {
      AfriToast.info(
        context,
        'Waiting for live session membership confirmation.',
      );
      return;
    }

    setState(() {
      _submittingOptionKey = option.key;
    });

    try {
      final repository = ref.read(gameSessionRepositoryProvider);
      await repository.submitAnswer(
        sessionQuestionId: state.sessionQuestionId!,
        sessionPlayerId: state.sessionPlayerId!,
        selectedOptionKey: option.key,
        idempotencyKey: _buildAnswerIdempotencyKey(state, option),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _submittedAnswersByQuestionId[state.sessionQuestionId!] = option.key;
      });
      ref.invalidate(gameSessionControllerStateProvider(_providerArgs));
      await ref.read(gameSessionControllerStateProvider(_providerArgs).future);
      if (!mounted) {
        return;
      }
      AfriToast.success(context, 'Answer sent for server confirmation.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      AfriToast.error(
        context,
        'Could not submit. Check connection and try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _submittingOptionKey = null;
        });
      }
    }
  }

  GameSessionControllerState _withLocalSubmittedAnswerLock(
    GameSessionControllerState state,
  ) {
    final questionId = state.sessionQuestionId;
    if (questionId == null || questionId.isEmpty) {
      return state;
    }

    final submittedOptionKey = _submittedAnswersByQuestionId[questionId];
    if (submittedOptionKey == null ||
        state.phase != GameSessionControllerPhase.answering) {
      return state;
    }

    return state.copyWith(
      phase: GameSessionControllerPhase.locked,
      selectedOptionKey: submittedOptionKey,
      statusMessage:
          'Answer submitted. Waiting for server claim or host reveal.',
    );
  }
}

String _buildAnswerIdempotencyKey(
  GameSessionControllerState state,
  GameAnswerOption option,
) {
  return [
    'answer',
    state.sessionId,
    state.sessionQuestionId,
    state.sessionPlayerId,
    option.key,
  ].join(':');
}

class _SessionStatusCard extends StatelessWidget {
  const _SessionStatusCard({required this.state});

  final GameSessionControllerState state;

  @override
  Widget build(BuildContext context) {
    return AfriSurfaceCard(
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
              ColorTokens.clubAccent,
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
              AfriInfoChip(label: state.phase.name, icon: AfriIcons.live),
            ],
          ),
        ],
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
            style: TypographyTokens.labelSmall(ColorTokens.clubAccent),
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
    required this.submittingOptionKey,
    required this.onAnswerSelected,
  });

  final GameSessionControllerState state;
  final String? submittingOptionKey;
  final void Function(GameSessionControllerState state, GameAnswerOption option)
  onAnswerSelected;

  bool get _isEnabled =>
      state.phase == GameSessionControllerPhase.answering &&
      submittingOptionKey == null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AfriSectionHeader(title: 'Answer pad'),
        const SizedBox(height: SpacingTokens.spacing4),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: SpacingTokens.spacing3,
          crossAxisSpacing: SpacingTokens.spacing3,
          childAspectRatio: 1.9,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          children: state.options
              .map(
                (option) => _AnswerButton(
                  option: option,
                  selected: option.key == state.selectedOptionKey,
                  enabled: _isEnabled,
                  submitting: option.key == submittingOptionKey,
                  onTap: () => onAnswerSelected(state, option),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        Text(
          _isEnabled
              ? 'Submissions must include an idempotency key and wait for server confirmation.'
              : 'Local state never decides the winner; it only displays server state.',
          style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _JoinSessionCard extends StatelessWidget {
  const _JoinSessionCard({
    required this.controller,
    required this.joining,
    required this.onJoin,
  });

  final TextEditingController controller;
  final bool joining;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return AfriSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'JOIN THIS SESSION',
            style: TypographyTokens.labelSmall(ColorTokens.clubAccent),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Text(
            'Confirm your display name before answering from this device.',
            style: TypographyTokens.bodyMedium(),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriInputField(
            controller: controller,
            enabled: !joining,
            maxLength: 48,
            label: 'Display name',
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => joining ? null : onJoin(),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriButton(
            label: 'Join session',
            icon: AfriIcons.live,
            isLoading: joining,
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
      onTap: enabled ? onTap : null,
      selected: selected,
      semanticsLabel: 'Answer ${option.label}',
      semanticsHint: enabled ? 'Submit answer' : 'Answer locked',
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? ColorTokens.clubAccent.withValues(alpha: 0.18)
              : ColorTokens.surfaceContainerLow,
          borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
          border: selected
              ? BorderTokens.all(color: ColorTokens.clubAccent)
              : BorderTokens.ghost(),
        ),
        child: submitting
            ? const SizedBox.square(
                dimension: SpacingTokens.spacing5,
                child: AfriLoadingIndicator(size: SpacingTokens.spacing5),
              )
            : Text(
                option.label,
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
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AfriSurfaceCard(
      child: Row(
        children: [
          const Icon(AfriIcons.live, size: SpacingTokens.spacing5),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Text(
              message,
              style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: SpacingTokens.spacing3),
            AfriTextButton(onPressed: onAction, child: Text(actionLabel!)),
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
      child: Column(
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
                      backgroundColor: ColorTokens.clubAccent.withValues(
                        alpha: 0.16,
                      ),
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
                        ColorTokens.clubAccent,
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
