import '../models/platform_feature_config.dart';
import '../policies/store_release_policy.dart';

const List<MapEntry<String, String>> _fallbackRouteFeatureKeys =
    <MapEntry<String, String>>[
      MapEntry<String, String>('/tickets', 'ticketing'),
      MapEntry<String, String>('/membership', 'membership'),
      MapEntry<String, String>('/fan-clubs', 'fan_clubs'),
      MapEntry<String, String>('/groups', 'contributions'),
      MapEntry<String, String>('/circles', 'contributions'),
      MapEntry<String, String>('/contribute', 'contributions'),
      MapEntry<String, String>('/shop', 'shop'),
      MapEntry<String, String>('/venues', 'venue_app'),
      MapEntry<String, String>('/venue', 'venue_app'),
      MapEntry<String, String>('/fixtures', 'live'),
      MapEntry<String, String>('/results', 'live'),
      MapEntry<String, String>('/standings', 'live'),
      MapEntry<String, String>('/news', 'news'),
      MapEntry<String, String>('/squad', 'squad'),
      MapEntry<String, String>('/fanzone', 'fanzone'),
      MapEntry<String, String>('/predict', 'predict'),
      MapEntry<String, String>('/admin', 'admin'),
    ];

const List<MapEntry<String, String>> _launchOptInRouteFeatureKeys =
    <MapEntry<String, String>>[
      MapEntry<String, String>('/fanzone/jackpot', 'challenge'),
      MapEntry<String, String>('/fanzone/challenges', 'challenge'),
      MapEntry<String, String>('/fanzone/challenge', 'challenge'),
      MapEntry<String, String>('/fanzone/friends', 'challenge'),
      MapEntry<String, String>('/fanzone/venue', 'venue_checkin'),
      MapEntry<String, String>('/predict', 'predict'),
    ];

/// Central service answering all feature-availability questions.
///
/// This is the single source of truth used by the mobile app, route guards,
/// home composition, navigation, and deep link handlers.
class FeatureConfigService {
  const FeatureConfigService(
    this._snapshot, {
    this.isAuthenticated = false,
    this.roles = const <String>{},
    this.storeReleasePolicy = const StoreReleasePolicy(isEnforced: true),
  });

  final PlatformConfigSnapshot _snapshot;
  final bool isAuthenticated;
  final Set<String> roles;
  final StoreReleasePolicy storeReleasePolicy;

  PlatformConfigSnapshot get snapshot => _snapshot;

  bool get hasConfig => _snapshot.isNotEmpty;

  FeatureAccessState getFeatureAccess(
    String featureKey, {
    bool? isAuthenticated,
    Iterable<String>? roles,
  }) {
    return _getFeatureAccess(
      featureKey,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      roles: roles ?? this.roles,
      visited: <String>{},
    );
  }

