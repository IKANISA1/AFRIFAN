import 'live_game_v2_models.dart';

enum ParticipantDiscoverySource {
  clubMembership,
  invitation,
  homeOwner,
  venue,
  deepLink;

  factory ParticipantDiscoverySource.fromWireValue(String value) {
    return switch (value) {
      'club_membership' => ParticipantDiscoverySource.clubMembership,
      'invitation' => ParticipantDiscoverySource.invitation,
      'home_owner' => ParticipantDiscoverySource.homeOwner,
      'venue' => ParticipantDiscoverySource.venue,
      'deep_link' => ParticipantDiscoverySource.deepLink,
      _ => throw const LiveGameContractViolation(
        'Unsupported participant discovery source.',
      ),
    };
  }
}

enum ParticipantDiscoveryAvailability { liveNow, scheduled }

class ParticipantGameDiscoveryItem {
  const ParticipantGameDiscoveryItem({
    required this.clubId,
    required this.sessionId,
    required this.title,
    required this.phase,
    required this.source,
    required this.sessionVersion,
    required this.availableFrom,
    required this.eligible,
  });

  final String clubId;
  final String sessionId;
  final String title;
  final LiveGamePhase phase;
  final ParticipantDiscoverySource source;
  final int sessionVersion;
  final DateTime? availableFrom;
  final bool eligible;

  ParticipantDiscoveryAvailability get availability =>
      phase == LiveGamePhase.scheduled
      ? ParticipantDiscoveryAvailability.scheduled
      : ParticipantDiscoveryAvailability.liveNow;

  factory ParticipantGameDiscoveryItem.fromJson(
    Map<String, dynamic> json, {
    required String expectedClubId,
  }) {
    assertParticipantPayloadSafe(json);
    final clubId = _requireString(json, 'club_id');
    if (clubId != expectedClubId) {
      throw const LiveGameContractViolation(
        'Discovered session is outside the expected club scope.',
      );
    }

    final eligible = _requireBool(json, 'eligibility');
    if (!eligible) {
      throw const LiveGameContractViolation(
        'An ineligible session cannot appear in participant discovery.',
      );
    }

    final phase = LiveGamePhase.fromWireValue(_requireString(json, 'phase'));
    const discoverablePhases = <LiveGamePhase>{
      LiveGamePhase.scheduled,
      LiveGamePhase.activatedLobby,
      LiveGamePhase.questionOpen,
      LiveGamePhase.reveal,
      LiveGamePhase.paused,
    };
    if (!discoverablePhases.contains(phase)) {
      throw const LiveGameContractViolation(
        'Session phase is not participant-discoverable.',
      );
    }

    final availableFrom = _optionalDateTime(json, 'available_from');
    if (phase == LiveGamePhase.scheduled && availableFrom == null) {
      throw const LiveGameContractViolation(
        'A scheduled session requires an availability time.',
      );
    }

    return ParticipantGameDiscoveryItem(
      clubId: clubId,
      sessionId: _requireString(json, 'session_id'),
      title: _requireString(json, 'title'),
      phase: phase,
      source: ParticipantDiscoverySource.fromWireValue(
        _requireString(json, 'source'),
      ),
      sessionVersion: _requireNonNegativeInt(json, 'session_version'),
      availableFrom: availableFrom,
      eligible: eligible,
    );
  }
}

class ParticipantGameDiscoveryFeed {
  const ParticipantGameDiscoveryFeed({
    required this.clubId,
    required this.feedVersion,
    required this.serverTime,
    required this.publicAlias,
    required this.sessions,
  });

  final String clubId;
  final int feedVersion;
  final DateTime serverTime;
  final String publicAlias;
  final List<ParticipantGameDiscoveryItem> sessions;

  bool get isEmpty => sessions.isEmpty;

  factory ParticipantGameDiscoveryFeed.fromJson(
    Map<String, dynamic> json, {
    required String expectedClubId,
  }) {
    assertParticipantPayloadSafe(json);
    final clubId = _requireString(json, 'club_id');
    if (clubId != expectedClubId) {
      throw const LiveGameContractViolation(
        'Discovery feed is outside the expected club scope.',
      );
    }

    final sessions = _requireList(json, 'sessions')
        .map(_requireDynamicMap)
        .map(
          (item) => ParticipantGameDiscoveryItem.fromJson(
            item,
            expectedClubId: expectedClubId,
          ),
        )
        .toList(growable: false);
    final sessionIds = sessions.map((session) => session.sessionId).toSet();
    if (sessionIds.length != sessions.length) {
      throw const LiveGameContractViolation(
        'Discovery feed contains duplicate sessions.',
      );
    }

    return ParticipantGameDiscoveryFeed(
      clubId: clubId,
      feedVersion: _requireNonNegativeInt(json, 'feed_version'),
      serverTime: _requireDateTime(json, 'server_time'),
      publicAlias: _requireString(json, 'public_alias'),
      sessions: List.unmodifiable(sessions),
    );
  }

  bool isNewerThan(ParticipantGameDiscoveryFeed current) {
    return clubId == current.clubId && feedVersion > current.feedVersion;
  }

  ParticipantGameDiscoveryItem? sessionById(String sessionId) {
    final normalized = sessionId.trim();
    if (normalized.isEmpty) return null;
    for (final session in sessions) {
      if (session.sessionId == normalized) return session;
    }
    return null;
  }
}

String _requireString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw LiveGameContractViolation('Required string field is invalid: $key.');
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
  final parsed = DateTime.tryParse(_requireString(json, key));
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

List<dynamic> _requireList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List) return value;
  throw LiveGameContractViolation('Required list field is invalid: $key.');
}

Map<String, dynamic> _requireDynamicMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const LiveGameContractViolation('List item must be an object.');
}
