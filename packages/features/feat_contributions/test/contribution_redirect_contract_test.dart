import 'package:feat_contributions/feat_contributions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final source in <String>[
    '/contribute',
    '/contribute/projects',
    '/contribute/groups',
  ]) {
    testWidgets(
      '$source resolves to the canonical Fan Zone Supporters target',
      (tester) async {
        final router = GoRouter(
          initialLocation: source,
          routes: <RouteBase>[
            ...ContributionsModule().routes,
            GoRoute(
              path: '/fanzone',
              builder: (context, state) => Scaffold(
                body: Text(
                  state.uri.queryParameters['section'] == 'supporters'
                      ? 'Fan Zone Supporters'
                      : 'Unexpected Fan Zone section',
                ),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(find.text('Fan Zone Supporters'), findsOneWidget);
        expect(
          router.routeInformationProvider.value.uri.toString(),
          '/fanzone?section=supporters',
        );
        expect(router.routeInformationProvider.value.uri.path, isNot(source));
      },
    );
  }

  test('all contribution redirects declare the same registered target', () {
    final decisions = ContributionsModule().routePresentationDecisions.where(
      (decision) => decision.presentation.name == 'redirect',
    );

    expect(
      decisions.map((decision) => decision.path),
      containsAll(<String>[
        '/contribute',
        '/contribute/projects',
        '/contribute/groups',
      ]),
    );
    expect(decisions.map((decision) => decision.targetPath).toSet(), <String>{
      '/fanzone?section=supporters',
    });
  });
}
