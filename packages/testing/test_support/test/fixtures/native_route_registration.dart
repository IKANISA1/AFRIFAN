import 'package:app_registry/app_registry.dart';
import 'package:core_theme/core_theme.dart';
import 'package:go_router/go_router.dart';

import 'five_club_configs.dart';

/// Exact native build scope used by the declared internal-admin catalog.
/// Consumer feature flags are preserved; internal admin is explicitly enabled.
Set<String> registeredNativeFeatures(ClubConfig config) =>
    AppModuleRegistry.build(
      internalAdminFixtureConfig(config),
      allowInternalMobileAdmin: true,
    ).map((module) => module.featureKey).toSet();

final Map<String, String> _featureByRoute = _declaredNativeRoutes();

String? nativeFeatureForRoute(String route, String kind) =>
    _featureByRoute['${route.split('?').first}|$kind'];

Map<String, String> _declaredNativeRoutes() {
  final result = <String, String>{};
  void collect(RouteBase route, String parent, String feature) {
    if (route is! GoRoute) {
      throw StateError('Unexpected declared native route type');
    }
    final path = route.path.startsWith('/')
        ? route.path
        : '$parent/${route.path}';
    final kind = route.redirect == null ? 'route' : 'redirect';
    result['$path|$kind'] = feature;
    for (final child in route.routes) {
      collect(child, path, feature);
    }
  }

  for (final module in AppModuleRegistry.allModules) {
    final tab = module.tabRoute;
    if (tab != null) {
      result['${tab.path}|tab'] = module.featureKey;
    }
    for (final route in module.routes) {
      collect(route, tab?.path ?? '', module.featureKey);
    }
    for (final route in module.standaloneRoutes) {
      collect(route, '', module.featureKey);
    }
  }
  return result;
}
