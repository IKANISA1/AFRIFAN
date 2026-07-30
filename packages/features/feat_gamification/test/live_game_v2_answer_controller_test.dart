import 'dart:async';

import 'package:feat_gamification/src/controllers/live_game_v2_answer_controller.dart';
import 'package:feat_gamification/src/models/live_game_v2_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ParticipantAnswerSubmissionController', () {
    test(
      'submits expected versions and accepts an authoritative response',
      () async {
        final gateway = _Gateway()
          ..response = _projection(
            sessionVersion: 5,
            eventSequence: 1,
            answerState: 'accepted',
            allowedActions: const <String>[],
          );
        final controller = _controller(gateway);
        addTearDown(controller.dispose);

        final outcome = await controller.submit('b');

        expect(outcome.accepted, isTrue);
        expect(
          controller.state.status,
          ParticipantAnswerSubmissionStatus.accepted,
        );
        expect(
          controller.state.projection.answerState,
          ParticipantAnswerState.accepted,
        );
        expect(gateway.requests, hasLength(1));
        expect(gateway.requests.single.toJson(), <String, Object>{
          'club_id': 'club-1',
          'session_id': 'session-1',
          'question_id': 'question-1',
          'option_key': 'b',
          'expected_session_version': 4,
          'expected_question_version': 2,
          'idempotency_key': 'participant-answer:session-1:question-1:2',
        });
      },
    );

    test('rejects an option outside the authoritative projection', () async {
      final gateway = _Gateway();
      final controller = _controller(gateway);
      addTearDown(controller.dispose);

      final outcome = await controller.submit('not-an-option');

      expect(outcome.accepted, isFalse);
      expect(
        outcome.failureKind,
        ParticipantAnswerSubmissionFailureKind.invalidAction,
      );
      expect(gateway.requests, isEmpty);
      expect(controller.state.status, ParticipantAnswerSubmissionStatus.idle);
    });

    test('does not resubmit after an authoritative answer state', () async {
      final gateway = _Gateway();
      final controller = ParticipantAnswerSubmissionController(
        gateway: gateway,
        initialProjection: _projection(
          answerState: 'accepted',
          allowedActions: const <String>['submit_answer'],
        ),
        expectedClubId: 'club-1',
        sessionId: 'session-1',
      );
      addTearDown(controller.dispose);

      final outcome = await controller.submit('a');

      expect(
        outcome.failureKind,
        ParticipantAnswerSubmissionFailureKind.invalidAction,
      );
      expect(gateway.requests, isEmpty);
    });

    test(
      'coalesces duplicate submissions while one request is in flight',
      () async {
        final pending = Completer<ParticipantGameProjection>();
        final gateway = _Gateway()..pendingResponse = pending;
        final controller = _controller(gateway);
        addTearDown(controller.dispose);

        final first = controller.submit('a');
        final duplicate = controller.submit('a');
        final conflicting = await controller.submit('b');
        pending.complete(
          _projection(
            sessionVersion: 5,
            answerState: 'accepted',
            allowedActions: const <String>[],
          ),
        );

        expect(identical(first, duplicate), isTrue);
        expect(
          conflicting.failureKind,
          ParticipantAnswerSubmissionFailureKind.conflict,
        );
        expect((await first).accepted, isTrue);
        expect(gateway.requests, hasLength(1));
      },
    );

    test(
      'timeout retains projection and requires authoritative refresh',
      () async {
        final gateway = _Gateway()
          ..pendingResponse = Completer<ParticipantGameProjection>();
        final controller = _controller(
          gateway,
          submissionTimeout: const Duration(milliseconds: 1),
        );
        addTearDown(controller.dispose);

        final outcome = await controller.submit('a');

        expect(
          outcome.failureKind,
          ParticipantAnswerSubmissionFailureKind.timeout,
        );
        expect(
          controller.state.status,
          ParticipantAnswerSubmissionStatus.uncertain,
        );
        expect(controller.state.requiresAuthoritativeRefresh, isTrue);
        expect(controller.state.projection.version.sessionVersion, 4);

        final reconciled = controller.reconcileProjection(
          _projection(
            sessionVersion: 5,
            answerState: 'accepted',
            allowedActions: const <String>[],
          ),
        );
        expect(reconciled, isTrue);
        expect(controller.state.status, ParticipantAnswerSubmissionStatus.idle);
        expect(
          controller.state.projection.answerState,
          ParticipantAnswerState.accepted,
        );
      },
    );

    test(
      'same-revision authoritative refresh safely clears uncertainty',
      () async {
        final gateway = _Gateway()
          ..pendingResponse = Completer<ParticipantGameProjection>();
        final controller = _controller(
          gateway,
          submissionTimeout: const Duration(milliseconds: 1),
        );
        addTearDown(controller.dispose);
        await controller.submit('a');

        expect(
          controller.resetFromAuthoritativeProjection(_projection()),
          isTrue,
        );
        expect(controller.state.status, ParticipantAnswerSubmissionStatus.idle);
        expect(controller.state.requiresAuthoritativeRefresh, isFalse);
      },
    );

    test(
      'keeps a newer Realtime answer confirmation over a stale response',
      () async {
        final pending = Completer<ParticipantGameProjection>();
        final gateway = _Gateway()..pendingResponse = pending;
        final controller = _controller(gateway);
        addTearDown(controller.dispose);

        final submission = controller.submit('a');
        expect(
          controller.reconcileProjection(
            _projection(
              sessionVersion: 6,
              answerState: 'accepted',
              allowedActions: const <String>[],
            ),
          ),
          isTrue,
        );
        pending.complete(
          _projection(
            sessionVersion: 5,
            answerState: 'accepted',
            allowedActions: const <String>[],
          ),
        );

        expect((await submission).accepted, isTrue);
        expect(controller.state.projection.version.sessionVersion, 6);
        expect(
          controller.state.status,
          ParticipantAnswerSubmissionStatus.accepted,
        );
      },
    );

    test('rejects a stale mutation response as a contract failure', () async {
      final gateway = _Gateway()..response = _projection();
      final controller = _controller(gateway);
      addTearDown(controller.dispose);

      final outcome = await controller.submit('a');

      expect(outcome.accepted, isFalse);
      expect(
        outcome.failureKind,
        ParticipantAnswerSubmissionFailureKind.contract,
      );
      expect(controller.state.projection.version.sessionVersion, 4);
    });

    test('maps sensitive gateway errors to a sanitized failure kind', () async {
      final gateway = _Gateway()
        ..error = StateError('RLS rejected secret-token-value');
      final controller = _controller(gateway);
      addTearDown(controller.dispose);

      final outcome = await controller.submit('a');

      expect(
        outcome.failureKind,
        ParticipantAnswerSubmissionFailureKind.permissionDenied,
      );
      expect(
        controller.state.failureKind,
        ParticipantAnswerSubmissionFailureKind.permissionDenied,
      );
      expect(
        controller.state.toString(),
        isNot(contains('secret-token-value')),
      );
    });

    test('rejects wrong-scope construction and reconciliation', () {
      final gateway = _Gateway();

      expect(
        () => ParticipantAnswerSubmissionController(
          gateway: gateway,
          initialProjection: _projection(clubId: 'club-2'),
          expectedClubId: 'club-1',
          sessionId: 'session-1',
        ),
        throwsA(isA<LiveGameContractViolation>()),
      );

      final controller = _controller(gateway);
      addTearDown(controller.dispose);
      expect(
        () => controller.reconcileProjection(
          _projection(sessionId: 'session-2', sessionVersion: 5),
        ),
        throwsA(isA<LiveGameContractViolation>()),
      );
    });
  });
}

