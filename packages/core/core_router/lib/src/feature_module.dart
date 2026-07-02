import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

String _normalizeFeatureKey(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return '';
  }

  return normalized
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

/// The only feature modules allowed to render in the mobile bottom nav.
const List<String> primaryBottomTabFeatureOrder = <String>[
  'home',
  'fanzone',
  'settings',
];

const Set<String> primaryBottomTabFeatureKeys = <String>{
  'home',
  'fanzone',
  'settings',
};

int primaryBottomTabOrderForFeature(String featureKey) {
  final index = primaryBottomTabFeatureOrder.indexOf(featureKey);
  if (index >= 0) {
    return index;
  }
  return primaryBottomTabFeatureOrder.length;
}

/// Abstract interface for feature modules.
///
/// Every feature package exports a single FeatureModule that
/// registers its routes. The app bootstrap collects all modules
/// and builds the GoRouter.
abstract class FeatureModule {
  /// Feature key — must match ClubConfig.features key AND
  /// `platform_features.feature_key` in Supabase.
  String get featureKey;

  /// Feature category for grouping in admin UI.
  String get category => 'core';

  /// Whether this module should be registered for the current app flavor.
  ///
  /// Missing keys are treated as always-on so core modules do not need to be
  /// redundantly listed in every club configuration package.
  bool isEnabled(Map<String, bool> featureFlags) {
    return featureFlags[featureKey] ?? true;
  }

  /// Config-aware enablement check.
  ///
  /// When a [PlatformConfigSnapshot] is available (fetched from Supabase),
  /// this checks `isEffectivelyEnabled` on the matching feature.
  /// Falls back to [isEnabled] with compile-time [featureFlags] when:
  ///   - The config snapshot is null (network failed, first run)
  ///   - The feature is not found in the snapshot
  ///
  /// This method is called by [AppModuleRegistry.build()] after bootstrap.
  bool isEnabledForConfig({
    Map<String, bool> featureFlags = const <String, bool>{},
    Map<String, dynamic>? configSnapshot,
  }) {
    if (configSnapshot != null) {
      final features = configSnapshot['features'];
      if (features is List) {
        for (final raw in features) {
          if (raw is Map<String, dynamic> &&
              _normalizeFeatureKey(raw['feature_key'] as String? ?? '') ==
                  _normalizeFeatureKey(featureKey)) {
            // Module registration should follow operational availability.
            // Hidden features remain registered so routes and deep links can be
            // handled gracefully, but maintenance / disabled features are
            // removed entirely.
            final isGlobalEnabled = raw['is_enabled'] as bool? ?? true;
            final visibility = raw['visibility_state'] as String? ?? 'visible';
            final channel = raw['channel'] as Map<String, dynamic>?;
            final channelEnabled = channel?['is_enabled'] as bool? ?? true;
            final rules = raw['rules'] as Map<String, dynamic>?;
            final isWithinSchedule =
                rules?['is_within_schedule'] as bool? ?? true;

            return isGlobalEnabled &&
                channelEnabled &&
                visibility != 'maintenance' &&
                isWithinSchedule;
          }
        }
      }
    }
    // Not in config → fall back to compile-time flags.
    return isEnabled(featureFlags);
  }

  /// Routes contributed by this module.
  /// For tab modules, these are nested sub-routes under the tab path.
  /// For non-tab modules, these become top-level standalone routes.
  List<RouteBase> get routes => const [];

  /// Product-level presentation decisions for this module's routes.
  ///
  /// This metadata keeps the route tree honest: a route can remain registered
  /// for deep links while the app presents it as a sheet, consolidated hub
  /// section, redirect, or internal-only surface instead of another full page.
  List<RoutePresentationDecision> get routePresentationDecisions => const [];

  /// Optional: tab route for bottom navigation.
  /// If non-null, this route appears as a bottom nav tab.
  TabRoute? get tabRoute => null;

  /// Optional: additional top-level standalone routes contributed by
  /// any module (including tab modules). These are registered at the
  /// root level of the router, independent of shell branches.
  ///
  /// Use this when a tab module needs to provide a route that is pushed
  /// absolutely from multiple unrelated features.
  List<RouteBase> get standaloneRoutes => const [];

  /// Paths that are accessible without authentication.
  ///
  /// Override in modules that provide pre-auth routes (splash, onboarding,
  /// phone auth). These paths bypass the auth redirect guard.
  Set<String> get publicPaths => const <String>{};
}

/// The intended product surface for a route.
enum RoutePresentation {
  fullScreen,
  modalSheet,
  fullHeightSheet,
  consolidatedHub,
  deepLinkOnly,
  redirect,
  internalOnly,
}

/// Product decision attached to a registered route.
class RoutePresentationDecision {
  const RoutePresentationDecision({
    required this.path,
    required this.presentation,
    required this.recommendation,
    required this.rationale,
    this.targetPath,
  });

  /// Absolute route path or route pattern.
  final String path;

  /// How the route should appear in the mobile product.
  final RoutePresentation presentation;

  /// Short action label such as keep, merge, convert to sheet, or hide.
  final String recommendation;

  /// Destination hub when the route is consolidated, redirected, or sheeted
  /// from another surface.
  final String? targetPath;

  /// Why this presentation is the right product decision.
  final String rationale;
}

/// Describes a bottom navigation tab provided by a feature.
class TabRoute {
  final String path;
  final String label;
  final IconData icon;
  final IconData? activeIcon;
  final Widget Function(BuildContext, GoRouterState) builder;

  const TabRoute({
    required this.path,
    required this.label,
    required this.icon,
    this.activeIcon,
    required this.builder,
  });
}
