import 'dart:async';

import 'package:feat_gamification/src/controllers/live_game_v2_answer_controller.dart';
import 'package:feat_gamification/src/controllers/live_game_v2_participant_controller.dart';
import 'package:feat_gamification/src/controllers/live_game_v2_reconciler.dart';
import 'package:feat_gamification/src/controllers/live_game_v2_synchronizer.dart';
import 'package:feat_gamification/src/models/live_game_v2_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ParticipantLiveGameController', () {
    test(
      'starts with an authoritative projection and enables answering',
      () async {
        final syncGateway = _SyncGateway()..projections.add(_projection());
        final controller = _controller(syncGateway: syncGateway);
        addTearDown(controller.dispose);

        await controller.start();

        expect(controller.state.syncStatus, LiveGameSyncStatus.ready);
        expect(controller.state.projection?.version.sessionVersion, 4);
        expect(controller.state.actionsBlocked, isFalse);
      },
    );

    test('automatically follows a newer invalidation hint', () async {
      final syncGateway = _SyncGateway()
        ..projections.addAll(<ParticipantGameProjection>[
          _projection(),
          _projection(sessionVersion: 5, eventSequence: 1),
        ]);
      final controller = _controller(syncGateway: syncGateway);
      addTearDown(controller.dispose);
      await controller.start();

      syncGateway.hints.add(
        const LiveGameInvalidationHint(
          clubId: 'club-1',
          sessionId: 'session-1',
          sessionVersion: 5,
          eventSequence: 1,
        ),
      );
      await _drainEvents();

      expect(controller.state.syncStatus, LiveGameSyncStatus.ready);
      expect(controller.state.projection?.version.sessionVersion, 5);
      expect(syncGateway.fetchCalls, 2);
    });

    test(
      'submits an answer and adopts the authoritative mutation projection',
      () async {
        final syncGateway = _SyncGateway()..projections.add(_projection());
        final answerGateway = _AnswerGateway()
          ..response = _projection(
            sessionVersion: 5,
            answerState: 'accepted',
            allowedActions: const <String>[],
          );
        final controller = _controller(
          syncGateway: syncGateway,
          answerGateway: answerGateway,
        );
        addTearDown(controller.dispose);
        await controller.start();

        final outcome = await controller.submitAnswer('b');

        expect(outcome.accepted, isTrue);
        expect(
          controller.state.answerStatus,
          ParticipantAnswerSubmissionStatus.accepted,
        );
        expect(
          controller.state.projection?.answerState,
          ParticipantAnswerState.accepted,
        );
        expect(controller.state.actionsBlocked, isTrue);
        expect(answerGateway.requests.single.expectedSessionVersion, 4);
        expect(answerGateway.requests.single.expectedQuestionVersion, 2);
      },
    );

    test(
      'blocks mutation while offline and retains the last projection',
      () async {
        final syncGateway = _SyncGateway()..projections.add(_projection());
        final answerGateway = _AnswerGateway();
        final controller = _controller(
          syncGateway: syncGateway,
          answerGateway: answerGateway,
        );
        addTearDown(controller.dispose);
        await controller.start();

        controller.markOffline();
        final outcome = await controller.submitAnswer('a');

        expect(controller.state.syncStatus, LiveGameSyncStatus.offline);
        expect(controller.state.hasRetainedProjection, isTrue);
        expect(
          outcome.failureKind,
          ParticipantAnswerSubmissionFailureKind.unavailable,
        );
        expect(answerGateway.requests, isEmpty);
      },
    );

    test(
      'refresh clears timeout uncertainty from an authoritative snapshot',
      () async {
        final syncGateway = _SyncGateway()
          ..projections.addAll(<ParticipantGameProjection>[
            _projection(),
            _projection(),
          ]);
        final answerGateway = _AnswerGateway()
          ..pendingResponse = Completer<ParticipantGameProjection>();
        final controller = _controller(
          syncGateway: syncGateway,
          answerGateway: answerGateway,
          submissionTimeout: const Duration(milliseconds: 1),
        );
        addTearDown(controller.dispose);
        await controller.start();

        final outcome = await controller.submitAnswer('a');
        expect(
          outcome.failureKind,
          ParticipantAnswerSubmissionFailureKind.timeout,
        );
        expect(controller.state.requiresAuthoritativeRefresh, isTrue);

        await controller.refresh();

        expect(controller.state.syncStatus, LiveGameSyncStatus.ready);
        expect(
          controller.state.answerStatus,
          ParticipantAnswerSubmissionStatus.idle,
        );
        expect(controller.state.actionsBlocked, isFalse);
      },
    );

    test(
      'permission revocation blocks actions without dropping content',
      () async {
        final syncGateway = _SyncGateway()..projections.add(_projection());
        final answerGateway = _AnswerGateway();
        final controller = _controller(
          syncGateway: syncGateway,
          answerGateway: answerGateway,
        );
        addTearDown(controller.dispose);
        await controller.start();
        syncGateway.fetchFailure = const LiveGameSyncFailure(
          LiveGameSyncFailureKind.permissionDenied,
        );

        await controller.refresh();
        final outcome = await controller.submitAnswer('a');

        expect(controller.state.syncStatus, LiveGameSyncStatus.failure);
        expect(controller.state.hasRetainedProjection, isTrue);
        expect(
          controller.state.syncFailureKind,
          LiveGameSyncFailureKind.permissionDenied,
        );
        expect(
          outcome.failureKind,
          ParticipantAnswerSubmissionFailureKind.permissionDenied,
        );
        expect(answerGateway.requests, isEmpty);
      },
    );

    test(
      'reconnect fetches a newer snapshot after offline retention',
      () async {
        final syncGateway = _SyncGateway()
          ..projections.addAll(<ParticipantGameProjection>[
            _projection(),
            _projection(sessionVersion: 5, eventSequence: 1),
          ]);
        final controller = _controller(syncGateway: syncGateway);
        addTearDown(controller.dispose);
        await controller.start();
        controller.markOffline();

        await controller.reconnect();

        expect(controller.state.syncStatus, LiveGameSyncStatus.ready);
        expect(controller.state.projection?.version.sessionVersion, 5);
      },
    );

    test('dispose prevents further controller operations', () async {
      final syncGateway = _SyncGateway()..projections.add(_projection());
      final controller = _controller(syncGateway: syncGateway);
      await controller.start();

      controller.dispose();

      expect(controller.refresh, throwsStateError);
      expect(() => controller.markOffline(), throwsStateError);
      await _drainEvents();
      expect(syncGateway.hints.hasListener, isFalse);
    });
  });
}

