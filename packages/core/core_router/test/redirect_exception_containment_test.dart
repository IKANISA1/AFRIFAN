import 'dart:async';

import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  setUp(() => TypographyTokens.debugUseFallbackFonts = true);
  tearDown(() => TypographyTokens.debugUseFallbackFonts = false);

  for (final asynchronous in [false, true]) {
    testWidgets(
      'contains ${asynchronous ? 'async' : 'sync'} top redirect failure',
      (tester) async {
        final factory = _factory(
          redirect: (_, state) {
            if (state.uri.path != '/alias') return null;
            final error = StateError('private-account-token-must-not-render');
            if (asynchronous) return Future<String?>.error(error);
            throw error;
          },
        );
        addTearDown(factory.router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(routerConfig: factory.router),
        );
        await tester.pumpAndSettle();
        factory.router.go('/alias?secret=private-query');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(RouteRecoveryScreen), findsOneWidget);
        expect(find.textContaining('private-account-token'), findsNothing);
        expect(find.textContaining('private-query'), findsNothing);
        expect(
          factory.router.routerDelegate.currentConfiguration.error.toString(),
          isNot(contains('private-account-token')),
        );
        await tester.tap(find.text('Go home'));
        await tester.pumpAndSettle();
        expect(find.text('Safe home'), findsOneWidget);
      },
    );
  }

  testWidgets('contains nested module redirect timeout', (tester) async {
    final factory = _factory(
      moduleRedirect: (_, __) async {
        throw TimeoutException('private-timeout-payload');
      },
    );
    addTearDown(factory.router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: factory.router));
    await tester.pumpAndSettle();
    factory.router.go('/section/alias');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('The route check timed out.'), findsOneWidget);
    expect(find.textContaining('private-timeout-payload'), findsNothing);
  });

  testWidgets('contains malformed dynamic path before redirects', (
    tester,
  ) async {
    final factory = _factory();
    addTearDown(factory.router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: factory.router));
    await tester.pumpAndSettle();
    factory.router.go('/item/%FF');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(RouteRecoveryScreen), findsOneWidget);
    await tester.tap(find.text('Go home'));
    await tester.pumpAndSettle();
    factory.router.go('/item/caf%C3%A9');
    await tester.pumpAndSettle();
    expect(find.text('Item café'), findsOneWidget);
  });

  testWidgets('failed push retains back stack and completes when popped', (
    tester,
  ) async {
    final factory = _factory(
      redirect: (_, state) {
        if (state.uri.path == '/alias') {
          throw StateError('private-push-failure');
        }
        return null;
      },
    );
    addTearDown(factory.router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: factory.router));
    await tester.pumpAndSettle();
    var completed = false;
    final pending = factory.router
        .push<void>('/alias')
        .then((_) => completed = true);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(RouteRecoveryScreen), findsOneWidget);
    expect(completed, isFalse);
    expect(factory.router.canPop(), isTrue);
    factory.router.pop();
    await tester.pumpAndSettle();
    await pending;
    expect(completed, isTrue);
    expect(find.text('Safe home'), findsOneWidget);
  });

  for (final replace in [false, true]) {
    testWidgets(
      'failed ${replace ? 'replace' : 'pushReplacement'} completes on pop',
      (tester) async {
        final factory = _factory(
          redirect: (_, state) {
            if (state.uri.path == '/alias') {
              throw StateError('replacement-recovery');
            }
            return null;
          },
        );
        addTearDown(factory.router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(routerConfig: factory.router),
        );
        await tester.pumpAndSettle();
        unawaited(factory.router.push<void>('/item/previous'));
        await tester.pumpAndSettle();
        final previousKey =
            factory.router.routerDelegate.currentConfiguration.last.pageKey;
        var completed = false;
        final pending =
            (replace
                    ? factory.router.replace<void>('/alias')
                    : factory.router.pushReplacement<void>('/alias'))
                .then((_) => completed = true);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(RouteRecoveryScreen), findsOneWidget);
        expect(completed, isFalse);
        expect(factory.router.canPop(), isTrue);
        final currentKey =
            factory.router.routerDelegate.currentConfiguration.last.pageKey;
        expect(currentKey, replace ? previousKey : isNot(previousKey));
        factory.router.pop();
        await tester.pumpAndSettle();
        await pending;
        expect(completed, isTrue);
        expect(find.text('Safe home'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'cold malformed URI renders recovery without an escaped exception',
    (tester) async {
      final factory = _factory(initialLocation: '/item/%E0%A0');
      addTearDown(factory.router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: factory.router));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(RouteRecoveryScreen), findsOneWidget);
      await tester.tap(find.text('Go home'));
      await tester.pumpAndSettle();
      expect(find.text('Safe home'), findsOneWidget);
    },
  );

  testWidgets('restored browser entry contains a new redirect failure', (
    tester,
  ) async {
    var fail = false;
    final factory = _factory(
      redirect: (_, state) {
        if (fail && state.uri.path == '/item/restored') {
          throw StateError('restored-private-error');
        }
        return null;
      },
    );
    addTearDown(factory.router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: factory.router));
    await tester.pumpAndSettle();
    factory.router.go('/item/restored');
    await tester.pumpAndSettle();
    final restored = factory.router.routeInformationParser
        .restoreRouteInformation(
          factory.router.routerDelegate.currentConfiguration,
        )!;
    factory.router.go('/home');
    await tester.pumpAndSettle();
    fail = true;
    await factory.router.routeInformationProvider.didPushRouteInformation(
      restored,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(RouteRecoveryScreen), findsOneWidget);
    expect(find.textContaining('restored-private-error'), findsNothing);
  });

  testWidgets('malformed pushed query is contained before page construction', (
    tester,
  ) async {
    final factory = _factory();
    addTearDown(factory.router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: factory.router));
    await tester.pumpAndSettle();
    final pending = factory.router.push<void>('/item/current?private=%FF');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(RouteRecoveryScreen), findsOneWidget);
    expect(factory.router.canPop(), isTrue);
    factory.router.pop();
    await tester.pumpAndSettle();
    await pending;
    expect(find.text('Safe home'), findsOneWidget);
  });

  testWidgets('network redirect failure retains finite offline recovery', (
    tester,
  ) async {
    final factory = _factory(
      moduleRedirect: (_, __) => throw StateError('network private-endpoint'),
    );
    addTearDown(factory.router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: factory.router));
    await tester.pumpAndSettle();
    factory.router.go('/section/alias');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('This route needs a connection.'), findsOneWidget);
    expect(find.textContaining('private-endpoint'), findsNothing);
  });
}

AppRouter _factory({
  GoRouterRedirect? redirect,
  GoRouterRedirect? moduleRedirect,
  String initialLocation = '/home',
}) => AppRouter(
  modules: [_Routes(moduleRedirect)],
  initialLocation: initialLocation,
  shellBuilder: (_, shell) => shell,
  redirect: redirect,
);

class _Routes extends FeatureModule {
  _Routes(this.moduleRedirect);
  final GoRouterRedirect? moduleRedirect;
  @override
  String get featureKey => 'test';
  @override
  List<GoRoute> get routes => [
    GoRoute(
      path: '/home',
      builder: (_, __) => const Scaffold(body: Text('Safe home')),
    ),
    GoRoute(path: '/alias', redirect: (_, __) => '/home'),
    GoRoute(
      path: '/item/:id',
      builder: (_, state) =>
          Scaffold(body: Text('Item ${state.pathParameters['id']}')),
    ),
    GoRoute(
      path: '/section',
      builder: (_, __) => const SizedBox(),
      routes: [
        GoRoute(path: 'alias', redirect: moduleRedirect ?? (_, __) => '/home'),
      ],
    ),
  ];
}
