import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../fet_providers.dart';
import '../models/fet_models.dart';
import '../models/partner_pool_models.dart';
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
    this.partnerPools = const <PartnerPredictionPool>[],
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
  final List<PartnerPredictionPool> partnerPools;
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
/// - Rapid navigation stays race-safe
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
    final partnerPoolRepo = ref.read(partnerPoolRepositoryProvider);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekEnd = today.add(const Duration(days: 7));

    var failures = 0;
    const totalCalls = 9;

    Future<T?> guarded<T>(Future<T?> Function() load) async {
      try {
        return await load();
      } catch (error, stackTrace) {
        AfriLogger.warn(
          'FanzoneHubProvider',
          'Operation failed (non-critical).',
          error,
          stackTrace,
        );
        failures++;
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
    final partnerPoolsFuture = guarded<List<PartnerPredictionPool>>(
      () => partnerPoolRepo.loadPools(limit: 4),
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
    final partnerPools =
        await partnerPoolsFuture ?? const <PartnerPredictionPool>[];
    final markets = await marketsFuture ?? const <PredictionMarket>[];
    final challenges = await challengesFuture ?? const <FetCatalogItem>[];

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
      partnerPools: partnerPools,
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
