import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/prediction_models.dart';
import '../repositories/prediction_repository.dart';
import '../widgets/prediction_share_card.dart';

enum ShareCardPhase { ready, syncing, degraded }

enum ShareCardMutation { idle, sharing, copying }

enum ShareCardFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class ShareCardFailure implements Exception {
  const ShareCardFailure(this.kind);

  final ShareCardFailureKind kind;

  static ShareCardFailure fromError(Object error) {
    if (error is ShareCardFailure) return error;
    if (error is TimeoutException) {
      return const ShareCardFailure(ShareCardFailureKind.securityTimeout);
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const ShareCardFailure(ShareCardFailureKind.permissionDenied);
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('already') ||
        normalized.contains('busy')) {
      return const ShareCardFailure(ShareCardFailureKind.conflict);
    }
    return const ShareCardFailure(ShareCardFailureKind.unknown);
  }

  @override
  String toString() => 'ShareCardFailure(${kind.name})';
}

class ShareCardRouteState {
  const ShareCardRouteState({
    this.history = const <UserPrediction>[],
    this.selectedId,
    this.phase = ShareCardPhase.ready,
    this.mutation = ShareCardMutation.idle,
    this.failure,
    this.uncertainMutation = false,
  });

  final List<UserPrediction> history;
  final String? selectedId;
  final ShareCardPhase phase;
  final ShareCardMutation mutation;
  final ShareCardFailure? failure;
  final bool uncertainMutation;

  UserPrediction? get selected {
    for (final prediction in history) {
      if (prediction.id == selectedId) return prediction;
    }
    return history.isEmpty ? null : history.first;
  }

  bool get isEmpty => history.isEmpty;

  bool get actionsBlocked =>
      phase != ShareCardPhase.ready ||
      mutation != ShareCardMutation.idle ||
      failure != null ||
      uncertainMutation;

  ShareCardRouteState copyWith({
    List<UserPrediction>? history,
    String? selectedId,
    ShareCardPhase? phase,
    ShareCardMutation? mutation,
    ShareCardFailure? failure,
    bool? uncertainMutation,
    bool clearFailure = false,
  }) {
    return ShareCardRouteState(
      history: history ?? this.history,
      selectedId: selectedId ?? this.selectedId,
      phase: phase ?? this.phase,
      mutation: mutation ?? this.mutation,
      failure: clearFailure ? null : failure ?? this.failure,
      uncertainMutation: uncertainMutation ?? this.uncertainMutation,
    );
  }
}

class ShareCardActionOutcome {
  const ShareCardActionOutcome._({required this.isSuccess, this.failure});

  const ShareCardActionOutcome.success() : this._(isSuccess: true);

  const ShareCardActionOutcome.failure(ShareCardFailure failure)
    : this._(isSuccess: false, failure: failure);

  final bool isSuccess;
  final ShareCardFailure? failure;
}

abstract interface class ShareCardGateway {
  Future<List<UserPrediction>> loadHistory({required int limit});

  Future<void> share(UserPrediction prediction);

  Future<void> copy(UserPrediction prediction);
}

class RepositoryShareCardGateway implements ShareCardGateway {
  const RepositoryShareCardGateway(this._repository);

  final PredictionRepository _repository;

  @override
  Future<List<UserPrediction>> loadHistory({required int limit}) {
    return _repository.loadPredictionHistory(limit: limit);
  }

  @override
  Future<void> share(UserPrediction prediction) {
    return PredictionShareService.share(
      data: PredictionShareData.fromPrediction(prediction),
    );
  }

  @override
  Future<void> copy(UserPrediction prediction) {
    return PredictionShareService.copy(
      data: PredictionShareData.fromPrediction(prediction),
    );
  }
}

