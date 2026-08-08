import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_game_operations/feat_game_operations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_support/app_font_loader.dart';

import 'game_operations_test_support.dart';

const _goldenKey = ValueKey<String>('live-control-route-state-golden');
const _primaryActionKey = ValueKey<String>('control-next-activated_lobby');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  for (final state in _liveControlStates) {
    testWidgets('live control $state route state', (tester) async {
      await _pumpLiveControlState(tester, state);
    });
  }
}

const _liveControlStates = <String>[
  'loading',
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
  'conflict',
  'security_timeout',
];

Future<void> _pumpLiveControlState(WidgetTester tester, String state) async {
  final largeText = state == 'large_text';
  final reducedMotion = state == 'reduced_motion';
  final brightness = state == 'light' ? Brightness.light : Brightness.dark;
  final size = largeText ? const Size(320, 720) : const Size(390, 844);
  final controller = LiveGameControlController(
    FakeGameOperationsGateway(),
    'session-1',
    initialState: _stateFor(state),
  );
  TestGesture? heldGesture;

  _setGoldenSurface(tester, size, reducedMotion: reducedMotion);
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
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        liveGameControlControllerProvider.overrideWith(
          (ref, sessionId) => controller,
        ),
      ],
      child: AfriLocalizationsScope(
        locale: const Locale('en'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ClubTheme.from(config, brightness: brightness),
          home: LiveGameControlScreen(
            sessionId: 'session-1',
            autofocusPrimaryAction: state == 'focused',
          ),
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();

  if (<String>{
    'disabled',
    'focused',
    'pressed',
    'large_text',
    'syncing',
    'conflict',
    'security_timeout',
  }.contains(state)) {
    await _scrollToPrimaryAction(tester);
    await tester.pump(const Duration(milliseconds: 500));
  }

  if (state == 'focused') {
    final primaryAction = find.byKey(_primaryActionKey);
    final detector = find
        .descendant(of: primaryAction, matching: find.byType(GestureDetector))
        .first;
    expect(Focus.of(tester.element(detector)).hasFocus, isTrue);
  }

  if (state == 'pressed') {
    final primaryAction = find.byKey(_primaryActionKey);
    final detector = find
        .descendant(of: primaryAction, matching: find.byType(GestureDetector))
        .first;
    heldGesture = await tester.startGesture(tester.getCenter(detector));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester
          .widgetList<ScaleTransition>(
            find.descendant(
              of: primaryAction,
              matching: find.byType(ScaleTransition),
            ),
          )
          .any((transition) => transition.scale.value < 1),
      isTrue,
    );
  }

  final l10n = lookupAfriLocalizations(const Locale('en'));
  if (state == 'loading') {
    expect(find.text(l10n.gameSyncing), findsOneWidget);
    expect(find.byKey(_primaryActionKey), findsNothing);
  }
  if (state == 'error') {
    expect(find.text(l10n.gameOperationsUnavailable), findsOneWidget);
  }
  if (state == 'offline') {
    expect(find.text(l10n.gameOperationsOffline), findsOneWidget);
  }
  if (state == 'permission_denied') {
    expect(find.text(l10n.gameOperationsAccessDenied), findsOneWidget);
  }
  if (state == 'syncing') {
    expect(
      find.byKey(const ValueKey<String>('control-syncing-warning')),
      findsOneWidget,
    );
  }
  if (state == 'conflict') {
    expect(find.text(l10n.gameOperationConflictDescription), findsOneWidget);
  }
  if (state == 'security_timeout') {
    expect(find.text(l10n.gameOperationTimeoutDescription), findsOneWidget);
  }
  if (<String>{
    'disabled',
    'syncing',
    'conflict',
    'security_timeout',
  }.contains(state)) {
    expect(
      tester.widget<AfriButton>(find.byKey(_primaryActionKey)).enabled,
      isFalse,
    );
  }
  if (state != 'loading' &&
      state != 'error' &&
      state != 'offline' &&
      state != 'permission_denied') {
    expect(find.text(l10n.gameOpenLobbyAction), findsOneWidget);
  }
  if (largeText) {
    expect(find.byKey(_primaryActionKey), findsOneWidget);
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
      'goldens/live_game_control_state_${state}_${themeName}_$dimensions.png',
    ),
  );

  await heldGesture?.cancel();
}

LiveGameControlState _stateFor(String state) {
  if (state == 'loading') {
    return const LiveGameControlState(status: GameOperationsLoadStatus.loading);
  }
  if (state == 'error') {
    return const LiveGameControlState(
      status: GameOperationsLoadStatus.failure,
      failure: GameOperationsFailure(GameOperationsFailureKind.unavailable),
    );
  }
  if (state == 'offline') {
    return const LiveGameControlState(
      status: GameOperationsLoadStatus.failure,
      failure: GameOperationsFailure(GameOperationsFailureKind.offline),
    );
  }
  if (state == 'permission_denied') {
    return const LiveGameControlState(
      status: GameOperationsLoadStatus.failure,
      failure: GameOperationsFailure(
        GameOperationsFailureKind.permissionDenied,
      ),
    );
  }
  if (state == 'syncing') {
    return LiveGameControlState(
      status: GameOperationsLoadStatus.loading,
      session: testManagedGame,
      refreshRequired: true,
    );
  }
  if (state == 'disabled') {
    return LiveGameControlState(
      status: GameOperationsLoadStatus.failure,
      session: testManagedGame,
      failure: const GameOperationsFailure(
        GameOperationsFailureKind.unavailable,
      ),
      refreshRequired: true,
    );
  }
  if (state == 'conflict') {
    return LiveGameControlState(
      status: GameOperationsLoadStatus.failure,
      session: testManagedGame,
      failure: const GameOperationsFailure(GameOperationsFailureKind.conflict),
      refreshRequired: true,
    );
  }
  if (state == 'security_timeout') {
    return LiveGameControlState(
      status: GameOperationsLoadStatus.failure,
      session: testManagedGame,
      failure: const GameOperationsFailure(GameOperationsFailureKind.timeout),
      refreshRequired: true,
    );
  }
  return LiveGameControlState(
    status: GameOperationsLoadStatus.ready,
    session: testManagedGame,
  );
}

Future<void> _scrollToPrimaryAction(WidgetTester tester) async {
  final primaryAction = find.byKey(_primaryActionKey);
  final scrollable = find.descendant(
    of: find.byKey(const ValueKey<String>('live-game-control')),
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(
    primaryAction,
    300,
    scrollable: scrollable.first,
  );
}

void _setGoldenSurface(
  WidgetTester tester,
  Size size, {
  required bool reducedMotion,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(
        disableAnimations: reducedMotion,
        accessibleNavigation: reducedMotion,
      );
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}
