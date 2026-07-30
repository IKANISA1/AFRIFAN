import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_gamification/src/controllers/game_session_controller.dart';
import 'package:feat_gamification/src/models/game_session_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test('loads the authoritative controller state', () async {
    final gateway = _Gateway();
    final controller = GameSessionController(
      gateway,
      sessionId: 'session-1',
      sessionPlayerId: 'player-1',
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.state.value!.content?.joinCode, 'RAYON24');
    expect(controller.state.value!.phase, GameSessionRoutePhase.ready);
    expect(gateway.loadCalls, 1);
  });

  test('fails offline before controller-state gateway access', () async {
    ConnectivityService.setOnlineForTest(false);
    final gateway = _Gateway();
    final controller = GameSessionController(
      gateway,
      sessionId: 'session-1',
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(gateway.loadCalls, 0);
    expect(
      (controller.state.error as GameSessionFailure).kind,
      GameSessionFailureKind.offline,
    );
  });

  test('maps authorization failures without raw details', () async {
    final gateway = _Gateway()
      ..loadError = StateError('row-level security denied player-secret-9');
    final controller = GameSessionController(
      gateway,
      sessionId: 'session-1',
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.load();

    final failure = controller.state.error as GameSessionFailure;
    expect(failure.kind, GameSessionFailureKind.permissionDenied);
    expect(failure.toString(), isNot(contains('player-secret-9')));
  });

  test('coalesces overlapping controller refreshes', () async {
    final pending = Completer<GameSessionControllerState?>();
    final gateway = _Gateway()..loadCompleter = pending;
    final controller = GameSessionController(
      gateway,
      sessionId: 'session-1',
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    final first = controller.load();
    final second = controller.refresh();
    pending.complete(_joinedState);
    await Future.wait([first, second]);

    expect(gateway.loadCalls, 1);
  });

  test('validates display name before join gateway access', () async {
    final gateway = _Gateway()..state = _unjoinedState;
    final controller = GameSessionController(
      gateway,
      sessionId: 'session-1',
      autoLoad: false,
    );
    addTearDown(controller.dispose);
    await controller.load();

    final outcome = await controller.join(' ');

    expect(outcome.isSuccess, isFalse);
    expect(gateway.joinCalls, 0);
    expect(controller.state.value!.validationMessage, contains('2 to 48'));
  });

  test('uncertain join timeout blocks repeated mutation', () async {
    final gateway = _Gateway()
      ..state = _unjoinedState
      ..joinCompleter = Completer<GameSessionJoinResult>();
    final controller = GameSessionController(
      gateway,
      sessionId: 'session-1',
      mutationTimeout: const Duration(milliseconds: 1),
      autoLoad: false,
    );
    addTearDown(controller.dispose);
    await controller.load();

    final first = await controller.join('Supporter');
    final repeated = await controller.join('Supporter');

    expect(first.failure?.kind, GameSessionFailureKind.securityTimeout);
    expect(repeated.failure?.kind, GameSessionFailureKind.conflict);
    expect(controller.state.value!.uncertainMutation, isTrue);
    expect(gateway.joinCalls, 1);
  });

  test(
    'answer confirmation locks locally with one stable idempotency key',
    () async {
      final gateway = _Gateway();
      final controller = GameSessionController(
        gateway,
        sessionId: 'session-1',
        sessionPlayerId: 'player-1',
        autoLoad: false,
      );
      addTearDown(controller.dispose);
      await controller.load();

      final outcome = await controller.submitAnswer(_joinedState.options.first);

      expect(outcome.isSuccess, isTrue);
      expect(gateway.answerCalls, 1);
      expect(gateway.idempotencyKeys, ['answer:session-1:question-1:player-1']);
      expect(
        controller.state.value!.content?.phase,
        GameSessionControllerPhase.locked,
      );
      expect(controller.state.value!.content?.selectedOptionKey, 'a');
    },
  );
}

const _joinedState = GameSessionControllerState(
  sessionId: 'session-1',
  phase: GameSessionControllerPhase.answering,
  joinCode: 'RAYON24',
  playerName: 'Supporter',
  teamName: 'Blue Zone',
  questionLabel: 'Question 1 of 3',
  prompt: 'Which season delivered the first title?',
  options: [
    GameAnswerOption(key: 'a', label: '1995'),
    GameAnswerOption(key: 'b', label: '1998'),
  ],
  selectedOptionKey: null,
  statusMessage: 'Choose once. The server confirms the answer.',
  leaderboard: [GameLeaderboardRow(rank: 1, teamName: 'Blue Zone', score: 120)],
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

const _joinResult = GameSessionJoinResult(
  sessionId: 'session-1',
  sessionPlayerId: 'player-1',
  displayName: 'Supporter',
  joinCode: 'RAYON24',
  score: 0,
);

class _Gateway implements GameSessionGateway {
  GameSessionControllerState? state = _joinedState;
  Object? loadError;
  Completer<GameSessionControllerState?>? loadCompleter;
  Completer<GameSessionJoinResult>? joinCompleter;
  int loadCalls = 0;
  int joinCalls = 0;
  int answerCalls = 0;
  final List<String> idempotencyKeys = [];

  @override
  Future<GameSessionControllerState?> loadControllerState({
    required String sessionId,
    String? sessionPlayerId,
  }) async {
    loadCalls += 1;
    if (loadError != null) throw loadError!;
    if (loadCompleter != null) return loadCompleter!.future;
    return state;
  }

  @override
  Future<GameSessionJoinResult> joinSession({
    required String sessionId,
    required String displayName,
  }) async {
    joinCalls += 1;
    if (joinCompleter != null) return joinCompleter!.future;
    return _joinResult;
  }

  @override
  Future<Object?> submitAnswer({
    required String sessionQuestionId,
    required String sessionPlayerId,
    required String selectedOptionKey,
    required String idempotencyKey,
  }) async {
    answerCalls += 1;
    idempotencyKeys.add(idempotencyKey);
    return const <String, Object?>{'accepted': true};
  }
}
