import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_game_operations/feat_game_operations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

import 'game_operations_test_support.dart';

const _goldenKey = ValueKey<String>('my-tvs-route-state-golden');

// Golden viewport contract: 390x844 standard and 320x720 at 200% text.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  for (final state in _inventoryStates) {
    testWidgets('my TVs $state route state', (tester) async {
      await _pumpInventoryState(tester, state);
    });
  }
}

const _inventoryStates = <String>[
  'loading',
  'empty',
  'error',
  'offline',
  'permission_denied',
  'disabled',
  'focused',
  'pressed',
  'large_text',
  'reduced_motion',
  'dark',
  'light',
  'syncing',
  'security_timeout',
];

Future<void> _pumpInventoryState(WidgetTester tester, String state) async {
  final largeText = state == 'large_text';
  final reducedMotion = state == 'reduced_motion';
  final brightness = state == 'light' ? Brightness.light : Brightness.dark;
  final size = largeText ? const Size(320, 720) : const Size(390, 844);
  final gateway = FakeGameOperationsGateway();
  final pending = Completer<OwnedDisplayInventory>();
  final seededController = state == 'loading'
      ? DisplayInventoryController(
          gateway,
          initialState: const DisplayInventoryState(
            status: GameOperationsLoadStatus.loading,
          ),
        )
      : null;
  TestGesture? heldGesture;

  if (state == 'empty') {
    gateway.displayInventory = OwnedDisplayInventory(
      clubId: '24',
      serverTime: DateTime.utc(2026, 8, 1, 12),
      displays: const <OwnedDisplay>[],
    );
  } else if (state == 'error') {
    gateway.displayFailure = const GameOperationsFailure(
      GameOperationsFailureKind.unavailable,
    );
  } else if (state == 'offline') {
    gateway.displayFailure = const GameOperationsFailure(
      GameOperationsFailureKind.offline,
    );
  } else if (state == 'permission_denied') {
    gateway.displayFailure = const GameOperationsFailure(
      GameOperationsFailureKind.permissionDenied,
    );
  } else if (state == 'security_timeout') {
    gateway.displayFailure = const GameOperationsFailure(
      GameOperationsFailureKind.timeout,
    );
  }

  _setGoldenSurface(tester, size, reducedMotion: reducedMotion);
  tester.platformDispatcher.textScaleFactorTestValue = largeText ? 2 : 1;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  TypographyTokens.debugUseFallbackFonts = true;
  addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
  ColorTokens.setBrightness(brightness);
  addTearDown(() => ColorTokens.setBrightness(Brightness.dark));

  final router = GoRouter(
    initialLocation: '/my-tvs',
    routes: <RouteBase>[
      GoRoute(
        path: '/my-tvs',
        builder: (_, __) => const MyTvsScreen(),
        routes: <RouteBase>[
          GoRoute(path: 'pair', builder: (_, __) => const SizedBox()),
          GoRoute(path: ':displayId', builder: (_, __) => const SizedBox()),
        ],
      ),
      GoRoute(path: '/game-operations', builder: (_, __) => const SizedBox()),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(() {
    if (!pending.isCompleted) pending.complete(testDisplayInventory);
  });
  final config = ClubConfig.fallback();

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        if (seededController != null)
          displayInventoryControllerProvider.overrideWith(
            (ref) => seededController,
          )
        else
          gameOperationsGatewayProvider.overrideWithValue(gateway),
      ],
      child: AfriLocalizationsScope(
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
    ),
  );

  await tester.pumpAndSettle();
  // Bound one additional route frame so a pending provider cannot leave
  // partially entered route chrome in the captured state.
  await tester.pump(const Duration(milliseconds: 500));

  if (state == 'disabled' || state == 'syncing') {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MyTvsScreen)),
    );
    if (state == 'disabled') {
      gateway.displayFailure = const GameOperationsFailure(
        GameOperationsFailureKind.unavailable,
      );
    } else {
      gateway.displayFetchCompleter = pending;
    }
    final refresh = container
        .read(displayInventoryControllerProvider.notifier)
        .load();
    if (state == 'disabled') {
      await refresh;
    } else {
      unawaited(refresh);
    }
    await tester.pumpAndSettle();
  }

  if (state == 'focused') {
    final previousHighlightStrategy = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousHighlightStrategy,
    );
    final pairButton = find.byKey(const ValueKey<String>('my-tvs-pair'));
    final focusable = find
        .descendant(
          of: pairButton,
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
          .descendant(of: pairButton, matching: find.byType(AnimatedScale))
          .first,
    );
    expect(focusedScale.scale, greaterThan(1));
  }

  if (state == 'pressed') {
    final pairButton = find.byKey(const ValueKey<String>('my-tvs-pair'));
    final gestureDetector = find
        .descendant(of: pairButton, matching: find.byType(GestureDetector))
        .first;
    heldGesture = await tester.startGesture(tester.getCenter(gestureDetector));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 100));
    final pressedScales = tester
        .widgetList<ScaleTransition>(
          find.descendant(
            of: pairButton,
            matching: find.byType(ScaleTransition),
          ),
        )
        .map((scale) => scale.scale.value);
    expect(pressedScales.any((scale) => scale < 1), isTrue);
  }

  if (state == 'offline') {
    expect(find.text('Game operations offline'), findsOneWidget);
  }
  if (state == 'permission_denied') {
    expect(find.text('Game operations access denied'), findsOneWidget);
  }
  if (state == 'disabled') {
    expect(
      find.byKey(const ValueKey<String>('my-tvs-retained-warning')),
      findsOneWidget,
    );
  }
  if (state == 'syncing') {
    expect(
      find.byKey(const ValueKey<String>('my-tvs-syncing-warning')),
      findsOneWidget,
    );
  }
  if (state == 'security_timeout') {
    expect(
      find.text(
        lookupAfriLocalizations(const Locale('en')).gameOperationTimeout,
      ),
      findsOneWidget,
    );
  }
  if (state == 'disabled' || state == 'syncing' || state == 'loading') {
    final pair = tester.widget<AfriButton>(
      find.byKey(const ValueKey<String>('my-tvs-pair')),
    );
    expect(pair.enabled, isFalse);
  }
  if (reducedMotion) {
    expect(
      AfriMotion.reduceMotion(tester.element(find.byKey(_goldenKey))),
      isTrue,
    );
  }
  expect(tester.takeException(), isNull);

  final themeName = brightness == Brightness.light ? 'light' : 'dark';
  final dimensions = '${size.width.toInt()}x${size.height.toInt()}';
  await expectLater(
    find.byKey(_goldenKey),
    matchesGoldenFile(
      'goldens/my_tvs_state_${state}_${themeName}_$dimensions.png',
    ),
  );

  await heldGesture?.cancel();
}

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
