enum LiveGamePhase {
  draft,
  validated,
  published,
  scheduled,
  activatedLobby,
  questionOpen,
  reveal,
  paused,
  completed,
  cancelled;

  factory LiveGamePhase.fromWireValue(String value) {
    return switch (value) {
      'draft' => LiveGamePhase.draft,
      'validated' => LiveGamePhase.validated,
      'published' => LiveGamePhase.published,
      'scheduled' => LiveGamePhase.scheduled,
      'activated_lobby' => LiveGamePhase.activatedLobby,
      'question_open' => LiveGamePhase.questionOpen,
      'reveal' => LiveGamePhase.reveal,
      'paused' => LiveGamePhase.paused,
      'completed' => LiveGamePhase.completed,
      'cancelled' => LiveGamePhase.cancelled,
      _ => throw const LiveGameContractViolation('Unsupported game phase.'),
    };
  }

  String get wireValue {
    return switch (this) {
      LiveGamePhase.draft => 'draft',
      LiveGamePhase.validated => 'validated',
      LiveGamePhase.published => 'published',
      LiveGamePhase.scheduled => 'scheduled',
      LiveGamePhase.activatedLobby => 'activated_lobby',
      LiveGamePhase.questionOpen => 'question_open',
      LiveGamePhase.reveal => 'reveal',
      LiveGamePhase.paused => 'paused',
      LiveGamePhase.completed => 'completed',
      LiveGamePhase.cancelled => 'cancelled',
    };
  }

  bool get mayRevealCorrectAnswer =>
      this == LiveGamePhase.reveal || this == LiveGamePhase.completed;
}

enum LiveGameFreshnessState {
  current,
  reconnecting,
  offline,
  degraded;

  factory LiveGameFreshnessState.fromWireValue(String value) {
    return switch (value) {
      'current' => LiveGameFreshnessState.current,
      'reconnecting' => LiveGameFreshnessState.reconnecting,
      'offline' => LiveGameFreshnessState.offline,
      'degraded' => LiveGameFreshnessState.degraded,
      _ => throw const LiveGameContractViolation(
        'Unsupported freshness state.',
      ),
    };
  }
}

enum ParticipantAnswerState {
  notAnswered,
  submitted,
  accepted,
  rejected,
  revealed;

  factory ParticipantAnswerState.fromWireValue(String value) {
    return switch (value) {
      'not_answered' => ParticipantAnswerState.notAnswered,
      'submitted' => ParticipantAnswerState.submitted,
      'accepted' => ParticipantAnswerState.accepted,
      'rejected' => ParticipantAnswerState.rejected,
      'revealed' => ParticipantAnswerState.revealed,
      _ => throw const LiveGameContractViolation(
        'Unsupported participant answer state.',
      ),
    };
  }
}

enum ParticipantGameAction {
  submitAnswer,
  retryProjection;

  factory ParticipantGameAction.fromWireValue(String value) {
    return switch (value) {
      'submit_answer' => ParticipantGameAction.submitAnswer,
      'retry_projection' => ParticipantGameAction.retryProjection,
      _ => throw const LiveGameContractViolation(
        'Unsupported participant action.',
      ),
    };
  }
}

class LiveGameContractViolation implements Exception {
  const LiveGameContractViolation(this.message);

  final String message;

  @override
  String toString() => 'LiveGameContractViolation: $message';
}

class LiveGameFreshness {
  const LiveGameFreshness({required this.state, required this.lastEventAt});

  final LiveGameFreshnessState state;
  final DateTime lastEventAt;

  factory LiveGameFreshness.fromJson(Map<String, dynamic> json) {
    return LiveGameFreshness(
      state: LiveGameFreshnessState.fromWireValue(
        _requireString(json, 'state'),
      ),
      lastEventAt: _requireDateTime(json, 'last_event_at'),
    );
  }
}

class LiveGameProjectionVersion {
  const LiveGameProjectionVersion({
    required this.clubId,
    required this.sessionId,
    required this.phase,
    required this.sessionVersion,
    required this.eventSequence,
    required this.serverTime,
    required this.questionVersion,
    required this.freshness,
    this.phaseDeadline,
  });

