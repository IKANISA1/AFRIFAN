import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/prediction_models.dart';
import '../prediction_providers.dart';

enum PredictionDetailPhase { ready, syncing, degraded }

enum PredictionDetailMutation { idle, cancelling }

enum PredictionDetailFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class PredictionDetailFailure implements Exception {
  const PredictionDetailFailure(this.kind);

  final PredictionDetailFailureKind kind;

  static PredictionDetailFailure fromError(Object error) {
    if (error is PredictionDetailFailure) return error;
    if (error is TimeoutException) {
      return const PredictionDetailFailure(
        PredictionDetailFailureKind.securityTimeout,
      );
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const PredictionDetailFailure(
        PredictionDetailFailureKind.permissionDenied,
      );
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision') ||
        normalized.contains('already settled') ||
        normalized.contains('already cancelled')) {
      return const PredictionDetailFailure(
        PredictionDetailFailureKind.conflict,
      );
    }
    return const PredictionDetailFailure(PredictionDetailFailureKind.unknown);
  }

  static PredictionDetailFailure fromResult(PredictionPlaceResult result) {
    return fromError(StateError('${result.status} ${result.message}'));
  }

  @override
  String toString() => 'PredictionDetailFailure(${kind.name})';
}

class PredictionDetailState {
  const PredictionDetailState({
    this.detail,
    this.phase = PredictionDetailPhase.ready,
    this.mutation = PredictionDetailMutation.idle,
    this.failure,
  });

  final PredictionDetail? detail;
  final PredictionDetailPhase phase;
  final PredictionDetailMutation mutation;
  final PredictionDetailFailure? failure;

  bool get isEmpty => detail == null;

  bool get actionsBlocked =>
      phase != PredictionDetailPhase.ready ||
      mutation != PredictionDetailMutation.idle ||
      failure != null;

