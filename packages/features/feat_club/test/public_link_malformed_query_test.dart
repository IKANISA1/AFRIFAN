import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  const destinations = <String, String>{
    '/club/open-web?path=%E0%A0': '/club',
    '/club/open-web?path=%FF': '/club',
    '/club/open-web?path=%2Fnews%2Fone&ignored=%FF': '/club',
    '/club/open-web?pa%FFth=%2Fnews%2Fone': '/club',
    '/club/open-web': '/club',
    '/club/open-web?path=%2Fnews%2Fone': '/club/news',
    '/club/open-web?path=%2Fsquad%2Fplayer%2Fone': '/club/team',
    '/club/open-web?path=%2Ftickets%2Fmatch%2Fone': '/club/fixtures',
    '/club/open-web?path=%2Fshop%2Fproduct%2Fone': '/shop',
    '/club/open-web?path=%2Ffanclubs%2Fone': '/fan-clubs',
    '/club/open-web?path=%2Fpartners%2Fone': '/club/partners',
    '/club/open-web?path=https%3A%2F%2Fexample.com%2Fnews%2Fone': '/club',
    '/club/open-web?path=%2F%2Fexample.com%2Fnews%2Fone': '/club',
  };
  for (final entry in destinations.entries) {
    testWidgets('${entry.key} falls back finitely to ${entry.value}', (
      tester,
    ) async {
      final redirect = ClubModule().routes.whereType<GoRoute>().singleWhere(
        (route) => route.path == 'open-web',
      );
      final router = GoRouter(
        initialLocation: entry.key,
        routes: [
          GoRoute(
            path: '/club',
            builder: (_, state) => Text('Target: ${state.uri.path}'),
            routes: [
              redirect,
              for (final path in ['news', 'team', 'fixtures', 'partners'])
                GoRoute(
                  path: path,
                  builder: (_, state) => Text('Target: ${state.uri.path}'),
                ),
            ],
          ),
          for (final path in ['/shop', '/fan-clubs'])
            GoRoute(
              path: path,
              builder: (_, state) => Text('Target: ${state.uri.path}'),
            ),
        ],
      );
      addTearDown(router.dispose);

      // The real module redirect runs without ProviderScope or backend setup.
      // An unavailable provider must retain the existing native collection
      // fallback, and malformed decoding must fall back before provider access.
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Target: ${entry.value}'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, entry.value);
      expect(tester.takeException(), isNull);
    });
  }
}