class _SyncGateway implements ParticipantLiveGameGateway {
  final List<ParticipantGameProjection> projections =
      <ParticipantGameProjection>[];
  final StreamController<LiveGameInvalidationHint> hints =
      StreamController<LiveGameInvalidationHint>.broadcast(sync: true);
  Object? fetchFailure;
  int fetchCalls = 0;

  @override
  Future<ParticipantGameProjection> fetchProjection() async {
    fetchCalls += 1;
    final failure = fetchFailure;
    if (failure != null) throw failure;
    if (projections.isEmpty) throw StateError('No projection configured.');
    return projections.removeAt(0);
  }

  @override
  Stream<LiveGameInvalidationHint> watchInvalidationHints() => hints.stream;

  Future<void> dispose() => hints.close();
}

class _AnswerGateway implements ParticipantAnswerSubmissionGateway {
  final List<ParticipantAnswerSubmissionRequest> requests =
      <ParticipantAnswerSubmissionRequest>[];
  ParticipantGameProjection? response;
  Completer<ParticipantGameProjection>? pendingResponse;

  @override
  Future<ParticipantGameProjection> submitAnswer(
    ParticipantAnswerSubmissionRequest request,
  ) async {
    requests.add(request);
    final pending = pendingResponse;
    if (pending != null) return pending.future;
    final current = response;
    if (current != null) return current;
    throw StateError('No answer response configured.');
  }
}

ParticipantLiveGameController _controller({
  required _SyncGateway syncGateway,
  _AnswerGateway? answerGateway,
  Duration submissionTimeout = const Duration(seconds: 1),
}) {
  addTearDown(syncGateway.dispose);
  return ParticipantLiveGameController(
    syncGateway: syncGateway,
    answerGateway: answerGateway ?? _AnswerGateway(),
    expectedClubId: 'club-1',
    sessionId: 'session-1',
    submissionTimeout: submissionTimeout,
    autoStart: false,
  );
}

ParticipantGameProjection _projection({
  int sessionVersion = 4,
  int eventSequence = 0,
  String answerState = 'not_answered',
  List<String> allowedActions = const <String>['submit_answer'],
}) {
  return ParticipantGameProjection.fromJson(<String, Object?>{
    'club_id': 'club-1',
    'session_id': 'session-1',
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
  }, expectedClubId: 'club-1');
}

Future<void> _drainEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
