import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/challenge_models.dart';
import '../prediction_providers.dart';

enum ChallengeDetailPhase { ready, syncing, degraded }

enum ChallengeDetailMutation { idle, joining, cancelling }

enum ChallengeDetailFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class ChallengeDetailFailure implements Exception {
  const ChallengeDetailFailure(this.kind);

  final ChallengeDetailFailureKind kind;

  static ChallengeDetailFailure fromError(Object error) {
    if (error is ChallengeDetailFailure) return error;
    if (error is TimeoutException) {
      return const ChallengeDetailFailure(
        ChallengeDetailFailureKind.securityTimeout,
      );
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const ChallengeDetailFailure(
        ChallengeDetailFailureKind.permissionDenied,
      );
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision')) {
      return const ChallengeDetailFailure(ChallengeDetailFailureKind.conflict);
    }
    return const ChallengeDetailFailure(ChallengeDetailFailureKind.unknown);
  }

  static ChallengeDetailFailure fromStatus(String status) {
    return fromError(StateError(status));
  }

  @override
  String toString() => 'ChallengeDetailFailure(${kind.name})';
}

class ChallengeDetailState {
  const ChallengeDetailState({
    this.payload,
    this.phase = ChallengeDetailPhase.ready,
    this.mutation = ChallengeDetailMutation.idle,
    this.failure,
  });

  final ChallengeDetailPayload? payload;
  final ChallengeDetailPhase phase;
  final ChallengeDetailMutation mutation;
  final ChallengeDetailFailure? failure;

  bool get isEmpty => payload == null;

  bool get actionsBlocked =>
      phase != ChallengeDetailPhase.ready ||
      mutation != ChallengeDetailMutation.idle ||
      failure != null;

  ChallengeDetailState copyWith({
    ChallengeDetailPayload? payload,
    ChallengeDetailPhase? phase,
    ChallengeDetailMutation? mutation,
    ChallengeDetailFailure? failure,
    bool clearFailure = false,
  }) {
    return ChallengeDetailState(
      payload: payload ?? this.payload,
      phase: phase ?? this.phase,
      mutation: mutation ?? this.mutation,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

class ChallengeDetailActionOutcome {
  const ChallengeDetailActionOutcome._({required this.isSuccess, this.failure});

  const ChallengeDetailActionOutcome.success() : this._(isSuccess: true);

  const ChallengeDetailActionOutcome.failure(ChallengeDetailFailure failure)
    : this._(isSuccess: false, failure: failure);

  final bool isSuccess;
  final ChallengeDetailFailure? failure;
}

final challengeDetailLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final challengeDetailMutationTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 15),
);

final challengeDetailActionsEnabledProvider = Provider<bool>((ref) => true);

final challengeDetailProvider =
    StateNotifierProvider.family<
      ChallengeDetailController,
      AsyncValue<ChallengeDetailState>,
      String
    >((ref, id) {
      return ChallengeDetailController(
        ref.watch(challengeRepositoryProvider),
        id,
        loadTimeout: ref.watch(challengeDetailLoadTimeoutProvider),
        mutationTimeout: ref.watch(challengeDetailMutationTimeoutProvider),
      );
    });

class ChallengeDetailController
    extends StateNotifier<AsyncValue<ChallengeDetailState>> {
  ChallengeDetailController(
    this._repository,
    this._id, {
    Duration loadTimeout = const Duration(seconds: 12),
    Duration mutationTimeout = const Duration(seconds: 15),
    bool autoLoad = true,
  }) : _loadTimeout = loadTimeout,
       _mutationTimeout = mutationTimeout,
       super(const AsyncValue.loading()) {
    if (autoLoad) {
      unawaited(load());
    }
  }

  final ChallengeRepository _repository;
  final String _id;
  final Duration _loadTimeout;
  final Duration _mutationTimeout;
  bool _loading = false;
  bool _mutating = false;

  Future<void> load() => _load(preserveCurrent: false);

  Future<void> refresh() => _load(preserveCurrent: true);

  Future<void> _load({required bool preserveCurrent}) async {
    if (_loading || _mutating) return;
    _loading = true;
    final previous = state.valueOrNull;
    state = preserveCurrent && previous?.payload != null
        ? const AsyncLoading<ChallengeDetailState>().copyWithPrevious(state)
        : const AsyncLoading<ChallengeDetailState>();
    try {
      if (!ConnectivityService.isOnline) {
        throw const ChallengeDetailFailure(ChallengeDetailFailureKind.offline);
      }
      final payload = await _repository
          .loadChallengeDetail(_id)
          .timeout(_loadTimeout);
      state = AsyncValue.data(ChallengeDetailState(payload: payload));
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'ChallengeDetailController',
        'Challenge detail load failed.',
        error,
        stackTrace,
      );
      final failure = ChallengeDetailFailure.fromError(error);
      state = previous?.payload != null
          ? AsyncValue.data(
              previous!.copyWith(
                phase: ChallengeDetailPhase.degraded,
                mutation: ChallengeDetailMutation.idle,
                failure: failure,
              ),
            )
          : AsyncValue.error(failure, stackTrace);
    } finally {
      _loading = false;
    }
  }

