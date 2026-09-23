import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/home_content_repository.dart';

enum HomeFeedFailureKind {
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class HomeFeedFailure implements Exception {
  const HomeFeedFailure(this.kind);

  final HomeFeedFailureKind kind;

  static HomeFeedFailure fromError(Object error) {
    if (error is HomeFeedFailure) return error;
    if (error is TimeoutException) {
      return const HomeFeedFailure(HomeFeedFailureKind.securityTimeout);
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const HomeFeedFailure(HomeFeedFailureKind.permissionDenied);
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision')) {
      return const HomeFeedFailure(HomeFeedFailureKind.conflict);
    }
    return const HomeFeedFailure(HomeFeedFailureKind.unknown);
  }

  @override
  String toString() => 'HomeFeedFailure(${kind.name})';
}

/// Riverpod AsyncNotifier managing the home feed lifecycle.
///
/// Replaces the manual setState-based loading/error/data handling
/// in HomeScreen with a declarative AsyncValue approach.
class HomeFeedNotifier extends AsyncNotifier<HomeFeedSnapshot> {
  HomeFeedNotifier({Duration loadTimeout = const Duration(seconds: 12)})
    : _loadTimeout = loadTimeout;

  final Duration _loadTimeout;
  int _latestIntelRefreshKey = 0;
  bool _connectivityBound = false;
  bool _refreshing = false;
  Timer? _loadTimeoutTimer;
  late bool _wasOnline;

  /// Monotonically increasing key used by LatestIntelSection
  /// to trigger its own independent child refresh cycle.
  int get latestIntelRefreshKey => _latestIntelRefreshKey;

  @override
  Future<HomeFeedSnapshot> build() async {
    _bindConnectivity();
    return _load();
  }

  /// Refresh the home feed data. Used by pull-to-refresh.
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    final previous = state.valueOrNull;

    // Preserve current data during refresh so the UI doesn't blank out.
    state = const AsyncLoading<HomeFeedSnapshot>().copyWithPrevious(state);
    try {
      final loaded = await _load();
      final shouldRetainPrevious =
          previous != null &&
          previous.hasAnyContent &&
          (loaded.status == HomeFeedStatus.error ||
              !ConnectivityService.isOnline);
      state = AsyncData(
        shouldRetainPrevious
            ? previous.copyWith(
                status: HomeFeedStatus.degraded,
                notice: HomeFeedNotice.savedContent,
              )
            : loaded,
      );
      _latestIntelRefreshKey++;
    } catch (error, stackTrace) {
      state = previous != null && previous.hasAnyContent
          ? AsyncData(
              previous.copyWith(
                status: HomeFeedStatus.degraded,
                notice: HomeFeedNotice.savedContent,
              ),
            )
          : AsyncError(error, stackTrace);
    } finally {
      _refreshing = false;
    }
  }

  Future<HomeFeedSnapshot> _load() async {
    if (!ConnectivityService.isOnline) {
      return localHomeFeedFallbackSnapshot().copyWith(
        notice: HomeFeedNotice.offlineShortcuts,
      );
    }

    final repo = ref.read(homeFeedRepositoryProvider);
    try {
      return await _withLoadTimeout(repo.load());
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'HomeFeedProvider',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      throw HomeFeedFailure.fromError(error);
    }
  }

  Future<HomeFeedSnapshot> _withLoadTimeout(
    Future<HomeFeedSnapshot> operation,
  ) {
    _loadTimeoutTimer?.cancel();
    final completer = Completer<HomeFeedSnapshot>();
    final timer = Timer(_loadTimeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('Home feed load timed out.', _loadTimeout),
        );
      }
    });
    _loadTimeoutTimer = timer;

    unawaited(
      operation.then(
        (snapshot) {
          if (!completer.isCompleted) {
            completer.complete(snapshot);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        },
      ),
    );

    return completer.future.whenComplete(() {
      timer.cancel();
      if (identical(_loadTimeoutTimer, timer)) {
        _loadTimeoutTimer = null;
      }
    });
  }

  void _bindConnectivity() {
    if (_connectivityBound) return;
    _connectivityBound = true;
    _wasOnline = ConnectivityService.isOnline;
    ConnectivityService.onlineNotifier.addListener(_handleConnectivityChange);
    ref.onDispose(() {
      _loadTimeoutTimer?.cancel();
      _loadTimeoutTimer = null;
      ConnectivityService.onlineNotifier.removeListener(
        _handleConnectivityChange,
      );
    });
  }

  void _handleConnectivityChange() {
    final isOnline = ConnectivityService.isOnline;
    final restored = !_wasOnline && isOnline;
    _wasOnline = isOnline;

    if (!isOnline) {
      final current = state.valueOrNull;
      if (current != null && current.hasAnyContent) {
        state = AsyncData(
          current.copyWith(
            status: HomeFeedStatus.degraded,
            notice: HomeFeedNotice.savedContent,
          ),
        );
      }
      return;
    }

    if (restored) {
      unawaited(refresh());
    }
  }
}

/// Provider for the home feed state managed by [HomeFeedNotifier].
final homeFeedProvider =
    AsyncNotifierProvider<HomeFeedNotifier, HomeFeedSnapshot>(() {
      return HomeFeedNotifier();
    });
