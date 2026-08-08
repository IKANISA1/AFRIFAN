enum GameOperationsFailureKind {
  offline,
  permissionDenied,
  conflict,
  invalidInput,
  timeout,
  unavailable,
}

class GameOperationsFailure implements Exception {
  const GameOperationsFailure(this.kind, [this.cause]);

  final GameOperationsFailureKind kind;
  final Object? cause;

  @override
  String toString() => 'GameOperationsFailure($kind)';
}

class OwnedDisplay {
  const OwnedDisplay({
    required this.id,
    required this.name,
    required this.scopeType,
    required this.pairingStatus,
    required this.health,
    this.venueId,
    this.appVersion,
    this.assignedSessionId,
    this.assignedSession,
    this.capabilities = const <String, Object?>{},
    this.lastSeenAt,
  });

  factory OwnedDisplay.fromJson(Map<String, dynamic> json) {
    _rejectSensitiveProjection(json);
    final assignedSession = json['assigned_session'] is Map
        ? OwnedAssignedSession.fromJson(
            Map<String, dynamic>.from(json['assigned_session'] as Map),
          )
        : null;
    return OwnedDisplay(
      id: _requiredString(json, 'display_id'),
      name: _requiredString(json, 'display_name'),
      scopeType: _requiredString(json, 'scope_type'),
      pairingStatus: _requiredString(json, 'pairing_status'),
      health: _requiredString(json, 'health'),
      venueId: _nullableString(json['venue_id']),
      appVersion: _nullableString(json['app_version']),
      assignedSessionId:
          assignedSession?.id ?? _nullableString(json['assigned_session_id']),
      assignedSession: assignedSession,
      capabilities: _safeCapabilities(json['capabilities']),
      lastSeenAt: _nullableDateTime(json['last_seen_at']),
    );
  }

  final String id;
  final String name;
  final String scopeType;
  final String pairingStatus;
  final String health;
  final String? venueId;
  final String? appVersion;
  final String? assignedSessionId;
  final OwnedAssignedSession? assignedSession;
  final Map<String, Object?> capabilities;
  final DateTime? lastSeenAt;
}

class OwnedAssignedSession {
  const OwnedAssignedSession({
    required this.id,
    required this.title,
    required this.phase,
  });

  factory OwnedAssignedSession.fromJson(Map<String, dynamic> json) {
    _rejectSensitiveProjection(json);
    return OwnedAssignedSession(
      id: _requiredString(json, 'session_id'),
      title: _requiredString(json, 'title'),
      phase: _requiredString(json, 'phase'),
    );
  }

  final String id;
  final String title;
  final String phase;
}

class OwnedDisplayScopeOption {
  const OwnedDisplayScopeOption({
    required this.scopeType,
    required this.label,
    this.venueId,
  });

  factory OwnedDisplayScopeOption.fromJson(Map<String, dynamic> json) {
    _rejectSensitiveProjection(json);
    final scopeType = _requiredString(json, 'scope_type');
    final label = _requiredString(json, 'label');
    final venueId = _nullableString(json['venue_id']);
    if (label.length > 120 ||
        (scopeType == 'home' && venueId != null) ||
        (scopeType == 'venue' &&
            (venueId == null || !_uuidPattern.hasMatch(venueId))) ||
        (scopeType != 'home' && scopeType != 'venue')) {
      throw const FormatException('Invalid display scope option.');
    }
    return OwnedDisplayScopeOption(
      scopeType: scopeType,
      venueId: venueId,
      label: label,
    );
  }

  final String scopeType;
  final String? venueId;
  final String label;

  String get key => scopeType == 'home' ? 'home' : 'venue:$venueId';
}

class OwnedDisplayInventory {
  const OwnedDisplayInventory({
    required this.clubId,
    required this.serverTime,
    required this.displays,
    this.scopeOptions = const <OwnedDisplayScopeOption>[],
  });

  factory OwnedDisplayInventory.fromJson(
    Map<String, dynamic> json, {
    required String expectedClubId,
  }) {
    final clubId = _requiredString(json, 'club_id');
    _requireClub(clubId, expectedClubId);
    return OwnedDisplayInventory(
      clubId: clubId,
      serverTime: _requiredDateTime(json, 'server_time'),
      displays: _mapList(json['displays'], OwnedDisplay.fromJson),
      scopeOptions: _mapList(
        json['scope_options'],
        OwnedDisplayScopeOption.fromJson,
      ),
    );
  }

