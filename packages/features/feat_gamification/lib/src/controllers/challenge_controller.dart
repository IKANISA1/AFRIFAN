import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/challenge_models.dart';
import '../prediction_providers.dart';

class ChallengeFeedState {
  const ChallengeFeedState({
    this.featured = const <Challenge>[],
    this.open = const <Challenge>[],
    this.mine = const <Challenge>[],
    this.settled = const <Challenge>[],
    this.status = ChallengeFeedStatus.ok,
    this.message,
  });

  final List<Challenge> featured;
  final List<Challenge> open;
  final List<Challenge> mine;
  final List<Challenge> settled;
  final ChallengeFeedStatus status;
  final String? message;

  bool get isEmpty =>
      featured.isEmpty && open.isEmpty && mine.isEmpty && settled.isEmpty;

  List<Challenge> allVisible() {
    final seen = <String>{};
    final merged = <Challenge>[...featured, ...open, ...mine, ...settled];
    return merged.where((challenge) => seen.add(challenge.id)).toList();
  }

  ChallengeFeedState copyWith({
    List<Challenge>? featured,
    List<Challenge>? open,
    List<Challenge>? mine,
    List<Challenge>? settled,
    ChallengeFeedStatus? status,
    String? message,
  }) {
    return ChallengeFeedState(
      featured: featured ?? this.featured,
      open: open ?? this.open,
      mine: mine ?? this.mine,
      settled: settled ?? this.settled,
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }
}

enum ChallengeFeedStatus { ok, degraded }

enum ChallengeFeedFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class ChallengeFeedFailure implements Exception {
  const ChallengeFeedFailure(this.kind);

  final ChallengeFeedFailureKind kind;

  static ChallengeFeedFailure fromError(Object error) {
    if (error is ChallengeFeedFailure) return error;
    if (error is TimeoutException) {
      return const ChallengeFeedFailure(
        ChallengeFeedFailureKind.securityTimeout,
      );
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const ChallengeFeedFailure(
        ChallengeFeedFailureKind.permissionDenied,
      );
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision')) {
      return const ChallengeFeedFailure(ChallengeFeedFailureKind.conflict);
    }
    return const ChallengeFeedFailure(ChallengeFeedFailureKind.unknown);
  }

  @override
  String toString() => 'ChallengeFeedFailure(${kind.name})';
}

final challengeFeedLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final challengeFeedActionsEnabledProvider = Provider<bool>((ref) => true);

final challengeFeedProvider =
    StateNotifierProvider<
      ChallengeFeedController,
      AsyncValue<ChallengeFeedState>
    >(
      (ref) => ChallengeFeedController(
        ref.watch(challengeRepositoryProvider),
        loadTimeout: ref.watch(challengeFeedLoadTimeoutProvider),
      ),
    );

final myChallengesProvider =
    StateNotifierProvider<MyChallengesController, AsyncValue<List<Challenge>>>(
      (ref) => MyChallengesController(ref.watch(challengeRepositoryProvider)),
    );

class ChallengeFeedController
    extends StateNotifier<AsyncValue<ChallengeFeedState>> {
  ChallengeFeedController(
    this._repository, {
    Duration loadTimeout = const Duration(seconds: 12),
    bool autoLoad = true,
  }) : _loadTimeout = loadTimeout,
       super(const AsyncValue.loading()) {
    if (autoLoad) {
      unawaited(load());
    }
  }

  final ChallengeRepository _repository;
  final Duration _loadTimeout;
  bool _refreshing = false;

  Future<void> load() async {
    await _load(preserveCurrent: false);
  }

  Future<void> _load({required bool preserveCurrent}) async {
    if (_refreshing) return;
    _refreshing = true;
    final previous = state.valueOrNull;
    state = preserveCurrent && previous != null
        ? const AsyncLoading<ChallengeFeedState>().copyWithPrevious(state)
        : const AsyncLoading<ChallengeFeedState>();
    try {
      if (!ConnectivityService.isOnline) {
        throw const ChallengeFeedFailure(ChallengeFeedFailureKind.offline);
      }
      final results = await Future.wait<List<Challenge>>([
        _repository
            .loadChallenges(
              statuses: const <String>['open'],
              sort: 'high_pool',
              limit: 5,
            )
            .timeout(_loadTimeout),
        _repository
            .loadChallenges(
              statuses: const <String>['open'],
              sort: 'ending_soon',
              limit: 24,
            )
            .timeout(_loadTimeout),
        _repository
            .loadMyChallenges(
              statuses: const <String>['open', 'locked'],
              sort: 'ending_soon',
              limit: 12,
            )
            .timeout(_loadTimeout),
        _repository
            .loadChallenges(
              statuses: const <String>['settled', 'void', 'cancelled'],
              sort: 'settled',
              limit: 12,
            )
            .timeout(_loadTimeout),
      ]);

      state = AsyncValue.data(
        ChallengeFeedState(
          featured: results[0],
          open: results[1],
          mine: results[2],
          settled: results[3],
        ),
      );
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'ChallengeFeedController',
        'Challenge feed load failed.',
        error,
        stackTrace,
      );
      final failure = ChallengeFeedFailure.fromError(error);
      state = previous != null && !previous.isEmpty
          ? AsyncValue.data(
              previous.copyWith(
                status: ChallengeFeedStatus.degraded,
                message: _retainedMessage(failure.kind),
              ),
            )
          : AsyncValue.error(failure, stackTrace);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> refresh() => _load(preserveCurrent: true);

  String _retainedMessage(ChallengeFeedFailureKind kind) {
    return switch (kind) {
      ChallengeFeedFailureKind.offline =>
        'Showing saved challenges. Reconnect before creating or joining a pool.',
      ChallengeFeedFailureKind.permissionDenied =>
        'Challenge access changed. Saved pools remain visible, but actions are blocked.',
      ChallengeFeedFailureKind.conflict =>
        'Challenge data changed elsewhere. Review the saved pools before refreshing.',
      ChallengeFeedFailureKind.securityTimeout =>
        'The security check did not finish. Saved pools remain visible and actions are blocked.',
      ChallengeFeedFailureKind.unknown =>
        'Live challenge updates are paused. Saved pools remain visible.',
    };
  }
}

class MyChallengesController
    extends StateNotifier<AsyncValue<List<Challenge>>> {
  MyChallengesController(this._repository) : super(const AsyncValue.loading()) {
    unawaited(loadOpen());
  }

  final ChallengeRepository _repository;

  Future<void> loadOpen() => _load(const <String>['open'], sort: 'ending_soon');

  Future<void> loadLocked() =>
      _load(const <String>['locked'], sort: 'ending_soon');

  Future<void> loadSettled() =>
      _load(const <String>['settled'], sort: 'settled');

  Future<void> loadVoided() =>
      _load(const <String>['void', 'cancelled'], sort: 'settled');

  Future<void> _load(List<String> statuses, {required String sort}) async {
    state = const AsyncLoading();
    try {
      final items = await _repository.loadMyChallenges(
        statuses: statuses,
        sort: sort,
        limit: 40,
      );
      state = AsyncValue.data(items);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
