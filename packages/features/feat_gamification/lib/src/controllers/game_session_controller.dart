import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_session_models.dart';
import '../repositories/game_session_repository.dart';

enum GameSessionRoutePhase { ready, syncing, degraded }

enum GameSessionMutation { idle, joining, submittingAnswer }

enum GameSessionFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class GameSessionFailure implements Exception {
  const GameSessionFailure(this.kind);

  final GameSessionFailureKind kind;

  static GameSessionFailure fromError(Object error) {
    if (error is GameSessionFailure) return error;
    if (error is TimeoutException) {
      return const GameSessionFailure(GameSessionFailureKind.securityTimeout);
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const GameSessionFailure(GameSessionFailureKind.permissionDenied);
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('already') ||
        normalized.contains('claimed') ||
        normalized.contains('locked') ||
        normalized.contains('closed')) {
      return const GameSessionFailure(GameSessionFailureKind.conflict);
    }
    return const GameSessionFailure(GameSessionFailureKind.unknown);
  }

  @override
  String toString() => 'GameSessionFailure(${kind.name})';
}

class GameSessionRouteState {
  const GameSessionRouteState({
    this.content,
    this.phase = GameSessionRoutePhase.ready,
    this.mutation = GameSessionMutation.idle,
    this.failure,
    this.validationMessage,
    this.uncertainMutation = false,
  });

  final GameSessionControllerState? content;
  final GameSessionRoutePhase phase;
  final GameSessionMutation mutation;
  final GameSessionFailure? failure;
  final String? validationMessage;
  final bool uncertainMutation;

  bool get isEmpty => content == null;

  bool get actionsBlocked =>
      phase != GameSessionRoutePhase.ready ||
      mutation != GameSessionMutation.idle ||
      failure != null ||
      uncertainMutation;

  GameSessionRouteState copyWith({
    GameSessionControllerState? content,
    GameSessionRoutePhase? phase,
    GameSessionMutation? mutation,
    GameSessionFailure? failure,
    String? validationMessage,
    bool? uncertainMutation,
    bool clearFailure = false,
    bool clearValidation = false,
  }) {
    return GameSessionRouteState(
      content: content ?? this.content,
      phase: phase ?? this.phase,
      mutation: mutation ?? this.mutation,
      failure: clearFailure ? null : failure ?? this.failure,
      validationMessage: clearValidation
          ? null
          : validationMessage ?? this.validationMessage,
      uncertainMutation: uncertainMutation ?? this.uncertainMutation,
    );
  }
}

class GameSessionActionOutcome {
  const GameSessionActionOutcome._({required this.isSuccess, this.failure});

  const GameSessionActionOutcome.success() : this._(isSuccess: true);

  const GameSessionActionOutcome.failure(GameSessionFailure failure)
    : this._(isSuccess: false, failure: failure);

  final bool isSuccess;
  final GameSessionFailure? failure;
}

abstract interface class GameSessionGateway {
  Future<GameSessionControllerState?> loadControllerState({
    required String sessionId,
    String? sessionPlayerId,
  });

  Future<GameSessionJoinResult> joinSession({
    required String sessionId,
    required String displayName,
  });

  Future<Object?> submitAnswer({
    required String sessionQuestionId,
    required String sessionPlayerId,
    required String selectedOptionKey,
    required String idempotencyKey,
  });
}

class RepositoryGameSessionGateway implements GameSessionGateway {
  const RepositoryGameSessionGateway(this._repository);

  final GameSessionRepository _repository;

  @override
  Future<GameSessionControllerState?> loadControllerState({
    required String sessionId,
    String? sessionPlayerId,
  }) {
    return _repository.loadControllerState(
      sessionId: sessionId,
      sessionPlayerId: sessionPlayerId,
    );
  }

  @override
  Future<GameSessionJoinResult> joinSession({
    required String sessionId,
    required String displayName,
  }) {
    return _repository.joinSession(
      sessionId: sessionId,
      displayName: displayName,
    );
  }

  @override
  Future<Object?> submitAnswer({
    required String sessionQuestionId,
    required String sessionPlayerId,
    required String selectedOptionKey,
    required String idempotencyKey,
  }) {
    return _repository.submitAnswer(
      sessionQuestionId: sessionQuestionId,
      sessionPlayerId: sessionPlayerId,
      selectedOptionKey: selectedOptionKey,
      idempotencyKey: idempotencyKey,
    );
  }
}