  final String clubId;
  final DateTime serverTime;
  final List<OwnedDisplay> displays;
  final List<OwnedDisplayScopeOption> scopeOptions;
}

class PlannerPack {
  const PlannerPack({
    required this.id,
    required this.title,
    required this.description,
    required this.questionCount,
    this.publishedAt,
  });

  factory PlannerPack.fromJson(Map<String, dynamic> json) {
    return PlannerPack(
      id: _requiredString(json, 'pack_id'),
      title: _requiredString(json, 'title'),
      description: _requiredString(json, 'description'),
      questionCount: _requiredInt(json, 'question_count'),
      publishedAt: _nullableDateTime(json['published_at']),
    );
  }

  final String id;
  final String title;
  final String description;
  final int questionCount;
  final DateTime? publishedAt;
}

class PlannerDisplay {
  const PlannerDisplay({
    required this.id,
    required this.name,
    required this.scopeType,
    required this.pairingStatus,
    required this.health,
    this.venueId,
    this.assignedSessionId,
  });

  factory PlannerDisplay.fromJson(Map<String, dynamic> json) {
    _rejectSensitiveProjection(json);
    return PlannerDisplay(
      id: _requiredString(json, 'display_id'),
      name: _requiredString(json, 'display_name'),
      scopeType: _requiredString(json, 'scope_type'),
      pairingStatus: _requiredString(json, 'pairing_status'),
      health: _requiredString(json, 'health'),
      venueId: _nullableString(json['venue_id']),
      assignedSessionId: _nullableString(json['assigned_session_id']),
    );
  }

  final String id;
  final String name;
  final String scopeType;
  final String pairingStatus;
  final String health;
  final String? venueId;
  final String? assignedSessionId;

  bool get isAvailable => assignedSessionId == null;
}

class PlannerInvitee {
  const PlannerInvitee({
    required this.userId,
    required this.displayName,
    required this.publicUserId,
  });

  factory PlannerInvitee.fromJson(Map<String, dynamic> json) {
    _rejectSensitiveProjection(json);
    final publicUserId = _requiredString(json, 'public_user_id');
    if (!RegExp(r'^\d{6}$').hasMatch(publicUserId)) {
      throw const FormatException('Invalid public_user_id.');
    }
    return PlannerInvitee(
      userId: _requiredString(json, 'user_id'),
      displayName: _requiredString(json, 'display_name'),
      publicUserId: publicUserId,
    );
  }

  final String userId;
  final String displayName;
  final String publicUserId;
}

class GamePlannerOptions {
  const GamePlannerOptions({
    required this.clubId,
    required this.serverTime,
    required this.packs,
    required this.displays,
    required this.invitees,
    required this.allowedEligibilityScopes,
  });

  factory GamePlannerOptions.fromJson(
    Map<String, dynamic> json, {
    required String expectedClubId,
  }) {
    final clubId = _requiredString(json, 'club_id');
    _requireClub(clubId, expectedClubId);
    return GamePlannerOptions(
      clubId: clubId,
      serverTime: _requiredDateTime(json, 'server_time'),
      packs: _mapList(json['packs'], PlannerPack.fromJson),
      displays: _mapList(json['displays'], PlannerDisplay.fromJson),
      invitees: _mapList(json['invitees'], PlannerInvitee.fromJson),
      allowedEligibilityScopes: _stringList(json['allowed_eligibility_scopes']),
    );
  }

  final String clubId;
  final DateTime serverTime;
  final List<PlannerPack> packs;
  final List<PlannerDisplay> displays;
  final List<PlannerInvitee> invitees;
  final List<String> allowedEligibilityScopes;
}

class ManagedDisplaySummary {
  const ManagedDisplaySummary({
    required this.id,
    required this.name,
    required this.scopeType,
    required this.pairingStatus,
    required this.health,
    this.lastSeenAt,
  });

  factory ManagedDisplaySummary.fromJson(Map<String, dynamic> json) {
    return ManagedDisplaySummary(
      id: _requiredString(json, 'display_id'),
      name: _requiredString(json, 'display_name'),
      scopeType: _requiredString(json, 'scope_type'),
      pairingStatus: _requiredString(json, 'pairing_status'),
      health: _requiredString(json, 'health'),
      lastSeenAt: _nullableDateTime(json['last_seen_at']),
    );
  }

