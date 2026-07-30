import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_gamification/src/controllers/game_session_join_controller.dart';
import 'package:feat_gamification/src/models/game_session_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test('normalizes code and confirms a successful join', () async {
    final gateway = _Gateway();
    final controller = GameSessionJoinController(gateway);
    addTearDown(controller.dispose);

    final outcome = await controller.join(
      joinCode: ' rayon6 ',
      displayName: '  ',
    );

    expect(outcome.isSuccess, isTrue);
    expect(outcome.result?.sessionId, 'session-1');
    expect(gateway.codes, ['RAYON6']);
    expect(gateway.names, ['Supporter']);
    expect(controller.state.value!.phase, GameSessionJoinPhase.ready);
  });

  test('rejects an empty code before gateway access', () async {
    final gateway = _Gateway();
    final controller = GameSessionJoinController(gateway);
    addTearDown(controller.dispose);

    final outcome = await controller.join(
      joinCode: ' ',
      displayName: 'Supporter',
    );

    expect(outcome.validationMessage, 'Enter the TV session code.');
    expect(gateway.calls, 0);
    expect(
      controller.state.value!.validationMessage,
      'Enter the TV session code.',
    );
  });

  test('rejects malformed codes before gateway access', () async {
    final gateway = _Gateway();
    final controller = GameSessionJoinController(gateway);
    addTearDown(controller.dispose);

    final outcome = await controller.join(
      joinCode: 'A!',
      displayName: 'Supporter',
    );

    expect(outcome.isSuccess, isFalse);
    expect(outcome.validationMessage, contains('3–32'));
    expect(gateway.calls, 0);
  });

  test('fails offline before gateway access', () async {
    ConnectivityService.setOnlineForTest(false);
    final gateway = _Gateway();
    final controller = GameSessionJoinController(gateway);
    addTearDown(controller.dispose);

    final outcome = await controller.join(
      joinCode: 'RAYON6',
      displayName: 'Supporter',
    );

    expect(gateway.calls, 0);
    expect(outcome.failure?.kind, GameSessionJoinFailureKind.offline);
    expect(
      controller.state.value!.failure?.kind,
      GameSessionJoinFailureKind.offline,
    );
  });

  test('maps authorization failures without exposing raw details', () async {
    final gateway = _Gateway()
      ..error = StateError('row-level security denied supporter-991');
    final controller = GameSessionJoinController(gateway);
    addTearDown(controller.dispose);

    final outcome = await controller.join(
      joinCode: 'RAYON6',
      displayName: 'Supporter',
    );

    expect(outcome.failure?.kind, GameSessionJoinFailureKind.permissionDenied);
    expect(outcome.failure.toString(), isNot(contains('supporter-991')));
  });

  test('uncertain timeout blocks a repeated join', () async {
    final gateway = _Gateway()..completer = Completer<GameSessionJoinResult>();
    final controller = GameSessionJoinController(
      gateway,
      mutationTimeout: const Duration(milliseconds: 1),
    );
    addTearDown(controller.dispose);

    final first = await controller.join(
      joinCode: 'RAYON6',
      displayName: 'Supporter',
    );
    final repeated = await controller.join(
      joinCode: 'RAYON6',
      displayName: 'Supporter',
    );

    expect(first.failure?.kind, GameSessionJoinFailureKind.securityTimeout);
    expect(repeated.failure?.kind, GameSessionJoinFailureKind.conflict);
    expect(gateway.calls, 1);
  });

  test('coalesces overlapping join attempts', () async {
    final pending = Completer<GameSessionJoinResult>();
    final gateway = _Gateway()..completer = pending;
    final controller = GameSessionJoinController(gateway);
    addTearDown(controller.dispose);

    final first = controller.join(joinCode: 'RAYON6', displayName: 'Supporter');
    final second = await controller.join(
      joinCode: 'RAYON6',
      displayName: 'Supporter',
    );
    pending.complete(_result);
    final confirmed = await first;

    expect(second.failure?.kind, GameSessionJoinFailureKind.conflict);
    expect(confirmed.isSuccess, isTrue);
    expect(gateway.calls, 1);
  });
}

const _result = GameSessionJoinResult(
  sessionId: 'session-1',
  sessionPlayerId: 'player-1',
  displayName: 'Supporter',
  joinCode: 'RAYON6',
  score: 0,
);

class _Gateway implements GameSessionJoinGateway {
  int calls = 0;
  final List<String> codes = [];
  final List<String> names = [];
  Object? error;
  Completer<GameSessionJoinResult>? completer;

  @override
  Future<GameSessionJoinResult> joinByCode({
    required String joinCode,
    required String displayName,
  }) async {
    calls += 1;
    codes.add(joinCode);
    names.add(displayName);
    if (error != null) throw error!;
    if (completer != null) return completer!.future;
    return _result;
  }
}
