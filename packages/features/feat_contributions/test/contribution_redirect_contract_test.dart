import 'package:feat_contributions/feat_contributions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final source in <String>['/contribute/projects', '/contribute/groups']) {
    testWidgets('$source resolves to the club initiatives', (tester) async {
      final router = GoRouter(
        initialLocation: source,
        routes: <RouteBase>[
          GoRoute(
            path: '/contribute',
            routes: ContributionsModule().routes
                .whereType<GoRoute>()
                .single
                .routes,
            builder: (context, state) =>
                const Scaffold(body: Text('Club initiatives')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Club initiatives'), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/contribute',
      );
      expect(router.routeInformationProvider.value.uri.path, isNot(source));
    });
  }

  test('all contribution redirects declare the same registered target', () {
    final decisions = ContributionsModule().routePresentationDecisions.where(
      (decision) => decision.presentation.name == 'redirect',
    );

    expect(
      decisions.map((decision) => decision.path),
      containsAll(<String>['/contribute/projects', '/contribute/groups']),
    );
    expect(decisions.map((decision) => decision.targetPath).toSet(), <String>{
      '/contribute',
    });
  });
}
