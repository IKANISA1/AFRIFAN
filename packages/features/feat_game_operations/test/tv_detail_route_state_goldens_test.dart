import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_game_operations/feat_game_operations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

import 'game_operations_test_support.dart';

const _goldenKey = ValueKey<String>('tv-detail-route-state-golden');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  for (final state in _managementStates) {
    testWidgets('TV detail $state route state', (tester) async {
      await _pumpManagementState(tester, state);
    });
  }
}

const _managementStates = <String>[
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

Future<void> _pumpManagementState(WidgetTester tester, String state) async {
  final largeText = state == 'large_text';
  final reducedMotion = state == 'reduced_motion';
  final brightness = state == 'light' ? Brightness.light : Brightness.dark;
  final size = largeText ? const Size(320, 720) : const Size(390, 844);
  final controller = DisplayInventoryController(
    FakeGameOperationsGateway(),
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
    initialLocation: '/my-tvs/display-1',
    routes: <RouteBase>[
      GoRoute(
        path: '/my-tvs',
        builder: (_, __) => const MyTvsScreen(),
        routes: <RouteBase>[
          GoRoute(path: 'pair', builder: (_, __) => const SizedBox()),
          GoRoute(
            path: ':displayId',
            builder: (_, routeState) => TvDetailScreen(
              displayId: routeState.pathParameters['displayId'] ?? '',
            ),
          ),
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
  await tester.pumpAndSettle();

  final hasManagement = !<String>{
    'loading',
    'empty',
    'error',
    'offline',
    'permission_denied',
  }.contains(state);

  if (state == 'focused') {
    final nameField = find.descendant(
      of: find.byKey(const ValueKey<String>('tv-detail-name')),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(nameField);
    final fieldRect = tester.getRect(nameField);
    await tester.tapAt(Offset(fieldRect.left + 16, fieldRect.center.dy));
    await tester.pumpAndSettle();
    final editable = tester.widget<EditableText>(
      find.descendant(of: nameField, matching: find.byType(EditableText)),
    );
    expect(editable.focusNode.hasFocus, isTrue);
  }

  if (state == 'pressed') {
    final action = find.byKey(
      const ValueKey<String>('tv-detail-revoke'),
      skipOffstage: false,
    );
    await tester.ensureVisible(action);
    await tester.pump(const Duration(milliseconds: 300));
    final detector = find
        .descendant(of: action, matching: find.byType(GestureDetector))
        .first;
    heldGesture = await tester.startGesture(tester.getCenter(detector));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester
          .widgetList<ScaleTransition>(
            find.descendant(of: action, matching: find.byType(ScaleTransition)),
          )
          .any((transition) => transition.scale.value < 1),
      isTrue,
    );
  }

  if (state == 'selected') {
    final scope = find.byKey(const ValueKey<String>('tv-detail-scope'));
    await tester.ensureVisible(scope);
    await tester.tap(find.text('Home').last);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Club House').last);
    await tester.pumpAndSettle();
    expect(find.text('Club House'), findsOneWidget);
  }

  if (state == 'disabled') {
    final save = find.byKey(const ValueKey<String>('tv-detail-save'));
    await tester.ensureVisible(save);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<AfriButton>(save).enabled, isFalse);
    expect(tester.widget<AfriButton>(save).isLoading, isFalse);
  }

  if (state == 'large_text') {
    final scrollable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    for (var index = 0; index < 5; index += 1) {
      final position = tester.state<ScrollableState>(scrollable.first).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(
      find.byKey(const ValueKey<String>('tv-detail-revoke')),
      findsOneWidget,
    );
  }

  if (state == 'syncing') {
    final warning = find.byKey(
      const ValueKey<String>('tv-detail-syncing-warning'),
    );
    await tester.ensureVisible(warning);
    await tester.pump(const Duration(milliseconds: 300));
    expect(warning, findsOneWidget);
  }

  if (<String>{'conflict', 'security_timeout'}.contains(state)) {
    final refresh = find.byKey(
      const ValueKey<String>('tv-detail-refresh-after-failure'),
    );
    await tester.ensureVisible(refresh);
    await tester.pump(const Duration(milliseconds: 300));
    expect(refresh, findsOneWidget);
  }

  if (hasManagement &&
      <String>{'syncing', 'conflict', 'security_timeout'}.contains(state)) {
    expect(
      tester
          .widget<AfriButton>(
            find.byKey(const ValueKey<String>('tv-detail-revoke')),
          )
          .enabled,
      isFalse,
    );
  }

  if (state == 'loading') {
    expect(
      find.text(
        lookupAfriLocalizations(const Locale('en')).gameTvInventoryLoading,
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('tv-detail-save')), findsNothing);
  }
  if (state == 'empty') {
    expect(
      find.text(lookupAfriLocalizations(const Locale('en')).gameNoTvs),
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
      'goldens/tv_detail_state_${state}_${themeName}_$dimensions.png',
    ),
  );

  await heldGesture?.cancel();
}

DisplayInventoryState _stateFor(String state) {
  final emptyInventory = OwnedDisplayInventory(
    clubId: '24',
    serverTime: DateTime.utc(2026, 8, 1, 12),
    displays: const <OwnedDisplay>[],
    scopeOptions: const <OwnedDisplayScopeOption>[
      OwnedDisplayScopeOption(scopeType: 'home', label: 'Home'),
    ],
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
