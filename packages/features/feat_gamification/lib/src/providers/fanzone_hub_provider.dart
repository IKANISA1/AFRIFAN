import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../fet_providers.dart';
import '../models/fet_models.dart';
import '../models/prediction_models.dart';
import '../prediction_providers.dart';

/// Snapshot of all data needed by the FanzoneHubScreen.
///
/// Mirrors the [HomeFeedSnapshot] pattern — a single immutable object
/// holding all concurrent data plus a status indicator for degraded/error
/// states when some (but not all) upstream calls fail.
class FanzoneHubSnapshot {
  const FanzoneHubSnapshot({
    this.dashboard,
    this.wallet,
    this.liveFixtures = const <FixtureSummary>[],
    this.todayFixtures = const <FixtureSummary>[],
    this.upcomingFixtures = const <FixtureSummary>[],
    this.leaderboard = const <PredictionLeaderboardEntry>[],
    this.markets = const <PredictionMarket>[],
    this.challenges = const <FetCatalogItem>[],
    this.status = FanzoneHubStatus.ok,
    this.message,
  });

  final PredictionDashboard? dashboard;
  final FetWalletSummary? wallet;
  final List<FixtureSummary> liveFixtures;
  final List<FixtureSummary> todayFixtures;
  final List<FixtureSummary> upcomingFixtures;
  final List<PredictionLeaderboardEntry> leaderboard;
  final List<PredictionMarket> markets;
  final List<FetCatalogItem> challenges;
  final FanzoneHubStatus status;
  final String? message;

  bool get hasAnyContent =>
      dashboard != null ||
      wallet != null ||
      liveFixtures.isNotEmpty ||
      todayFixtures.isNotEmpty ||
      upcomingFixtures.isNotEmpty ||
      leaderboard.isNotEmpty ||
      markets.isNotEmpty ||
      challenges.isNotEmpty;

  FanzoneHubSnapshot copyWith({
    PredictionDashboard? dashboard,
    FetWalletSummary? wallet,
    List<FixtureSummary>? liveFixtures,
    List<FixtureSummary>? todayFixtures,
    List<FixtureSummary>? upcomingFixtures,
    List<PredictionLeaderboardEntry>? leaderboard,
    List<PredictionMarket>? markets,
    List<FetCatalogItem>? challenges,
    FanzoneHubStatus? status,
    String? message,
  }) {
    return FanzoneHubSnapshot(
      dashboard: dashboard ?? this.dashboard,
      wallet: wallet ?? this.wallet,
      liveFixtures: liveFixtures ?? this.liveFixtures,
      todayFixtures: todayFixtures ?? this.todayFixtures,
      upcomingFixtures: upcomingFixtures ?? this.upcomingFixtures,
      leaderboard: leaderboard ?? this.leaderboard,
      markets: markets ?? this.markets,
      challenges: challenges ?? this.challenges,
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }
}

abstract final class FanzoneHubSnapshotMessage {
  static const savedContent = 'saved_content';
  static const connectionRequired = 'connection_required';
}

enum FanzoneHubStatus { ok, degraded, error }

enum FanzoneHubFailureKind {
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class FanzoneHubFailure implements Exception {
  const FanzoneHubFailure(this.kind);

  final FanzoneHubFailureKind kind;

  static FanzoneHubFailure fromError(Object error) {
    if (error is FanzoneHubFailure) return error;
    if (error is TimeoutException) {
      return const FanzoneHubFailure(FanzoneHubFailureKind.securityTimeout);
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const FanzoneHubFailure(FanzoneHubFailureKind.permissionDenied);
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision')) {
      return const FanzoneHubFailure(FanzoneHubFailureKind.conflict);
    }
    return const FanzoneHubFailure(FanzoneHubFailureKind.unknown);
  }

  @override
  String toString() => 'FanzoneHubFailure(${kind.name})';
}

/// Riverpod AsyncNotifier managing the Fanzone Hub lifecycle.
///
/// Replaces the manual setState-based loading/error/data handling
/// in FanzoneHubScreen with a declarative AsyncValue approach.
///
/// Benefits over the old pattern:
/// - Data cached across navigations (no refetch on every visit)
/// - Proper loading states via AsyncValue.when()
/// - DevTools observability
/// - Rapid navigation stays race-safe
class FanzoneHubNotifier extends AsyncNotifier<FanzoneHubSnapshot> {
  FanzoneHubNotifier({
    Future<FanzoneHubSnapshot> Function()? loadOverride,
    Duration loadTimeout = const Duration(seconds: 12),
  }) : _loadOverride = loadOverride,
       _loadTimeout = loadTimeout;

  final Future<FanzoneHubSnapshot> Function()? _loadOverride;
  final Duration _loadTimeout;
  bool _connectivityBound = false;
  bool _refreshing = false;
  late bool _wasOnline;

  @override
  Future<FanzoneHubSnapshot> build() async {
    _bindConnectivity();
    return _load();
  }

