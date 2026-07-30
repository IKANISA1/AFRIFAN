import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_gamification/src/controllers/game_session_join_controller.dart';
import 'package:feat_gamification/src/models/game_session_models.dart';
import 'package:feat_gamification/src/screens/game_session_join_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

const _goldens = <String, String>{
  'loading': 'goldens/game_join_state_loading_dark_390x844.png',
  'empty': 'goldens/game_join_state_empty_dark_390x844.png',
  'error': 'goldens/game_join_state_error_dark_390x844.png',
  'offline': 'goldens/game_join_state_offline_dark_390x844.png',
  'permission_denied':
      'goldens/game_join_state_permission_denied_dark_390x844.png',
  'disabled': 'goldens/game_join_state_disabled_dark_390x844.png',
  'focused': 'goldens/game_join_state_focused_dark_390x844.png',
  'pressed': 'goldens/game_join_state_pressed_dark_390x844.png',
  'selected': 'goldens/game_join_state_selected_dark_390x844.png',
  'large_text': 'goldens/game_join_state_large_text_dark_320x720.png',
  'reduced_motion': 'goldens/game_join_state_reduced_motion_dark_390x844.png',
  'dark': 'goldens/game_join_state_dark_dark_390x844.png',
  'light': 'goldens/game_join_state_light_light_390x844.png',
  'syncing': 'goldens/game_join_state_syncing_dark_390x844.png',
  'conflict': 'goldens/game_join_state_conflict_dark_390x844.png',
  'security_timeout':
      'goldens/game_join_state_security_timeout_dark_390x844.png',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('Game join clears offline state after reconnect', (tester) async {
    ConnectivityService.setOnlineForTest(false);
    final controller = _Controller(
      const AsyncData<GameSessionJoinState>(
        GameSessionJoinState(
          phase: GameSessionJoinPhase.degraded,
          failure: GameSessionJoinFailure(GameSessionJoinFailureKind.offline),
        ),
      ),
    );
    await _pumpRoute(
      tester,
      controller: controller,
      online: false,
      capture: false,
    );

    ConnectivityService.setOnlineForTest(true);
    await tester.pump();
    await tester.pump();

    expect(controller.restoredCalls, 1);
  });

  testWidgets('golden Game join loading state', (tester) async {
    await _pumpState(
      tester,
      id: 'loading',
      value: const AsyncLoading<GameSessionJoinState>(),
      settle: false,
    );
  });

  testWidgets('golden Game join empty state', (tester) async {
    await _pumpState(
      tester,
      id: 'empty',
      value: const AsyncData<GameSessionJoinState>(
        GameSessionJoinState(validationMessage: 'Enter the TV session code.'),
      ),
      check: (_) async =>
          expect(find.text('Enter the TV session code.'), findsOneWidget),
    );
  });

  testWidgets('golden Game join error state', (tester) async {
    await _pumpState(
      tester,
      id: 'error',
      value: const AsyncError<GameSessionJoinState>(
        GameSessionJoinFailure(GameSessionJoinFailureKind.unknown),
        StackTrace.empty,
      ),
      check: (_) async =>
          expect(find.text('Unable to join live game'), findsOneWidget),
    );
  });

  testWidgets('golden Game join offline state', (tester) async {
    await _pumpState(
      tester,
      id: 'offline',
      value: const AsyncData<GameSessionJoinState>(GameSessionJoinState()),
      online: false,
      check: (tester) async {
        expect(find.text('Live games require a connection'), findsOneWidget);
        expect(_joinButton(tester).enabled, isFalse);
      },
    );
  });

  testWidgets('golden Game join permission-denied state', (tester) async {
    await _pumpState(
      tester,
      id: 'permission_denied',
      value: const AsyncError<GameSessionJoinState>(
        GameSessionJoinFailure(GameSessionJoinFailureKind.permissionDenied),
        StackTrace.empty,
      ),
      check: (_) async {
        expect(find.text('Live game access denied'), findsOneWidget);
        expect(find.text('JOIN GAME'), findsNothing);
      },
    );
  });

  testWidgets('golden Game join disabled state', (tester) async {
    await _pumpState(
      tester,
      id: 'disabled',
      value: const AsyncData<GameSessionJoinState>(GameSessionJoinState()),
      accessEnabled: false,
      check: (_) async =>
          expect(find.text('Live games unavailable'), findsOneWidget),
    );
  });

  testWidgets('golden Game join focused state', (tester) async {
    final previous = FocusManager.instance.highlightStrategy;
    addTearDown(() => FocusManager.instance.highlightStrategy = previous);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await _pumpState(
      tester,
      id: 'focused',
      value: const AsyncData<GameSessionJoinState>(GameSessionJoinState()),
      check: (tester) async {
        await tester.tap(
          find.byKey(const ValueKey<String>('game-session-code-field')),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(
                find
                    .descendant(
                      of: find.byKey(
                        const ValueKey<String>('game-session-code-field'),
                      ),
                      matching: find.byType(TextField),
                    )
                    .first,
              )
              .focusNode
              ?.hasFocus,
          isTrue,
        );
      },
    );
  });

  testWidgets('golden Game join pressed state', (tester) async {
    TestGesture? gesture;
    addTearDown(() async => gesture?.cancel());
    await _pumpState(
      tester,
      id: 'pressed',
      value: const AsyncData<GameSessionJoinState>(GameSessionJoinState()),
      check: (tester) async {
        await tester.enterText(
          find.byKey(const ValueKey<String>('game-session-code-field')),
          'RAYON6',
        );
        final action = find.byKey(
          const ValueKey<String>('game-session-join-action'),
        );
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        gesture = await tester.startGesture(tester.getCenter(action));
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 40));
        final scales = tester
            .widgetList<ScaleTransition>(
              find.descendant(
                of: action,
                matching: find.byType(ScaleTransition),
              ),
            )
            .map((transition) => transition.scale.value);
        expect(scales.any((scale) => scale < 1), isTrue);
      },
    );
  });

  testWidgets('golden Game join selected state', (tester) async {
    await _pumpState(
      tester,
      id: 'selected',
      value: const AsyncData<GameSessionJoinState>(GameSessionJoinState()),
      check: (_) async {
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.selected == true,
          ),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('golden Game join large-text state', (tester) async {
    await _pumpState(
      tester,
      id: 'large_text',
      value: const AsyncData<GameSessionJoinState>(GameSessionJoinState()),
      size: const Size(320, 720),
      textScale: 2,
      check: (tester) async {
        final action = find.text('JOIN GAME');
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        final rect = tester.getRect(action);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(720));
      },
    );
  });

  testWidgets('golden Game join reduced-motion state', (tester) async {
    await _pumpState(
      tester,
      id: 'reduced_motion',
      value: const AsyncData<GameSessionJoinState>(GameSessionJoinState()),
      reducedMotion: true,
      check: (tester) async => expect(
        MediaQuery.disableAnimationsOf(
          tester.element(find.byType(GameSessionJoinScreen)),
        ),
        isTrue,
      ),
    );
  });

  testWidgets('golden Game join dark state', (tester) async {
    await _pumpState(
      tester,
      id: 'dark',
      value: const AsyncData<GameSessionJoinState>(GameSessionJoinState()),
    );
  });

  testWidgets('golden Game join light state', (tester) async {
    await _pumpState(
      tester,
      id: 'light',
      value: const AsyncData<GameSessionJoinState>(GameSessionJoinState()),
      brightness: Brightness.light,
    );
  });

  testWidgets('golden Game join syncing state', (tester) async {
    await _pumpState(
      tester,
      id: 'syncing',
      value: const AsyncData<GameSessionJoinState>(
        GameSessionJoinState(phase: GameSessionJoinPhase.syncing),
      ),
      settle: false,
      check: (_) async =>
          expect(find.text('Joining TV session'), findsOneWidget),
    );
  });

  testWidgets('golden Game join conflict state', (tester) async {
    await _pumpState(
      tester,
      id: 'conflict',
      value: const AsyncData<GameSessionJoinState>(
        GameSessionJoinState(
          phase: GameSessionJoinPhase.degraded,
          failure: GameSessionJoinFailure(GameSessionJoinFailureKind.conflict),
        ),
      ),
      check: (tester) async {
        expect(find.text('TV session unavailable'), findsOneWidget);
        final field = tester.widget<TextField>(
          find
              .descendant(
                of: find.byKey(
                  const ValueKey<String>('game-session-code-field'),
                ),
                matching: find.byType(TextField),
              )
              .first,
        );
        expect(field.enabled, isTrue);
        expect(_joinButton(tester).enabled, isFalse);
      },
    );
  });

  testWidgets('golden Game join security-timeout state', (tester) async {
    await _pumpState(
      tester,
      id: 'security_timeout',
      value: const AsyncData<GameSessionJoinState>(
        GameSessionJoinState(
          phase: GameSessionJoinPhase.degraded,
          failure: GameSessionJoinFailure(
            GameSessionJoinFailureKind.securityTimeout,
          ),
        ),
      ),
      check: (tester) async {
        expect(find.text('Join result is uncertain'), findsOneWidget);
        expect(_joinButton(tester).enabled, isFalse);
      },
    );
  });
}

AfriButton _joinButton(WidgetTester tester) {
  return tester.widget<AfriButton>(
    find.byKey(const ValueKey<String>('game-session-join-action')),
  );
}

Future<void> _pumpState(
  WidgetTester tester, {
  required String id,
  required AsyncValue<GameSessionJoinState> value,
  bool online = true,
  bool accessEnabled = true,
  Brightness brightness = Brightness.dark,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reducedMotion = false,
  bool settle = true,
  Future<void> Function(WidgetTester tester)? check,
}) async {
  final controller = _Controller(value);
  await _pumpRoute(
    tester,
    controller: controller,
    online: online,
    accessEnabled: accessEnabled,
    brightness: brightness,
    size: size,
    textScale: textScale,
    reducedMotion: reducedMotion,
    settle: settle,
  );
  await check?.call(tester);
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byKey(const ValueKey<String>('game-session-join-state-golden')),
    matchesGoldenFile(_goldens[id]!),
  );
}

