import 'dart:async';

import 'package:feat_gamification/src/controllers/live_game_v2_answer_controller.dart';
import 'package:feat_gamification/src/controllers/live_game_v2_discovery_controller.dart';
import 'package:feat_gamification/src/controllers/live_game_v2_entry_controller.dart';
import 'package:feat_gamification/src/controllers/live_game_v2_participant_controller.dart';
import 'package:feat_gamification/src/controllers/live_game_v2_reconciler.dart';
import 'package:feat_gamification/src/controllers/live_game_v2_synchronizer.dart';
import 'package:feat_gamification/src/models/live_game_v2_discovery_models.dart';
import 'package:feat_gamification/src/models/live_game_v2_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ParticipantGameEntryController', () {
    test(
      'loads code-free discovery without creating a session runtime',
      () async {
        final discovery = _DiscoveryGateway()..feeds.add(_feed());
        final runtimes = _RuntimeFactory();
        final controller = _controller(discovery, runtimes);
        addTearDown(controller.dispose);

        await controller.start();

        expect(controller.state.status, ParticipantGameEntryStatus.ready);
        expect(controller.state.acceptsParticipantCode, isFalse);
        expect(controller.state.feed?.publicAlias, 'Lion 42');
        expect(runtimes.createdSessionIds, isEmpty);
      },
    );

    test('opens an eligible live session by authoritative identity', () async {
      final discovery = _DiscoveryGateway()..feeds.add(_feed());
      final runtimes = _RuntimeFactory();
      final controller = _controller(discovery, runtimes);
      addTearDown(controller.dispose);
      await controller.start();

      final opened = await controller.openEligibleSession('session-live');

      expect(opened, isTrue);
      expect(controller.state.status, ParticipantGameEntryStatus.live);
      expect(controller.state.selectedSession?.sessionId, 'session-live');
      expect(runtimes.createdSessionIds, <String>['session-live']);
    });

    test('forwards answers only after eligible live entry', () async {
      final discovery = _DiscoveryGateway()..feeds.add(_feed());
      final runtimes = _RuntimeFactory();
      final controller = _controller(discovery, runtimes);
      addTearDown(controller.dispose);
      await controller.start();

      final beforeEntry = await controller.submitAnswer('a');
      expect(
        beforeEntry.failureKind,
        ParticipantAnswerSubmissionFailureKind.invalidAction,
      );

      await controller.openEligibleSession('session-live');
      final submitted = await controller.submitAnswer('b');

      expect(submitted.accepted, isTrue);
      expect(
        controller.state.runtime?.projection?.answerState,
        ParticipantAnswerState.accepted,
      );
      expect(runtimes.answerGateways.single.requests, hasLength(1));
    });

    test(
      'deep-link opening waits for auto-started discovery authority',
      () async {
        final pending = Completer<ParticipantGameDiscoveryFeed>();
        final discovery = _DiscoveryGateway()..pendingFeed = pending;
        final runtimes = _RuntimeFactory();
        final controller = ParticipantGameEntryController(
          discoveryGateway: discovery,
          runtimeFactory: runtimes,
          expectedClubId: 'club-1',
        );
        addTearDown(controller.dispose);

        final opening = controller.openEligibleSession('session-live');
        pending.complete(_feed());

        expect(await opening, isTrue);
        expect(controller.state.status, ParticipantGameEntryStatus.live);
        expect(discovery.fetchCalls, 1);
      },
    );

    test(
      'rejects unknown deep-link identity without creating a runtime',
      () async {
        final discovery = _DiscoveryGateway()..feeds.add(_feed());
        final runtimes = _RuntimeFactory();
        final controller = _controller(discovery, runtimes);
        addTearDown(controller.dispose);
        await controller.start();

        final opened = await controller.openEligibleSession('TV-CODE-123');

        expect(opened, isFalse);
        expect(controller.state.status, ParticipantGameEntryStatus.failure);
        expect(
          controller.state.entryFailureKind,
          ParticipantGameEntryFailureKind.notEligible,
        );
        expect(runtimes.createdSessionIds, isEmpty);
      },
    );

    test(
      'keeps a scheduled eligible session out of the live runtime',
      () async {
        final scheduled = ParticipantGameDiscoveryItem(
          clubId: 'club-1',
          sessionId: 'session-scheduled',
          title: 'Friday trivia',
          phase: LiveGamePhase.scheduled,
          source: ParticipantDiscoverySource.invitation,
          sessionVersion: 2,
          availableFrom: DateTime.utc(2026, 8, 1, 18),
          eligible: true,
        );
        final discovery = _DiscoveryGateway()
          ..feeds.add(
            _feed(sessions: <ParticipantGameDiscoveryItem>[scheduled]),
          );
        final runtimes = _RuntimeFactory();
        final controller = _controller(discovery, runtimes);
        addTearDown(controller.dispose);
        await controller.start();

        final opened = await controller.openEligibleSession(
          'session-scheduled',
        );

        expect(opened, isTrue);
        expect(controller.state.status, ParticipantGameEntryStatus.scheduled);
        expect(runtimes.createdSessionIds, isEmpty);
      },
    );

    test(
      'accepts invitation and deep-link sources only when feed-authorized',
      () async {
        final invitation = _liveItem(
          sessionId: 'session-invited',
          source: ParticipantDiscoverySource.invitation,
        );
        final deepLink = _liveItem(
          sessionId: 'session-deep-link',
          source: ParticipantDiscoverySource.deepLink,
        );
        final discovery = _DiscoveryGateway()
          ..feeds.add(
            _feed(
              sessions: <ParticipantGameDiscoveryItem>[invitation, deepLink],
            ),
          );
        final runtimes = _RuntimeFactory();
        final controller = _controller(discovery, runtimes);
        addTearDown(controller.dispose);
        await controller.start();

        expect(await controller.openEligibleSession('session-invited'), isTrue);
        expect(
          await controller.openEligibleSession('session-deep-link'),
          isTrue,
        );
        expect(runtimes.createdSessionIds, <String>[
          'session-invited',
          'session-deep-link',
        ]);
        expect(runtimes.controllers.first.refresh, throwsStateError);
      },
    );

    test('fails closed when discovery and runtime aliases differ', () async {
      final discovery = _DiscoveryGateway()..feeds.add(_feed());
      final runtimes = _RuntimeFactory(runtimeAlias: 'Different Alias');
      final controller = _controller(discovery, runtimes);
      addTearDown(controller.dispose);
      await controller.start();

      final opened = await controller.openEligibleSession('session-live');

      expect(opened, isFalse);
      expect(controller.state.status, ParticipantGameEntryStatus.failure);
      expect(
        controller.state.entryFailureKind,
        ParticipantGameEntryFailureKind.aliasMismatch,
      );
      await _drainEvents();
      expect(runtimes.controllers.single.refresh, throwsStateError);
    });

    test(
      'offline and reconnect propagate to discovery and active runtime',
      () async {
        final discovery = _DiscoveryGateway()
          ..feeds.addAll(<ParticipantGameDiscoveryFeed>[
            _feed(),
            _feed(feedVersion: 4),
          ]);
        final runtimes = _RuntimeFactory();
        final controller = _controller(discovery, runtimes);
        addTearDown(controller.dispose);
        await controller.start();
        await controller.openEligibleSession('session-live');

        controller.markOffline();
        expect(controller.state.status, ParticipantGameEntryStatus.offline);
        expect(controller.state.hasRetainedDiscovery, isTrue);

        await controller.reconnect();
        expect(controller.state.status, ParticipantGameEntryStatus.live);
        expect(discovery.fetchCalls, 2);
        expect(runtimes.syncGateways.single.fetchCalls, 2);
      },
    );

    test('dispose closes discovery and the active runtime', () async {
      final discovery = _DiscoveryGateway()..feeds.add(_feed());
      final runtimes = _RuntimeFactory();
      final controller = _controller(discovery, runtimes);
      await controller.start();
      await controller.openEligibleSession('session-live');

      controller.dispose();

      expect(controller.refreshDiscovery, throwsStateError);
      expect(runtimes.controllers.single.refresh, throwsStateError);
    });
  });
}

