import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/partner_pool_models.dart';
import '../models/prediction_models.dart';
import '../prediction_providers.dart';

enum MatchDetailPhase { ready, syncing, degraded }

enum MatchDetailMutation { idle, joiningPool }

enum MatchDetailFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class MatchDetailFailure implements Exception {
  const MatchDetailFailure(this.kind);

  final MatchDetailFailureKind kind;

  static MatchDetailFailure fromError(Object error) {
    if (error is MatchDetailFailure) return error;
    if (error is TimeoutException) {
      return const MatchDetailFailure(MatchDetailFailureKind.securityTimeout);
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const MatchDetailFailure(MatchDetailFailureKind.permissionDenied);
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision') ||
        normalized.contains('already joined') ||
        normalized.contains('locked') ||
        normalized.contains('closed')) {
      return const MatchDetailFailure(MatchDetailFailureKind.conflict);
    }
    return const MatchDetailFailure(MatchDetailFailureKind.unknown);
  }

  static MatchDetailFailure fromResult(PartnerPoolMutationResult result) {
    return fromError(StateError(result.status));
  }

  @override
  String toString() => 'MatchDetailFailure(${kind.name})';
}

class MatchDetailState {
  const MatchDetailState({
    this.fixture,
    this.matchCenter,
    this.partnerPools = const <PartnerPredictionPool>[],
    this.phase = MatchDetailPhase.ready,
    this.mutation = MatchDetailMutation.idle,
    this.failure,
  });

  final FixtureSummary? fixture;
  final PredictionMatchCenter? matchCenter;
  final List<PartnerPredictionPool> partnerPools;
  final MatchDetailPhase phase;
  final MatchDetailMutation mutation;
  final MatchDetailFailure? failure;

  bool get isEmpty => fixture == null;

  bool get actionsBlocked =>
      phase != MatchDetailPhase.ready ||
      mutation != MatchDetailMutation.idle ||
      failure != null;

