import 'package:app_registry/app_registry.dart';
import 'package:core_router/core_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  late List<FeatureModule> modules;
  late AppRouter appRouter;
  late Map<String, GoRoute?> canonicalRoutes;

  setUp(() {
    modules = AppModuleRegistry.allModules;
    appRouter = AppRouter(
      modules: modules,
      initialLocation: '/home',
      shellBuilder: (_, shell) => Scaffold(body: shell),
    );
    canonicalRoutes = _collectCanonicalRoutes(modules);
  });

  test('every canonical Flutter route resolves through the router graph', () {
    expect(canonicalRoutes.length, 88);
    expect(canonicalRoutes, contains('/predict'));
    expect(
      canonicalRoutes.keys.any((path) => path.startsWith('/challenge')),
      isTrue,
    );

    for (final path in canonicalRoutes.keys) {
      final concreteUri = Uri.parse(_concretePath(path));
      final match = appRouter.router.configuration.findMatch(concreteUri);
      expect(match.isError, isFalse, reason: '$path -> $concreteUri');
    }
  });

  test('every presentation decision maps to exactly one registered route', () {
    final decisions = modules
        .expand((module) => module.routePresentationDecisions)
        .toList(growable: false);
    final decisionPaths = decisions
        .map((decision) => decision.path)
        .toList(growable: false);

    expect(decisionPaths.toSet().length, decisionPaths.length);
    expect(decisionPaths.toSet(), canonicalRoutes.keys.toSet());
  });

  test('critical sheet and modal decisions use pushed route pages', () {
    final criticalDecisions = modules
        .expand((module) => module.routePresentationDecisions)
        .where(
          (decision) =>
              decision.presentation == RoutePresentation.fullHeightSheet ||
              decision.presentation == RoutePresentation.modalSheet,
        );

    expect(criticalDecisions, isNotEmpty);
    for (final decision in criticalDecisions) {
      final route = canonicalRoutes[decision.path];
      expect(route, isNotNull, reason: decision.path);
      expect(
        route!.pageBuilder,
        isNotNull,
        reason: '${decision.path} must be a pushed route page',
      );
    }
  });

  test('compatibility redirects have registered safe target routes', () {
    final redirectDecisions = modules
        .expand((module) => module.routePresentationDecisions)
        .where(
          (decision) => decision.presentation == RoutePresentation.redirect,
        );

    expect(redirectDecisions, isNotEmpty);
    for (final decision in redirectDecisions) {
      final route = canonicalRoutes[decision.path];
      expect(route, isNotNull, reason: decision.path);
      expect(route!.redirect, isNotNull, reason: decision.path);

      final target = decision.targetPath;
      expect(target, isNotNull, reason: decision.path);
      final targetUri = Uri.parse(_concretePath(target!));
      final match = appRouter.router.configuration.findMatch(targetUri);
      expect(match.isError, isFalse, reason: '${decision.path} -> $targetUri');
    }
  });

  testWidgets(
    'registered compatibility redirects reach a terminal destination',
    (tester) async {
      // Use the real redirects, with lightweight page bodies, so cross-module
      // chains are exercised without authenticated repositories or network IO.
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          for (final entry in canonicalRoutes.entries)
            GoRoute(
              path: entry.key,
              redirect: entry.value?.redirect,
              builder: (_, state) => Text('Destination: ${state.uri.path}'),
            ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      for (final entry in {
        '/fanzone': '/predict',
        '/challenge': '/predict',
        '/challenge/create': '/predict',
        '/challenge/my': '/predict?section=history',
        '/fanzone?section=predictions': '/predict',
        '/fanzone?section=supporters': '/fan-clubs',
        '/fanzone?section=league': '/club/fixtures',
        '/fanzone/wallet': '/predict?section=wallet',
        '/membership/fans': '/fan-clubs',
        '/fan-clubs': '/fan-clubs',
        '/contribute': '/contribute',
        '/contribute/groups': '/contribute',
        '/contribute/projects': '/contribute',
      }.entries) {
        router.go(entry.key);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.toString(),
          entry.value,
          reason: entry.key,
        );
        expect(tester.takeException(), isNull, reason: entry.key);
        expect(
          find.text('Destination: ${Uri.parse(entry.value).path}'),
          findsOneWidget,
        );
      }
    },
  );
}

Map<String, GoRoute?> _collectCanonicalRoutes(List<FeatureModule> modules) {
  final routes = <String, GoRoute?>{};

  for (final module in modules) {
    final tabRoute = module.tabRoute;
    final parentPath = tabRoute?.path ?? '';
    if (tabRoute != null) {
      routes[tabRoute.path] = null;
    }
    for (final route in module.routes) {
      _collectRoute(route, parentPath, routes);
    }
    for (final route in module.standaloneRoutes) {
      _collectRoute(route, '', routes);
    }
  }

  return routes;
}

void _collectRoute(
  RouteBase route,
  String parentPath,
  Map<String, GoRoute?> output,
) {
  if (route is! GoRoute) {
    return;
  }

  final path = route.path.startsWith('/')
      ? route.path
      : '${parentPath.endsWith('/') ? parentPath.substring(0, parentPath.length - 1) : parentPath}/${route.path}';
  expect(output.containsKey(path), isFalse, reason: 'duplicate route $path');
  output[path] = route;

  for (final child in route.routes) {
    _collectRoute(child, path, output);
  }
}

String _concretePath(String pattern) {
  final uri = Uri.parse(pattern);
  final concretePath = uri.path.replaceAllMapped(
    RegExp(r':([A-Za-z][A-Za-z0-9_]*)'),
    (match) => 'sample-${match.group(1)}',
  );
  return uri.replace(path: concretePath).toString();
}