class _DiscoveryGateway implements ParticipantDiscoveryGateway {
  final List<ParticipantGameDiscoveryFeed> feeds =
      <ParticipantGameDiscoveryFeed>[];
  Completer<ParticipantGameDiscoveryFeed>? pendingFeed;
  int fetchCalls = 0;

  @override
  Future<ParticipantGameDiscoveryFeed> fetchEligibleSessions() async {
    fetchCalls += 1;
    final pending = pendingFeed;
    if (pending != null) return pending.future;
    if (feeds.isEmpty) {
      throw const ParticipantDiscoveryFailure(
        ParticipantDiscoveryFailureKind.unavailable,
      );
    }
    return feeds.removeAt(0);
  }
}

class _RuntimeFactory implements ParticipantLiveGameRuntimeFactory {
  _RuntimeFactory({this.runtimeAlias = 'Lion 42'});

  final String runtimeAlias;
  final List<String> createdSessionIds = <String>[];
  final List<ParticipantLiveGameController> controllers =
      <ParticipantLiveGameController>[];
  final List<_SyncGateway> syncGateways = <_SyncGateway>[];
  final List<_AnswerGateway> answerGateways = <_AnswerGateway>[];

  @override
  ParticipantLiveGameController create({
    required String clubId,
    required String sessionId,
  }) {
    createdSessionIds.add(sessionId);
    final syncGateway = _SyncGateway()
      ..projections.addAll(<ParticipantGameProjection>[
        _projection(
          clubId: clubId,
          sessionId: sessionId,
          publicAlias: runtimeAlias,
        ),
        _projection(
          clubId: clubId,
          sessionId: sessionId,
          publicAlias: runtimeAlias,
          sessionVersion: 5,
        ),
      ]);
    syncGateways.add(syncGateway);
    final answerGateway = _AnswerGateway(
      response: _projection(
        clubId: clubId,
        sessionId: sessionId,
        publicAlias: runtimeAlias,
        sessionVersion: 5,
        answerState: 'accepted',
        allowedActions: const <String>[],
      ),
    );
    answerGateways.add(answerGateway);
    final controller = ParticipantLiveGameController(
      syncGateway: syncGateway,
      answerGateway: answerGateway,
      expectedClubId: clubId,
      sessionId: sessionId,
      autoStart: false,
    );
    controllers.add(controller);
    return controller;
  }
}

