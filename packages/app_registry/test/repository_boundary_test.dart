import 'package:app_registry/app_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('registry contains exactly the supported football platform modules', () {
    final modules = AppModuleRegistry.allModules;
    final featureKeys = modules.map((module) => module.featureKey).toSet();
    final routePaths = <String>{};

    for (final module in modules) {
      final tab = module.tabRoute;
      final parentPath = tab?.path ?? '';
      if (tab != null) routePaths.add(tab.path);
      for (final route in module.routes) {
        _collectGoRoutePaths(route, parentPath, routePaths);
      }
      for (final route in module.standaloneRoutes) {
        _collectGoRoutePaths(route, '', routePaths);
      }
    }

    expect(
      featureKeys,
      equals(const <String>{
        'home',
        'club',
        'live',
        'predict',
        'settings',
        'onboarding',
        'membership',
        'contributions',
        'ticketing',
        'fan_clubs',
        'admin',
        'shop',
      }),
    );

    const supportedRouteRoots = <String>{
      '/home',
      '/search',
      '/club',
      '/live',
      '/live-match',
      '/predict',
      '/settings',
      '/splash',
      '/onboarding',
      '/auth',
      '/membership',
      '/contribute',
      '/tickets',
      '/my-tickets',
      '/e-ticket',
      '/fan-clubs',
      '/admin',
      '/shop',
    };

    expect(
      routePaths.where(
        (routePath) => !supportedRouteRoots.any(
          (root) => routePath == root || routePath.startsWith('$root/'),
        ),
      ),
      isEmpty,
    );

    expect(
      routePaths,
      containsAll(const <String>{
        '/club/fixtures',
        '/club/results',
        '/club/standings',
        '/predict/match/:fixtureId',
        '/predict/picks/:predictionId',
        '/membership',
        '/contribute',
        '/tickets',
        '/shop',
      }),
    );
  });
}

void _collectGoRoutePaths(
  RouteBase route,
  String parentPath,
  Set<String> paths,
) {
  if (route is! GoRoute) return;

  final path = route.path.startsWith('/')
      ? route.path
      : '${parentPath.endsWith('/') ? parentPath.substring(0, parentPath.length - 1) : parentPath}/${route.path}';
  paths.add(path);
  for (final child in route.routes) {
    _collectGoRoutePaths(child, path, paths);
  }
}
