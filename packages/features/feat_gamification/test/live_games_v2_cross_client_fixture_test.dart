import 'dart:convert';
import 'dart:io';

import 'package:feat_gamification/src/models/live_game_v2_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixture = _loadFixture();

  test('participant projection matches every authoritative QA-02 state', () {
    for (final state in fixture.states) {
      final projection = ParticipantGameProjection.fromJson(
        _participantPayload(fixture, state),
        expectedClubId: 'club-1',
      );

      expect(projection.version.sessionId, fixture.sessionId, reason: state.id);
      expect(projection.version.phase.wireValue, state.phase, reason: state.id);
      expect(
        projection.version.sessionVersion,
        state.sessionVersion,
        reason: state.id,
      );
      expect(
        projection.version.questionVersion,
        state.questionVersion,
        reason: state.id,
      );
      expect(
        projection.version.eventSequence,
        state.eventSequence,
        reason: state.id,
      );
      expect(
        projection.canSubmitAnswer,
        state.participantSubmitEnabled,
        reason: state.id,
      );
      expect(
        projection.question?.correctOptionKey,
        state.correctOptionKey,
        reason: state.id,
      );
    }
  });
}

Map<String, Object?> _participantPayload(
  _CrossClientFixture fixture,
  _CrossClientState state,
) {
  final question = state.questionPrompt == null
      ? null
      : <String, Object?>{
          'id': 'question-${state.questionOrdinal}',
          'prompt': state.questionPrompt,
          'options': _options,
          if (state.correctOptionKey != null)
            'correct_option_key': state.correctOptionKey,
        };
  return <String, Object?>{
    'club_id': 'club-1',
    'session_id': fixture.sessionId,
    'phase': state.phase,
    'session_version': state.sessionVersion,
    'question_version': state.questionVersion,
    'event_sequence': state.eventSequence,
    'server_time': '2026-08-01T14:00:0${state.eventSequence}Z',
    'phase_deadline': state.phase == 'question_open'
        ? '2026-08-01T14:00:30Z'
        : null,
    'freshness': <String, Object?>{
      'state': 'current',
      'last_event_at': '2026-08-01T14:00:0${state.eventSequence}Z',
    },
    'eligibility': true,
    'public_alias': 'Fan 042',
    'answer_state': state.correctOptionKey == null
        ? 'not_answered'
        : 'revealed',
    'allowed_actions': state.participantSubmitEnabled
        ? <String>['submit_answer', 'retry_projection']
        : <String>['retry_projection'],
    'question': question,
    'leader_summary': <Map<String, Object?>>[
      <String, Object?>{
        'rank': 1,
        'public_alias': 'Fan 042',
        'score': state.eventSequence * 10,
      },
    ],
  };
}

const _options = <Map<String, String>>[
  <String, String>{'key': 'a', 'label': 'Player A'},
  <String, String>{'key': 'b', 'label': '1968'},
];

_CrossClientFixture _loadFixture() {
  final file = _findFixture();
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return _CrossClientFixture(
    sessionId: json['session_id']! as String,
    states: (json['states']! as List<dynamic>)
        .map(
          (value) => _CrossClientState.fromJson(value as Map<String, dynamic>),
        )
        .toList(growable: false),
  );
}

File _findFixture() {
  var directory = Directory.current.absolute;
  while (true) {
    final candidate = File(
      '${directory.path}/docs/architecture/'
      'live-games-v2-cross-client-fixtures.json',
    );
    if (candidate.existsSync()) return candidate;
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('Unable to locate the GAME-QA-02 fixture.');
    }
    directory = parent;
  }
}

class _CrossClientFixture {
  const _CrossClientFixture({required this.sessionId, required this.states});

  final String sessionId;
  final List<_CrossClientState> states;
}

class _CrossClientState {
  const _CrossClientState({
    required this.id,
    required this.phase,
    required this.sessionVersion,
    required this.questionVersion,
    required this.eventSequence,
    required this.questionOrdinal,
    required this.questionPrompt,
    required this.correctOptionKey,
    required this.participantSubmitEnabled,
  });

  factory _CrossClientState.fromJson(Map<String, dynamic> json) {
    return _CrossClientState(
      id: json['id']! as String,
      phase: json['phase']! as String,
      sessionVersion: json['session_version']! as int,
      questionVersion: json['question_version']! as int,
      eventSequence: json['event_sequence']! as int,
      questionOrdinal: json['question_ordinal'] as int?,
      questionPrompt: json['question_prompt'] as String?,
      correctOptionKey: json['correct_option_key'] as String?,
      participantSubmitEnabled: json['participant_submit_enabled']! as bool,
    );
  }

  final String id;
  final String phase;
  final int sessionVersion;
  final int questionVersion;
  final int eventSequence;
  final int? questionOrdinal;
  final String? questionPrompt;
  final String? correctOptionKey;
  final bool participantSubmitEnabled;
}
