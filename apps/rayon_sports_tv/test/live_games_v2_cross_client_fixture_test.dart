import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rayon_sports_tv/src/tv_runtime.dart';

void main() {
  final fixture = _loadFixture();

  test('native TV projection matches every authoritative QA-02 state', () {
    for (final state in fixture.states) {
      final projection = TvGameProjection.fromJson(
        _tvPayload(fixture, state),
        expectedClubId: 'club-1',
      );

      expect(projection.sessionId, fixture.sessionId, reason: state.id);
      expect(projection.phase, state.phase, reason: state.id);
      expect(projection.sessionVersion, state.sessionVersion, reason: state.id);
      expect(
        projection.questionVersion,
        state.questionVersion,
        reason: state.id,
      );
      expect(projection.eventSequence, state.eventSequence, reason: state.id);
      expect(
        projection.question?.prompt,
        state.questionPrompt,
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

Map<String, dynamic> _tvPayload(
  _CrossClientFixture fixture,
  _CrossClientState state,
) {
  return <String, dynamic>{
    'status': 'ready',
    'display_id': 'display-1',
    'club_id': 'club-1',
    'server_time': '2026-08-01T14:00:0${state.eventSequence}Z',
    'allowed_actions': <String>['retry_projection'],
    'freshness': <String, dynamic>{
      'state': 'current',
      'last_event_at': '2026-08-01T14:00:0${state.eventSequence}Z',
    },
    'session_id': fixture.sessionId,
    'session_title': fixture.sessionTitle,
    'phase': state.phase,
    'session_version': state.sessionVersion,
    'question_version': state.questionVersion,
    'event_sequence': state.eventSequence,
    'phase_deadline': state.phase == 'question_open'
        ? '2026-08-01T14:00:30Z'
        : null,
    'question': state.questionPrompt == null
        ? null
        : <String, dynamic>{
            'id': 'question-${state.questionOrdinal}',
            'ordinal': state.questionOrdinal,
            'prompt': state.questionPrompt,
            'options': _options,
            if (state.correctOptionKey != null)
              'correct_option_key': state.correctOptionKey,
          },
    'leaderboard': <Map<String, dynamic>>[
      <String, dynamic>{
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
    required this.correctOptionKey,
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
}
