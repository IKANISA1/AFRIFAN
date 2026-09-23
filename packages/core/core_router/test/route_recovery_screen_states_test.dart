import 'dart:async';

import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../core_theme/test/support/golden_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadCoreThemeGoldenFonts();
    TypographyTokens.debugUseFallbackFonts = true;
  });
  tearDownAll(() {
    TypographyTokens.debugUseFallbackFonts = false;
  });

  test('router errors are classified without exposing raw diagnostics', () {
    expect(
      RouteRecoveryScreen.classifyRouterError(
        StateError('socket offline member-secret-42'),
      ),
      RouteRecoveryVisualState.offline,
    );
    expect(
      RouteRecoveryScreen.classifyRouterError(
        StateError('row permission forbidden member-secret-42'),
      ),
      RouteRecoveryVisualState.permissionDenied,
    );
    expect(
      RouteRecoveryScreen.classifyRouterError(
        TimeoutException('member-secret-42 timed out'),
      ),
      RouteRecoveryVisualState.securityTimeout,
    );
  });

  for (final kind in RouteRecoveryKind.values) {
    for (final state in RouteRecoveryVisualState.values) {
      testWidgets('golden ${kind.name} ${state.name} state', (tester) async {
        final fixture = _Fixture(kind: kind, state: state);
        await fixture.pump(tester);

        TestGesture? heldGesture;
        if (state == RouteRecoveryVisualState.focused) {
          final previous = FocusManager.instance.highlightStrategy;
          addTearDown(() => FocusManager.instance.highlightStrategy = previous);
          FocusManager.instance.highlightStrategy =
              FocusHighlightStrategy.alwaysTraditional;
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          expect(FocusManager.instance.primaryFocus, isNotNull);
        } else if (state == RouteRecoveryVisualState.pressed) {
          final actionLabel = kind == RouteRecoveryKind.featureUnavailable
              ? 'Go back'
              : 'Go home';
          final action = find.text(actionLabel).first;
          final detector = find.ancestor(
            of: action,
            matching: find.byType(GestureDetector),
          );
          expect(detector, findsOneWidget);
          heldGesture = await tester.startGesture(tester.getCenter(detector));
          await tester.pump(const Duration(milliseconds: 120));
          await tester.pump(const Duration(milliseconds: 40));
          expect(
            tester
                .widgetList<ScaleTransition>(
                  find.descendant(
                    of: detector,
                    matching: find.byType(ScaleTransition),
                  ),
                )
                .any((transition) => transition.scale.value < 1),
            isTrue,
          );
        }

        expect(find.textContaining('member-secret-42'), findsNothing);
        await expectLater(
          find.byKey(fixture.boundaryKey),
          matchesGoldenFile(fixture.goldenPath),
        );

        if (heldGesture != null) {
          await heldGesture.up();
        }
      });
    }
  }

  testWidgets('feature-unavailable action returns to the safe route', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/feature-unavailable',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const Text('Safe home')),
        GoRoute(
          path: '/feature-unavailable',
          builder: (_, __) => const RouteRecoveryScreen(
            kind: RouteRecoveryKind.featureUnavailable,
            fallbackLocation: '/home',
            visualState: RouteRecoveryVisualState.disabled,
            requestedPath: '/predict/private-member-id',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Go back'));
    await tester.pumpAndSettle();

    expect(find.text('Safe home'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/home');
  });
}

class _Fixture {
  const _Fixture({required this.kind, required this.state});

  final RouteRecoveryKind kind;
  final RouteRecoveryVisualState state;

  Key get boundaryKey =>
      ValueKey<String>('route-recovery-${kind.name}-${state.name}');

  String get goldenPath {
    final prefix = kind == RouteRecoveryKind.featureUnavailable
        ? 'feature_unavailable'
        : 'router_error';
    final stateName = _snakeCase(state.name);
    final theme = state == RouteRecoveryVisualState.light ? 'light' : 'dark';
    final dimensions = state == RouteRecoveryVisualState.largeText
        ? '320x720'
        : '390x844';
    return 'goldens/${prefix}_state_${stateName}_${theme}_$dimensions.png';
  }

  Future<void> pump(WidgetTester tester) async {
    final isLargeText = state == RouteRecoveryVisualState.largeText;
    final size = isLargeText ? const Size(320, 720) : const Size(390, 844);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final brightness = state == RouteRecoveryVisualState.light
        ? Brightness.light
        : Brightness.dark;
    ColorTokens.setBrightness(brightness);
    addTearDown(() => ColorTokens.setBrightness(Brightness.dark));

    final config = ClubConfig.fallback();
    final router = GoRouter(
      initialLocation: '/recovery',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const Text('Safe home')),
        GoRoute(
          path: '/recovery',
          builder: (_, __) => RepaintBoundary(
            key: boundaryKey,
            child: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(isLargeText ? 2 : 1),
                accessibleNavigation:
                    state == RouteRecoveryVisualState.reducedMotion,
                disableAnimations:
                    state == RouteRecoveryVisualState.reducedMotion,
              ),
              child: RouteRecoveryScreen(
                kind: kind,
                fallbackLocation: '/home',
                visualState: state,
                requestedPath: kind == RouteRecoveryKind.featureUnavailable
                    ? '/predict/private-member-id'
                    : '/unknown/member-secret-42',
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ClubConfigScope(
        config: config,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ClubTheme.from(config, brightness: brightness),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

String _snakeCase(String value) {
  return value.replaceAllMapped(
    RegExp('([a-z0-9])([A-Z])'),
    (match) => '${match.group(1)}_${match.group(2)!.toLowerCase()}',
  );
}
