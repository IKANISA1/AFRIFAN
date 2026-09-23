import 'package:feat_onboarding/feat_onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  const redirects = <String, String>{
    '/splash': '/onboarding',
    '/splash?from=%2Ftickets': '/onboarding?from=%2Ftickets',
    '/splash?from=%2Fsplash': '/onboarding',
    '/splash?from=https%3A%2F%2Fexample.com': '/onboarding',
  };

  for (final entry in redirects.entries) {
    testWidgets('${entry.key} resolves safely to ${entry.value}', (
      tester,
    ) async {
      final module = OnboardingModule();
      final splash = module.routes.whereType<GoRoute>().singleWhere(
        (route) => route.path == '/splash',
      );
      final router = GoRouter(
        initialLocation: entry.key,
        routes: <RouteBase>[
          splash,
          GoRoute(
            path: '/onboarding',
            builder: (context, state) =>
                Scaffold(body: Text('Target: ${state.uri}')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Target: ${entry.value}'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.toString(), entry.value);
    });
  }

  test('presentation decision declares the actual safe onboarding target', () {
    final decision = OnboardingModule().routePresentationDecisions.singleWhere(
      (candidate) => candidate.path == '/splash',
    );

    expect(decision.targetPath, '/onboarding');
  });
}