  Future<ChallengeDetailActionOutcome> join(int homeScore, int awayScore) {
    return _mutate(
      mutation: ChallengeDetailMutation.joining,
      invoke: () => _repository.joinChallenge(
        challengeId: _id,
        homeScore: homeScore,
        awayScore: awayScore,
      ),
    );
  }

  Future<ChallengeDetailActionOutcome> cancel() {
    return _mutate(
      mutation: ChallengeDetailMutation.cancelling,
      invoke: () => _repository.cancelChallenge(_id),
    );
  }

  Future<ChallengeDetailActionOutcome> _mutate({
    required ChallengeDetailMutation mutation,
    required Future<ChallengeMutationResult> Function() invoke,
  }) async {
    final current = state.valueOrNull;
    if (_mutating || current?.payload == null || current!.actionsBlocked) {
      return const ChallengeDetailActionOutcome.failure(
        ChallengeDetailFailure(ChallengeDetailFailureKind.conflict),
      );
    }
    if (!ConnectivityService.isOnline) {
      const failure = ChallengeDetailFailure(
        ChallengeDetailFailureKind.offline,
      );
      _retainFailure(current, failure);
      return const ChallengeDetailActionOutcome.failure(failure);
    }

    _mutating = true;
    state = AsyncValue.data(
      current.copyWith(
        phase: ChallengeDetailPhase.syncing,
        mutation: mutation,
        clearFailure: true,
      ),
    );
    try {
      final result = await invoke().timeout(_mutationTimeout);
      if (!result.isSuccess) {
        final failure = ChallengeDetailFailure.fromStatus(result.status);
        _retainFailure(current, failure);
        return ChallengeDetailActionOutcome.failure(failure);
      }

      final currentPayload = current.payload!;
      final returnedChallenge = result.challenge;
      state = AsyncValue.data(
        ChallengeDetailState(
          payload: returnedChallenge == null
              ? currentPayload
              : ChallengeDetailPayload(
                  challenge: returnedChallenge,
                  entries: currentPayload.entries,
                ),
        ),
      );
      return const ChallengeDetailActionOutcome.success();
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'ChallengeDetailController',
        'Challenge detail mutation failed.',
        error,
        stackTrace,
      );
      final failure = ChallengeDetailFailure.fromError(error);
      _retainFailure(current, failure);
      return ChallengeDetailActionOutcome.failure(failure);
    } finally {
      _mutating = false;
    }
  }

  void _retainFailure(
    ChallengeDetailState current,
    ChallengeDetailFailure failure,
  ) {
    state = AsyncValue.data(
      current.copyWith(
        phase: ChallengeDetailPhase.degraded,
        mutation: ChallengeDetailMutation.idle,
        failure: failure,
      ),
    );
  }
}
