import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Abstract interface for feature modules.
///
/// Every feature package exports a single FeatureModule that
/// registers its routes. The app bootstrap collects all modules
/// and builds the GoRouter.
abstract class FeatureModule {
  /// Feature key — must match ClubConfig.features key.
  String get featureKey;

  /// Whether this module should be registered for the current app flavor.
  ///
  /// Missing keys are treated as always-on so core modules do not need to be
  /// redundantly listed in every club configuration package.
  bool isEnabled(Map<String, bool> featureFlags) {
    return featureFlags[featureKey] ?? true;
  }

  /// Routes contributed by this module.
  /// For tab modules, these are nested sub-routes under the tab path.
  /// For non-tab modules, these become top-level standalone routes.
  List<RouteBase> get routes => const [];

  /// Optional: tab route for bottom navigation.
  /// If non-null, this route appears as a bottom nav tab.
  TabRoute? get tabRoute => null;

  /// Optional: additional top-level standalone routes contributed by
  /// any module (including tab modules). These are registered at the
  /// root level of the router, independent of shell branches.
  ///
  /// Use this when a tab module needs to provide a route that is
  /// pushed absolutely (e.g. context.push('/profile_setup')) from
  /// multiple unrelated features.
  List<RouteBase> get standaloneRoutes => const [];
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