  FeatureAccessState _getFeatureAccess(
    String featureKey, {
    required bool isAuthenticated,
    required Iterable<String> roles,
    required Set<String> visited,
  }) {
    final normalizedKey = normalizePlatformFeatureKey(featureKey);
    final feature = _snapshot.featureByKey(normalizedKey);

    if (feature == null) {
      return FeatureAccessState(
        featureKey: featureKey,
        normalizedKey: normalizedKey,
        isRegistered: false,
        isVisible: true,
        isOperational: true,
        isAvailable: true,
        showInNavigation: false,
        showOnHome: false,
        routeKey: null,
        placementKey: null,
        reason: 'unregistered',
      );
    }

    final normalizedRoles = roles
        .map(normalizePlatformFeatureKey)
        .where((role) => role.isNotEmpty)
        .toSet();
    final visibilityState = feature.visibilityState;
    final channel = feature.channel;
    final rules = feature.rules;

    final isVisible =
        visibilityState != 'hidden' && (channel?.isVisible ?? true);
    final dependencies = rules?.dependencyRules['requires'];
    final nextVisited = <String>{...visited, normalizedKey};
    final dependenciesSatisfied =
        dependencies is! List ||
        dependencies.every((dependency) {
          if (dependency is! String) {
            return true;
          }
          final normalizedDependency = normalizePlatformFeatureKey(dependency);
          if (nextVisited.contains(normalizedDependency)) {
            return true;
          }
          return _getFeatureAccess(
            dependency,
            isAuthenticated: isAuthenticated,
            roles: normalizedRoles,
            visited: nextVisited,
          ).isOperational;
        });

    final roleRestrictions = (rules?.roleRestrictions ?? <String>[])
        .map(normalizePlatformFeatureKey)
        .where((role) => role.isNotEmpty)
        .toSet();
    final authAllowed = !(rules?.authRequired ?? false) || isAuthenticated;
    final roleAllowed =
        roleRestrictions.isEmpty ||
        (isAuthenticated && normalizedRoles.any(roleRestrictions.contains));
    final isWithinSchedule = rules?.isWithinSchedule ?? true;

    final isOperational =
        feature.isOperationallyEnabled && dependenciesSatisfied;
    final isAvailable = isOperational && authAllowed && roleAllowed;

    var reason = 'ok';
    if (!feature.isEnabled) {
      reason = 'global_disabled';
    } else if (!(channel?.isEnabled ?? true)) {
      reason = 'channel_disabled';
    } else if (visibilityState == 'hidden') {
      reason = 'hidden';
    } else if (!(channel?.isVisible ?? true)) {
      reason = 'channel_hidden';
    } else if (visibilityState == 'maintenance') {
      reason = 'maintenance';
    } else if (!isWithinSchedule) {
      reason = 'outside_schedule';
    } else if (!dependenciesSatisfied) {
      reason = 'dependency_blocked';
    } else if (!authAllowed) {
      reason = 'auth_required';
    } else if (!roleAllowed) {
      reason = 'role_restricted';
    }

    return FeatureAccessState(
      feature: feature,
      featureKey: feature.featureKey,
      normalizedKey: normalizedKey,
      isRegistered: true,
      isVisible: isVisible,
      isOperational: isOperational,
      isAvailable: isAvailable,
      showInNavigation: channel?.showInNavigation ?? false,
      showOnHome: channel?.showOnHome ?? false,
      routeKey: channel?.routeKey,
      placementKey: channel?.placementKey,
      reason: reason,
    );
  }

  /// Enablement check for existing UI entry points.
  ///
  /// This keeps hidden features out of UI entry points while
  /// [`isFeatureOperational`] and [`canUseFeature`] preserve the more precise
  /// operational distinction for routing and business actions.
  bool isFeatureEnabled(String featureKey) {
    final access = getFeatureAccess(featureKey);
    return access.isVisible && access.isOperational;
  }

  bool isFeatureOperational(String featureKey) {
    return getFeatureAccess(featureKey).isOperational;
  }

  bool canRenderFeature(String featureKey) {
    final access = getFeatureAccess(featureKey);
    return access.isVisible && access.isAvailable;
  }

  bool canUseFeature(String featureKey) {
    return getFeatureAccess(featureKey).isAvailable;
  }

  bool isFeatureVisible(String featureKey) {
    return getFeatureAccess(featureKey).isVisible;
  }

  bool isFeatureInMaintenance(String featureKey) {
    final feature = _snapshot.featureByKey(featureKey);
    if (feature == null) return false;
    return feature.visibilityState == 'maintenance';
  }

  bool shouldShowInNav(String featureKey) {
    final access = getFeatureAccess(featureKey);
    return access.showInNavigation && access.isVisible && access.isAvailable;
  }

  bool shouldShowOnHome(String featureKey) {
    final access = getFeatureAccess(featureKey);
    return access.showOnHome && access.isVisible && access.isAvailable;
  }

  bool isAuthRequired(String featureKey) {
    final feature = _snapshot.featureByKey(featureKey);
    if (feature == null) return false;
    return feature.rules?.authRequired ?? false;
  }

  bool isInsideScheduleWindow(String featureKey) {
    final feature = _snapshot.featureByKey(featureKey);
    if (feature == null) return true;
    return feature.rules?.isWithinSchedule ?? true;
  }

