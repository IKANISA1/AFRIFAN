import 'package:feat_gamification/src/controllers/live_game_v2_reconciler.dart';
import 'package:feat_gamification/src/models/live_game_v2_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ParticipantProjectionReconciler', () {
    test('accepts an initial authoritative snapshot', () {
      final reconciler = _reconciler();
      final projection = _projection();

      expect(
        reconciler.apply(projection),
        LiveGameProjectionDecision.acceptedInitial,
      );
      expect(reconciler.current, same(projection));
    });

    test('accepts only a newer snapshot', () {
      final reconciler = _reconciler()..apply(_projection());
      final newer = _projection(sessionVersion: 5, eventSequence: 1);
      final stale = _projection(sessionVersion: 4, eventSequence: 11);

      expect(reconciler.apply(stale), LiveGameProjectionDecision.ignoredStale);
      expect(reconciler.apply(newer), LiveGameProjectionDecision.acceptedNewer);
      expect(reconciler.current, same(newer));
    });

    test('ignores duplicate snapshots', () {
      final reconciler = _reconciler()..apply(_projection());

      expect(
        reconciler.apply(_projection()),
        LiveGameProjectionDecision.ignoredDuplicate,
      );
    });

    test('rejects snapshots outside the expected session scope', () {
      final reconciler = _reconciler();

      expect(
        reconciler.apply(_projection(sessionId: 'session-2')),
        LiveGameProjectionDecision.rejectedScope,
      );
      expect(reconciler.current, isNull);
    });

    test('requests reconciliation for a newer invalidation hint', () {
      final reconciler = _reconciler()..apply(_projection());

      expect(
        reconciler.shouldReconcile(
          const LiveGameInvalidationHint(
            clubId: 'club-1',
            sessionId: 'session-1',
            sessionVersion: 4,
            eventSequence: 13,
          ),
        ),
        isTrue,
      );
    });

    test('ignores duplicate, stale, and wrong-scope hints', () {
      final reconciler = _reconciler()..apply(_projection());

      expect(
        reconciler.shouldReconcile(
          const LiveGameInvalidationHint(
            clubId: 'club-1',
            sessionId: 'session-1',
            sessionVersion: 4,
            eventSequence: 12,
          ),
        ),
        isFalse,
      );
      expect(
        reconciler.shouldReconcile(
          const LiveGameInvalidationHint(
            clubId: 'club-1',
            sessionId: 'session-1',
            sessionVersion: 3,
            eventSequence: 99,
          ),
        ),
        isFalse,
      );
      expect(
        reconciler.shouldReconcile(
          const LiveGameInvalidationHint(
            clubId: 'club-2',
            sessionId: 'session-1',
            sessionVersion: 99,
            eventSequence: 99,
          ),
        ),
        isFalse,
      );
    });

    test('requires an initial snapshot for any matching hint', () {
      final reconciler = _reconciler();

      expect(
        reconciler.shouldReconcile(
          const LiveGameInvalidationHint(
            clubId: 'club-1',
            sessionId: 'session-1',
            sessionVersion: 0,
            eventSequence: 0,
          ),
        ),
        isTrue,
      );
    });

    test('parses a valid invalidation hint and rejects invalid versions', () {
      final hint = LiveGameInvalidationHint.fromJson(<String, Object?>{
        'club_id': 'club-1',
        'session_id': 'session-1',
        'session_version': 4,
        'event_sequence': 13,
      });

      expect(hint.eventSequence, 13);
      expect(
        () => LiveGameInvalidationHint.fromJson(<String, Object?>{
          'club_id': 'club-1',
          'session_id': 'session-1',
          'session_version': -1,
          'event_sequence': 13,
        }),
        throwsA(isA<LiveGameContractViolation>()),
      );
    });

    test('clear removes retained state for account or session changes', () {
      final reconciler = _reconciler()..apply(_projection());

      reconciler.clear();

      expect(reconciler.current, isNull);
    });
  });
}

ParticipantProjectionReconciler _reconciler() {
  return ParticipantProjectionReconciler(
    expectedClubId: 'club-1',
    sessionId: 'session-1',
  );
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