  MatchDetailState copyWith({
    FixtureSummary? fixture,
    PredictionMatchCenter? matchCenter,
    List<PartnerPredictionPool>? partnerPools,
    MatchDetailPhase? phase,
    MatchDetailMutation? mutation,
    MatchDetailFailure? failure,
    bool clearFailure = false,
  }) {
    return MatchDetailState(
      fixture: fixture ?? this.fixture,
      matchCenter: matchCenter ?? this.matchCenter,
      partnerPools: partnerPools ?? this.partnerPools,
      phase: phase ?? this.phase,
      mutation: mutation ?? this.mutation,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

class MatchDetailActionOutcome {
  const MatchDetailActionOutcome._({required this.isSuccess, this.failure});

  const MatchDetailActionOutcome.success() : this._(isSuccess: true);

  const MatchDetailActionOutcome.failure(MatchDetailFailure failure)
    : this._(isSuccess: false, failure: failure);

  final bool isSuccess;
  final MatchDetailFailure? failure;
}

abstract interface class MatchDetailGateway {
  Future<FixtureSummary?> loadFixture(String fixtureId);

  Future<PredictionMatchCenter?> loadMatchCenter(String fixtureId);

  Future<List<PartnerPredictionPool>> loadPools();

  Future<PartnerPoolMutationResult> joinPool({
    required String poolId,
    required PartnerPoolOutcome selectedOutcome,
    required String idempotencyKey,
  });
}

class RepositoryMatchDetailGateway implements MatchDetailGateway {
  const RepositoryMatchDetailGateway(
    this._predictionRepository,
    this._partnerPoolRepository,
  );

  final PredictionRepository _predictionRepository;
  final PartnerPoolRepository _partnerPoolRepository;

  @override
  Future<FixtureSummary?> loadFixture(String fixtureId) {
    return _predictionRepository.loadFixture(fixtureId);
  }

  @override
  Future<PredictionMatchCenter?> loadMatchCenter(String fixtureId) {
    return _predictionRepository.loadMatchCenter(fixtureId);
  }

  @override
  Future<List<PartnerPredictionPool>> loadPools() {
    return _partnerPoolRepository.loadPools(limit: 50);
  }

  @override
  Future<PartnerPoolMutationResult> joinPool({
    required String poolId,
    required PartnerPoolOutcome selectedOutcome,
    required String idempotencyKey,
  }) {
    return _partnerPoolRepository.joinPool(
      poolId: poolId,
      selectedOutcome: selectedOutcome.rpcValue,
      idempotencyKey: idempotencyKey,
    );
  }
}

final matchDetailGatewayProvider = Provider<MatchDetailGateway>(
  (ref) => RepositoryMatchDetailGateway(
    ref.watch(predictionRepositoryProvider),
    ref.watch(partnerPoolRepositoryProvider),
  ),
);

final matchDetailLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final matchDetailMutationTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 15),
);

final matchDetailActionsEnabledProvider = Provider<bool>((ref) => true);

final matchDetailProvider =
    StateNotifierProvider.family<
      MatchDetailController,
      AsyncValue<MatchDetailState>,
      String
    >((ref, fixtureId) {
      return MatchDetailController(
        ref.watch(matchDetailGatewayProvider),
        fixtureId,
        loadTimeout: ref.watch(matchDetailLoadTimeoutProvider),
        mutationTimeout: ref.watch(matchDetailMutationTimeoutProvider),
      );
    });

class MatchDetailController
    extends StateNotifier<AsyncValue<MatchDetailState>> {
  MatchDetailController(
    this._gateway,
    this._fixtureId, {
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

  final MatchDetailGateway _gateway;
  final String _fixtureId;
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
    state = preserveCurrent && previous?.fixture != null
        ? const AsyncLoading<MatchDetailState>().copyWithPrevious(state)
        : const AsyncLoading<MatchDetailState>();
    try {
      if (!ConnectivityService.isOnline) {
        throw const MatchDetailFailure(MatchDetailFailureKind.offline);
      }
      final results = await Future.wait<Object?>([
        _gateway.loadFixture(_fixtureId),
        _gateway.loadMatchCenter(_fixtureId),
        _gateway.loadPools(),
      ]).timeout(_loadTimeout);
      final pools = (results[2]! as List<PartnerPredictionPool>)
          .where((pool) => pool.fixtureId == _fixtureId)
          .toList(growable: false);
      state = AsyncValue.data(
        MatchDetailState(
          fixture: results[0] as FixtureSummary?,
          matchCenter: results[1] as PredictionMatchCenter?,
          partnerPools: pools,
        ),
      );
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'MatchDetailController',
        'Match detail load failed.',
        error,
        stackTrace,
      );
      final failure = MatchDetailFailure.fromError(error);
      state = previous?.fixture != null
          ? AsyncValue.data(
              previous!.copyWith(
                phase: MatchDetailPhase.degraded,
                mutation: MatchDetailMutation.idle,
                failure: failure,
              ),
            )
          : AsyncValue.error(failure, stackTrace);
    } finally {
      _loading = false;
    }
  }

  Future<MatchDetailActionOutcome> joinPool({
    required PartnerPredictionPool pool,
    required PartnerPoolOutcome selectedOutcome,
  }) async {
    final current = state.valueOrNull;
    if (_mutating ||
        current?.fixture == null ||
        current!.actionsBlocked ||
        !pool.isOpen ||
        pool.hasJoined) {
      return const MatchDetailActionOutcome.failure(
        MatchDetailFailure(MatchDetailFailureKind.conflict),
      );
    }
    if (!ConnectivityService.isOnline) {
      const failure = MatchDetailFailure(MatchDetailFailureKind.offline);
      _retainFailure(current, failure);
      return const MatchDetailActionOutcome.failure(failure);
    }

    _mutating = true;
    state = AsyncValue.data(
      current.copyWith(
        phase: MatchDetailPhase.syncing,
        mutation: MatchDetailMutation.joiningPool,
        clearFailure: true,
      ),
    );
    final idempotencyKey =
        '${pool.id}-${selectedOutcome.rpcValue}-${DateTime.now().microsecondsSinceEpoch}';
    try {
      final result = await _gateway
          .joinPool(
            poolId: pool.id,
            selectedOutcome: selectedOutcome,
            idempotencyKey: idempotencyKey,
          )
          .timeout(_mutationTimeout);
      if (!_isJoinAccepted(result)) {
        final failure = MatchDetailFailure.fromResult(result);
        _retainFailure(current, failure);
        return MatchDetailActionOutcome.failure(failure);
      }

      await _loadAfterMutation();
      return const MatchDetailActionOutcome.success();
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'MatchDetailController',
        'Partner pool join failed.',
        error,
        stackTrace,
      );
      final failure = MatchDetailFailure.fromError(error);
      _retainFailure(current, failure);
      return MatchDetailActionOutcome.failure(failure);
    } finally {
      _mutating = false;
    }
  }

  Future<void> _loadAfterMutation() async {
    final results = await Future.wait<Object?>([
      _gateway.loadFixture(_fixtureId),
      _gateway.loadMatchCenter(_fixtureId),
      _gateway.loadPools(),
    ]).timeout(_loadTimeout);
    final pools = (results[2]! as List<PartnerPredictionPool>)
        .where((pool) => pool.fixtureId == _fixtureId)
        .toList(growable: false);
    state = AsyncValue.data(
      MatchDetailState(
        fixture: results[0] as FixtureSummary?,
        matchCenter: results[1] as PredictionMatchCenter?,
        partnerPools: pools,
      ),
    );
  }

  bool _isJoinAccepted(PartnerPoolMutationResult result) {
    return switch (result.status.trim().toLowerCase()) {
      'success' || 'joined' || 'ok' => true,
      _ => false,
    };
  }

  void _retainFailure(MatchDetailState current, MatchDetailFailure failure) {
    state = AsyncValue.data(
      current.copyWith(
        phase: MatchDetailPhase.degraded,
        mutation: MatchDetailMutation.idle,
        failure: failure,
      ),
    );
  }
}