  final String clubId;
  final String sessionId;
  final LiveGamePhase phase;
  final int sessionVersion;
  final int eventSequence;
  final DateTime serverTime;
  final DateTime? phaseDeadline;
  final int questionVersion;
  final LiveGameFreshness freshness;

  factory LiveGameProjectionVersion.fromJson(
    Map<String, dynamic> json, {
    required String expectedClubId,
  }) {
    final clubId = _requireString(json, 'club_id');
    if (clubId != expectedClubId) {
      throw const LiveGameContractViolation(
        'Projection is outside the expected club scope.',
      );
    }

    final sessionVersion = _requireNonNegativeInt(json, 'session_version');
    final eventSequence = _requireNonNegativeInt(json, 'event_sequence');
    final questionVersion = _requireNonNegativeInt(json, 'question_version');

    return LiveGameProjectionVersion(
      clubId: clubId,
      sessionId: _requireString(json, 'session_id'),
      phase: LiveGamePhase.fromWireValue(_requireString(json, 'phase')),
      sessionVersion: sessionVersion,
      eventSequence: eventSequence,
      serverTime: _requireDateTime(json, 'server_time'),
      phaseDeadline: _optionalDateTime(json, 'phase_deadline'),
      questionVersion: questionVersion,
      freshness: LiveGameFreshness.fromJson(_requireMap(json, 'freshness')),
    );
  }

  bool isNewerThan(LiveGameProjectionVersion current) {
    if (clubId != current.clubId || sessionId != current.sessionId) {
      return false;
    }
    if (sessionVersion != current.sessionVersion) {
      return sessionVersion > current.sessionVersion;
    }
    return eventSequence > current.eventSequence;
  }
}

class LiveGameOption {
  const LiveGameOption({required this.key, required this.label});

  final String key;
  final String label;

  factory LiveGameOption.fromJson(Map<String, dynamic> json) {
    return LiveGameOption(
      key: _requireString(json, 'key'),
      label: _requireString(json, 'label'),
    );
  }
}

class LiveGameQuestionProjection {
  const LiveGameQuestionProjection({
    required this.id,
    required this.prompt,
    required this.options,
    this.correctOptionKey,
  });

  final String id;
  final String prompt;
  final List<LiveGameOption> options;
  final String? correctOptionKey;

  factory LiveGameQuestionProjection.fromJson(
    Map<String, dynamic> json, {
    required LiveGamePhase phase,
  }) {
    final options = _requireList(json, 'options')
        .map(_requireDynamicMap)
        .map(LiveGameOption.fromJson)
        .toList(growable: false);
    final optionKeys = options.map((option) => option.key).toSet();
    if (optionKeys.length != options.length || options.length < 2) {
      throw const LiveGameContractViolation('Question options are invalid.');
    }

    final correctOptionKey = _optionalString(json, 'correct_option_key');
    if (correctOptionKey != null && !phase.mayRevealCorrectAnswer) {
      throw const LiveGameContractViolation(
        'Correct answer was exposed before reveal.',
      );
    }
    if (correctOptionKey != null && !optionKeys.contains(correctOptionKey)) {
      throw const LiveGameContractViolation(
        'Correct answer does not match a question option.',
      );
    }

    return LiveGameQuestionProjection(
      id: _requireString(json, 'id'),
      prompt: _requireString(json, 'prompt'),
      options: options,
      correctOptionKey: correctOptionKey,
    );
  }
}

class LiveGameLeaderSummaryRow {
  const LiveGameLeaderSummaryRow({
    required this.rank,
    required this.publicAlias,
    required this.score,
  });

  final int rank;
  final String publicAlias;
  final int score;

  factory LiveGameLeaderSummaryRow.fromJson(Map<String, dynamic> json) {
    final rank = _requireNonNegativeInt(json, 'rank');
    if (rank < 1) {
      throw const LiveGameContractViolation(
        'Leaderboard rank must start at one.',
      );
    }
    return LiveGameLeaderSummaryRow(
      rank: rank,
      publicAlias: _requireString(json, 'public_alias'),
      score: _requireNonNegativeInt(json, 'score'),
    );
  }
}

class ParticipantGameProjection {
  const ParticipantGameProjection({
    required this.version,
    required this.eligible,
    required this.publicAlias,
    required this.answerState,
    required this.allowedActions,
    required this.leaderSummary,
    this.question,
  });

