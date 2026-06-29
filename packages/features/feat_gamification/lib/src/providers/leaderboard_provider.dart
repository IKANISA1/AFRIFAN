import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../fet_providers.dart';
import '../models/fet_models.dart';
import '../models/prediction_models.dart';
import '../prediction_providers.dart';

// ══════════════════════════════════════════════════════════════════════════
// FET LEADERBOARD
// ══════════════════════════════════════════════════════════════════════════

/// Snapshot for the FET Ranking tab.
class FetLeaderboardSnapshot {
  const FetLeaderboardSnapshot({
    this.rows = const <PredictionLeaderboardEntry>[],
    this.period = 'all',
  });

  final List<PredictionLeaderboardEntry> rows;
  final String period;
}

/// Provider family keyed by period ('all', 'weekly', 'monthly').
///
/// Each period gets its own cached state so switching tabs doesn't trigger
/// a refetch unless the cache is invalidated.
class FetLeaderboardNotifier
    extends FamilyAsyncNotifier<FetLeaderboardSnapshot, String> {
  @override
  Future<FetLeaderboardSnapshot> build(String period) async {
    return _load(period);
  }

  /// Refresh the leaderboard for the current period.
  Future<void> refresh() async {
    state = const AsyncLoading<FetLeaderboardSnapshot>().copyWithPrevious(
      state,
    );
    state = await AsyncValue.guard(() => _load(arg));
  }

  Future<FetLeaderboardSnapshot> _load(String period) async {
    final repo = ref.read(predictionRepositoryProvider);
    final rows = await repo.loadLeaderboard(limit: 25, period: period);
    return FetLeaderboardSnapshot(rows: rows, period: period);
  }
}

/// Provider for FET leaderboard data, keyed by period string.
final fetLeaderboardProvider =
    AsyncNotifierProvider.family<
      FetLeaderboardNotifier,
      FetLeaderboardSnapshot,
      String
    >(() {
      return FetLeaderboardNotifier();
    });

// ══════════════════════════════════════════════════════════════════════════
// SUPPORTER LEADERBOARD
// ══════════════════════════════════════════════════════════════════════════

/// Snapshot for the Supporters tab.
class SupporterLeaderboardSnapshot {
  const SupporterLeaderboardSnapshot({this.rows = const <FetLeaderboardRow>[]});

  final List<FetLeaderboardRow> rows;
}

/// AsyncNotifier managing the supporter leaderboard lifecycle.
class SupporterLeaderboardNotifier
    extends AsyncNotifier<SupporterLeaderboardSnapshot> {
  @override
  Future<SupporterLeaderboardSnapshot> build() async {
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<SupporterLeaderboardSnapshot>().copyWithPrevious(
      state,
    );
    state = await AsyncValue.guard(_load);
  }

  Future<SupporterLeaderboardSnapshot> _load() async {
    final repo = ref.read(fetRepositoryProvider);
    final rows = await repo.loadLeaderboard(limit: 25);
    return SupporterLeaderboardSnapshot(rows: rows);
  }
}

/// Provider for supporter leaderboard data.
final supporterLeaderboardProvider =
    AsyncNotifierProvider<
      SupporterLeaderboardNotifier,
      SupporterLeaderboardSnapshot
    >(() {
      return SupporterLeaderboardNotifier();
    });