class ShareCardController
    extends StateNotifier<AsyncValue<ShareCardRouteState>> {
  ShareCardController(
    this._gateway, {
    Duration loadTimeout = const Duration(seconds: 12),
    Duration actionTimeout = const Duration(seconds: 12),
    bool autoLoad = true,
  }) : _loadTimeout = loadTimeout,
       _actionTimeout = actionTimeout,
       super(const AsyncValue.loading()) {
    if (autoLoad) unawaited(load());
  }

  final ShareCardGateway _gateway;
  final Duration _loadTimeout;
  final Duration _actionTimeout;
  bool _loading = false;
  bool _mutating = false;

  Future<void> load() => _load(preserveCurrent: false);

  Future<void> refresh() => _load(preserveCurrent: true);

  Future<void> connectionRestored() async {
    final current = state.valueOrNull;
    if (current?.failure?.kind != ShareCardFailureKind.offline ||
        current?.uncertainMutation == true) {
      return;
    }
    await refresh();
  }

  void select(String predictionId) {
    final current = state.valueOrNull;
    if (current == null || _mutating) return;
    final exists = current.history.any(
      (prediction) => prediction.id == predictionId,
    );
    if (!exists || current.selectedId == predictionId) return;
    state = AsyncValue.data(current.copyWith(selectedId: predictionId));
  }

  void acknowledgeActionFailure() {
    final current = state.valueOrNull;
    if (current == null || _mutating || current.failure == null) return;
    state = AsyncValue.data(
      current.copyWith(
        phase: ShareCardPhase.ready,
        mutation: ShareCardMutation.idle,
        clearFailure: true,
        uncertainMutation: false,
      ),
    );
  }

  Future<void> _load({required bool preserveCurrent}) async {
    if (_loading || _mutating) return;
    _loading = true;
    final previous = state.valueOrNull;
    state = preserveCurrent && previous?.history.isNotEmpty == true
        ? const AsyncLoading<ShareCardRouteState>().copyWithPrevious(state)
        : const AsyncLoading<ShareCardRouteState>();
    try {
      if (!ConnectivityService.isOnline) {
        throw const ShareCardFailure(ShareCardFailureKind.offline);
      }
      final history = await _gateway
          .loadHistory(limit: 30)
          .timeout(_loadTimeout);
      final selectedId = _resolveSelectedId(history, previous?.selectedId);
      state = AsyncValue.data(
        ShareCardRouteState(history: history, selectedId: selectedId),
      );
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'ShareCardController',
        'Share-card history failed to load.',
        error,
        stackTrace,
      );
      final failure = ShareCardFailure.fromError(error);
      state = previous?.history.isNotEmpty == true
          ? AsyncValue.data(
              previous!.copyWith(
                phase: ShareCardPhase.degraded,
                mutation: ShareCardMutation.idle,
                failure: failure,
              ),
            )
          : AsyncValue.error(failure, stackTrace);
    } finally {
      _loading = false;
    }
  }

  Future<ShareCardActionOutcome> share() {
    return _runAction(
      mutation: ShareCardMutation.sharing,
      operation: _gateway.share,
    );
  }

  Future<ShareCardActionOutcome> copy() {
    return _runAction(
      mutation: ShareCardMutation.copying,
      operation: _gateway.copy,
    );
  }

  Future<ShareCardActionOutcome> _runAction({
    required ShareCardMutation mutation,
    required Future<void> Function(UserPrediction prediction) operation,
  }) async {
    final current = state.valueOrNull;
    final selected = current?.selected;
    if (_mutating ||
        current == null ||
        selected == null ||
        current.actionsBlocked) {
      return const ShareCardActionOutcome.failure(
        ShareCardFailure(ShareCardFailureKind.conflict),
      );
    }
    if (!ConnectivityService.isOnline) {
      const failure = ShareCardFailure(ShareCardFailureKind.offline);
      _retainFailure(current, failure);
      return const ShareCardActionOutcome.failure(failure);
    }

    _mutating = true;
    state = AsyncValue.data(
      current.copyWith(
        phase: ShareCardPhase.syncing,
        mutation: mutation,
        clearFailure: true,
      ),
    );
    try {
      await operation(selected).timeout(_actionTimeout);
      state = AsyncValue.data(
        current.copyWith(
          phase: ShareCardPhase.ready,
          mutation: ShareCardMutation.idle,
          clearFailure: true,
          uncertainMutation: false,
        ),
      );
      return const ShareCardActionOutcome.success();
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'ShareCardController',
        'Platform share-card action failed.',
        error,
        stackTrace,
      );
      final failure = ShareCardFailure.fromError(error);
      _retainFailure(
        current,
        failure,
        uncertain: failure.kind == ShareCardFailureKind.securityTimeout,
      );
      return ShareCardActionOutcome.failure(failure);
    } finally {
      _mutating = false;
    }
  }

  void _retainFailure(
    ShareCardRouteState current,
    ShareCardFailure failure, {
    bool uncertain = false,
  }) {
    state = AsyncValue.data(
      current.copyWith(
        phase: ShareCardPhase.degraded,
        mutation: ShareCardMutation.idle,
        failure: failure,
        uncertainMutation: uncertain,
      ),
    );
  }

  String? _resolveSelectedId(List<UserPrediction> history, String? previousId) {
    if (history.isEmpty) return null;
    if (previousId != null &&
        history.any((prediction) => prediction.id == previousId)) {
      return previousId;
    }
    return history.first.id;
  }
}
