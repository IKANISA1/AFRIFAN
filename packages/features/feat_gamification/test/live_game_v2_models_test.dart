import 'package:feat_gamification/src/models/live_game_v2_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ParticipantGameProjection', () {
    test('parses a valid code-free participant projection', () {
      final projection = ParticipantGameProjection.fromJson(
        _projection(),
        expectedClubId: 'club-1',
      );

      expect(projection.version.phase, LiveGamePhase.questionOpen);
      expect(projection.version.sessionVersion, 4);
      expect(projection.version.eventSequence, 12);
      expect(projection.publicAlias, '240731');
      expect(projection.question?.options, hasLength(2));
      expect(projection.canSubmitAnswer, isTrue);
    });

    test('rejects a projection outside the expected club scope', () {
      expect(
        () => ParticipantGameProjection.fromJson(
          _projection(),
          expectedClubId: 'club-2',
        ),
        throwsA(isA<LiveGameContractViolation>()),
      );
    });

    test('rejects participant TV code fields at any payload depth', () {
      final json = _projection()
        ..['metadata'] = <String, Object?>{'join_code': 'LEGACY'};

      expect(
        () =>
            ParticipantGameProjection.fromJson(json, expectedClubId: 'club-1'),
        throwsA(isA<LiveGameContractViolation>()),
      );
    });

    test('rejects free-text display identity fields', () {
      final json = _projection()..['display_name'] = 'Person Name';

      expect(
        () =>
            ParticipantGameProjection.fromJson(json, expectedClubId: 'club-1'),
        throwsA(isA<LiveGameContractViolation>()),
      );
    });

    test('rejects a correct answer before reveal', () {
      final json = _projection();
      final question = Map<String, Object?>.from(
        json['question'] as Map<String, Object?>,
      )..['correct_option_key'] = 'b';
      json['question'] = question;

      expect(
        () =>
            ParticipantGameProjection.fromJson(json, expectedClubId: 'club-1'),
        throwsA(isA<LiveGameContractViolation>()),
      );
    });

    test('allows a correct answer in reveal phase', () {
      final json = _projection()
        ..['phase'] = 'reveal'
        ..['allowed_actions'] = <String>['retry_projection']
        ..['answer_state'] = 'revealed';
      final question = Map<String, Object?>.from(
        json['question'] as Map<String, Object?>,
      )..['correct_option_key'] = 'b';
      json['question'] = question;

      final projection = ParticipantGameProjection.fromJson(
        json,
        expectedClubId: 'club-1',
      );

      expect(projection.question?.correctOptionKey, 'b');
      expect(projection.canSubmitAnswer, isFalse);
    });

    test('rejects duplicate option keys', () {
      final json = _projection();
      final question =
          Map<String, Object?>.from(json['question'] as Map<String, Object?>)
            ..['options'] = <Map<String, String>>[
              <String, String>{'key': 'a', 'label': 'First'},
              <String, String>{'key': 'a', 'label': 'Second'},
            ];
      json['question'] = question;

      expect(
        () =>
            ParticipantGameProjection.fromJson(json, expectedClubId: 'club-1'),
        throwsA(isA<LiveGameContractViolation>()),
      );
    });

    test('applies only a newer version from the same session', () {
      final current = ParticipantGameProjection.fromJson(
        _projection(),
        expectedClubId: 'club-1',
      );
      final nextJson = _projection()
        ..['session_version'] = 5
        ..['event_sequence'] = 1;
      final next = ParticipantGameProjection.fromJson(
        nextJson,
        expectedClubId: 'club-1',
      );
      final staleJson = _projection()
        ..['session_version'] = 4
        ..['event_sequence'] = 11;
      final stale = ParticipantGameProjection.fromJson(
        staleJson,
        expectedClubId: 'club-1',
      );

      expect(next.shouldReplace(current), isTrue);
      expect(stale.shouldReplace(current), isFalse);
    });

    test('does not compare versions across sessions', () {
      final current = ParticipantGameProjection.fromJson(
        _projection(),
        expectedClubId: 'club-1',
      );
      final otherJson = _projection()
        ..['session_id'] = 'session-2'
        ..['session_version'] = 50;
      final other = ParticipantGameProjection.fromJson(
        otherJson,
        expectedClubId: 'club-1',
      );

      expect(other.shouldReplace(current), isFalse);
    });

    test('rejects unknown participant actions', () {
      final json = _projection()
        ..['allowed_actions'] = <String>['force_advance'];

      expect(
        () =>
            ParticipantGameProjection.fromJson(json, expectedClubId: 'club-1'),
        throwsA(isA<LiveGameContractViolation>()),
      );
    });
  });
}

Map<String, Object?> _projection() {
  return <String, Object?>{
    'club_id': 'club-1',
    'session_id': 'session-1',
    'phase': 'question_open',
    'session_version': 4,
    'event_sequence': 12,
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
    'allowed_actions': <String>['submit_answer', 'retry_projection'],
    'question': <String, Object?>{
      'id': 'question-2',
      'prompt': 'Sanitized question?',
      'options': <Map<String, String>>[
        <String, String>{'key': 'a', 'label': 'First'},
        <String, String>{'key': 'b', 'label': 'Second'},
      ],
    },
    'leader_summary': <Map<String, Object?>>[
      <String, Object?>{'rank': 1, 'public_alias': '240731', 'score': 200},
    ],
  };
}