  /// Refresh the hub data. Used by pull-to-refresh.
  ///
  /// Preserves current data during refresh so the UI doesn't blank out.
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    final previous = state.valueOrNull;
    state = const AsyncLoading<FanzoneHubSnapshot>().copyWithPrevious(state);
    try {
      final loaded = await _load();
      final shouldRetainPrevious =
          previous != null &&
          previous.hasAnyContent &&
          (loaded.status == FanzoneHubStatus.error ||
              !ConnectivityService.isOnline);
      state = AsyncData(
        shouldRetainPrevious
            ? previous.copyWith(
                status: FanzoneHubStatus.degraded,
                message: FanzoneHubSnapshotMessage.savedContent,
              )
            : loaded,
      );
    } catch (error, stackTrace) {
      state = previous != null && previous.hasAnyContent
          ? AsyncData(
              previous.copyWith(
                status: FanzoneHubStatus.degraded,
                message: FanzoneHubSnapshotMessage.savedContent,
              ),
            )
          : AsyncError(error, stackTrace);
    } finally {
      _refreshing = false;
    }
  }

  Future<FanzoneHubSnapshot> _load() async {
    if (!ConnectivityService.isOnline) {
      return const FanzoneHubSnapshot(
        status: FanzoneHubStatus.error,
        message: FanzoneHubSnapshotMessage.connectionRequired,
      );
    }
    final loadOverride = _loadOverride;
    if (loadOverride != null) {
      try {
        return await loadOverride().timeout(_loadTimeout);
      } catch (error) {
        throw FanzoneHubFailure.fromError(error);
      }
    }

    final predictionRepo = ref.read(predictionRepositoryProvider);
    final fetRepo = ref.read(fetRepositoryProvider);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekEnd = today.add(const Duration(days: 7));

    var failures = 0;
    FanzoneHubFailureKind? aggregateFailureKind;
    const totalCalls = 8;

    Future<T?> guarded<T>(Future<T?> Function() load) async {
      try {
        return await load().timeout(_loadTimeout);
      } catch (error, stackTrace) {
        AfriLogger.warn(
          'FanzoneHubProvider',
          'Operation failed (non-critical).',
          error,
          stackTrace,
        );
        failures++;
        final failure = FanzoneHubFailure.fromError(error);
        if (_failurePriority(failure.kind) >
            _failurePriority(aggregateFailureKind)) {
          aggregateFailureKind = failure.kind;
        }
        return null;
      }
    }

    final dashboardFuture = guarded<PredictionDashboard>(
      predictionRepo.loadUserStats,
    );
    final walletFuture = guarded<FetWalletSummary>(() => fetRepo.loadWallet());
    final liveFixturesFuture = guarded<List<FixtureSummary>>(
      () => predictionRepo.loadFixtures(status: 'live', limit: 5),
    );
    final todayFixturesFuture = guarded<List<FixtureSummary>>(
      () => predictionRepo.loadFixturesByDate(dateFrom: today, dateTo: today),
    );
    final upcomingFixturesFuture = guarded<List<FixtureSummary>>(
      () => predictionRepo.loadFixturesByDate(
        dateFrom: tomorrow,
        dateTo: weekEnd,
        limit: 8,
      ),
    );
    final leaderboardFuture = guarded<List<PredictionLeaderboardEntry>>(
      () => predictionRepo.loadLeaderboard(limit: 5),
    );
    final marketsFuture = guarded<List<PredictionMarket>>(
      predictionRepo.loadMarketCatalog,
    );
    final challengesFuture = guarded<List<FetCatalogItem>>(fetRepo.loadCatalog);

    final dashboard = await dashboardFuture;
    final wallet = await walletFuture;
    final liveFixtures = await liveFixturesFuture ?? const <FixtureSummary>[];
    final todayFixtures = await todayFixturesFuture ?? const <FixtureSummary>[];
    final upcomingFixtures =
        await upcomingFixturesFuture ?? const <FixtureSummary>[];
    final leaderboard =
        await leaderboardFuture ?? const <PredictionLeaderboardEntry>[];
    final markets = await marketsFuture ?? const <PredictionMarket>[];
    final challenges = await challengesFuture ?? const <FetCatalogItem>[];

    final FanzoneHubStatus status;
    final String? message;

    if (failures >= totalCalls) {
      throw FanzoneHubFailure(
        aggregateFailureKind ?? FanzoneHubFailureKind.unknown,
      );
    } else if (failures > 0) {
      status = FanzoneHubStatus.degraded;
      message = 'Some sections may be incomplete.';
    } else {
      status = FanzoneHubStatus.ok;
      message = null;
    }

    return FanzoneHubSnapshot(
      dashboard: dashboard,
      wallet: wallet,
      liveFixtures: liveFixtures,
      todayFixtures: todayFixtures,
      upcomingFixtures: upcomingFixtures,
      leaderboard: leaderboard,
      markets: markets,
      challenges: challenges,
      status: status,
      message: message,
    );
  }

  int _failurePriority(FanzoneHubFailureKind? kind) {
    return switch (kind) {
      FanzoneHubFailureKind.permissionDenied => 4,
      FanzoneHubFailureKind.conflict => 3,
      FanzoneHubFailureKind.securityTimeout => 2,
      FanzoneHubFailureKind.unknown => 1,
      null => 0,
    };
  }

  void _bindConnectivity() {
    if (_connectivityBound) return;
    _connectivityBound = true;
    _wasOnline = ConnectivityService.isOnline;
    ConnectivityService.onlineNotifier.addListener(_handleConnectivityChange);
    ref.onDispose(() {
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
            status: FanzoneHubStatus.degraded,
            message: FanzoneHubSnapshotMessage.savedContent,
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

/// Provider for the Fanzone Hub state managed by [FanzoneHubNotifier].
final fanzoneHubProvider =
    AsyncNotifierProvider<FanzoneHubNotifier, FanzoneHubSnapshot>(() {
      return FanzoneHubNotifier();
    });