  bool areDependenciesSatisfied(String featureKey) {
    return getFeatureAccess(featureKey).reason != 'dependency_blocked';
  }

  String? getRoute(String featureKey) {
    return getFeatureAccess(featureKey).routeKey;
  }

  int? getSortOrder(String featureKey) {
    return _snapshot.featureByKey(featureKey)?.channel?.sortOrder;
  }

  PlatformFeature? getFeature(String featureKey) {
    return _snapshot.featureByKey(featureKey);
  }

  List<PlatformFeature> getNavFeatures() {
    return _snapshot.features
        .where((feature) => shouldShowInNav(feature.featureKey))
        .toList()
      ..sort(_bySortOrder);
  }

  List<PlatformFeature> getHomeFeatures() {
    return _snapshot.features
        .where((feature) => shouldShowOnHome(feature.featureKey))
        .toList()
      ..sort(_bySortOrder);
  }

  List<ContentBlock> getContentBlocks(String placementKey) {
    return _snapshot.contentBlocks.where((block) {
      if (block.placementKey != placementKey) return false;
      if (!block.isActive) return false;
      if (block.featureKey != null) {
        return canRenderFeature(block.featureKey!);
      }
      return true;
    }).toList()..sort(_byBlockSortOrder);
  }

  String? getFeatureKeyForPath(String path) {
    final normalizedPath = _normalizeRoutePath(path);
    if (normalizedPath.isEmpty || normalizedPath == '/') {
      return null;
    }

    final registeredRoute = _snapshot.routeByPath(normalizedPath);
    if (registeredRoute != null &&
        registeredRoute.featureKey.trim().isNotEmpty) {
      return registeredRoute.featureKey;
    }

    final routeMatch =
        _snapshot.features
            .map(
              (feature) => MapEntry<String, String>(
                feature.featureKey,
                feature.channel?.routeKey?.trim().toLowerCase() ?? '',
              ),
            )
            .where((entry) => entry.value.startsWith('/'))
            .toList()
          ..sort(
            (left, right) => right.value.length.compareTo(left.value.length),
          );

    for (final entry in routeMatch) {
      if (entry.value == normalizedPath ||
          normalizedPath.startsWith('${entry.value}/')) {
        return entry.key;
      }
    }

    for (final fallback in _fallbackRouteFeatureKeys) {
      if (fallback.key == normalizedPath ||
          normalizedPath.startsWith('${fallback.key}/')) {
        return fallback.value;
      }
    }

    return null;
  }

  bool isRouteAvailable(String path) {
    if (!storeReleasePolicy.isRouteAllowed(path)) {
      return false;
    }

    // M-8: Admin routes are always available — admin access is enforced by
    // the AdminRouteGuard (RBAC), not by public feature gating.
    final normalizedPath = _normalizeRoutePath(path);
    if (normalizedPath.startsWith('/admin')) {
      return true;
    }

    final launchOptInFeatureKey = _getLaunchOptInFeatureKeyForPath(
      normalizedPath,
    );
    if (launchOptInFeatureKey != null) {
      return _canRenderRegisteredFeature(launchOptInFeatureKey);
    }

    final featureKey = getFeatureKeyForPath(normalizedPath);
    if (featureKey == null) {
      return true;
    }

    return canRenderFeature(featureKey);
  }

  String? _getLaunchOptInFeatureKeyForPath(String normalizedPath) {
    for (final route in _launchOptInRouteFeatureKeys) {
      if (route.key == normalizedPath ||
          normalizedPath.startsWith('${route.key}/')) {
        return route.value;
      }
    }
    return null;
  }

  bool _canRenderRegisteredFeature(String featureKey) {
    final normalizedKey = normalizePlatformFeatureKey(featureKey);
    if (_snapshot.featureByKey(normalizedKey) == null) {
      return false;
    }
    return canRenderFeature(normalizedKey);
  }

  String _normalizeRoutePath(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final parsed = Uri.tryParse(trimmed);
    final path = parsed?.path.trim();
    return (path == null || path.isEmpty ? trimmed : path).toLowerCase();
  }

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
