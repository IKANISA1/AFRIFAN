import '../models/live_game_v2_models.dart';

enum LiveGameProjectionDecision {
  acceptedInitial,
  acceptedNewer,
  ignoredDuplicate,
  ignoredStale,
  rejectedScope,
}

class LiveGameInvalidationHint {
  const LiveGameInvalidationHint({
    required this.clubId,
    required this.sessionId,
    required this.sessionVersion,
    required this.eventSequence,
  });

  final String clubId;
  final String sessionId;
  final int sessionVersion;
  final int eventSequence;

  factory LiveGameInvalidationHint.fromJson(Map<String, dynamic> json) {
    return LiveGameInvalidationHint(
      clubId: _requiredString(json, 'club_id'),
      sessionId: _requiredString(json, 'session_id'),
      sessionVersion: _requiredNonNegativeInt(json, 'session_version'),
      eventSequence: _requiredNonNegativeInt(json, 'event_sequence'),
    );
  }
}

class ParticipantProjectionReconciler {
  ParticipantProjectionReconciler({
    required this.expectedClubId,
    required this.sessionId,
  });

  final String expectedClubId;
  final String sessionId;

  ParticipantGameProjection? _current;

  ParticipantGameProjection? get current => _current;

  bool shouldReconcile(LiveGameInvalidationHint hint) {
    if (!_matchesScope(hint.clubId, hint.sessionId)) return false;
    final currentProjection = _current;
    if (currentProjection == null) return true;

    final version = currentProjection.version;
    return hint.sessionVersion > version.sessionVersion ||
        (hint.sessionVersion == version.sessionVersion &&
            hint.eventSequence > version.eventSequence);
  }

  LiveGameProjectionDecision apply(ParticipantGameProjection candidate) {
    final candidateVersion = candidate.version;
    if (!_matchesScope(candidateVersion.clubId, candidateVersion.sessionId)) {
      return LiveGameProjectionDecision.rejectedScope;
    }

    final currentProjection = _current;
    if (currentProjection == null) {
      _current = candidate;
      return LiveGameProjectionDecision.acceptedInitial;
    }

    final currentVersion = currentProjection.version;
    if (candidateVersion.sessionVersion == currentVersion.sessionVersion &&
        candidateVersion.eventSequence == currentVersion.eventSequence) {
      return LiveGameProjectionDecision.ignoredDuplicate;
    }
    if (!candidate.shouldReplace(currentProjection)) {
      return LiveGameProjectionDecision.ignoredStale;
    }

    _current = candidate;
    return LiveGameProjectionDecision.acceptedNewer;
  }

  void clear() {
    _current = null;
  }

  bool _matchesScope(String clubId, String candidateSessionId) {
    return clubId == expectedClubId && candidateSessionId == sessionId;
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw LiveGameContractViolation('Invalid invalidation field: $key.');
}

int _requiredNonNegativeInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int && value >= 0) return value;
  throw LiveGameContractViolation('Invalid invalidation field: $key.');
}
