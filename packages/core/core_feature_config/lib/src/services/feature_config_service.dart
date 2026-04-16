import '../models/platform_feature_config.dart';

/// Central service answering all feature-availability questions.
///
/// This is the **single source of truth** used by the mobile app,
/// route guards, home composition, navigation, and deep link handlers.
///
/// It wraps a [PlatformConfigSnapshot] and provides typed query methods.
/// When no config is available, methods default to "enabled" for backward
/// compatibility with the compile-time [ClubConfig.features] approach.
class FeatureConfigService {
  const FeatureConfigService(this._snapshot);

  final PlatformConfigSnapshot _snapshot;

  /// The raw snapshot, if needed for debugging or admin previews.
  PlatformConfigSnapshot get snapshot => _snapshot;

  /// Whether config was successfully loaded (vs. empty fallback).
  bool get hasConfig => _snapshot.isNotEmpty;

  // ── Feature queries ──

  /// Is this feature effectively enabled for the current channel?
  /// Checks: global enable, channel enable, visibility state, schedule.
  bool isFeatureEnabled(String featureKey) {
    final feature = _snapshot.featureByKey(featureKey);
    if (feature == null) {
      // Feature not in registry → default enabled (backward compat)
      return true;
    }
    return feature.isEffectivelyEnabled;
  }

  /// Is this feature visible? (not hidden or in maintenance)
  bool isFeatureVisible(String featureKey) {
    final feature = _snapshot.featureByKey(featureKey);
    if (feature == null) return true;
    return feature.visibilityState != 'hidden';
  }

  /// Is the feature in maintenance mode?
  bool isFeatureInMaintenance(String featureKey) {
    final feature = _snapshot.featureByKey(featureKey);
    if (feature == null) return false;
    return feature.visibilityState == 'maintenance';
  }

  /// Should this feature appear in navigation?
  bool shouldShowInNav(String featureKey) {
    final feature = _snapshot.featureByKey(featureKey);
    if (feature == null) return false;
    return feature.isEffectivelyEnabled &&
        (feature.channel?.showInNavigation ?? false);
  }

  /// Should this feature appear on the home screen?
  bool shouldShowOnHome(String featureKey) {
    final feature = _snapshot.featureByKey(featureKey);
    if (feature == null) return false;
    return feature.isEffectivelyEnabled &&
        (feature.channel?.showOnHome ?? false);
  }

  /// Does this feature require authentication?
  bool isAuthRequired(String featureKey) {
    final feature = _snapshot.featureByKey(featureKey);
    if (feature == null) return false;
    return feature.rules?.authRequired ?? false;
  }

  /// Is the feature currently within its scheduled window?
  bool isInsideScheduleWindow(String featureKey) {
    final feature = _snapshot.featureByKey(featureKey);
    if (feature == null) return true;
    return feature.rules?.isWithinSchedule ?? true;
  }

  /// Are all dependency features also enabled?
  bool areDependenciesSatisfied(String featureKey) {
    final feature = _snapshot.featureByKey(featureKey);
    if (feature == null) return true;

    final deps = feature.rules?.dependencyRules ?? const <String, dynamic>{};
    final requires = deps['requires'];
    if (requires is! List || requires.isEmpty) return true;

    for (final dep in requires) {
      if (dep is String && !isFeatureEnabled(dep)) {
        return false;
      }
    }
    return true;
  }

  /// Get the route key for a feature.
  String? getRoute(String featureKey) {
    return _snapshot.featureByKey(featureKey)?.channel?.routeKey;
  }

  /// Get the sort order for a feature.
  int? getSortOrder(String featureKey) {
    return _snapshot.featureByKey(featureKey)?.channel?.sortOrder;
  }

  /// Get the full feature config.
  PlatformFeature? getFeature(String featureKey) {
    return _snapshot.featureByKey(featureKey);
  }

  // ── Aggregate queries ──

  /// All features that should appear in navigation, sorted by sort_order.
  List<PlatformFeature> getNavFeatures() {
    return _snapshot.features
        .where(
          (f) =>
              f.isEffectivelyEnabled &&
              (f.channel?.showInNavigation ?? false),
        )
        .toList()
      ..sort(_bySortOrder);
  }

  /// All features that should appear on the home screen, sorted by sort_order.
  List<PlatformFeature> getHomeFeatures() {
    return _snapshot.features
        .where(
          (f) =>
              f.isEffectivelyEnabled && (f.channel?.showOnHome ?? false),
        )
        .toList()
      ..sort(_bySortOrder);
  }

  // ── Content block queries ──

  /// Get content blocks for a given placement.
  /// Returns only blocks whose linked feature is enabled (or unlinked blocks).
  List<ContentBlock> getContentBlocks(String placementKey) {
    return _snapshot.contentBlocks
        .where((block) {
          if (block.placementKey != placementKey) return false;
          if (!block.isActive) return false;
          if (block.featureKey != null) {
            return isFeatureEnabled(block.featureKey!);
          }
          return true;
        })
        .toList()
      ..sort(_byBlockSortOrder);
  }

  // ── Private helpers ──

  static int _bySortOrder(PlatformFeature a, PlatformFeature b) {
    final aOrder = a.channel?.sortOrder ?? 999;
    final bOrder = b.channel?.sortOrder ?? 999;
    return aOrder.compareTo(bOrder);
  }

  static int _byBlockSortOrder(ContentBlock a, ContentBlock b) {
    final aOrder = a.sortOrder ?? 999;
    final bOrder = b.sortOrder ?? 999;
    return aOrder.compareTo(bOrder);
  }
}