class _Gateway implements ParticipantAnswerSubmissionGateway {
  final List<ParticipantAnswerSubmissionRequest> requests =
      <ParticipantAnswerSubmissionRequest>[];
  ParticipantGameProjection? response;
  Completer<ParticipantGameProjection>? pendingResponse;
  Object? error;

  @override
  Future<ParticipantGameProjection> submitAnswer(
    ParticipantAnswerSubmissionRequest request,
  ) async {
    requests.add(request);
    final currentError = error;
    if (currentError != null) throw currentError;
    final pending = pendingResponse;
    if (pending != null) return pending.future;
    final currentResponse = response;
    if (currentResponse != null) return currentResponse;
    throw StateError('No response configured.');
  }
}

ParticipantAnswerSubmissionController _controller(
  _Gateway gateway, {
  Duration submissionTimeout = const Duration(seconds: 1),
}) {
  return ParticipantAnswerSubmissionController(
    gateway: gateway,
    initialProjection: _projection(),
    expectedClubId: 'club-1',
    sessionId: 'session-1',
    submissionTimeout: submissionTimeout,
  );
}

ParticipantGameProjection _projection({
  String clubId = 'club-1',
  String sessionId = 'session-1',
  int sessionVersion = 4,
  int eventSequence = 0,
  String answerState = 'not_answered',
  List<String> allowedActions = const <String>['submit_answer'],
}) {
  return ParticipantGameProjection.fromJson(<String, Object?>{
    'club_id': clubId,
    'session_id': sessionId,
    'phase': 'question_open',
    'session_version': sessionVersion,
    'event_sequence': eventSequence,
    'server_time': '2026-07-30T08:00:00Z',
    'phase_deadline': '2026-07-30T08:00:15Z',
    'question_version': 2,
    'freshness': <String, Object?>{
      'state': 'current',
      'last_event_at': '2026-07-30T08:00:00Z',
    },
    'eligibility': true,
    'public_alias': 'Lion 42',
    'answer_state': answerState,
    'allowed_actions': allowedActions,
    'question': <String, Object?>{
      'id': 'question-1',
      'prompt': 'Who scored first?',
      'options': <Map<String, String>>[
        <String, String>{'key': 'a', 'label': 'Player A'},
        <String, String>{'key': 'b', 'label': 'Player B'},
      ],
    },
    'leader_summary': const <Object?>[],
  }, expectedClubId: clubId);
}
