import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_game_operations/feat_game_operations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

import 'game_operations_test_support.dart';

const _goldenKey = ValueKey<String>('pair-tv-route-state-golden');

// Golden viewport contract: 390x844 standard and 320x720 at 200% text.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  for (final state in _pairingStates) {
    testWidgets('pair TV $state route state', (tester) async {
      await _pumpPairingState(tester, state);
    });
  }
}

const _pairingStates = <String>[
  'loading',
  'empty',
  'error',
  'offline',
  'permission_denied',
  'disabled',
  'focused',
  'pressed',
  'selected',
  'large_text',
  'reduced_motion',
  'dark',
  'light',
  'syncing',
  'conflict',
  'security_timeout',
];

Future<void> _pumpPairingState(WidgetTester tester, String state) async {
  final largeText = state == 'large_text';
  final reducedMotion = state == 'reduced_motion';
  final brightness = state == 'light' ? Brightness.light : Brightness.dark;
  final size = largeText ? const Size(320, 720) : const Size(390, 844);
  final gateway = FakeGameOperationsGateway();
  final controller = DisplayInventoryController(
    gateway,
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

  final router = GoRouter(
    initialLocation: '/my-tvs/pair?challenge=A1B2C3D4',
    routes: <RouteBase>[
      GoRoute(
        path: '/my-tvs',
        builder: (_, __) => const MyTvsScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'pair',
            builder: (_, routeState) => PairTvScreen(
              initialChallenge: routeState.uri.queryParameters['challenge'],
            ),
          ),
          GoRoute(path: ':displayId', builder: (_, __) => const SizedBox()),
        ],
      ),
      GoRoute(path: '/game-operations', builder: (_, __) => const SizedBox()),
    ],
  );
  addTearDown(router.dispose);
  final config = ClubConfig.fallback();

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        displayInventoryControllerProvider.overrideWith((ref) => controller),
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));

  final hasForm = !<String>{
    'loading',
    'error',
    'offline',
    'permission_denied',
  }.contains(state);
  if (hasForm && !<String>{'empty', 'disabled'}.contains(state)) {
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey<String>('pair-tv-name')),
        matching: find.byType(TextField),
      ),
      'Lounge TV',
    );
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 300));
  }

  if (hasForm) {
    final formScrollable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    tester.state<ScrollableState>(formScrollable.first).position.jumpTo(0);
    await tester.pump(const Duration(milliseconds: 500));
  }

  await tester.pumpAndSettle();

  if (state == 'selected') {
    await tester.tap(find.text('Home').last);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Club House').last);
    await tester.pump(const Duration(milliseconds: 500));
    FocusManager.instance.primaryFocus?.unfocus();
    tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .jumpTo(0);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Club House'), findsOneWidget);
  }

  if (state == 'large_text') {
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('pair-tv-submit')),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  if (state == 'focused') {
    final challengeField = find.descendant(
      of: find.byKey(const ValueKey<String>('pair-tv-challenge')),
      matching: find.byType(TextField),
    );
    await tester.tap(challengeField);
    await tester.pumpAndSettle();
    tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .jumpTo(0);
    await tester.pump(const Duration(milliseconds: 500));
    final editable = tester.widget<EditableText>(
      find.descendant(of: challengeField, matching: find.byType(EditableText)),
    );
    expect(editable.focusNode.hasFocus, isTrue);
  }

  if (state == 'pressed') {
    final submit = find.byKey(const ValueKey<String>('pair-tv-submit'));
    final gestureDetector = find
        .descendant(of: submit, matching: find.byType(GestureDetector))
        .first;
    heldGesture = await tester.startGesture(tester.getCenter(gestureDetector));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 100));
    final pressedScales = tester
        .widgetList<ScaleTransition>(
          find.descendant(of: submit, matching: find.byType(ScaleTransition)),
        )
        .map((scale) => scale.scale.value);
    expect(pressedScales.any((scale) => scale < 1), isTrue);
  }

  if (state == 'loading') {
    expect(find.text('Loading your TV inventory'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('pair-tv-submit')), findsNothing);
  }
  if (state == 'empty') {
    expect(
      find.text(
        'No authorized home or venue location is available for this TV.',
      ),
      findsOneWidget,
    );
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
  if (state == 'syncing') {
    expect(
      find.byKey(const ValueKey<String>('pair-tv-syncing-warning')),
      findsOneWidget,
    );
  }
  if (state == 'conflict') {
    expect(
      find.text(
        lookupAfriLocalizations(
          const Locale('en'),
        ).gameOperationConflictDescription,
      ),
      findsOneWidget,
    );
  }
  if (state == 'security_timeout') {
    expect(
      find.text(
        lookupAfriLocalizations(
          const Locale('en'),
        ).gameOperationTimeoutDescription,
      ),
      findsOneWidget,
    );
  }
  if (<String>{
    'empty',
    'disabled',
    'syncing',
    'conflict',
    'security_timeout',
  }.contains(state)) {
    final submit = tester.widget<AfriButton>(
      find.byKey(const ValueKey<String>('pair-tv-submit')),
    );
    expect(submit.enabled, isFalse);
  }
  if (state == 'disabled') {
    final submit = tester.widget<AfriButton>(
      find.byKey(const ValueKey<String>('pair-tv-submit')),
    );
    expect(submit.isLoading, isFalse);
  }
  expect(find.text('99000000-0000-4000-8000-000000000081'), findsNothing);
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
      'goldens/pair_tv_state_${state}_${themeName}_$dimensions.png',
    ),
  );

  await heldGesture?.cancel();
}

DisplayInventoryState _stateFor(String state) {
  final emptyInventory = OwnedDisplayInventory(
    clubId: '24',
    serverTime: DateTime.utc(2026, 8, 1, 12),
    displays: const <OwnedDisplay>[],
    scopeOptions: const <OwnedDisplayScopeOption>[],
  );
  return switch (state) {
    'loading' => const DisplayInventoryState(
      status: GameOperationsLoadStatus.loading,
    ),
    'empty' => DisplayInventoryState(
      status: GameOperationsLoadStatus.empty,
      inventory: emptyInventory,
    ),
    'error' => const DisplayInventoryState(
      status: GameOperationsLoadStatus.failure,
      failure: GameOperationsFailure(GameOperationsFailureKind.unavailable),
    ),
    'offline' => const DisplayInventoryState(
      status: GameOperationsLoadStatus.failure,
      failure: GameOperationsFailure(GameOperationsFailureKind.offline),
    ),
    'permission_denied' => const DisplayInventoryState(
      status: GameOperationsLoadStatus.failure,
      failure: GameOperationsFailure(
        GameOperationsFailureKind.permissionDenied,
      ),
    ),
    'disabled' => DisplayInventoryState(
      status: GameOperationsLoadStatus.ready,
      inventory: testDisplayInventory,
    ),
    'syncing' => DisplayInventoryState(
      status: GameOperationsLoadStatus.loading,
      inventory: testDisplayInventory,
    ),
    'conflict' => DisplayInventoryState(
      status: GameOperationsLoadStatus.ready,
      inventory: testDisplayInventory,
      failure: const GameOperationsFailure(GameOperationsFailureKind.conflict),
    ),
    'security_timeout' => DisplayInventoryState(
      status: GameOperationsLoadStatus.ready,
      inventory: testDisplayInventory,
      failure: const GameOperationsFailure(GameOperationsFailureKind.timeout),
    ),
    _ => DisplayInventoryState(
      status: GameOperationsLoadStatus.ready,
      inventory: testDisplayInventory,
    ),
  };
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
