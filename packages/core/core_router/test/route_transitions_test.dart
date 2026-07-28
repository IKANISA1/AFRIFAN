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

  testWidgets(
    'route and routed-sheet builders remove motion for accessible navigation',
    (tester) async {
      late CustomTransitionPage<void> routePage;
      late CustomTransitionPage<void> sheetPage;
      late Widget routeTransition;
      late Widget sheetTransition;

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, __) => const Text('Home')),
          GoRoute(
            path: '/route',
            pageBuilder: (context, state) {
              routePage =
                  afriRoutePage<void>(state, const Text('Reduced route'))
                      as CustomTransitionPage<void>;
              return routePage;
            },
          ),
          GoRoute(
            path: '/sheet',
            pageBuilder: (context, state) {
              sheetPage =
                  afriSheetPage<void>(state, const Text('Reduced sheet'))
                      as CustomTransitionPage<void>;
              return sheetPage;
            },
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.go('/route');
      await tester.pumpAndSettle();
      router.go('/sheet');
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(accessibleNavigation: true),
            child: Builder(
              builder: (context) {
                routeTransition = routePage.transitionsBuilder(
                  context,
                  kAlwaysCompleteAnimation,
                  kAlwaysDismissedAnimation,
                  routePage.child,
                );
                sheetTransition = sheetPage.transitionsBuilder(
                  context,
                  kAlwaysCompleteAnimation,
                  kAlwaysDismissedAnimation,
                  sheetPage.child,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(routeTransition, isA<Text>());
      expect(sheetTransition, isNot(isA<FadeTransition>()));
      expect(sheetTransition, isNot(isA<SlideTransition>()));
    },
  );

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

  testWidgets('AfriDeferredRouteLoader disables transition motion on request', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(accessibleNavigation: true),
        child: MaterialApp(
          home: AfriDeferredRouteLoader(
            loadLibrary: _completeDeferredRoute,
            builder: _buildLoadedRoute,
          ),
        ),
      ),
    );

    await tester.pump();

    final switcher = tester.widget<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher),
    );
    expect(switcher.duration, Duration.zero);
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

Future<void> _completeDeferredRoute() async {}

Widget _buildLoadedRoute(BuildContext context) => const Text('Loaded route');
