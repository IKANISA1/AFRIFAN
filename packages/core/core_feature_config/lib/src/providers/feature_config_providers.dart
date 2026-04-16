import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/platform_feature_config.dart';
import '../repositories/feature_config_repository.dart';
import '../services/feature_config_service.dart';

/// Singleton repository provider.
/// The repository doesn't need constructor args — it uses SafeRpc internally.
final featureConfigRepositoryProvider = Provider<FeatureConfigRepository>(
  (ref) => FeatureConfigRepository(),
);

/// AsyncNotifier managing the platform feature config lifecycle.
///
/// Must be initialized with clubId after bootstrap.
/// Call `ref.read(featureConfigProvider.notifier).loadForClub(clubId)`
/// during app startup.
class FeatureConfigNotifier extends AsyncNotifier<PlatformConfigSnapshot> {
  @override
  Future<PlatformConfigSnapshot> build() async {
    // Returns empty initially — loadForClub() is called during bootstrap.
    return const PlatformConfigSnapshot();
  }

  /// Load the platform config for a specific club.
  /// Called once during app bootstrap.
  Future<void> loadForClub(int clubId, {String channel = 'mobile'}) async {
    state = const AsyncLoading<PlatformConfigSnapshot>()
        .copyWithPrevious(state);
    final repo = ref.read(featureConfigRepositoryProvider);
    state = await AsyncValue.guard(
      () => repo.loadConfig(clubId: clubId, channel: channel),
    );
  }

  /// Hydrate from a pre-fetched bootstrap snapshot.
  ///
  /// Called once during app initialization to seed the reactive provider graph
  /// with the snapshot that was already fetched during [bootstrap()].
  /// Avoids a redundant network call.
  void hydrateFromBootstrap(PlatformConfigSnapshot snapshot) {
    state = AsyncData<PlatformConfigSnapshot>(snapshot);
  }

  /// Refresh the feature config from the server.
  Future<void> refresh(int clubId, {String channel = 'mobile'}) async {
    state = const AsyncLoading<PlatformConfigSnapshot>()
        .copyWithPrevious(state);
    final repo = ref.read(featureConfigRepositoryProvider);
    state = await AsyncValue.guard(
      () => repo.loadConfig(clubId: clubId, channel: channel),
    );
  }
}

/// Provider for the feature config state.
final featureConfigProvider = AsyncNotifierProvider<
    FeatureConfigNotifier, PlatformConfigSnapshot>(
  FeatureConfigNotifier.new,
);

/// Derived provider for the [FeatureConfigService].
///
/// Returns service wrapping the current snapshot (or empty if still loading).
final featureConfigServiceProvider = Provider<FeatureConfigService>((ref) {
  final asyncConfig = ref.watch(featureConfigProvider);
  final snapshot =
      asyncConfig.valueOrNull ?? const PlatformConfigSnapshot();
  return FeatureConfigService(snapshot);
});

/// Check if a specific feature is enabled.
///
/// Usage: `ref.watch(isFeatureEnabledProvider('ticketing'))`
final isFeatureEnabledProvider = Provider.family<bool, String>(
  (ref, featureKey) {
    final service = ref.watch(featureConfigServiceProvider);
    return service.isFeatureEnabled(featureKey);
  },
);

/// Check if a feature should show in navigation.
final shouldShowInNavProvider = Provider.family<bool, String>(
  (ref, featureKey) {
    final service = ref.watch(featureConfigServiceProvider);
    return service.shouldShowInNav(featureKey);
  },
);

/// Check if a feature should show on home.
final shouldShowOnHomeProvider = Provider.family<bool, String>(
  (ref, featureKey) {
    final service = ref.watch(featureConfigServiceProvider);
    return service.shouldShowOnHome(featureKey);
  },
);

/// Features to show in navigation, sorted by sort_order.
final navFeaturesProvider = Provider<List<PlatformFeature>>((ref) {
  final service = ref.watch(featureConfigServiceProvider);
  return service.getNavFeatures();
});

/// Features to show on home, sorted by sort_order.
final homeFeaturesProvider = Provider<List<PlatformFeature>>((ref) {
  final service = ref.watch(featureConfigServiceProvider);
  return service.getHomeFeatures();
});

/// Content blocks for a specific placement.
final contentBlocksProvider = Provider.family<List<ContentBlock>, String>(
  (ref, placementKey) {
    final service = ref.watch(featureConfigServiceProvider);
    return service.getContentBlocks(placementKey);
  },
);
