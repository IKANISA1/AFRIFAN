import 'dart:convert';
import 'dart:io';

import 'package:feat_game_operations/feat_game_operations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixture = _loadFixture();

  test('organizer projection matches every authoritative QA-02 state', () {
    for (final state in fixture.states) {
      final session = ManagedGameSession.fromJson(
        _organizerPayload(fixture, state),
        expectedClubId: '24',
      );

      expect(session.id, fixture.sessionId, reason: state.id);
      expect(session.phase, state.phase, reason: state.id);
      expect(session.sessionVersion, state.sessionVersion, reason: state.id);
      expect(session.questionVersion, state.questionVersion, reason: state.id);
      expect(session.eventSequence, state.eventSequence, reason: state.id);
      expect(
        session.currentQuestion?.prompt,
        state.questionPrompt,
        reason: state.id,
      );
      expect(
        session.currentQuestion?.options.any(
          (option) => option.containsKey('correct_option_key'),
        ),
        isNot(true),
        reason: state.id,
      );
    }
  });
}

Map<String, dynamic> _organizerPayload(
  _CrossClientFixture fixture,
  _CrossClientState state,
) {
  return <String, dynamic>{
    'club_id': '24',
    'session_id': fixture.sessionId,
    'session_title': fixture.sessionTitle,
    'pack_title': 'Approved matchday pack',
    'phase': state.phase,
    'session_version': state.sessionVersion,
    'question_version': state.questionVersion,
    'event_sequence': state.eventSequence,
    'server_time': '2026-08-01T14:00:0${state.eventSequence}Z',
    'phase_deadline': state.phase == 'question_open'
        ? '2026-08-01T14:00:30Z'
        : null,
    'scheduled_start_at': '2026-08-01T14:00:00Z',
    'eligibility_scope': 'club_membership',
    'allowed_actions': <String>[],
    'participant_count': 18,
    'assigned_displays': <Map<String, dynamic>>[
      <String, dynamic>{
        'display_id': 'display-1',
        'display_name': 'Main stand screen',
        'scope_type': 'venue',
        'pairing_status': 'paired',
        'health': 'online',
      },
    ],
    'current_question_control': state.questionPrompt == null
        ? null
        : <String, dynamic>{
            'id': 'question-${state.questionOrdinal}',
            'ordinal': state.questionOrdinal,
            'state': state.phase,
            'prompt': state.questionPrompt,
            'options': _options,
          },
  };
}

const _options = <Map<String, String>>[
  <String, String>{'key': 'a', 'label': 'Player A'},
  <String, String>{'key': 'b', 'label': '1968'},
];

_CrossClientFixture _loadFixture() {
  final json =
      jsonDecode(_findFixture().readAsStringSync()) as Map<String, dynamic>;
  return _CrossClientFixture(
    sessionId: json['session_id']! as String,
    sessionTitle: json['session_title']! as String,
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
  const _CrossClientFixture({
    required this.sessionId,
    required this.sessionTitle,
    required this.states,
  });

  final String sessionId;
  final String sessionTitle;
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
    );
  }

  final String id;
  final String phase;
  final int sessionVersion;
  final int questionVersion;
  final int eventSequence;
  final int? questionOrdinal;
  final String? questionPrompt;
}
