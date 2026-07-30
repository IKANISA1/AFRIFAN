import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_gamification/src/controllers/game_session_controller.dart';
import 'package:feat_gamification/src/game_session_providers.dart';
import 'package:feat_gamification/src/models/game_session_models.dart';
import 'package:feat_gamification/src/screens/game_session_controller_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

const _goldens = <String, String>{
  'loading': 'goldens/game_controller_state_loading_dark_390x844.png',
  'empty': 'goldens/game_controller_state_empty_dark_390x844.png',
  'error': 'goldens/game_controller_state_error_dark_390x844.png',
  'offline': 'goldens/game_controller_state_offline_dark_390x844.png',
  'permission_denied':
      'goldens/game_controller_state_permission_denied_dark_390x844.png',
  'disabled': 'goldens/game_controller_state_disabled_dark_390x844.png',
  'focused': 'goldens/game_controller_state_focused_dark_390x844.png',
  'pressed': 'goldens/game_controller_state_pressed_dark_390x844.png',
  'selected': 'goldens/game_controller_state_selected_dark_390x844.png',
  'large_text': 'goldens/game_controller_state_large_text_dark_320x720.png',
  'reduced_motion':
      'goldens/game_controller_state_reduced_motion_dark_390x844.png',
  'dark': 'goldens/game_controller_state_dark_dark_390x844.png',
  'light': 'goldens/game_controller_state_light_light_390x844.png',
  'syncing': 'goldens/game_controller_state_syncing_dark_390x844.png',
  'conflict': 'goldens/game_controller_state_conflict_dark_390x844.png',
  'security_timeout':
      'goldens/game_controller_state_security_timeout_dark_390x844.png',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('Game controller refreshes once after reconnect', (tester) async {
    ConnectivityService.setOnlineForTest(false);
    final controller = _Controller(
      const AsyncData<GameSessionRouteState>(
        GameSessionRouteState(
          content: _joinedState,
          phase: GameSessionRoutePhase.degraded,
          failure: GameSessionFailure(GameSessionFailureKind.offline),
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

  testWidgets('golden Game controller loading state', (tester) async {
    await _pumpState(
      tester,
      id: 'loading',
      value: const AsyncLoading<GameSessionRouteState>(),
      settle: false,
    );
  });

  testWidgets('golden Game controller empty state', (tester) async {
    await _pumpState(
      tester,
      id: 'empty',
      value: const AsyncData<GameSessionRouteState>(GameSessionRouteState()),
      check: (_) async =>
          expect(find.text('Live session not found'), findsOneWidget),
    );
  });

  testWidgets('golden Game controller error state', (tester) async {
    await _pumpState(
      tester,
      id: 'error',
      value: const AsyncError<GameSessionRouteState>(
        GameSessionFailure(GameSessionFailureKind.unknown),
        StackTrace.empty,
      ),
      check: (_) async =>
          expect(find.text('Controller unavailable'), findsOneWidget),
    );
  });

  testWidgets('golden Game controller offline state', (tester) async {
    await _pumpState(
      tester,
      id: 'offline',
      online: false,
      value: const AsyncData<GameSessionRouteState>(
        GameSessionRouteState(
          content: _joinedState,
          phase: GameSessionRoutePhase.degraded,
          failure: GameSessionFailure(GameSessionFailureKind.offline),
        ),
      ),
      check: (_) async {
        expect(find.text('Controller offline'), findsOneWidget);
        expect(find.textContaining('never queued'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Game controller permission-denied state', (tester) async {
    await _pumpState(
      tester,
      id: 'permission_denied',
      value: const AsyncError<GameSessionRouteState>(
        GameSessionFailure(GameSessionFailureKind.permissionDenied),
        StackTrace.empty,
      ),
      check: (_) async =>
          expect(find.text('Live session access denied'), findsOneWidget),
    );
  });

  testWidgets('golden Game controller disabled state', (tester) async {
    await _pumpState(
      tester,
      id: 'disabled',
      accessEnabled: false,
      value: const AsyncData<GameSessionRouteState>(
        GameSessionRouteState(content: _joinedState),
      ),
      check: (_) async =>
          expect(find.text('Game controller unavailable'), findsOneWidget),
    );
  });

  testWidgets('golden Game controller focused state', (tester) async {
    final previous = FocusManager.instance.highlightStrategy;
    addTearDown(() => FocusManager.instance.highlightStrategy = previous);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await _pumpState(
      tester,
      id: 'focused',
      playerId: null,
      value: const AsyncData<GameSessionRouteState>(
        GameSessionRouteState(content: _unjoinedState),
      ),
      check: (tester) async {
        final field = find.byKey(
          const ValueKey<String>('game-controller-display-name'),
        );
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(
                find
                    .descendant(of: field, matching: find.byType(TextField))
                    .first,
              )
              .focusNode
              ?.hasFocus,
          isTrue,
        );
      },
    );
  });

  testWidgets('golden Game controller pressed state', (tester) async {
    TestGesture? gesture;
    addTearDown(() async => gesture?.cancel());
    await _pumpState(
      tester,
      id: 'pressed',
      value: const AsyncData<GameSessionRouteState>(
        GameSessionRouteState(content: _joinedState),
      ),
      check: (tester) async {
        final answer = find.byKey(
          const ValueKey<String>('game-controller-answer-a'),
        );
        await tester.ensureVisible(answer);
        await tester.pumpAndSettle();
        expect(tester.widget<AfriPressFeedback>(answer).onTap, isNotNull);
        final detector = find.descendant(
          of: answer,
          matching: find.byType(GestureDetector),
        );
        expect(detector, findsOneWidget);
        gesture = await tester.startGesture(tester.getCenter(detector));
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 40));
        final scales = tester
            .widgetList<ScaleTransition>(
              find.descendant(
                of: answer,
                matching: find.byType(ScaleTransition),
              ),
            )
            .map((transition) => transition.scale.value);
        expect(
          scales.any((scale) => scale < 1),
          isTrue,
          reason: scales.toList().toString(),
        );
      },
    );
  });

  testWidgets('golden Game controller selected state', (tester) async {
    await _pumpState(
      tester,
      id: 'selected',
      value: const AsyncData<GameSessionRouteState>(
        GameSessionRouteState(content: _lockedState),
      ),
      check: (_) async => expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.selected == true,
        ),
        findsAtLeastNWidgets(2),
      ),
    );
  });

  testWidgets('golden Game controller large-text state', (tester) async {
    await _pumpState(
      tester,
      id: 'large_text',
      size: const Size(320, 720),
      textScale: 2,
      value: const AsyncData<GameSessionRouteState>(
        GameSessionRouteState(content: _joinedState),
      ),
      check: (tester) async {
        final answer = find.byKey(
          const ValueKey<String>('game-controller-answer-a'),
        );
        await tester.scrollUntilVisible(
          answer,
          240,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(answer).height, greaterThanOrEqualTo(64));
      },
    );
  });

  testWidgets('golden Game controller reduced-motion state', (tester) async {
    await _pumpState(
      tester,
      id: 'reduced_motion',
      reducedMotion: true,
      value: const AsyncData<GameSessionRouteState>(
        GameSessionRouteState(content: _joinedState),
      ),
      check: (tester) async => expect(
        MediaQuery.disableAnimationsOf(
          tester.element(find.byType(GameSessionControllerScreen)),
        ),
        isTrue,
      ),
    );
  });

  testWidgets('golden Game controller dark state', (tester) async {
    await _pumpState(
      tester,
      id: 'dark',
      value: const AsyncData<GameSessionRouteState>(
        GameSessionRouteState(content: _joinedState),
      ),
    );
  });

  testWidgets('golden Game controller light state', (tester) async {
    await _pumpState(
      tester,
      id: 'light',
      brightness: Brightness.light,
      value: const AsyncData<GameSessionRouteState>(
        GameSessionRouteState(content: _joinedState),
      ),
    );
  });

  testWidgets('golden Game controller syncing state', (tester) async {
    await _pumpState(
      tester,
      id: 'syncing',
      settle: false,
      value: const AsyncData<GameSessionRouteState>(
        GameSessionRouteState(
          content: _joinedState,
          phase: GameSessionRoutePhase.syncing,
          mutation: GameSessionMutation.submittingAnswer,
        ),
      ),
      check: (_) async =>
          expect(find.text('Confirming answer'), findsOneWidget),
    );
  });

  testWidgets('golden Game controller conflict state', (tester) async {
    await _pumpState(
      tester,
      id: 'conflict',
      value: const AsyncData<GameSessionRouteState>(
        GameSessionRouteState(
          content: _joinedState,
          phase: GameSessionRoutePhase.degraded,
          failure: GameSessionFailure(GameSessionFailureKind.conflict),
        ),
      ),
      check: (_) async =>
          expect(find.text('Live state changed'), findsOneWidget),
    );
  });

  testWidgets('golden Game controller security-timeout state', (tester) async {
    await _pumpState(
      tester,
      id: 'security_timeout',
      value: const AsyncData<GameSessionRouteState>(
        GameSessionRouteState(
          content: _joinedState,
          phase: GameSessionRoutePhase.degraded,
          failure: GameSessionFailure(GameSessionFailureKind.securityTimeout),
          uncertainMutation: true,
        ),
      ),
      check: (_) async =>
          expect(find.text('Confirmation uncertain'), findsOneWidget),
    );
  });
}

Future<void> _pumpState(
  WidgetTester tester, {
  required String id,
  required AsyncValue<GameSessionRouteState> value,
  String? playerId = 'player-1',
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
    playerId: playerId,
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
    find.byKey(const ValueKey<String>('game-controller-state-golden')),
    matchesGoldenFile(_goldens[id]!),
  );
}

Future<void> _pumpRoute(
  WidgetTester tester, {
  required _Controller controller,
  String? playerId = 'player-1',
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

  final query = playerId == null
      ? ''
      : '?session_player_id=${Uri.encodeQueryComponent(playerId)}';
  final router = GoRouter(
    initialLocation: '/fanzone/game/session-1$query',
    routes: [
      GoRoute(
        path: '/fanzone/game/:sessionId',
        builder: (_, state) => RepaintBoundary(
          key: const ValueKey<String>('game-controller-state-golden'),
          child: GameSessionControllerScreen(
            sessionId: state.pathParameters['sessionId']!,
            sessionPlayerId: state.uri.queryParameters['session_player_id'],
          ),
        ),
      ),
      GoRoute(path: '/fanzone', builder: (_, _) => const SizedBox.shrink()),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gameSessionControllerStateProvider.overrideWith(
          (ref, args) => controller,
        ),
        gameSessionControllerAccessEnabledProvider.overrideWithValue(
          accessEnabled,
        ),
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
  if (capture) {
    expect(find.byType(GameSessionControllerScreen), findsOneWidget);
  }
}

class _Controller extends GameSessionController {
  _Controller(AsyncValue<GameSessionRouteState> value)
    : super(_Gateway(), sessionId: 'session-1', autoLoad: false) {
    state = value;
  }

  int restoredCalls = 0;

  @override
  Future<void> connectionRestored() async {
    restoredCalls += 1;
  }
}

class _Gateway implements GameSessionGateway {
  @override
  Future<GameSessionControllerState?> loadControllerState({
    required String sessionId,
    String? sessionPlayerId,
  }) async => _joinedState;

  @override
  Future<GameSessionJoinResult> joinSession({
    required String sessionId,
    required String displayName,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Object?> submitAnswer({
    required String sessionQuestionId,
    required String sessionPlayerId,
    required String selectedOptionKey,
    required String idempotencyKey,
  }) {
    throw UnimplementedError();
  }
}

const _joinedState = GameSessionControllerState(
  sessionId: 'session-1',
  phase: GameSessionControllerPhase.answering,
  joinCode: 'RAYON24',
  playerName: 'Supporter',
  teamName: 'Blue Zone',
  questionLabel: 'Question 1 of 3',
  prompt: 'Which season delivered the first league title of the modern era?',
  options: [
    GameAnswerOption(key: 'a', label: '1995'),
    GameAnswerOption(key: 'b', label: '1998'),
    GameAnswerOption(key: 'c', label: '2002'),
    GameAnswerOption(key: 'd', label: '2004'),
  ],
  selectedOptionKey: null,
  statusMessage: 'Choose once. The server confirms the first accepted answer.',
  leaderboard: [
    GameLeaderboardRow(rank: 1, teamName: 'East Stand', score: 820),
    GameLeaderboardRow(rank: 2, teamName: 'Blue Zone', score: 760),
    GameLeaderboardRow(rank: 3, teamName: 'Away Corner', score: 610),
  ],
  sessionQuestionId: 'question-1',
  sessionPlayerId: 'player-1',
);

const _lockedState = GameSessionControllerState(
  sessionId: 'session-1',
  phase: GameSessionControllerPhase.locked,
  joinCode: 'RAYON24',
  playerName: 'Supporter',
  teamName: 'Blue Zone',
  questionLabel: 'Question 1 of 3',
  prompt: 'Which season delivered the first league title of the modern era?',
  options: [
    GameAnswerOption(key: 'a', label: '1995'),
    GameAnswerOption(key: 'b', label: '1998'),
    GameAnswerOption(key: 'c', label: '2002'),
    GameAnswerOption(key: 'd', label: '2004'),
  ],
  selectedOptionKey: 'a',
  statusMessage: 'Answer submitted. Waiting for the TV reveal.',
  leaderboard: [
    GameLeaderboardRow(rank: 1, teamName: 'East Stand', score: 820),
    GameLeaderboardRow(rank: 2, teamName: 'Blue Zone', score: 760),
  ],
  sessionQuestionId: 'question-1',
  sessionPlayerId: 'player-1',
);

const _unjoinedState = GameSessionControllerState(
  sessionId: 'session-1',
  phase: GameSessionControllerPhase.join,
  joinCode: 'RAYON24',
  playerName: 'Supporter',
  teamName: 'Fan Zone',
  questionLabel: 'Waiting room',
  prompt: 'Join before the host opens the next question.',
  options: [],
  selectedOptionKey: null,
  statusMessage: 'Confirm membership before answering.',
  leaderboard: [],
);