  final String id;
  final String name;
  final String scopeType;
  final String pairingStatus;
  final String health;
  final DateTime? lastSeenAt;
}

class ManagedQuestionControl {
  const ManagedQuestionControl({
    required this.id,
    required this.ordinal,
    required this.state,
    required this.prompt,
    required this.options,
  });

  factory ManagedQuestionControl.fromJson(Map<String, dynamic> json) {
    return ManagedQuestionControl(
      id: _requiredString(json, 'id'),
      ordinal: _requiredInt(json, 'ordinal'),
      state: _requiredString(json, 'state'),
      prompt: _requiredString(json, 'prompt'),
      options: _mapList(
        json['options'],
        (option) => Map<String, dynamic>.unmodifiable(option),
      ),
    );
  }

  final String id;
  final int ordinal;
  final String state;
  final String prompt;
  final List<Map<String, dynamic>> options;
}

class ManagedQuestionSummary {
  const ManagedQuestionSummary({
    required this.id,
    required this.ordinal,
    required this.state,
    required this.prompt,
  });

  factory ManagedQuestionSummary.fromJson(Map<String, dynamic> json) {
    _rejectSensitiveProjection(json);
    return ManagedQuestionSummary(
      id: _requiredString(json, 'id'),
      ordinal: _requiredInt(json, 'ordinal'),
      state: _requiredString(json, 'state'),
      prompt: _requiredString(json, 'prompt'),
    );
  }

  final String id;
  final int ordinal;
  final String state;
  final String prompt;
}

class ManagedGameSession {
  const ManagedGameSession({
    required this.clubId,
    required this.id,
    required this.title,
    required this.packTitle,
    required this.phase,
    required this.sessionVersion,
    required this.questionVersion,
    required this.eventSequence,
    required this.serverTime,
    required this.eligibilityScope,
    required this.allowedActions,
    required this.participantCount,
    required this.assignedDisplays,
    this.questionControls = const <ManagedQuestionSummary>[],
    this.phaseDeadline,
    this.scheduledStartAt,
    this.currentQuestion,
  });

  factory ManagedGameSession.fromJson(
    Map<String, dynamic> json, {
    required String expectedClubId,
  }) {
    _rejectSensitiveProjection(json);
    final clubId = _requiredString(json, 'club_id');
    _requireClub(clubId, expectedClubId);
    final question = json['current_question_control'];
    return ManagedGameSession(
      clubId: clubId,
      id: _requiredString(json, 'session_id'),
      title: _requiredString(json, 'session_title'),
      packTitle: _requiredString(json, 'pack_title'),
      phase: _requiredString(json, 'phase'),
      sessionVersion: _requiredInt(json, 'session_version'),
      questionVersion: _requiredInt(json, 'question_version'),
      eventSequence: _requiredInt(json, 'event_sequence'),
      serverTime: _requiredDateTime(json, 'server_time'),
      phaseDeadline: _nullableDateTime(json['phase_deadline']),
      scheduledStartAt: _nullableDateTime(json['scheduled_start_at']),
      eligibilityScope: _requiredString(json, 'eligibility_scope'),
      allowedActions: _stringList(json['allowed_actions']),
      participantCount: _requiredInt(json, 'participant_count'),
      assignedDisplays: _mapList(
        json['assigned_displays'],
        ManagedDisplaySummary.fromJson,
      ),
      questionControls: json['question_controls'] == null
          ? const <ManagedQuestionSummary>[]
          : _mapList(
              json['question_controls'],
              ManagedQuestionSummary.fromJson,
            ),
      currentQuestion: question is Map
          ? ManagedQuestionControl.fromJson(Map<String, dynamic>.from(question))
          : null,
    );
  }

  final String clubId;
  final String id;
  final String title;
  final String packTitle;
  final String phase;
  final int sessionVersion;
  final int questionVersion;
  final int eventSequence;
  final DateTime serverTime;
  final DateTime? phaseDeadline;
  final DateTime? scheduledStartAt;
  final String eligibilityScope;
  final List<String> allowedActions;
  final int participantCount;
  final List<ManagedDisplaySummary> assignedDisplays;
  final List<ManagedQuestionSummary> questionControls;
  final ManagedQuestionControl? currentQuestion;

