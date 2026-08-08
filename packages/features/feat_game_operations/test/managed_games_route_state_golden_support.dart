import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_game_operations/feat_game_operations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_support/app_font_loader.dart';

import 'game_operations_test_support.dart';

const _goldenKeyPrefix = 'managed-games-route-state-golden';

void registerManagedGamesRouteStateGolden(String state) {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  testWidgets('managed games $state route state', (tester) async {
    await _pumpInventoryState(tester, state);
  });
}

Future<void> _pumpInventoryState(WidgetTester tester, String state) async {
  final largeText = state == 'large_text';
  final reducedMotion = state == 'reduced_motion';
  final brightness = state == 'light' ? Brightness.light : Brightness.dark;
  final size = largeText ? const Size(320, 720) : const Size(390, 844);
  final goldenKey = ValueKey<String>('$_goldenKeyPrefix-$state');
  final initialState = _stateFor(state);
  TestGesture? heldGesture;

  await _setGoldenSurface(tester, size, reducedMotion: reducedMotion);
  tester.platformDispatcher.textScaleFactorTestValue = largeText ? 2 : 1;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  TypographyTokens.debugUseFallbackFonts = true;
  addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
  ColorTokens.setBrightness(brightness);
  addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
  if (state == 'focused') {
    final previousHighlightStrategy = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousHighlightStrategy,
    );
  }

  final config = ClubConfig.fallback();
  await _pumpTestApp(
    tester,
    state: state,
    controller: ManagedGamesController(
      FakeGameOperationsGateway(),
      initialState: initialState,
    ),
    brightness: brightness,
    reducedMotion: reducedMotion,
    config: config,
    goldenKey: goldenKey,
  );
  expect(tester.getSize(find.byKey(goldenKey)), size);
  expect(
    MediaQuery.sizeOf(tester.element(find.byType(ManagedGamesScreen))),
    size,
  );

  if (state == 'focused') {
    final planButton = find.byKey(const ValueKey<String>('managed-games-plan'));
    final detector = find
        .descendant(of: planButton, matching: find.byType(GestureDetector))
        .first;
    expect(Focus.of(tester.element(detector)).hasFocus, isTrue);
  }

  if (state == 'pressed') {
    final planButton = find.byKey(const ValueKey<String>('managed-games-plan'));
    final detector = find
        .descendant(of: planButton, matching: find.byType(GestureDetector))
        .first;
    heldGesture = await tester.startGesture(tester.getCenter(detector));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester
          .widgetList<ScaleTransition>(
            find.descendant(
              of: planButton,
              matching: find.byType(ScaleTransition),
            ),
          )
          .any((transition) => transition.scale.value < 1),
      isTrue,
    );
  }

  if (state == 'loading') {
    expect(find.text('Loading your assigned games'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('managed-games-plan')),
      findsNothing,
    );
  }
  if (state == 'empty') {
    expect(find.text('No assigned games'), findsOneWidget);
  }
  if (state == 'error') {
    expect(find.text('Game operations unavailable'), findsOneWidget);
  }
  if (state == 'offline') {
    expect(find.text('Game operations offline'), findsOneWidget);
  }
  if (state == 'permission_denied') {
    expect(find.text('Game operations access denied'), findsOneWidget);
  }
  if (state == 'disabled') {
    expect(
      find.byKey(const ValueKey<String>('managed-games-retained-warning')),
      findsOneWidget,
    );
  }
  if (state == 'syncing') {
    expect(
      find.byKey(const ValueKey<String>('managed-games-syncing-warning')),
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
  if (state == 'disabled' || state == 'syncing') {
    expect(
      tester
          .widget<AfriButton>(
            find.byKey(const ValueKey<String>('managed-games-plan')),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<AfriListRow>(
            find.byKey(
              const ValueKey<String>('managed-game-session-session-1'),
            ),
          )
          .enabled,
      isFalse,
    );
  }
  if (largeText) {
    expect(
      find.byKey(const ValueKey<String>('managed-games-plan')),
      findsOneWidget,
    );
  }
  if (reducedMotion) {
    expect(
      AfriMotion.reduceMotion(tester.element(find.byKey(goldenKey))),
      isTrue,
    );
  }
  expect(tester.takeException(), isNull);

  final themeName = brightness == Brightness.light ? 'light' : 'dark';
  final dimensions = '${size.width.toInt()}x${size.height.toInt()}';
  await expectLater(
    find.byKey(goldenKey),
    matchesGoldenFile(
      'goldens/managed_games_state_${state}_${themeName}_$dimensions.png',
    ),
  );

  await heldGesture?.cancel();
}

Future<void> _pumpTestApp(
  WidgetTester tester, {
  required String state,
  required ManagedGamesController controller,
  required Brightness brightness,
  required bool reducedMotion,
  required ClubConfig config,
  required Key goldenKey,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        managedGamesControllerProvider.overrideWith((ref) => controller),
      ],
      child: AfriLocalizationsScope(
        locale: const Locale('en'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ClubTheme.from(config, brightness: brightness),
          home: ManagedGamesScreen(autofocusPlanAction: state == 'focused'),
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
                  key: goldenKey,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 500));
}

ManagedGamesState _stateFor(String state) {
  if (state == 'loading') {
    return const ManagedGamesState(status: GameOperationsLoadStatus.loading);
  }
  if (state == 'empty') {
    return ManagedGamesState(
      status: GameOperationsLoadStatus.empty,
      inventory: ManagedGamesInventory(
        clubId: '24',
        serverTime: DateTime.utc(2026, 8, 1, 12),
        canPlan: true,
        sessions: const <ManagedGameSession>[],
      ),
    );
  }
  if (state == 'error') {
    return const ManagedGamesState(
      status: GameOperationsLoadStatus.failure,
      failure: GameOperationsFailure(GameOperationsFailureKind.unavailable),
    );
  }
  if (state == 'offline') {
    return const ManagedGamesState(
      status: GameOperationsLoadStatus.failure,
      failure: GameOperationsFailure(GameOperationsFailureKind.offline),
    );
  }
  if (state == 'permission_denied') {
    return const ManagedGamesState(
      status: GameOperationsLoadStatus.failure,
      failure: GameOperationsFailure(
        GameOperationsFailureKind.permissionDenied,
      ),
    );
  }
  if (state == 'security_timeout') {
    return const ManagedGamesState(
      status: GameOperationsLoadStatus.failure,
      failure: GameOperationsFailure(GameOperationsFailureKind.timeout),
    );
  }
  if (state == 'disabled') {
    return ManagedGamesState(
      status: GameOperationsLoadStatus.failure,
      inventory: testManagedInventory,
      failure: const GameOperationsFailure(
        GameOperationsFailureKind.unavailable,
      ),
    );
  }
  if (state == 'syncing') {
    return ManagedGamesState(
      status: GameOperationsLoadStatus.loading,
      inventory: testManagedInventory,
    );
  }
  return ManagedGamesState(
    status: GameOperationsLoadStatus.ready,
    inventory: testManagedInventory,
  );
}

Future<void> _setGoldenSurface(
  WidgetTester tester,
  Size size, {
  required bool reducedMotion,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pump();
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(
        disableAnimations: reducedMotion,
        accessibleNavigation: reducedMotion,
      );
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });
}