  PredictionDetailState copyWith({
    PredictionDetail? detail,
    PredictionDetailPhase? phase,
    PredictionDetailMutation? mutation,
    PredictionDetailFailure? failure,
    bool clearFailure = false,
  }) {
    return PredictionDetailState(
      detail: detail ?? this.detail,
      phase: phase ?? this.phase,
      mutation: mutation ?? this.mutation,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

class PredictionDetailActionOutcome {
  const PredictionDetailActionOutcome._({
    required this.isSuccess,
    this.failure,
  });

  const PredictionDetailActionOutcome.success() : this._(isSuccess: true);

  const PredictionDetailActionOutcome.failure(PredictionDetailFailure failure)
    : this._(isSuccess: false, failure: failure);

  final bool isSuccess;
  final PredictionDetailFailure? failure;
}

abstract interface class PredictionDetailGateway {
  Future<PredictionDetail?> load(String predictionId);

  Future<PredictionPlaceResult> cancel(String predictionId);
}

class RepositoryPredictionDetailGateway implements PredictionDetailGateway {
  const RepositoryPredictionDetailGateway(this._repository);

  final PredictionRepository _repository;

  @override
  Future<PredictionDetail?> load(String predictionId) {
    return _repository.loadPredictionDetail(predictionId);
  }

  @override
  Future<PredictionPlaceResult> cancel(String predictionId) {
    return _repository.cancelPrediction(predictionId);
  }
}

final predictionDetailGatewayProvider = Provider<PredictionDetailGateway>(
  (ref) => RepositoryPredictionDetailGateway(
    ref.watch(predictionRepositoryProvider),
  ),
);

final predictionDetailLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final predictionDetailMutationTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 15),
);

final predictionDetailActionsEnabledProvider = Provider<bool>((ref) => true);

final predictionDetailProvider =
    StateNotifierProvider.family<
      PredictionDetailController,
      AsyncValue<PredictionDetailState>,
      String
    >((ref, predictionId) {
      return PredictionDetailController(
        ref.watch(predictionDetailGatewayProvider),
        predictionId,
        loadTimeout: ref.watch(predictionDetailLoadTimeoutProvider),
        mutationTimeout: ref.watch(predictionDetailMutationTimeoutProvider),
      );
    });

class PredictionDetailController
    extends StateNotifier<AsyncValue<PredictionDetailState>> {
  PredictionDetailController(
    this._gateway,
    this._predictionId, {
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

  final PredictionDetailGateway _gateway;
  final String _predictionId;
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
    state = preserveCurrent && previous?.detail != null
        ? const AsyncLoading<PredictionDetailState>().copyWithPrevious(state)
        : const AsyncLoading<PredictionDetailState>();
    try {
      if (!ConnectivityService.isOnline) {
        throw const PredictionDetailFailure(
          PredictionDetailFailureKind.offline,
        );
      }
      final detail = await _gateway.load(_predictionId).timeout(_loadTimeout);
      state = AsyncValue.data(PredictionDetailState(detail: detail));
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'PredictionDetailController',
        'Prediction detail load failed.',
        error,
        stackTrace,
      );
      final failure = PredictionDetailFailure.fromError(error);
      state = previous?.detail != null
          ? AsyncValue.data(
              previous!.copyWith(
                phase: PredictionDetailPhase.degraded,
                mutation: PredictionDetailMutation.idle,
                failure: failure,
              ),
            )
          : AsyncValue.error(failure, stackTrace);
    } finally {
      _loading = false;
    }
  }

  Future<PredictionDetailActionOutcome> cancel() async {
    final current = state.valueOrNull;
    if (_mutating || current?.detail == null || current!.actionsBlocked) {
      return const PredictionDetailActionOutcome.failure(
        PredictionDetailFailure(PredictionDetailFailureKind.conflict),
      );
    }
    if (!current.detail!.isPending) {
      const failure = PredictionDetailFailure(
        PredictionDetailFailureKind.conflict,
      );
      _retainFailure(current, failure);
      return const PredictionDetailActionOutcome.failure(failure);
    }
    if (!ConnectivityService.isOnline) {
      const failure = PredictionDetailFailure(
        PredictionDetailFailureKind.offline,
      );
      _retainFailure(current, failure);
      return const PredictionDetailActionOutcome.failure(failure);
    }

    _mutating = true;
    state = AsyncValue.data(
      current.copyWith(
        phase: PredictionDetailPhase.syncing,
        mutation: PredictionDetailMutation.cancelling,
        clearFailure: true,
      ),
    );
    try {
      final result = await _gateway
          .cancel(_predictionId)
          .timeout(_mutationTimeout);
      if (!_isCancellationAccepted(result)) {
        final failure = PredictionDetailFailure.fromResult(result);
        _retainFailure(current, failure);
        return PredictionDetailActionOutcome.failure(failure);
      }

      final refreshed = await _gateway
          .load(_predictionId)
          .timeout(_loadTimeout);
      state = AsyncValue.data(PredictionDetailState(detail: refreshed));
      return const PredictionDetailActionOutcome.success();
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'PredictionDetailController',
        'Prediction cancellation failed.',
        error,
        stackTrace,
      );
      final failure = PredictionDetailFailure.fromError(error);
      _retainFailure(current, failure);
      return PredictionDetailActionOutcome.failure(failure);
    } finally {
      _mutating = false;
    }
  }

  bool _isCancellationAccepted(PredictionPlaceResult result) {
    if (result.isError) return false;
    return switch (result.status.trim().toLowerCase()) {
      'cancelled' || 'canceled' || 'updated' || 'success' || 'ok' => true,
      _ => result.isSuccess,
    };
  }

  void _retainFailure(
    PredictionDetailState current,
    PredictionDetailFailure failure,
  ) {
    state = AsyncValue.data(
      current.copyWith(
        phase: PredictionDetailPhase.degraded,
        mutation: PredictionDetailMutation.idle,
        failure: failure,
      ),
    );
  }
}
