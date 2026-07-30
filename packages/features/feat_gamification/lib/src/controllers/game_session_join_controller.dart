import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game_session_providers.dart';
import '../models/game_session_models.dart';
import '../repositories/game_session_repository.dart';

enum GameSessionJoinPhase { ready, syncing, degraded }

enum GameSessionJoinFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class GameSessionJoinFailure implements Exception {
  const GameSessionJoinFailure(this.kind);

  final GameSessionJoinFailureKind kind;

  static GameSessionJoinFailure fromError(Object error) {
    if (error is GameSessionJoinFailure) return error;
    if (error is TimeoutException) {
      return const GameSessionJoinFailure(
        GameSessionJoinFailureKind.securityTimeout,
      );
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('authentication') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const GameSessionJoinFailure(
        GameSessionJoinFailureKind.permissionDenied,
      );
    }
    if (normalized.contains('not found') ||
        normalized.contains('not joinable') ||
        normalized.contains('expired') ||
        normalized.contains('closed') ||
        normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('already')) {
      return const GameSessionJoinFailure(GameSessionJoinFailureKind.conflict);
    }
    return const GameSessionJoinFailure(GameSessionJoinFailureKind.unknown);
  }

  @override
  String toString() => 'GameSessionJoinFailure(${kind.name})';
}

class GameSessionJoinState {
  const GameSessionJoinState({
    this.phase = GameSessionJoinPhase.ready,
    this.failure,
    this.validationMessage,
  });

  final GameSessionJoinPhase phase;
  final GameSessionJoinFailure? failure;
  final String? validationMessage;

  bool get actionsBlocked =>
      phase != GameSessionJoinPhase.ready || failure != null;

  GameSessionJoinState copyWith({
    GameSessionJoinPhase? phase,
    GameSessionJoinFailure? failure,
    String? validationMessage,
    bool clearFailure = false,
    bool clearValidation = false,
  }) {
    return GameSessionJoinState(
      phase: phase ?? this.phase,
      failure: clearFailure ? null : failure ?? this.failure,
      validationMessage: clearValidation
          ? null
          : validationMessage ?? this.validationMessage,
    );
  }
}

class GameSessionJoinOutcome {
  const GameSessionJoinOutcome._({
    required this.isSuccess,
    this.result,
    this.failure,
    this.validationMessage,
  });

  const GameSessionJoinOutcome.success(GameSessionJoinResult result)
    : this._(isSuccess: true, result: result);

  const GameSessionJoinOutcome.failure(GameSessionJoinFailure failure)
    : this._(isSuccess: false, failure: failure);

  const GameSessionJoinOutcome.validation(String message)
    : this._(isSuccess: false, validationMessage: message);

  final bool isSuccess;
  final GameSessionJoinResult? result;
  final GameSessionJoinFailure? failure;
  final String? validationMessage;
}

abstract interface class GameSessionJoinGateway {
  Future<GameSessionJoinResult> joinByCode({
    required String joinCode,
    required String displayName,
  });
}

class RepositoryGameSessionJoinGateway implements GameSessionJoinGateway {
  const RepositoryGameSessionJoinGateway(this._repository);

  final GameSessionRepository _repository;

  @override
  Future<GameSessionJoinResult> joinByCode({
    required String joinCode,
    required String displayName,
  }) {
    return _repository.joinSessionByCode(
      joinCode: joinCode,
      displayName: displayName,
    );
  }
}

final gameSessionJoinGatewayProvider = Provider<GameSessionJoinGateway>(
  (ref) => RepositoryGameSessionJoinGateway(
    ref.watch(gameSessionRepositoryProvider),
  ),
);

final gameSessionJoinTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final gameSessionJoinAccessEnabledProvider = Provider<bool>((ref) => true);

final gameSessionJoinProvider =
    StateNotifierProvider<
      GameSessionJoinController,
      AsyncValue<GameSessionJoinState>
    >((ref) {
      return GameSessionJoinController(
        ref.watch(gameSessionJoinGatewayProvider),
        mutationTimeout: ref.watch(gameSessionJoinTimeoutProvider),
      );
    });

class GameSessionJoinController
    extends StateNotifier<AsyncValue<GameSessionJoinState>> {
  GameSessionJoinController(
    this._gateway, {
    Duration mutationTimeout = const Duration(seconds: 12),
  }) : _mutationTimeout = mutationTimeout,
       super(const AsyncValue.data(GameSessionJoinState()));

  static final RegExp _joinCodePattern = RegExp(r'^[A-Z0-9_-]{3,32}$');

  final GameSessionJoinGateway _gateway;
  final Duration _mutationTimeout;
  bool _joining = false;

  void clearInputFeedback() {
    final current = state.valueOrNull;
    if (current == null || current.phase == GameSessionJoinPhase.syncing) {
      return;
    }
    state = AsyncValue.data(
      current.copyWith(
        phase: GameSessionJoinPhase.ready,
        clearFailure: true,
        clearValidation: true,
      ),
    );
  }

  void connectionRestored() {
    final current = state.valueOrNull;
    if (current?.failure?.kind != GameSessionJoinFailureKind.offline) return;
    clearInputFeedback();
  }

  Future<GameSessionJoinOutcome> join({
    required String joinCode,
    required String displayName,
  }) async {
    final current = state.valueOrNull ?? const GameSessionJoinState();
    if (_joining || current.actionsBlocked) {
      return const GameSessionJoinOutcome.failure(
        GameSessionJoinFailure(GameSessionJoinFailureKind.conflict),
      );
    }

    final normalizedCode = joinCode.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      return _validationFailure(current, 'Enter the TV session code.');
    }
    if (!_joinCodePattern.hasMatch(normalizedCode)) {
      return _validationFailure(
        current,
        'Use 3–32 letters, numbers, hyphens, or underscores.',
      );
    }
    final normalizedName = displayName.trim().isEmpty
        ? 'Supporter'
        : displayName.trim();

    if (!ConnectivityService.isOnline) {
      const failure = GameSessionJoinFailure(
        GameSessionJoinFailureKind.offline,
      );
      _retainFailure(current, failure);
      return const GameSessionJoinOutcome.failure(failure);
    }

    _joining = true;
    state = AsyncValue.data(
      current.copyWith(
        phase: GameSessionJoinPhase.syncing,
        clearFailure: true,
        clearValidation: true,
      ),
    );
    try {
      final result = await _gateway
          .joinByCode(joinCode: normalizedCode, displayName: normalizedName)
          .timeout(_mutationTimeout);
      state = const AsyncValue.data(GameSessionJoinState());
      return GameSessionJoinOutcome.success(result);
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'GameSessionJoinController',
        'TV game join failed.',
        error,
        stackTrace,
      );
      final failure = GameSessionJoinFailure.fromError(error);
      _retainFailure(current, failure);
      return GameSessionJoinOutcome.failure(failure);
    } finally {
      _joining = false;
    }
  }

  GameSessionJoinOutcome _validationFailure(
    GameSessionJoinState current,
    String message,
  ) {
    state = AsyncValue.data(
      current.copyWith(
        phase: GameSessionJoinPhase.ready,
        validationMessage: message,
        clearFailure: true,
      ),
    );
    return GameSessionJoinOutcome.validation(message);
  }

  void _retainFailure(
    GameSessionJoinState current,
    GameSessionJoinFailure failure,
  ) {
    state = AsyncValue.data(
      current.copyWith(
        phase: GameSessionJoinPhase.degraded,
        failure: failure,
        clearValidation: true,
      ),
    );
  }
}