Future<void> _pumpRoute(
  WidgetTester tester, {
  required _Controller controller,
  bool online = true,
  bool accessEnabled = true,
  Brightness brightness = Brightness.dark,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reducedMotion = false,
  bool settle = true,
  bool capture = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  TypographyTokens.debugUseFallbackFonts = true;
  addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
  ColorTokens.setBrightness(brightness);
  addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
  ConnectivityService.setOnlineForTest(online);
  addTearDown(() => ConnectivityService.setOnlineForTest(true));

  final router = GoRouter(
    initialLocation: '/fanzone/game',
    routes: [
      GoRoute(
        path: '/fanzone/game',
        builder: (_, _) => const RepaintBoundary(
          key: ValueKey<String>('game-session-join-state-golden'),
          child: GameSessionJoinScreen(),
        ),
      ),
      GoRoute(path: '/fanzone', builder: (_, _) => const SizedBox.shrink()),
      GoRoute(
        path: '/fanzone/game/:sessionId',
        builder: (_, _) => const SizedBox.shrink(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gameSessionJoinProvider.overrideWith((ref) => controller),
        gameSessionJoinAccessEnabledProvider.overrideWithValue(accessEnabled),
      ],
      child: MaterialApp.router(
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              disableAnimations: reducedMotion,
              accessibleNavigation: reducedMotion,
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        theme: ClubTheme.from(ClubConfig.fallback(), brightness: brightness),
        routerConfig: router,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  if (capture) expect(find.byType(GameSessionJoinScreen), findsOneWidget);
}

class _Controller extends GameSessionJoinController {
  _Controller(AsyncValue<GameSessionJoinState> value) : super(_Gateway()) {
    state = value;
  }

  int restoredCalls = 0;

  @override
  void connectionRestored() {
    restoredCalls += 1;
  }
}

class _Gateway implements GameSessionJoinGateway {
  @override
  Future<GameSessionJoinResult> joinByCode({
    required String joinCode,
    required String displayName,
  }) {
    return Future.value(
      const GameSessionJoinResult(
        sessionId: 'session-1',
        sessionPlayerId: 'player-1',
        displayName: 'Supporter',
        joinCode: 'RAYON6',
        score: 0,
      ),
    );
  }
}
