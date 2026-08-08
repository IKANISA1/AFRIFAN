import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_game_operations/feat_game_operations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

const _goldenKey = ValueKey<String>('game-operations-hub-route-golden');

// Golden viewport contract: 390x844 standard and 320x720 at 200% text.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  for (final state in _hubStates) {
    testWidgets('game operations hub $state route state', (tester) async {
      final largeText = state == 'large_text';
      final reducedMotion = state == 'reduced_motion';
      final brightness = state == 'light' ? Brightness.light : Brightness.dark;
      final size = largeText ? const Size(320, 720) : const Size(390, 844);
      TestGesture? heldGesture;

      _setGoldenSurface(tester, size, reducedMotion: reducedMotion);
      tester.platformDispatcher.textScaleFactorTestValue = largeText ? 2 : 1;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      TypographyTokens.debugUseFallbackFonts = true;
      addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
      ColorTokens.setBrightness(brightness);
      addTearDown(() => ColorTokens.setBrightness(Brightness.dark));

      final router = GoRouter(
        initialLocation: '/game-operations',
        routes: <RouteBase>[
          GoRoute(
            path: '/game-operations',
            builder: (_, __) => const GameOperationsHubScreen(),
          ),
          GoRoute(path: '/settings', builder: (_, __) => const SizedBox()),
          GoRoute(path: '/my-tvs', builder: (_, __) => const SizedBox()),
          GoRoute(
            path: '/game-operations/sessions',
            builder: (_, __) => const SizedBox(),
          ),
        ],
      );
      addTearDown(router.dispose);
      final config = ClubConfig.fallback();

      await tester.pumpWidget(
        AfriLocalizationsScope(
          locale: const Locale('en'),
          child: MaterialApp.router(
            theme: ClubTheme.from(config, brightness: brightness),
            routerConfig: router,
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              return MediaQuery(
                data: mediaQuery.copyWith(
                  disableAnimations: reducedMotion,
                  accessibleNavigation: reducedMotion,
                ),
                child: ClubConfigScope(
                  config: config,
                  child: RepaintBoundary(
                    key: _goldenKey,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      if (state == 'focused') {
        final previousHighlightStrategy =
            FocusManager.instance.highlightStrategy;
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        addTearDown(
          () => FocusManager.instance.highlightStrategy =
              previousHighlightStrategy,
        );
        final focusable = find
            .descendant(
              of: find.byKey(
                const ValueKey<String>('game-operations-my-tvs-action'),
              ),
              matching: find.byType(FocusableActionDetector),
            )
            .first;
        final gestureDetector = find
            .descendant(of: focusable, matching: find.byType(GestureDetector))
            .first;
        Focus.of(tester.element(gestureDetector)).requestFocus();
        await tester.pumpAndSettle();
        expect(Focus.of(tester.element(gestureDetector)).hasFocus, isTrue);
        final focusedScale = tester.widget<AnimatedScale>(
          find
              .descendant(
                of: find.byType(AfriListRow).first,
                matching: find.byType(AnimatedScale),
              )
              .first,
        );
        expect(focusedScale.scale, greaterThan(1));
      }

      if (state == 'pressed') {
        final firstRow = find.byKey(
          const ValueKey<String>('game-operations-my-tvs-action'),
        );
        heldGesture = await tester.startGesture(
          tester.getCenter(find.bySemanticsLabel('My TVs')),
        );
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 100));
        final pressedScales = tester
            .widgetList<ScaleTransition>(
              find.descendant(
                of: firstRow,
                matching: find.byType(ScaleTransition),
              ),
            )
            .map((scale) => scale.scale.value);
        expect(pressedScales.any((scale) => scale < 1), isTrue);
      }

      if (reducedMotion) {
        final context = tester.element(find.byKey(_goldenKey));
        expect(AfriMotion.reduceMotion(context), isTrue);
      }
      expect(find.byType(AfriListRow), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      final themeName = brightness == Brightness.light ? 'light' : 'dark';
      final dimensions = '${size.width.toInt()}x${size.height.toInt()}';
      await expectLater(
        find.byKey(_goldenKey),
        matchesGoldenFile(
          'goldens/game_operations_hub_state_${state}_${themeName}_$dimensions.png',
        ),
      );

      await heldGesture?.cancel();
    });
  }
}

const _hubStates = <String>[
  'focused',
  'pressed',
  'large_text',
  'reduced_motion',
  'dark',
  'light',
];

void _setGoldenSurface(
  WidgetTester tester,
  Size size, {
  required bool reducedMotion,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(
        disableAnimations: reducedMotion,
        accessibleNavigation: reducedMotion,
      );
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}
