import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_game_operations/feat_game_operations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_support/app_font_loader.dart';

import 'game_operations_test_support.dart';

const _goldenKey = ValueKey<String>('session-planner-route-state-golden');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  for (final state in _plannerStates) {
    testWidgets('session planner $state route state', (tester) async {
      await _pumpPlannerState(tester, state);
    });
  }
}

const _plannerStates = <String>[
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

Future<void> _pumpPlannerState(WidgetTester tester, String state) async {
  final largeText = state == 'large_text';
  final reducedMotion = state == 'reduced_motion';
  final brightness = state == 'light' ? Brightness.light : Brightness.dark;
  final size = largeText ? const Size(320, 720) : const Size(390, 844);
  final controller = SessionPlannerController(
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
        sessionPlannerControllerProvider.overrideWith((ref) => controller),
      ],
      child: AfriLocalizationsScope(
        locale: const Locale('en'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ClubTheme.from(config, brightness: brightness),
          home: SessionPlannerScreen(
            now: () => DateTime(2026, 8, 1, 19, 12),
            autofocusCreateAction: state == 'focused',
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

  if (state == 'disabled' || state == 'selected') {
    await tester.tap(find.byKey(const ValueKey<String>('planner-eligibility')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invited supporters only').last);
    await tester.pumpAndSettle();
  }

  if (state == 'selected') {
    final invitee = find.byKey(
      const ValueKey<String>('planner-invitee-supporter-1'),
    );
    await tester.ensureVisible(invitee);
    await tester.tap(invitee);
    await tester.pumpAndSettle();
    expect(tester.widget<AfriCheckbox>(invitee).value, isTrue);
  }

  if (<String>{
    'disabled',
    'focused',
    'pressed',
    'large_text',
    'conflict',
    'security_timeout',
  }.contains(state)) {
    await _scrollToCreate(tester);
    await tester.pump(const Duration(milliseconds: 500));
  }

  if (state == 'focused') {
    final createButton = find.byKey(const ValueKey<String>('planner-create'));
    final detector = find
        .descendant(of: createButton, matching: find.byType(GestureDetector))
        .first;
    expect(Focus.of(tester.element(detector)).hasFocus, isTrue);
  }

  if (state == 'pressed') {
    final createButton = find.byKey(const ValueKey<String>('planner-create'));
    final detector = find
        .descendant(of: createButton, matching: find.byType(GestureDetector))
        .first;
    heldGesture = await tester.startGesture(tester.getCenter(detector));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester
          .widgetList<ScaleTransition>(
            find.descendant(
              of: createButton,
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
    expect(find.byKey(const ValueKey<String>('planner-create')), findsNothing);
  }
  if (state == 'empty') {
    expect(find.text(l10n.gamePlannerNoPacks), findsOneWidget);
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
      find.byKey(const ValueKey<String>('planner-syncing-warning')),
      findsOneWidget,
    );
  }
  if (state == 'conflict') {
    expect(find.text(l10n.gameOperationConflictDescription), findsOneWidget);
  }
  if (state == 'security_timeout') {
    expect(find.text(l10n.gameOperationTimeoutDescription), findsOneWidget);
  }
  if (<String>{'syncing', 'conflict', 'security_timeout'}.contains(state)) {
    expect(
      tester
          .widget<AfriDropdownField<String>>(
            find.byKey(const ValueKey<String>('planner-pack')),
          )
          .enabled,
      isFalse,
    );
  }
  if (<String>{
    'disabled',
    'syncing',
    'conflict',
    'security_timeout',
  }.contains(state)) {
    expect(
      tester
          .widget<AfriButton>(
            find.byKey(const ValueKey<String>('planner-create')),
          )
          .enabled,
      isFalse,
    );
  }
  if (largeText) {
    expect(
      find.byKey(const ValueKey<String>('planner-create')),
      findsOneWidget,
    );
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
      'goldens/session_planner_state_${state}_${themeName}_$dimensions.png',
    ),
  );

  await heldGesture?.cancel();
}

SessionPlannerState _stateFor(String state) {
  if (state == 'loading') {
    return const SessionPlannerState(status: GameOperationsLoadStatus.loading);
  }
  if (state == 'empty') {
    return SessionPlannerState(
      status: GameOperationsLoadStatus.empty,
      options: _emptyPlannerOptions(),
    );
  }
  if (state == 'error') {
    return const SessionPlannerState(
      status: GameOperationsLoadStatus.failure,
      failure: GameOperationsFailure(GameOperationsFailureKind.unavailable),
    );
  }
  if (state == 'offline') {
    return const SessionPlannerState(
      status: GameOperationsLoadStatus.failure,
      failure: GameOperationsFailure(GameOperationsFailureKind.offline),
    );
  }
  if (state == 'permission_denied') {
    return const SessionPlannerState(
      status: GameOperationsLoadStatus.failure,
      failure: GameOperationsFailure(
        GameOperationsFailureKind.permissionDenied,
      ),
    );
  }
  if (state == 'disabled') {
    return SessionPlannerState(
      status: GameOperationsLoadStatus.ready,
      options: testPlannerOptions,
    );
  }
  if (state == 'syncing') {
    return SessionPlannerState(
      status: GameOperationsLoadStatus.loading,
      options: testPlannerOptions,
    );
  }
  if (state == 'conflict') {
    return SessionPlannerState(
      status: GameOperationsLoadStatus.failure,
      options: testPlannerOptions,
      failure: const GameOperationsFailure(GameOperationsFailureKind.conflict),
    );
  }
  if (state == 'security_timeout') {
    return SessionPlannerState(
      status: GameOperationsLoadStatus.failure,
      options: testPlannerOptions,
      failure: const GameOperationsFailure(GameOperationsFailureKind.timeout),
    );
  }
  return SessionPlannerState(
    status: GameOperationsLoadStatus.ready,
    options: testPlannerOptions,
  );
}

Future<void> _scrollToCreate(WidgetTester tester) async {
  final createButton = find.byKey(const ValueKey<String>('planner-create'));
  final scrollable = find.descendant(
    of: find.byType(ListView),
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(
    createButton,
    300,
    scrollable: scrollable.first,
  );
}

GamePlannerOptions _emptyPlannerOptions() {
  return GamePlannerOptions(
    clubId: testPlannerOptions.clubId,
    serverTime: testPlannerOptions.serverTime,
    packs: const <PlannerPack>[],
    displays: testPlannerOptions.displays,
    invitees: testPlannerOptions.invitees,
    allowedEligibilityScopes: testPlannerOptions.allowedEligibilityScopes,
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
