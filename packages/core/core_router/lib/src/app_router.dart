import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'feature_module.dart';

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

  AppRouter({
    required this.modules,
    required this.shellBuilder,
    String? initialLocation,
    this.redirect,
    this.refreshListenable,
    this.errorBuilder,
    this.observers = const <NavigatorObserver>[],
  }) : _explicitInitialLocation = initialLocation;

  String get initialLocation =>
      _explicitInitialLocation ?? _resolveInitialLocation();

  late final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    redirect: redirect,
    refreshListenable: refreshListenable,
    observers: observers,
    errorBuilder:
        errorBuilder ??
        (context, state) => _RouterErrorScreen(
          error: state.error,
          fallbackLocation: initialLocation,
        ),
    routes: [
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
    final tabModules = modules.where((m) => m.tabRoute != null).toList();

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
  List<TabRoute> get tabs =>
      modules.where((m) => m.tabRoute != null).map((m) => m.tabRoute!).toList();

  String _resolveInitialLocation() {
    final standaloneRoutes = _buildStandaloneRoutes();
    for (final route in standaloneRoutes) {
      if (route is GoRoute && route.path == '/splash') {
        return route.path;
      }
    }

    for (final module in modules) {
      final tabRoute = module.tabRoute;
      if (tabRoute != null) {
        return tabRoute.path;
      }
    }

    for (final route in standaloneRoutes) {
      if (route is GoRoute && route.path.startsWith('/')) {
        return route.path;
      }
    }

    throw StateError(
      'AppRouter requires at least one tab route or absolute standalone route.',
    );
  }
}

class _RouterErrorScreen extends StatelessWidget {
  const _RouterErrorScreen({
    required this.error,
    required this.fallbackLocation,
  });

  final Exception? error;
  final String fallbackLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48),
              const SizedBox(height: 16),
              const Text(
                'We could not open that page.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(fallbackLocation),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
