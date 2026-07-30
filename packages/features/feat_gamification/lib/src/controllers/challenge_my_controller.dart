import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/challenge_models.dart';
import '../prediction_providers.dart';

enum MyChallengeFilter { open, locked, settled, refunded }

extension MyChallengeFilterContract on MyChallengeFilter {
  List<String> get statuses => switch (this) {
    MyChallengeFilter.open => const <String>['open'],
    MyChallengeFilter.locked => const <String>['locked'],
    MyChallengeFilter.settled => const <String>['settled'],
    MyChallengeFilter.refunded => const <String>['void', 'cancelled'],
  };

  String get sort => switch (this) {
    MyChallengeFilter.open || MyChallengeFilter.locked => 'ending_soon',
    MyChallengeFilter.settled || MyChallengeFilter.refunded => 'settled',
  };

  String get label => switch (this) {
    MyChallengeFilter.open => 'Open',
    MyChallengeFilter.locked => 'Locked',
    MyChallengeFilter.settled => 'Settled',
    MyChallengeFilter.refunded => 'Refunded',
  };
}

enum MyChallengesPhase { ready, syncing, degraded }

enum MyChallengesFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class MyChallengesFailure implements Exception {
  const MyChallengesFailure(this.kind);

  final MyChallengesFailureKind kind;

  static MyChallengesFailure fromError(Object error) {
    if (error is MyChallengesFailure) return error;
    if (error is TimeoutException) {
      return const MyChallengesFailure(MyChallengesFailureKind.securityTimeout);
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const MyChallengesFailure(
        MyChallengesFailureKind.permissionDenied,
      );
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision')) {
      return const MyChallengesFailure(MyChallengesFailureKind.conflict);
    }
    return const MyChallengesFailure(MyChallengesFailureKind.unknown);
  }

  @override
  String toString() => 'MyChallengesFailure(${kind.name})';
}

class MyChallengesState {
  const MyChallengesState({
    this.items = const <Challenge>[],
    this.filter = MyChallengeFilter.open,
    this.phase = MyChallengesPhase.ready,
    this.failure,
  });

  final List<Challenge> items;
  final MyChallengeFilter filter;
  final MyChallengesPhase phase;
  final MyChallengesFailure? failure;

  bool get actionsBlocked => phase != MyChallengesPhase.ready;
}

final myChallengesLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final myChallengesActionsEnabledProvider = Provider<bool>((ref) => true);

final myChallengesProvider =
    StateNotifierProvider<
      MyChallengesController,
      AsyncValue<MyChallengesState>
    >(
      (ref) => MyChallengesController(
        ref.watch(challengeRepositoryProvider),
        loadTimeout: ref.watch(myChallengesLoadTimeoutProvider),
      ),
    );

class MyChallengesController
    extends StateNotifier<AsyncValue<MyChallengesState>> {
  MyChallengesController(
    this._repository, {
    Duration loadTimeout = const Duration(seconds: 12),
    bool autoLoad = true,
  }) : _loadTimeout = loadTimeout,
       super(const AsyncValue.loading()) {
    if (autoLoad) {
      unawaited(select(MyChallengeFilter.open));
    }
  }

  final ChallengeRepository _repository;
  final Duration _loadTimeout;
  final Map<MyChallengeFilter, List<Challenge>> _cache =
      <MyChallengeFilter, List<Challenge>>{};

  Future<void>? _activeLoad;
  MyChallengeFilter _requestedFilter = MyChallengeFilter.open;

  MyChallengeFilter get currentFilter =>
      state.valueOrNull?.filter ?? _requestedFilter;

  Future<void> select(MyChallengeFilter filter) {
    _requestedFilter = filter;
    return _enqueue(filter);
  }

  Future<void> refresh() => _enqueue(currentFilter);

  Future<void> _enqueue(MyChallengeFilter filter) async {
    final activeLoad = _activeLoad;
    if (activeLoad != null) {
      await activeLoad;
      if (_requestedFilter != filter) return;
    }
    if (_requestedFilter != filter) return;

    final load = _load(filter);
    _activeLoad = load;
    try {
      await load;
    } finally {
      if (identical(_activeLoad, load)) {
        _activeLoad = null;
      }
    }
  }

  Future<void> _load(MyChallengeFilter filter) async {
    final hasCachedItems = _cache.containsKey(filter);
    final cachedItems = _cache[filter] ?? const <Challenge>[];
    state = hasCachedItems
        ? AsyncValue.data(
            MyChallengesState(
              items: cachedItems,
              filter: filter,
              phase: MyChallengesPhase.syncing,
            ),
          )
        : const AsyncLoading<MyChallengesState>();

    try {
      if (!ConnectivityService.isOnline) {
        throw const MyChallengesFailure(MyChallengesFailureKind.offline);
      }
      final items = await _repository
          .loadMyChallenges(
            statuses: filter.statuses,
            sort: filter.sort,
            limit: 40,
          )
          .timeout(_loadTimeout);
      if (_requestedFilter != filter) return;
      _cache[filter] = List<Challenge>.unmodifiable(items);
      state = AsyncValue.data(
        MyChallengesState(items: _cache[filter]!, filter: filter),
      );
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'MyChallengesController',
        'Challenge history failed to load.',
        error,
        stackTrace,
      );
      if (_requestedFilter != filter) return;
      final failure = error is MyChallengesFailure
          ? error
          : MyChallengesFailure.fromError(error);
      state = hasCachedItems
          ? AsyncValue.data(
              MyChallengesState(
                items: cachedItems,
                filter: filter,
                phase: MyChallengesPhase.degraded,
                failure: failure,
              ),
            )
          : AsyncValue.error(failure, stackTrace);
    }
  }
}
