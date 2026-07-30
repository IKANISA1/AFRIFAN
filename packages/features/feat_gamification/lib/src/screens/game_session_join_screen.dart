import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/game_session_join_controller.dart';

class GameSessionJoinScreen extends ConsumerStatefulWidget {
  const GameSessionJoinScreen({super.key});

  @override
  ConsumerState<GameSessionJoinScreen> createState() =>
      _GameSessionJoinScreenState();
}

class _GameSessionJoinScreenState extends ConsumerState<GameSessionJoinScreen> {
  late final TextEditingController _codeController;
  late final TextEditingController _displayNameController;
  late final FocusNode _codeFocusNode;
  late final FocusNode _displayNameFocusNode;
  late bool _wasOnline;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
    _displayNameController = TextEditingController(text: 'Supporter');
    _codeFocusNode = FocusNode(debugLabel: 'game-session-code');
    _displayNameFocusNode = FocusNode(debugLabel: 'game-display-name');
    _wasOnline = ConnectivityService.isOnline;
    ConnectivityService.onlineNotifier.addListener(_handleConnectivityChange);
  }

  @override
  void dispose() {
    ConnectivityService.onlineNotifier.removeListener(
      _handleConnectivityChange,
    );
    _codeController.dispose();
    _displayNameController.dispose();
    _codeFocusNode.dispose();
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
      ref.read(gameSessionJoinProvider.notifier).connectionRestored();
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/fanzone');
    }
  }

  void _clearFeedback(String _) {
    ref.read(gameSessionJoinProvider.notifier).clearInputFeedback();
  }

  Future<void> _joinByCode() async {
    FocusScope.of(context).unfocus();
    final outcome = await ref
        .read(gameSessionJoinProvider.notifier)
        .join(
          joinCode: _codeController.text,
          displayName: _displayNameController.text,
        );
    if (!mounted || !outcome.isSuccess || outcome.result == null) return;
    final result = outcome.result!;
    context.go(
      '/fanzone/game/${result.sessionId}'
      '?session_player_id=${Uri.encodeQueryComponent(result.sessionPlayerId)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final accessEnabled = ref.watch(gameSessionJoinAccessEnabledProvider);
    final joinAsync = ref.watch(gameSessionJoinProvider);

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        title: Text(
          'Join Live Game',
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: AfriIconButton(
          key: const ValueKey<String>('game-session-join-back'),
          icon: AfriIcons.back,
          onTap: _close,
          tooltip: 'Back',
        ),
      ),
      scrollable: false,
      constrainContent: true,
      child: !accessEnabled
          ? _JoinConsequence(
              title: 'Live games unavailable',
              body: 'TV game joining is not enabled for this build or club.',
              actionLabel: 'BACK TO FAN ZONE',
              onAction: _close,
            )
          : joinAsync.when(
              loading: () => const SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(SpacingTokens.spacing6),
                  child: AfriSkeletonList(),
                ),
              ),
              error: (error, _) => _failureConsequence(error),
              data: _buildReady,
            ),
    );
  }

  Widget _buildReady(GameSessionJoinState state) {
    final online = ConnectivityService.isOnline;
    final failure = state.failure;
    if (failure?.kind == GameSessionJoinFailureKind.permissionDenied) {
      return _JoinConsequence(
        title: 'Live game access denied',
        body: 'This account cannot join the requested TV game.',
        actionLabel: 'BACK TO FAN ZONE',
        onAction: _close,
      );
    }

    final blocked = state.actionsBlocked || !online;
    final inputsEnabled =
        online &&
        state.phase != GameSessionJoinPhase.syncing &&
        failure?.kind != GameSessionJoinFailureKind.securityTimeout;
    final status = _statusFor(state, online: online);
    return SafeArea(
      child: AutofillGroup(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(SpacingTokens.screenPadding),
          children: [
            if (status != null) ...[
              status,
              const SizedBox(height: SpacingTokens.spacing4),
            ],
            AfriSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: SizeTokens.touchTargetMin,
                        height: SizeTokens.touchTargetMin,
                        decoration: BoxDecoration(
                          color: ColorTokens.clubAccent.withValues(alpha: 0.14),
                          borderRadius: ShapeTokens.buttonRadius,
                        ),
                        child: Icon(
                          AfriIcons.live,
                          color: ColorTokens.clubAccent,
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.spacing3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              selected: true,
                              label: 'Selected join method, TV code',
                              child: Text(
                                'TV CODE',
                                style: TypographyTokens.labelSmall(
                                  ColorTokens.clubAccent,
                                ),
                              ),
                            ),
                            const SizedBox(height: SpacingTokens.spacing1),
                            Text(
                              'Play from your phone',
                              style: TypographyTokens.titleLarge().copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  Text(
                    'Enter the code shown on the shared TV. Questions stay on '
                    'the TV; this phone becomes your private controller.',
                    style: TypographyTokens.bodyMedium(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing5),
                  AfriInputField(
                    key: const ValueKey<String>('game-session-code-field'),
                    controller: _codeController,
                    focusNode: _codeFocusNode,
                    enabled: inputsEnabled,
                    textCapitalization: TextCapitalization.characters,
                    label: 'Session code',
                    hint: 'Example: RAYON6',
                    helperText: 'Letters, numbers, - or _',
                    helperMaxLines: 2,
                    errorText: state.validationMessage,
                    maxLength: 32,
                    autocorrect: false,
                    enableSuggestions: false,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-Z0-9_-]'),
                      ),
                    ],
                    textInputAction: TextInputAction.next,
                    onChanged: _clearFeedback,
                    onSubmitted: (_) => _displayNameFocusNode.requestFocus(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  AfriInputField(
                    key: const ValueKey<String>('game-display-name-field'),
                    controller: _displayNameController,
                    focusNode: _displayNameFocusNode,
                    enabled: inputsEnabled,
                    maxLength: 48,
                    label: 'Display name',
                    helperText: 'Shown on the leaderboard.',
                    helperMaxLines: 2,
                    textInputAction: TextInputAction.done,
                    onChanged: _clearFeedback,
                    onSubmitted: (_) {
                      if (!blocked) unawaited(_joinByCode());
                    },
                  ),
                  const SizedBox(height: SpacingTokens.spacing5),
                  AfriButton(
                    key: const ValueKey<String>('game-session-join-action'),
                    label: state.phase == GameSessionJoinPhase.syncing
                        ? 'JOINING GAME'
                        : 'JOIN GAME',
                    icon: AfriIcons.live,
                    enabled: !blocked,
                    isLoading: state.phase == GameSessionJoinPhase.syncing,
                    onTap: _joinByCode,
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            AfriSurfaceCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    AfriIcons.statusInfo,
                    color: ColorTokens.onSurfaceVariant,
                  ),
                  const SizedBox(width: SpacingTokens.spacing3),
                  Expanded(
                    child: Text(
                      'Live connection required. Joins and answers wait for '
                      'server confirmation and are never queued offline.',
                      style: TypographyTokens.bodySmall(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _failureConsequence(Object error) {
    final failure = error is GameSessionJoinFailure
        ? error
        : GameSessionJoinFailure.fromError(error);
    return switch (failure.kind) {
      GameSessionJoinFailureKind.permissionDenied => _JoinConsequence(
        title: 'Live game access denied',
        body: 'This account cannot join the requested TV game.',
        actionLabel: 'BACK TO FAN ZONE',
        onAction: _close,
      ),
      GameSessionJoinFailureKind.securityTimeout => _JoinConsequence(
        title: 'Game security check timed out',
        body:
            'The join result could not be confirmed safely. Return to Fan Zone before trying again.',
        actionLabel: 'BACK TO FAN ZONE',
        onAction: _close,
      ),
      GameSessionJoinFailureKind.offline => _JoinConsequence(
        title: 'Live games require a connection',
        body: 'Reconnect before entering a TV session code.',
        actionLabel: 'BACK TO FAN ZONE',
        onAction: _close,
      ),
      GameSessionJoinFailureKind.conflict => _JoinConsequence(
        title: 'TV session unavailable',
        body: 'The code may have expired or the host may have closed the game.',
        actionLabel: 'BACK TO FAN ZONE',
        onAction: _close,
      ),
      GameSessionJoinFailureKind.unknown => _JoinConsequence(
        title: 'Unable to join live game',
        body:
            'The session could not be confirmed. Check the code and try once.',
        actionLabel: 'BACK TO FAN ZONE',
        onAction: _close,
      ),
    };
  }

  Widget? _statusFor(GameSessionJoinState state, {required bool online}) {
    if (!online || state.failure?.kind == GameSessionJoinFailureKind.offline) {
      return const _JoinStatus(
        title: 'Live games require a connection',
        body: 'Your code and display name stay on this device.',
      );
    }
    if (state.phase == GameSessionJoinPhase.syncing) {
      return const _JoinStatus(
        title: 'Joining TV session',
        body: 'Waiting for server confirmation. Keep this screen open.',
        tone: AfriStateBannerTone.info,
      );
    }
    final failure = state.failure;
    if (failure == null) return null;
    return switch (failure.kind) {
      GameSessionJoinFailureKind.conflict => const _JoinStatus(
        title: 'TV session unavailable',
        body: 'The code may have expired. Edit the code before trying again.',
      ),
      GameSessionJoinFailureKind.securityTimeout => const _JoinStatus(
        title: 'Join result is uncertain',
        body:
            'Do not retry this code yet. Return to Fan Zone and confirm with the host.',
        tone: AfriStateBannerTone.danger,
      ),
      GameSessionJoinFailureKind.unknown => const _JoinStatus(
        title: 'Join was not confirmed',
        body: 'Edit or re-enter the code before trying again.',
        tone: AfriStateBannerTone.danger,
      ),
      GameSessionJoinFailureKind.offline => null,
      GameSessionJoinFailureKind.permissionDenied => null,
    };
  }
}

class _JoinStatus extends StatelessWidget {
  const _JoinStatus({
    required this.title,
    required this.body,
    this.tone = AfriStateBannerTone.warning,
  });

  final String title;
  final String body;
  final AfriStateBannerTone tone;

  @override
  Widget build(BuildContext context) {
    return AfriStateBanner(
      icon: tone == AfriStateBannerTone.danger
          ? AfriIcons.statusError
          : AfriIcons.statusWarning,
      title: title,
      subtitle: body,
      tone: tone,
      compact: true,
    );
  }
}

class _JoinConsequence extends StatelessWidget {
  const _JoinConsequence({
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
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AfriIcons.live,
                size: SizeTokens.iconXxl,
                color: ColorTokens.onSurfaceVariant,
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TypographyTokens.headlineSmall(),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TypographyTokens.bodyMedium(),
              ),
              const SizedBox(height: SpacingTokens.spacing6),
              AfriButton(label: actionLabel, onTap: onAction),
            ],
          ),
        ),
      ),
    );
  }
}
