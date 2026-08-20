import 'package:app_registry/app_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('registry contains no retired TV or trivia modules and routes', () {
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
      featureKeys.intersection(const <String>{
        'game_operations',
        'trivia',
        'tv',
        'tv_display',
      }),
      isEmpty,
    );
    expect(
      routePaths.intersection(const <String>{
        '/admin/games',
        '/fanzone/game',
        '/game-operations',
        '/my-tvs',
        '/pair-tv',
        '/tv-display',
      }),
      isEmpty,
    );
    expect(
      routePaths.where(
        (path) =>
            path.startsWith('/game-operations/') ||
            path.startsWith('/fanzone/game/') ||
            path.startsWith('/tv-display/'),
      ),
      isEmpty,
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
