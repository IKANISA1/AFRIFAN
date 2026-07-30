import 'package:feat_membership/feat_membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('/membership/fans resolves to Fan Zone Supporters', (
    tester,
  ) async {
    final module = MembershipModule();
    final redirect = module.routes.whereType<GoRoute>().singleWhere(
      (route) => route.path == 'fans',
    );
    final router = GoRouter(
      initialLocation: '/membership/fans',
      routes: <RouteBase>[
        GoRoute(
          path: '/membership',
          builder: (context, state) => const SizedBox.shrink(),
          routes: <RouteBase>[redirect],
        ),
        GoRoute(
          path: '/fanzone',
          builder: (context, state) =>
              Scaffold(body: Text('Target: ${state.uri}')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Target: /fanzone?section=supporters'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/fanzone?section=supporters',
    );
  });

  test('presentation decision declares the exact registered target', () {
    final decision = MembershipModule().routePresentationDecisions.singleWhere(
      (candidate) => candidate.path == '/membership/fans',
    );

    expect(decision.targetPath, '/fanzone?section=supporters');
  });
}
