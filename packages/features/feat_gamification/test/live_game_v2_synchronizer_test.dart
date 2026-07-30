import 'dart:async';

import 'package:feat_gamification/src/controllers/live_game_v2_reconciler.dart';
import 'package:feat_gamification/src/controllers/live_game_v2_synchronizer.dart';
import 'package:feat_gamification/src/models/live_game_v2_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ParticipantLiveGameSynchronizer', () {
    test('loads an initial authoritative snapshot', () async {
      final gateway = _Gateway()..projections.add(_projection());
      final synchronizer = _synchronizer(gateway);
      addTearDown(synchronizer.dispose);

      await synchronizer.start();

      expect(synchronizer.state.status, LiveGameSyncStatus.ready);
      expect(synchronizer.state.projection?.version.sessionVersion, 4);
      expect(gateway.fetchCalls, 1);
    });

    test('reconciles after a newer invalidation hint', () async {
      final gateway = _Gateway()
        ..projections.addAll(<ParticipantGameProjection>[
          _projection(),
          _projection(sessionVersion: 5, eventSequence: 1),
        ]);
      final synchronizer = _synchronizer(gateway);
      addTearDown(synchronizer.dispose);
      await synchronizer.start();

      gateway.hints.add(
        const LiveGameInvalidationHint(
          clubId: 'club-1',
          sessionId: 'session-1',
          sessionVersion: 5,
          eventSequence: 1,
        ),
      );
      await _drainEvents();

      expect(synchronizer.state.projection?.version.sessionVersion, 5);
      expect(gateway.fetchCalls, 2);
    });

    test('ignores stale and wrong-scope invalidation hints', () async {
      final gateway = _Gateway()..projections.add(_projection());
      final synchronizer = _synchronizer(gateway);
      addTearDown(synchronizer.dispose);
      await synchronizer.start();

      gateway.hints.add(
        const LiveGameInvalidationHint(
          clubId: 'club-1',
          sessionId: 'session-1',
          sessionVersion: 3,
          eventSequence: 99,
        ),
      );
      gateway.hints.add(
        const LiveGameInvalidationHint(
          clubId: 'club-2',
          sessionId: 'session-1',
          sessionVersion: 99,
          eventSequence: 99,
        ),
      );
      await _drainEvents();

      expect(gateway.fetchCalls, 1);
      expect(synchronizer.state.status, LiveGameSyncStatus.ready);
    });

    test('coalesces overlapping refresh requests', () async {
      final initial = Completer<ParticipantGameProjection>();
      final gateway = _Gateway()..pendingProjection = initial;
      final synchronizer = _synchronizer(gateway);
      addTearDown(synchronizer.dispose);

      final start = synchronizer.start();
      final refresh = synchronizer.refresh();
      initial.complete(_projection());
      await Future.wait(<Future<void>>[start, refresh]);

      expect(gateway.fetchCalls, 1);
      expect(synchronizer.state.status, LiveGameSyncStatus.ready);
    });

    test(
      'retains the latest projection while offline and reconnecting',
      () async {
        final gateway = _Gateway()
          ..projections.addAll(<ParticipantGameProjection>[
            _projection(),
            _projection(sessionVersion: 5, eventSequence: 1),
          ]);
        final synchronizer = _synchronizer(gateway);
        addTearDown(synchronizer.dispose);
        await synchronizer.start();

        synchronizer.markOffline();
        expect(synchronizer.state.status, LiveGameSyncStatus.offline);
        expect(synchronizer.state.hasRetainedProjection, isTrue);

        await synchronizer.reconnect();

        expect(synchronizer.state.status, LiveGameSyncStatus.ready);
        expect(synchronizer.state.projection?.version.sessionVersion, 5);
      },
    );

    test('maps raw gateway failures to a sanitized failure kind', () async {
      final gateway = _Gateway()
        ..fetchError = StateError('private-session-token-123');
      final synchronizer = _synchronizer(gateway);
      addTearDown(synchronizer.dispose);

      await synchronizer.start();

      expect(synchronizer.state.status, LiveGameSyncStatus.failure);
      expect(synchronizer.state.failureKind, LiveGameSyncFailureKind.unknown);
      expect(synchronizer.state.toString(), isNot(contains('private-session')));
    });

    test(
      'fails closed when a snapshot is outside the expected scope',
      () async {
        final gateway = _Gateway()
          ..projections.add(_projection(sessionId: 'session-2'));
        final synchronizer = _synchronizer(gateway);
        addTearDown(synchronizer.dispose);

        await synchronizer.start();

        expect(synchronizer.state.status, LiveGameSyncStatus.failure);
        expect(
          synchronizer.state.failureKind,
          LiveGameSyncFailureKind.permissionDenied,
        );
        expect(synchronizer.state.projection, isNull);
      },
    );

    test('maps fetch timeout without losing retained state', () async {
      final gateway = _Gateway()..projections.add(_projection());
      final synchronizer = ParticipantLiveGameSynchronizer(
        gateway: gateway,
        expectedClubId: 'club-1',
        sessionId: 'session-1',
        fetchTimeout: const Duration(milliseconds: 2),
      );
      addTearDown(gateway.dispose);
      addTearDown(synchronizer.dispose);
      await synchronizer.start();
      gateway.pendingProjection = Completer<ParticipantGameProjection>();

      await synchronizer.refresh();

      expect(synchronizer.state.status, LiveGameSyncStatus.failure);
      expect(synchronizer.state.failureKind, LiveGameSyncFailureKind.timeout);
      expect(synchronizer.state.hasRetainedProjection, isTrue);
    });

    test('disposal cancels updates and prevents reuse', () async {
      final gateway = _Gateway()..projections.add(_projection());
      final synchronizer = _synchronizer(gateway);
      await synchronizer.start();

      await synchronizer.dispose();

      expect(synchronizer.state.status, LiveGameSyncStatus.disposed);
      expect(synchronizer.refresh, throwsStateError);
    });
  });
}

