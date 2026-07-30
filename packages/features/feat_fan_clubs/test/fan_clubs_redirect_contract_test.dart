import 'package:feat_fan_clubs/feat_fan_clubs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('/fan-clubs resolves to Fan Zone Supporters', (tester) async {
    final module = FanClubsModule();
    final router = GoRouter(
      initialLocation: '/fan-clubs',
      routes: <RouteBase>[
        ...module.routes,
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
    final decision = FanClubsModule().routePresentationDecisions.singleWhere(
      (candidate) => candidate.path == '/fan-clubs',
    );

    expect(decision.targetPath, '/fanzone?section=supporters');
  });
}