  ManagedQuestionSummary? get nextQuestion {
    final currentOrdinal = currentQuestion?.ordinal ?? 0;
    final candidates =
        questionControls
            .where(
              (question) =>
                  question.ordinal > currentOrdinal &&
                  question.id != currentQuestion?.id &&
                  question.state != 'closed',
            )
            .toList(growable: false)
          ..sort((left, right) => left.ordinal.compareTo(right.ordinal));
    return candidates.firstOrNull;
  }
}

class ManagedGamesInventory {
  const ManagedGamesInventory({
    required this.clubId,
    required this.serverTime,
    required this.canPlan,
    required this.sessions,
  });

  factory ManagedGamesInventory.fromJson(
    Map<String, dynamic> json, {
    required String expectedClubId,
  }) {
    final clubId = _requiredString(json, 'club_id');
    _requireClub(clubId, expectedClubId);
    return ManagedGamesInventory(
      clubId: clubId,
      serverTime: _requiredDateTime(json, 'server_time'),
      canPlan: json['can_plan'] == true,
      sessions: _mapList(
        json['sessions'],
        (entry) =>
            ManagedGameSession.fromJson(entry, expectedClubId: expectedClubId),
      ),
    );
  }

  final String clubId;
  final DateTime serverTime;
  final bool canPlan;
  final List<ManagedGameSession> sessions;
}

Map<String, dynamic> requireObject(Object? value, String label) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('$label returned an invalid object.');
}

List<T> _mapList<T>(Object? value, T Function(Map<String, dynamic>) mapper) {
  if (value is! List) throw const FormatException('Expected a JSON list.');
  return List<T>.unmodifiable(
    value.map((entry) {
      if (entry is! Map) throw const FormatException('Invalid list entry.');
      return mapper(Map<String, dynamic>.from(entry));
    }),
  );
}

List<String> _stringList(Object? value) {
  if (value is! List || value.any((entry) => entry is! String)) {
    throw const FormatException('Expected a string list.');
  }
  return List<String>.unmodifiable(value.cast<String>());
}

Map<String, Object?> _safeCapabilities(Object? value) {
  if (value == null) return const <String, Object?>{};
  if (value is! Map || value.length > 32) {
    throw const FormatException('Invalid display capabilities.');
  }
  final capabilities = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key.toString().trim();
    final capability = entry.value;
    if (key.isEmpty || key.length > 64) {
      throw const FormatException('Invalid display capability key.');
    }
    if (capability is bool || capability is num) {
      capabilities[key] = capability;
    } else if (capability is String && capability.trim().length <= 80) {
      capabilities[key] = capability.trim();
    } else {
      throw const FormatException('Invalid display capability value.');
    }
  }
  return Map<String, Object?>.unmodifiable(capabilities);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    throw FormatException('Missing $key.');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) throw FormatException('Invalid $key.');
  return parsed;
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = _nullableDateTime(json[key]);
  if (value == null) throw FormatException('Invalid $key.');
  return value;
}

String? _nullableString(Object? value) {
  final normalized = value?.toString().trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

DateTime? _nullableDateTime(Object? value) {
  final normalized = _nullableString(value);
  return normalized == null ? null : DateTime.tryParse(normalized)?.toUtc();
}

void _requireClub(String actual, String expected) {
  if (actual != expected.trim()) {
    throw const GameOperationsFailure(
      GameOperationsFailureKind.permissionDenied,
    );
  }
}

void _rejectSensitiveProjection(Object? value) {
  const forbiddenKeys = <String>{
    'credential_token_hash',
    'device_credential',
    'pairing_code',
    'pairing_code_hash',
    'join_code',
    'phone',
    'email',
    'correct_option_key',
  };
  if (value is Map) {
    for (final entry in value.entries) {
      if (forbiddenKeys.contains(entry.key.toString())) {
        throw const FormatException('Sensitive projection field received.');
      }
      _rejectSensitiveProjection(entry.value);
    }
    return;
  }
  if (value is List) {
    for (final entry in value) {
      _rejectSensitiveProjection(entry);
    }
  }
}

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);
