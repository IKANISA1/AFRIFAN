import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/home_content_repository.dart';
import 'package:core_utils/core_utils.dart';

/// Riverpod AsyncNotifier managing the home feed lifecycle.
///
/// Replaces the manual setState-based loading/error/data handling
/// in HomeScreen with a declarative AsyncValue approach.
class HomeFeedNotifier extends AsyncNotifier<HomeFeedSnapshot> {
  int _latestIntelRefreshKey = 0;

  /// Monotonically increasing key used by LatestIntelSection
  /// to trigger its own independent child refresh cycle.
  int get latestIntelRefreshKey => _latestIntelRefreshKey;

  @override
  Future<HomeFeedSnapshot> build() async {
    return _load();
  }

  /// Refresh the home feed data. Used by pull-to-refresh.
  Future<void> refresh() async {
    // Preserve current data during refresh so the UI doesn't blank out.
    state = const AsyncLoading<HomeFeedSnapshot>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
    _latestIntelRefreshKey++;
  }

  Future<HomeFeedSnapshot> _load() async {
    final repo = ref.read(homeFeedRepositoryProvider);
    try {
      return await repo.load();
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'HomeFeedProvider',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      return const HomeFeedSnapshot(
        status: HomeFeedStatus.error,
        message: 'Live club data is temporarily unavailable. Pull to refresh.',
      );
    }
  }
}

/// Provider for the home feed state managed by [HomeFeedNotifier].
final homeFeedProvider =
    AsyncNotifierProvider<HomeFeedNotifier, HomeFeedSnapshot>(() {
      return HomeFeedNotifier();
    });
