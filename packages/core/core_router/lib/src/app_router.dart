import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'feature_module.dart';
import 'route_recovery_screens.dart';

/// App router factory — builds GoRouter from registered feature modules.
class AppRouter {
  final List<FeatureModule> modules;
  final Widget Function(BuildContext context, StatefulNavigationShell shell)
  shellBuilder;
  final String? _explicitInitialLocation;
  final GoRouterRedirect? redirect;
  final Listenable? refreshListenable;
  final GoRouterWidgetBuilder? errorBuilder;
  final List<NavigatorObserver> observers;
  final bool Function(String path)? isFeatureEnabled;

  AppRouter({
    required this.modules,
    required this.shellBuilder,
    String? initialLocation,
    this.redirect,
    this.refreshListenable,
    this.errorBuilder,
    this.observers = const <NavigatorObserver>[],
    this.isFeatureEnabled,
  }) : _explicitInitialLocation = initialLocation;

  String get initialLocation =>
      _explicitInitialLocation ?? _resolveInitialLocation();

  late final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    redirect: (context, state) {
      // 1. Feature Gate Check
      if (isFeatureEnabled != null) {
        final path = state.uri.path;
        if (path != '/' &&
            path != '/home' &&
            path != '/feature-unavailable' &&
            !isFeatureEnabled!(path)) {
          return Uri(
            path: '/feature-unavailable',
            queryParameters: <String, String>{'from': path},
          ).toString();
        }
      }

      // 2. Custom Redirect
      if (redirect != null) {
        return redirect!(context, state);
      }

      return null;
    },
    refreshListenable: refreshListenable,
    observers: observers,
    errorBuilder:
        errorBuilder ??
        (context, state) => RouteRecoveryScreen(
          kind: RouteRecoveryKind.routerError,
          fallbackLocation: initialLocation,
          visualState: RouteRecoveryScreen.classifyRouterError(state.error),
          requestedPath: state.uri.path,
        ),
    routes: [
      GoRoute(
        path: '/feature-unavailable',
        builder: (context, state) => RouteRecoveryScreen(
          kind: RouteRecoveryKind.featureUnavailable,
          fallbackLocation: initialLocation,
          visualState: RouteRecoveryVisualState.disabled,
          requestedPath: state.uri.queryParameters['from'],
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => shellBuilder(context, shell),
        branches: _buildBranches(),
      ),
      // Non-tab routes from all modules
      ..._buildStandaloneRoutes(),
    ],
  );

  /// Build shell branches from tab routes.
  List<StatefulShellBranch> _buildBranches() {
    final tabModules =
        modules
            .where(
              (module) =>
                  module.tabRoute != null &&
                  shellBranchFeatureKeys.contains(module.featureKey),
            )
            .toList()
          ..sort(
            (left, right) => shellBranchOrderForFeature(
              left.featureKey,
            ).compareTo(shellBranchOrderForFeature(right.featureKey)),
          );

    return tabModules.map((module) {
      final tab = module.tabRoute!;
      return StatefulShellBranch(
        routes: [
          GoRoute(
            path: tab.path,
            name: tab.path.replaceFirst('/', ''),
            builder: tab.builder,
            routes: module.routes,
          ),
        ],
      );
    }).toList();
  }

  /// Collect top-level standalone routes:
  /// 1. All routes from non-tab modules (their routes are standalone by nature).
  /// 2. standaloneRoutes from ALL modules (including tab modules).
  List<RouteBase> _buildStandaloneRoutes() {
    final nonTabRoutes = modules
        .where((m) => m.tabRoute == null)
        .expand((m) => m.routes);

    final explicitStandalone = modules.expand((m) => m.standaloneRoutes);

    return [...nonTabRoutes, ...explicitStandalone];
  }

  /// Get tab info for building bottom nav.
  List<TabRoute> get tabs {
    final tabModules =
        modules
            .where(
              (module) =>
                  module.tabRoute != null &&
                  primaryBottomTabFeatureKeys.contains(module.featureKey),
            )
            .toList()
          ..sort(
            (left, right) => primaryBottomTabOrderForFeature(
              left.featureKey,
            ).compareTo(primaryBottomTabOrderForFeature(right.featureKey)),
          );

    return tabModules.map((module) => module.tabRoute!).toList();
  }

  String _resolveInitialLocation() {
    final tabModules =
        modules
            .where(
              (module) =>
                  module.tabRoute != null &&
                  primaryBottomTabFeatureKeys.contains(module.featureKey),
            )
            .toList()
          ..sort(
            (left, right) => primaryBottomTabOrderForFeature(
              left.featureKey,
            ).compareTo(primaryBottomTabOrderForFeature(right.featureKey)),
          );

    for (final module in tabModules) {
      final tabRoute = module.tabRoute;
      if (tabRoute != null) {
        return tabRoute.path;
      }
    }

    final standaloneRoutes = _buildStandaloneRoutes();
    for (final route in standaloneRoutes) {
      if (route is GoRoute &&
          route.path.startsWith('/') &&
          route.path != '/splash') {
        return route.path;
      }
    }

    throw StateError(
      'AppRouter requires at least one tab route or absolute standalone route.',
    );
  }
}
