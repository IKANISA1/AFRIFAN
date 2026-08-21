import 'package:feat_ticketing/feat_ticketing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('/my-tickets resolves to the owned Tickets tab', (tester) async {
    final module = TicketingModule();
    final redirect = module.routes.singleWhere(
      (route) => route.path == '/my-tickets',
    );
    final router = GoRouter(
      initialLocation: '/my-tickets',
      routes: <RouteBase>[
        redirect,
        GoRoute(
          path: '/tickets',
          builder: (context, state) =>
              Scaffold(body: Text('Target: ${state.uri}')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Target: /tickets?tab=mine'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/tickets?tab=mine',
    );
  });

  test('presentation decision declares the exact registered target', () {
    final decision = TicketingModule().routePresentationDecisions.singleWhere(
      (candidate) => candidate.path == '/my-tickets',
    );

    expect(decision.targetPath, '/tickets?tab=mine');
  });
}
