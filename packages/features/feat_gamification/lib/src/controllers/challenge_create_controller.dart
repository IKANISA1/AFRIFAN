import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/challenge_models.dart';
import '../models/prediction_models.dart';
import '../prediction_providers.dart';

enum ChallengeCreatePhase { ready, syncing, degraded }

enum ChallengeCreateFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class ChallengeCreateFailure implements Exception {
  const ChallengeCreateFailure(this.kind);

  final ChallengeCreateFailureKind kind;

  static ChallengeCreateFailure fromError(Object error) {
    if (error is ChallengeCreateFailure) return error;
    if (error is TimeoutException) {
      return const ChallengeCreateFailure(
        ChallengeCreateFailureKind.securityTimeout,
      );
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const ChallengeCreateFailure(
        ChallengeCreateFailureKind.permissionDenied,
      );
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision') ||
        normalized.contains('already')) {
      return const ChallengeCreateFailure(ChallengeCreateFailureKind.conflict);
    }
    return const ChallengeCreateFailure(ChallengeCreateFailureKind.unknown);
  }

  @override
  String toString() => 'ChallengeCreateFailure(${kind.name})';
}

class ChallengeCreateState {
  const ChallengeCreateState({
    this.fixtures = const <FixtureSummary>[],
    this.phase = ChallengeCreatePhase.ready,
    this.failure,
  });

  final List<FixtureSummary> fixtures;
  final ChallengeCreatePhase phase;
  final ChallengeCreateFailure? failure;

  bool get actionsBlocked =>
      phase != ChallengeCreatePhase.ready || failure != null;

  ChallengeCreateState copyWith({
    List<FixtureSummary>? fixtures,
    ChallengeCreatePhase? phase,
    ChallengeCreateFailure? failure,
    bool clearFailure = false,
  }) {
    return ChallengeCreateState(
      fixtures: fixtures ?? this.fixtures,
      phase: phase ?? this.phase,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

class ChallengeCreateOutcome {
  const ChallengeCreateOutcome._({
    required this.isSuccess,
    this.challenge,
    this.failure,
  });

  const ChallengeCreateOutcome.success(Challenge challenge)
    : this._(isSuccess: true, challenge: challenge);

  const ChallengeCreateOutcome.failure(ChallengeCreateFailure failure)
    : this._(isSuccess: false, failure: failure);

  final bool isSuccess;
  final Challenge? challenge;
  final ChallengeCreateFailure? failure;
}

final challengeCreateLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final challengeCreateMutationTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 15),
);

final challengeCreateActionsEnabledProvider = Provider<bool>((ref) => true);

final challengeCreateProvider =
    StateNotifierProvider<
      ChallengeCreateController,
      AsyncValue<ChallengeCreateState>
    >((ref) {
      return ChallengeCreateController(
        ref.watch(challengeFixturesGatewayProvider),
        ref.watch(challengeRepositoryProvider),
        loadTimeout: ref.watch(challengeCreateLoadTimeoutProvider),
        mutationTimeout: ref.watch(challengeCreateMutationTimeoutProvider),
      );
    });

class ChallengeCreateController
    extends StateNotifier<AsyncValue<ChallengeCreateState>> {
  ChallengeCreateController(
    this._fixturesGateway,
    this._repository, {
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

  final ChallengeFixturesGateway _fixturesGateway;
  final ChallengeRepository _repository;
  final Duration _loadTimeout;
  final Duration _mutationTimeout;
  bool _loading = false;
  bool _submitting = false;

  Future<void> load() => _load(preserveCurrent: false);

  Future<void> refresh() => _load(preserveCurrent: true);

  Future<void> _load({required bool preserveCurrent}) async {
    if (_loading || _submitting) return;
    _loading = true;
    final previous = state.valueOrNull;
    state = preserveCurrent && previous?.fixtures.isNotEmpty == true
        ? const AsyncLoading<ChallengeCreateState>().copyWithPrevious(state)
        : const AsyncLoading<ChallengeCreateState>();
    try {
      if (!ConnectivityService.isOnline) {
        throw const ChallengeCreateFailure(ChallengeCreateFailureKind.offline);
      }
      final fixtures = await _fixturesGateway
          .loadFixtures(status: 'scheduled', limit: 60)
          .timeout(_loadTimeout);
      state = AsyncValue.data(
        ChallengeCreateState(
          fixtures: fixtures
              .where((fixture) => fixture.isPredictable)
              .toList(growable: false),
        ),
      );
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'ChallengeCreateController',
        'Challenge creation fixtures failed to load.',
        error,
        stackTrace,
      );
      final failure = ChallengeCreateFailure.fromError(error);
      state = previous?.fixtures.isNotEmpty == true
          ? AsyncValue.data(
              previous!.copyWith(
                phase: ChallengeCreatePhase.degraded,
                failure: failure,
              ),
            )
          : AsyncValue.error(failure, stackTrace);
    } finally {
      _loading = false;
    }
  }

  Future<ChallengeCreateOutcome> create({
    required String matchId,
    required int homeScore,
    required int awayScore,
    required int stakeFet,
  }) async {
    final current = state.valueOrNull;
    if (_submitting || current == null || current.actionsBlocked) {
      return const ChallengeCreateOutcome.failure(
        ChallengeCreateFailure(ChallengeCreateFailureKind.conflict),
      );
    }
    if (!ConnectivityService.isOnline) {
      const failure = ChallengeCreateFailure(
        ChallengeCreateFailureKind.offline,
      );
      _retainFailure(current, failure);
      return const ChallengeCreateOutcome.failure(failure);
    }

    _submitting = true;
    state = AsyncValue.data(
      current.copyWith(phase: ChallengeCreatePhase.syncing, clearFailure: true),
    );
    try {
      final result = await _repository
          .createChallenge(
            matchId: matchId,
            homeScore: homeScore,
            awayScore: awayScore,
            stakeFet: stakeFet,
          )
          .timeout(_mutationTimeout);
      final challenge = result.challenge;
      if (!result.isSuccess || challenge == null) {
        final failure = ChallengeCreateFailure.fromError(
          StateError(result.status),
        );
        _retainFailure(current, failure);
        return ChallengeCreateOutcome.failure(failure);
      }
      state = AsyncValue.data(current);
      return ChallengeCreateOutcome.success(challenge);
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'ChallengeCreateController',
        'Challenge creation failed.',
        error,
        stackTrace,
      );
      final failure = ChallengeCreateFailure.fromError(error);
      _retainFailure(current, failure);
      return ChallengeCreateOutcome.failure(failure);
    } finally {
      _submitting = false;
    }
  }

  void _retainFailure(
    ChallengeCreateState current,
    ChallengeCreateFailure failure,
  ) {
    state = AsyncValue.data(
      current.copyWith(phase: ChallengeCreatePhase.degraded, failure: failure),
    );
  }
}