class GameSessionController
    extends StateNotifier<AsyncValue<GameSessionRouteState>> {
  GameSessionController(
    this._gateway, {
    required String sessionId,
    String? sessionPlayerId,
    Duration loadTimeout = const Duration(seconds: 12),
    Duration mutationTimeout = const Duration(seconds: 12),
    bool autoLoad = true,
  }) : _sessionId = sessionId.trim(),
       _sessionPlayerId = _normalizeOptional(sessionPlayerId),
       _loadTimeout = loadTimeout,
       _mutationTimeout = mutationTimeout,
       super(const AsyncValue.loading()) {
    if (autoLoad) unawaited(load());
  }

  final GameSessionGateway _gateway;
  final String _sessionId;
  final Duration _loadTimeout;
  final Duration _mutationTimeout;
  String? _sessionPlayerId;
  bool _loading = false;
  bool _mutating = false;
  GameSessionMutation? _uncertainMutation;

  Future<void> load() => _load(preserveCurrent: false);

  Future<void> refresh() => _load(preserveCurrent: true);

  Future<void> connectionRestored() async {
    final current = state.valueOrNull;
    if (current?.failure?.kind != GameSessionFailureKind.offline ||
        current?.uncertainMutation == true) {
      return;
    }
    await refresh();
  }

  void clearInputFeedback() {
    final current = state.valueOrNull;
    if (current == null || current.uncertainMutation) return;
    final canClearFailure = switch (current.failure?.kind) {
      GameSessionFailureKind.conflict || GameSessionFailureKind.unknown => true,
      _ => false,
    };
    state = AsyncValue.data(
      current.copyWith(
        phase: canClearFailure ? GameSessionRoutePhase.ready : current.phase,
        clearFailure: canClearFailure,
        clearValidation: true,
      ),
    );
  }

  Future<void> _load({required bool preserveCurrent}) async {
    if (_loading || _mutating) return;
    if (_sessionId.isEmpty) {
      state = const AsyncValue.data(GameSessionRouteState());
      return;
    }

    _loading = true;
    final previous = state.valueOrNull;
    state = preserveCurrent && previous?.content != null
        ? const AsyncLoading<GameSessionRouteState>().copyWithPrevious(state)
        : const AsyncLoading<GameSessionRouteState>();
    try {
      if (!ConnectivityService.isOnline) {
        throw const GameSessionFailure(GameSessionFailureKind.offline);
      }
      final content = await _gateway
          .loadControllerState(
            sessionId: _sessionId,
            sessionPlayerId: _sessionPlayerId,
          )
          .timeout(_loadTimeout);
      if (content == null || content.sessionId.trim().isEmpty) {
        state = const AsyncValue.data(GameSessionRouteState());
        return;
      }

      if (_uncertainMutation != null &&
          !_authoritativeStateResolvesUncertainty(content)) {
        state = AsyncValue.data(
          GameSessionRouteState(
            content: content,
            phase: GameSessionRoutePhase.degraded,
            failure: const GameSessionFailure(
              GameSessionFailureKind.securityTimeout,
            ),
            uncertainMutation: true,
          ),
        );
        return;
      }

      _uncertainMutation = null;
      _sessionPlayerId = _normalizeOptional(content.sessionPlayerId);
      state = AsyncValue.data(GameSessionRouteState(content: content));
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'GameSessionController',
        'Game controller state failed to load.',
        error,
        stackTrace,
      );
      final failure = GameSessionFailure.fromError(error);
      state = previous?.content != null
          ? AsyncValue.data(
              previous!.copyWith(
                phase: GameSessionRoutePhase.degraded,
                mutation: GameSessionMutation.idle,
                failure: failure,
              ),
            )
          : AsyncValue.error(failure, stackTrace);
    } finally {
      _loading = false;
    }
  }

  Future<GameSessionActionOutcome> join(String displayName) async {
    final current = state.valueOrNull;
    if (_mutating ||
        current?.content == null ||
        current!.actionsBlocked ||
        _sessionPlayerId != null) {
      return const GameSessionActionOutcome.failure(
        GameSessionFailure(GameSessionFailureKind.conflict),
      );
    }
    final normalizedName = displayName.trim();
    if (normalizedName.length < 2 || normalizedName.length > 48) {
      state = AsyncValue.data(
        current.copyWith(
          validationMessage: 'Enter a display name from 2 to 48 characters.',
        ),
      );
      return const GameSessionActionOutcome.failure(
        GameSessionFailure(GameSessionFailureKind.conflict),
      );
    }
    if (!ConnectivityService.isOnline) {
      const failure = GameSessionFailure(GameSessionFailureKind.offline);
      _retainFailure(current, failure);
      return const GameSessionActionOutcome.failure(failure);
    }

    _mutating = true;
    state = AsyncValue.data(
      current.copyWith(
        phase: GameSessionRoutePhase.syncing,
        mutation: GameSessionMutation.joining,
        clearFailure: true,
        clearValidation: true,
      ),
    );
    try {
      final result = await _gateway
          .joinSession(sessionId: _sessionId, displayName: normalizedName)
          .timeout(_mutationTimeout);
      if (result.sessionPlayerId.trim().isEmpty ||
          result.sessionId.trim().isEmpty) {
        throw StateError('Game join returned incomplete confirmation.');
      }
      _sessionPlayerId = result.sessionPlayerId;
      _uncertainMutation = null;
      state = AsyncValue.data(
        GameSessionRouteState(
          content: current.content!.copyWith(
            sessionPlayerId: result.sessionPlayerId,
            playerName: result.displayName,
          ),
        ),
      );
      return const GameSessionActionOutcome.success();
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'GameSessionController',
        'Game session join failed.',
        error,
        stackTrace,
      );
      final failure = GameSessionFailure.fromError(error);
      if (failure.kind == GameSessionFailureKind.securityTimeout) {
        _uncertainMutation = GameSessionMutation.joining;
      }
      _retainFailure(
        current,
        failure,
        uncertain: failure.kind == GameSessionFailureKind.securityTimeout,
      );
      return GameSessionActionOutcome.failure(failure);
    } finally {
      _mutating = false;
    }
  }

  Future<GameSessionActionOutcome> submitAnswer(GameAnswerOption option) async {
    final current = state.valueOrNull;
    final content = current?.content;
    if (_mutating ||
        content == null ||
        current!.actionsBlocked ||
        !content.canSubmitAnswer ||
        option.key.trim().isEmpty) {
      return const GameSessionActionOutcome.failure(
        GameSessionFailure(GameSessionFailureKind.conflict),
      );
    }
    if (!ConnectivityService.isOnline) {
      const failure = GameSessionFailure(GameSessionFailureKind.offline);
      _retainFailure(current, failure);
      return const GameSessionActionOutcome.failure(failure);
    }

    _mutating = true;
    state = AsyncValue.data(
      current.copyWith(
        phase: GameSessionRoutePhase.syncing,
        mutation: GameSessionMutation.submittingAnswer,
        clearFailure: true,
      ),
    );
    final questionId = content.sessionQuestionId!;
    final playerId = content.sessionPlayerId!;
    try {
      await _gateway
          .submitAnswer(
            sessionQuestionId: questionId,
            sessionPlayerId: playerId,
            selectedOptionKey: option.key,
            idempotencyKey: [
              'answer',
              content.sessionId,
              questionId,
              playerId,
            ].join(':'),
          )
          .timeout(_mutationTimeout);
      _uncertainMutation = null;
      state = AsyncValue.data(
        GameSessionRouteState(
          content: content.copyWith(
            phase: GameSessionControllerPhase.locked,
            selectedOptionKey: option.key,
            statusMessage:
                'Answer submitted. Waiting for server claim or host reveal.',
          ),
        ),
      );
      return const GameSessionActionOutcome.success();
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'GameSessionController',
        'Game answer submission failed.',
        error,
        stackTrace,
      );
      final failure = GameSessionFailure.fromError(error);
      if (failure.kind == GameSessionFailureKind.securityTimeout) {
        _uncertainMutation = GameSessionMutation.submittingAnswer;
      }
      _retainFailure(
        current,
        failure,
        uncertain: failure.kind == GameSessionFailureKind.securityTimeout,
      );
      return GameSessionActionOutcome.failure(failure);
    } finally {
      _mutating = false;
    }
  }

  bool _authoritativeStateResolvesUncertainty(
    GameSessionControllerState content,
  ) {
    return switch (_uncertainMutation) {
      GameSessionMutation.joining =>
        _sessionPlayerId != null && _sessionPlayerId!.isNotEmpty,
      GameSessionMutation.submittingAnswer =>
        content.selectedOptionKey != null ||
            content.phase != GameSessionControllerPhase.answering,
      _ => true,
    };
  }

  void _retainFailure(
    GameSessionRouteState current,
    GameSessionFailure failure, {
    bool uncertain = false,
  }) {
    state = AsyncValue.data(
      current.copyWith(
        phase: GameSessionRoutePhase.degraded,
        mutation: GameSessionMutation.idle,
        failure: failure,
        uncertainMutation: uncertain,
      ),
    );
  }
}

String? _normalizeOptional(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