class _SyncGateway implements ParticipantLiveGameGateway {
  final List<ParticipantGameProjection> projections =
      <ParticipantGameProjection>[];
  final StreamController<LiveGameInvalidationHint> hints =
      StreamController<LiveGameInvalidationHint>.broadcast(sync: true);
  int fetchCalls = 0;

  @override
  Future<ParticipantGameProjection> fetchProjection() async {
    fetchCalls += 1;
    if (projections.isEmpty) throw StateError('No projection configured.');
    return projections.removeAt(0);
  }

  @override
  Stream<LiveGameInvalidationHint> watchInvalidationHints() => hints.stream;

  Future<void> dispose() => hints.close();
}

class _AnswerGateway implements ParticipantAnswerSubmissionGateway {
  _AnswerGateway({required this.response});

  final ParticipantGameProjection response;
  final List<ParticipantAnswerSubmissionRequest> requests =
      <ParticipantAnswerSubmissionRequest>[];

  @override
  Future<ParticipantGameProjection> submitAnswer(
    ParticipantAnswerSubmissionRequest request,
  ) async {
    requests.add(request);
    return response;
  }
}

ParticipantGameEntryController _controller(
  _DiscoveryGateway discovery,
  _RuntimeFactory runtimes,
) {
  addTearDown(() async {
    for (final gateway in runtimes.syncGateways) {
      await gateway.dispose();
    }
  });
  return ParticipantGameEntryController(
    discoveryGateway: discovery,
    runtimeFactory: runtimes,
    expectedClubId: 'club-1',
    autoStart: false,
  );
}

ParticipantGameDiscoveryFeed _feed({
  int feedVersion = 3,
  List<ParticipantGameDiscoveryItem>? sessions,
}) {
  return ParticipantGameDiscoveryFeed(
    clubId: 'club-1',
    feedVersion: feedVersion,
    serverTime: DateTime.utc(2026, 7, 30, 8),
    publicAlias: 'Lion 42',
    sessions: sessions ?? <ParticipantGameDiscoveryItem>[_liveItem()],
  );
}

ParticipantGameDiscoveryItem _liveItem({
  String sessionId = 'session-live',
  ParticipantDiscoverySource source = ParticipantDiscoverySource.clubMembership,
}) {
  return ParticipantGameDiscoveryItem(
    clubId: 'club-1',
    sessionId: sessionId,
    title: 'Live trivia',
    phase: LiveGamePhase.questionOpen,
    source: source,
    sessionVersion: 4,
    availableFrom: DateTime.utc(2026, 7, 30, 7, 55),
    eligible: true,
  );
}

ParticipantGameProjection _projection({
  required String clubId,
  required String sessionId,
  required String publicAlias,
  int sessionVersion = 4,
  String answerState = 'not_answered',
  List<String> allowedActions = const <String>['submit_answer'],
}) {
  return ParticipantGameProjection.fromJson(<String, Object?>{
    'club_id': clubId,
    'session_id': sessionId,
    'phase': 'question_open',
    'session_version': sessionVersion,
    'event_sequence': 0,
    'server_time': '2026-07-30T08:00:00Z',
    'phase_deadline': '2026-07-30T08:00:15Z',
    'question_version': 2,
    'freshness': <String, Object?>{
      'state': 'current',
      'last_event_at': '2026-07-30T08:00:00Z',
    },
    'eligibility': true,
    'public_alias': publicAlias,
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

Future<void> _drainEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
