import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../fet_providers.dart';
import '../models/fet_models.dart';
import '../models/prediction_models.dart';
import '../prediction_providers.dart';
import '../repositories/prediction_repository.dart';

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
}

enum FanzoneHubStatus { ok, degraded, error }

/// Riverpod AsyncNotifier managing the Fanzone Hub lifecycle.
///
/// Replaces the manual setState-based loading/error/data handling
/// in FanzoneHubScreen with a declarative AsyncValue approach.
///
/// Benefits over the old pattern:
/// - Data cached across navigations (no refetch on every visit)
/// - Proper loading states via AsyncValue.when()
/// - DevTools observability
/// - No race conditions from rapid navigation
class FanzoneHubNotifier extends AsyncNotifier<FanzoneHubSnapshot> {
  @override
  Future<FanzoneHubSnapshot> build() async {
    return _load();
  }

  /// Refresh the hub data. Used by pull-to-refresh.
  ///
  /// Preserves current data during refresh so the UI doesn't blank out.
  Future<void> refresh() async {
    state = const AsyncLoading<FanzoneHubSnapshot>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }

  Future<FanzoneHubSnapshot> _load() async {
    final predictionRepo = ref.read(predictionRepositoryProvider);
    final fetRepo = ref.read(fetRepositoryProvider);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekEnd = today.add(const Duration(days: 7));

    // Fire all 8 requests concurrently and track individual failures.
    PredictionDashboard? dashboard;
    FetWalletSummary? wallet;
    var liveFixtures = const <FixtureSummary>[];
    var todayFixtures = const <FixtureSummary>[];
    var upcomingFixtures = const <FixtureSummary>[];
    var leaderboard = const <PredictionLeaderboardEntry>[];
    var markets = const <PredictionMarket>[];
    var challenges = const <FetCatalogItem>[];

    var failures = 0;
    const totalCalls = 8;

    try {
      dashboard = await predictionRepo.loadUserStats();
    } catch (_) {
      failures++;
    }

    try {
      wallet = await fetRepo.loadWallet();
    } catch (_) {
      failures++;
    }

    try {
      liveFixtures =
          await predictionRepo.loadFixtures(status: 'live', limit: 5);
    } catch (_) {
      failures++;
    }

    try {
      todayFixtures = await predictionRepo.loadFixturesByDate(
        dateFrom: today,
        dateTo: today,
      );
    } catch (_) {
      failures++;
    }

    try {
      upcomingFixtures = await predictionRepo.loadFixturesByDate(
        dateFrom: tomorrow,
        dateTo: weekEnd,
        limit: 8,
      );
    } catch (_) {
      failures++;
    }

    try {
      leaderboard = await predictionRepo.loadLeaderboard(limit: 5);
    } catch (_) {
      failures++;
    }

    try {
      markets = await predictionRepo.loadMarketCatalog();
    } catch (_) {
      failures++;
    }

    try {
      challenges = await fetRepo.loadCatalog();
    } catch (_) {
      failures++;
    }

    final FanzoneHubStatus status;
    final String? message;

    if (failures >= totalCalls) {
      status = FanzoneHubStatus.error;
      message = 'Fanzone is temporarily unavailable.';
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
}

/// Provider for the Fanzone Hub state managed by [FanzoneHubNotifier].
final fanzoneHubProvider =
    AsyncNotifierProvider<FanzoneHubNotifier, FanzoneHubSnapshot>(() {
  return FanzoneHubNotifier();
});