ParticipantLiveGameSynchronizer _synchronizer(_Gateway gateway) {
  addTearDown(gateway.dispose);
  return ParticipantLiveGameSynchronizer(
    gateway: gateway,
    expectedClubId: 'club-1',
    sessionId: 'session-1',
  );
}

Future<void> _drainEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _Gateway implements ParticipantLiveGameGateway {
  final StreamController<LiveGameInvalidationHint> hints =
      StreamController<LiveGameInvalidationHint>.broadcast(sync: true);
  final List<ParticipantGameProjection> projections =
      <ParticipantGameProjection>[];

  Completer<ParticipantGameProjection>? pendingProjection;
  Object? fetchError;
  int fetchCalls = 0;

  @override
  Future<ParticipantGameProjection> fetchProjection() async {
    fetchCalls += 1;
    final error = fetchError;
    if (error != null) throw error;
    final pending = pendingProjection;
    if (pending != null) return pending.future;
    if (projections.isEmpty) {
      throw const LiveGameSyncFailure(LiveGameSyncFailureKind.unavailable);
    }
    return projections.removeAt(0);
  }

  @override
  Stream<LiveGameInvalidationHint> watchInvalidationHints() => hints.stream;

  Future<void> dispose() => hints.close();
}

ParticipantGameProjection _projection({
  String sessionId = 'session-1',
  int sessionVersion = 4,
  int eventSequence = 12,
}) {
  return ParticipantGameProjection.fromJson(<String, Object?>{
    'club_id': 'club-1',
    'session_id': sessionId,
    'phase': 'question_open',
    'session_version': sessionVersion,
    'event_sequence': eventSequence,
    'server_time': '2026-07-30T07:20:00Z',
    'phase_deadline': '2026-07-30T07:20:15Z',
    'question_version': 2,
    'freshness': <String, Object?>{
      'state': 'current',
      'last_event_at': '2026-07-30T07:20:00Z',
    },
    'eligibility': true,
    'public_alias': '240731',
    'answer_state': 'not_answered',
    'allowed_actions': <String>['submit_answer'],
    'question': <String, Object?>{
      'id': 'question-2',
      'prompt': 'Sanitized question?',
      'options': <Map<String, String>>[
        <String, String>{'key': 'a', 'label': 'First'},
        <String, String>{'key': 'b', 'label': 'Second'},
      ],
    },
    'leader_summary': const <Map<String, Object?>>[],
  }, expectedClubId: 'club-1');
}