  final LiveGameProjectionVersion version;
  final bool eligible;
  final String publicAlias;
  final ParticipantAnswerState answerState;
  final Set<ParticipantGameAction> allowedActions;
  final LiveGameQuestionProjection? question;
  final List<LiveGameLeaderSummaryRow> leaderSummary;

  bool get canSubmitAnswer =>
      eligible &&
      version.phase == LiveGamePhase.questionOpen &&
      answerState == ParticipantAnswerState.notAnswered &&
      allowedActions.contains(ParticipantGameAction.submitAnswer) &&
      question != null;

  factory ParticipantGameProjection.fromJson(
    Map<String, dynamic> json, {
    required String expectedClubId,
  }) {
    assertParticipantPayloadSafe(json);
    final version = LiveGameProjectionVersion.fromJson(
      json,
      expectedClubId: expectedClubId,
    );
    final questionJson = _optionalMap(json, 'question');
    final actions = _requireList(json, 'allowed_actions')
        .map(_requireDynamicString)
        .map(ParticipantGameAction.fromWireValue)
        .toSet();
    final leaderSummary = _requireList(json, 'leader_summary')
        .map(_requireDynamicMap)
        .map(LiveGameLeaderSummaryRow.fromJson)
        .toList(growable: false);

    return ParticipantGameProjection(
      version: version,
      eligible: _requireBool(json, 'eligibility'),
      publicAlias: _requireString(json, 'public_alias'),
      answerState: ParticipantAnswerState.fromWireValue(
        _requireString(json, 'answer_state'),
      ),
      allowedActions: Set.unmodifiable(actions),
      question: questionJson == null
          ? null
          : LiveGameQuestionProjection.fromJson(
              questionJson,
              phase: version.phase,
            ),
      leaderSummary: List.unmodifiable(leaderSummary),
    );
  }

  bool shouldReplace(ParticipantGameProjection current) {
    return version.isNewerThan(current.version);
  }
}

const _participantForbiddenKeys = <String>{
  'joincode',
  'tvcode',
  'pairingchallenge',
  'devicecredential',
  'displayname',
  'realname',
  'phone',
  'email',
  'authuid',
  'walletbalance',
  'checkinidentity',
  'orderqueue',
};

void assertParticipantPayloadSafe(Object? value) {
  if (value is Map) {
    for (final entry in value.entries) {
      final key = entry.key.toString();
      if (_participantForbiddenKeys.contains(_normalizeKey(key))) {
        throw const LiveGameContractViolation(
          'Participant projection contains a forbidden field.',
        );
      }
      assertParticipantPayloadSafe(entry.value);
    }
    return;
  }
  if (value is Iterable) {
    for (final item in value) {
      assertParticipantPayloadSafe(item);
    }
  }
}

String _normalizeKey(String value) {
  return value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
}

String _requireString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw LiveGameContractViolation('Required string field is invalid: $key.');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw LiveGameContractViolation('Optional string field is invalid: $key.');
}

int _requireNonNegativeInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int && value >= 0) return value;
  throw LiveGameContractViolation('Required integer field is invalid: $key.');
}

bool _requireBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw LiveGameContractViolation('Required boolean field is invalid: $key.');
}

DateTime _requireDateTime(Map<String, dynamic> json, String key) {
  final value = _requireString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw LiveGameContractViolation('Required date field is invalid: $key.');
  }
  return parsed.toUtc();
}

DateTime? _optionalDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw LiveGameContractViolation('Optional date field is invalid: $key.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw LiveGameContractViolation('Optional date field is invalid: $key.');
  }
  return parsed.toUtc();
}

Map<String, dynamic> _requireMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map) return Map<String, dynamic>.from(value);
  throw LiveGameContractViolation('Required object field is invalid: $key.');
}

Map<String, dynamic>? _optionalMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw LiveGameContractViolation('Optional object field is invalid: $key.');
}

List<dynamic> _requireList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List) return value;
  throw LiveGameContractViolation('Required list field is invalid: $key.');
}

Map<String, dynamic> _requireDynamicMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const LiveGameContractViolation('List item must be an object.');
}

String _requireDynamicString(dynamic value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw const LiveGameContractViolation('List item must be a string.');
}
