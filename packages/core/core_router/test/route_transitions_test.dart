import 'package:core_router/core_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test(
    'route transition durations stay aligned with the mobile motion spec',
    () {
      expect(afriRouteTransitionDuration, const Duration(milliseconds: 220));
      expect(
        afriRouteReverseTransitionDuration,
        const Duration(milliseconds: 170),
      );
    },
  );

  testWidgets('afriRoutePage builds a CustomTransitionPage', (tester) async {
    Page<void>? capturedPage;

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Text('Home')),
        GoRoute(
          path: '/detail',
          pageBuilder: (context, state) {
            final page = afriRoutePage<void>(state, const Text('Detail'));
            capturedPage = page;
            return page;
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/detail');
    await tester.pumpAndSettle();

    expect(capturedPage, isA<CustomTransitionPage<void>>());
    expect(find.text('Detail'), findsOneWidget);
  });

  testWidgets('AfriDeferredRouteLoader shows loading then loaded content', (
    tester,
  ) async {
    var completeLoad = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AfriDeferredRouteLoader(
          loadLibrary: () async {
            while (!completeLoad) {
              await Future<void>.delayed(const Duration(milliseconds: 1));
            }
          },
          builder: (_) => const Text('Loaded route'),
        ),
      ),
    );

    expect(find.byType(AfriDeferredRouteLoader), findsOneWidget);
    expect(find.text('Loaded route'), findsNothing);

    completeLoad = true;
    await tester.pumpAndSettle();

    expect(find.text('Loaded route'), findsOneWidget);
  });

  testWidgets('AfriDeferredRouteLoader renders a tokenized error state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AfriDeferredRouteLoader(
          loadLibrary: () async => throw StateError('broken route'),
          builder: (_) => const Text('Loaded route'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Screen failed to load'), findsOneWidget);
    expect(find.textContaining('broken route'), findsOneWidget);
  });
}
