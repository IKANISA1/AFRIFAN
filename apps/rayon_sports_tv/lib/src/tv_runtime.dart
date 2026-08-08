import 'dart:async';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const tvCredentialStorageKey = 'africlub_tv_device_credential_v2';
const tvInstallationNonceStorageKey = 'africlub_tv_installation_nonce_v2';
const tvSupportedProjectionPhases = <String>{
  'scheduled',
  'activated_lobby',
  'question_open',
  'reveal',
  'paused',
  'completed',
  'cancelled',
};

enum TvRuntimeFailureKind {
  unavailable,
  securityTimeout,
  invalidResponse,
  challengeExpired,
  revoked,
  secureStorage,
}

class TvRuntimeFailure implements Exception {
  const TvRuntimeFailure(this.kind, [this.cause]);

  final TvRuntimeFailureKind kind;
  final Object? cause;

  @override
  String toString() => 'TvRuntimeFailure($kind)';
}

class TvBootstrapChallenge {
  const TvBootstrapChallenge({
    required this.challenge,
    required this.expiresAt,
    required this.qrPayload,
  });

  factory TvBootstrapChallenge.fromJson(Map<String, dynamic> json) {
    if (json['status'] != 'pending_owner_claim') {
      throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
    }
    final challenge = _requiredString(json, 'challenge', exactLength: 8);
    if (!RegExp(r'^[A-Z0-9]{8}$').hasMatch(challenge)) {
      throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
    }
    final qrPayload = _requiredString(json, 'qr_payload', maxLength: 256);
    final qrUri = Uri.tryParse(qrPayload);
    if (qrUri == null ||
        qrUri.scheme != 'africlub' ||
        qrUri.host != 'my-tvs' ||
        qrUri.path != '/pair' ||
        qrUri.queryParameters['challenge'] != challenge ||
        qrUri.queryParameters.length != 1) {
      throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
    }
    return TvBootstrapChallenge(
      challenge: challenge,
      expiresAt: _requiredDateTime(json, 'expires_at'),
      qrPayload: qrPayload,
    );
  }

  final String challenge;
  final DateTime expiresAt;
  final String qrPayload;
}

enum TvCredentialExchangeStatus { pendingOwnerClaim, paired }

class TvCredentialExchange {
  const TvCredentialExchange._({
    required this.status,
    this.credential,
    this.displayId,
    this.clubId,
    this.expiresAt,
  });

  factory TvCredentialExchange.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString();
    if (status == 'pending_owner_claim') {
      return TvCredentialExchange._(
        status: TvCredentialExchangeStatus.pendingOwnerClaim,
        expiresAt: _requiredDateTime(json, 'expires_at'),
      );
    }
    if (status == 'paired') {
      return TvCredentialExchange._(
        status: TvCredentialExchangeStatus.paired,
        credential: _requiredString(json, 'device_credential', exactLength: 64),
        displayId: _requiredString(json, 'display_id'),
        clubId: _requiredString(json, 'club_id'),
      );
    }
    final code = json['code']?.toString();
    if (code == 'challenge_invalid_or_expired') {
      throw const TvRuntimeFailure(TvRuntimeFailureKind.challengeExpired);
    }
    if (code == 'display_revoked' || code == 'credential_already_issued') {
      throw const TvRuntimeFailure(TvRuntimeFailureKind.revoked);
    }
    throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
  }

  final TvCredentialExchangeStatus status;
  final String? credential;
  final String? displayId;
  final String? clubId;
  final DateTime? expiresAt;
}

class TvRealtimeIdentity {
  const TvRealtimeIdentity({required this.displayId, required this.clubId});

  factory TvRealtimeIdentity.fromJson(
    Map<String, dynamic> json, {
    required String expectedClubId,
  }) {
    if (json['status'] != 'ready') {
      final code = json['code']?.toString();
      if (code == 'credential_revoked_or_invalid' ||
          code == 'identity_already_bound' ||
          code == 'identity_in_use') {
        throw const TvRuntimeFailure(TvRuntimeFailureKind.revoked);
      }
      throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
    }
    final clubId = _requiredString(json, 'club_id');
    if (clubId != expectedClubId ||
        json['authorization'] != 'assigned_session_events_only') {
      throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
    }
    return TvRealtimeIdentity(
      displayId: _requiredString(json, 'display_id'),
      clubId: clubId,
    );
  }

  final String displayId;
  final String clubId;
}

enum TvRealtimeSignalKind { subscribed, invalidation }

class TvRealtimeSignal {
  const TvRealtimeSignal._({
    required this.kind,
    required this.clubId,
    required this.sessionId,
    this.sessionVersion = 0,
    this.questionVersion = 0,
    this.eventSequence = 0,
  });

  factory TvRealtimeSignal.subscribed({
    required String clubId,
    required String sessionId,
  }) {
    return TvRealtimeSignal._(
      kind: TvRealtimeSignalKind.subscribed,
      clubId: clubId,
      sessionId: sessionId,
    );
  }

  factory TvRealtimeSignal.invalidation(
    Map<String, dynamic> json, {
    required String expectedClubId,
    required String expectedSessionId,
  }) {
    _rejectSensitiveProjection(json);
    _rejectSensitiveInvalidation(json);
    final clubId = _requiredString(json, 'club_id');
    final sessionId = _requiredString(json, 'session_id');
    final topic = _requiredString(json, 'topic');
    final payload = json['payload'];
    if (clubId != expectedClubId ||
        sessionId != expectedSessionId ||
        topic != '$expectedClubId:game_session:$expectedSessionId' ||
        json['event_type'] != 'projection_invalidated' ||
        payload is! Map ||
        payload['requires_projection_refresh'] != true) {
      throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
    }
    return TvRealtimeSignal._(
      kind: TvRealtimeSignalKind.invalidation,
      clubId: clubId,
      sessionId: sessionId,
      sessionVersion: _requiredNonNegativeInt(json, 'session_version'),
      questionVersion: _requiredNonNegativeInt(json, 'question_version'),
      eventSequence: _requiredNonNegativeInt(json, 'event_sequence'),
    );
  }

  final TvRealtimeSignalKind kind;
  final String clubId;
  final String sessionId;
  final int sessionVersion;
  final int questionVersion;
  final int eventSequence;
}

class TvQuestionOption {
  const TvQuestionOption({required this.key, required this.label});

  factory TvQuestionOption.fromJson(Map<String, dynamic> json) {
    return TvQuestionOption(
      key: _requiredString(json, 'key', maxLength: 24),
      label: _requiredString(json, 'label', maxLength: 160),
    );
  }

  final String key;
  final String label;
}

class TvQuestionProjection {
  const TvQuestionProjection({
    required this.id,
    required this.ordinal,
    required this.prompt,
    required this.options,
    this.correctOptionKey,
  });

  factory TvQuestionProjection.fromJson(
    Map<String, dynamic> json, {
    required String phase,
  }) {
    final correctOptionKey = _nullableString(json['correct_option_key']);
    if (correctOptionKey != null && phase != 'reveal' && phase != 'completed') {
      throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
    }
    final options = json['options'];
    if (options is! List || options.length < 2 || options.length > 8) {
      throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
    }
    final parsedOptions = options
        .map((option) {
          if (option is! Map) {
            throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
          }
          return TvQuestionOption.fromJson(Map<String, dynamic>.from(option));
        })
        .toList(growable: false);
    final optionKeys = parsedOptions.map((option) => option.key).toSet();
    if (optionKeys.length != parsedOptions.length ||
        (correctOptionKey != null && !optionKeys.contains(correctOptionKey))) {
      throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
    }
    return TvQuestionProjection(
      id: _requiredString(json, 'id'),
      ordinal: _requiredNonNegativeInt(json, 'ordinal'),
      prompt: _requiredString(json, 'prompt', maxLength: 500),
      options: List<TvQuestionOption>.unmodifiable(parsedOptions),
      correctOptionKey: correctOptionKey,
    );
  }

  final String id;
  final int ordinal;
  final String prompt;
  final List<TvQuestionOption> options;
  final String? correctOptionKey;
}

class TvLeaderboardEntry {
  const TvLeaderboardEntry({
    required this.rank,
    required this.publicAlias,
    required this.score,
  });

  factory TvLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return TvLeaderboardEntry(
      rank: _requiredNonNegativeInt(json, 'rank'),
      publicAlias: _requiredString(json, 'public_alias', maxLength: 80),
      score: _requiredNonNegativeInt(json, 'score'),
    );
  }

  final int rank;
  final String publicAlias;
  final int score;
}

class TvProjectionFreshness {
  const TvProjectionFreshness({required this.state, required this.lastEventAt});

  factory TvProjectionFreshness.fromJson(Map<String, dynamic> json) {
    final state = _requiredString(json, 'state', maxLength: 24);
    if (state != 'current') {
      throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
    }
    return TvProjectionFreshness(
      state: state,
      lastEventAt: _requiredDateTime(json, 'last_event_at'),
    );
  }

  final String state;
  final DateTime lastEventAt;
}

class TvGameProjection {
  const TvGameProjection({
    required this.status,
    required this.displayId,
    required this.clubId,
    required this.serverTime,
    this.allowedActions = const <String>{'retry_projection'},
    this.freshness,
    this.sessionId,
    this.sessionTitle,
    this.phase,
    this.sessionVersion = 0,
    this.questionVersion = 0,
    this.eventSequence = 0,
    this.phaseDeadline,
    this.question,
    this.leaderboard = const <TvLeaderboardEntry>[],
  });

  factory TvGameProjection.fromJson(
    Map<String, dynamic> json, {
    String? expectedClubId,
  }) {
    _rejectSensitiveProjection(json);
    final status = _requiredString(json, 'status');
    if (status != 'empty' && status != 'ready') {
      final code = json['code']?.toString();
      if (code == 'credential_invalid' ||
          code == 'credential_revoked_or_invalid') {
        throw const TvRuntimeFailure(TvRuntimeFailureKind.revoked);
      }
      throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
    }
    final clubId = _requiredString(json, 'club_id');
    if (expectedClubId != null &&
        expectedClubId.isNotEmpty &&
        expectedClubId != clubId) {
      throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
    }
    final displayId = _requiredString(json, 'display_id');
    final serverTime = _requiredDateTime(json, 'server_time');
    final actionsJson = json['allowed_actions'];
    if (actionsJson is! List || actionsJson.length != 1) {
      throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
    }
    final allowedActions = actionsJson
        .map((action) => action.toString())
        .toSet();
    if (allowedActions.length != 1 ||
        !allowedActions.contains('retry_projection')) {
      throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
    }
    final freshnessJson = json['freshness'];
    if (freshnessJson is! Map) {
      throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
    }
    final freshness = TvProjectionFreshness.fromJson(
      Map<String, dynamic>.from(freshnessJson),
    );
    if (status == 'empty') {
      return TvGameProjection(
        status: status,
        displayId: displayId,
        clubId: clubId,
        serverTime: serverTime,
        allowedActions: Set<String>.unmodifiable(allowedActions),
        freshness: freshness,
      );
    }

    final phase = _requiredString(json, 'phase');
    if (!tvSupportedProjectionPhases.contains(phase)) {
      throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
    }
    final questionJson = json['question'];
    final leaderboardJson = json['leaderboard'];
    if (leaderboardJson is! List || leaderboardJson.length > 20) {
      throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
    }
    final phaseDeadline = _nullableDateTime(json['phase_deadline']);
    if ((phase == 'question_open') != (phaseDeadline != null)) {
      throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
    }
    final question = questionJson is Map
        ? TvQuestionProjection.fromJson(
            Map<String, dynamic>.from(questionJson),
            phase: phase,
          )
        : null;
    if ((phase == 'question_open' ||
            phase == 'reveal' ||
            phase == 'completed') &&
        question == null) {
      throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
    }
    if ((phase == 'reveal' || phase == 'completed') &&
        question?.correctOptionKey == null) {
      throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
    }
    final leaderboard = leaderboardJson
        .map((entry) {
          if (entry is! Map) {
            throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
          }
          return TvLeaderboardEntry.fromJson(Map<String, dynamic>.from(entry));
        })
        .toList(growable: false);
    for (var index = 0; index < leaderboard.length; index += 1) {
      if (leaderboard[index].rank != index + 1) {
        throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
      }
    }
    return TvGameProjection(
      status: status,
      displayId: displayId,
      clubId: clubId,
      serverTime: serverTime,
      allowedActions: Set<String>.unmodifiable(allowedActions),
      freshness: freshness,
      sessionId: _requiredString(json, 'session_id'),
      sessionTitle: _requiredString(json, 'session_title', maxLength: 120),
      phase: phase,
      sessionVersion: _requiredNonNegativeInt(json, 'session_version'),
      questionVersion: _requiredNonNegativeInt(json, 'question_version'),
      eventSequence: _requiredNonNegativeInt(json, 'event_sequence'),
      phaseDeadline: phaseDeadline,
      question: question,
      leaderboard: List<TvLeaderboardEntry>.unmodifiable(leaderboard),
    );
  }

  final String status;
  final String displayId;
  final String clubId;
  final DateTime serverTime;
  final Set<String> allowedActions;
  final TvProjectionFreshness? freshness;
  final String? sessionId;
  final String? sessionTitle;
  final String? phase;
  final int sessionVersion;
  final int questionVersion;
  final int eventSequence;
  final DateTime? phaseDeadline;
  final TvQuestionProjection? question;
  final List<TvLeaderboardEntry> leaderboard;

  bool get isEmpty => status == 'empty';
}

class TvProjectionReconciler {
  TvGameProjection? _current;

  TvGameProjection? get current => _current;

  TvGameProjection accept(TvGameProjection incoming) {
    final existing = _current;
    if (existing == null) {
      _current = incoming;
      return incoming;
    }
    if (incoming.serverTime.isBefore(existing.serverTime)) {
      return existing;
    }
    if (incoming.sessionId == existing.sessionId &&
        incoming.sessionId != null) {
      if (incoming.sessionVersion < existing.sessionVersion) return existing;
      if (incoming.sessionVersion == existing.sessionVersion &&
          incoming.eventSequence <= existing.eventSequence) {
        return existing;
      }
    }
    _current = incoming;
    return incoming;
  }

  void clear() => _current = null;
}

abstract interface class TvRuntimeGateway {
  Future<void> prepareDeviceIdentity();

  Future<TvBootstrapChallenge> createPairingChallenge({
    required String installationNonce,
  });

  Future<TvCredentialExchange> exchangePairingChallenge({
    required String challenge,
    required String installationNonce,
  });

  Future<TvRealtimeIdentity> bindRealtimeIdentity(String credential);

  Future<TvGameProjection> fetchProjection(String credential);

  Stream<TvRealtimeSignal> watchInvalidations({
    required String clubId,
    required String sessionId,
  });
}

class SupabaseTvRuntimeGateway implements TvRuntimeGateway {
  SupabaseTvRuntimeGateway({
    required SupabaseClient client,
    this.expectedClubId,
  }) : _client = client;

  final SupabaseClient _client;
  final String? expectedClubId;

  String get _requiredExpectedClubId {
    final value = expectedClubId?.trim() ?? '';
    if (value.isEmpty) {
      throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
    }
    return value;
  }

  @override
  Future<void> prepareDeviceIdentity() {
    return _guard(() async {
      final expected = _requiredExpectedClubId;
      var user = _client.auth.currentUser;
      if (user == null) {
        final response = await _client.auth.signInAnonymously(
          data: <String, dynamic>{
            'club_id': expected,
            'auth_purpose': 'native_tv_realtime',
          },
        );
        user = response.user;
      }
      final userClubId = user?.userMetadata?['club_id']?.toString();
      if (user == null || !user.isAnonymous || userClubId != expected) {
        throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
      }
    });
  }

  @override
  Future<TvBootstrapChallenge> createPairingChallenge({
    required String installationNonce,
  }) {
    return _guard(() async {
      final response = await _client.rpc<Object?>(
        'create_display_pairing_challenge_v2',
        params: <String, dynamic>{
          'p_installation_nonce': installationNonce,
          'p_app_version': '1.0.0',
          'p_capabilities': const <String, dynamic>{
            'platform': 'android_tv',
            'remote_focus': true,
            'projection_version': 2,
          },
        },
      );
      return TvBootstrapChallenge.fromJson(
        _requiredMap(response, 'Pairing challenge'),
      );
    });
  }

  @override
  Future<TvCredentialExchange> exchangePairingChallenge({
    required String challenge,
    required String installationNonce,
  }) {
    return _guard(() async {
      final response = await _client.rpc<Object?>(
        'exchange_display_pairing_challenge_v2',
        params: <String, dynamic>{
          'p_challenge': challenge,
          'p_installation_nonce': installationNonce,
        },
      );
      return TvCredentialExchange.fromJson(
        _requiredMap(response, 'Pairing exchange'),
      );
    });
  }

  @override
  Future<TvRealtimeIdentity> bindRealtimeIdentity(String credential) {
    return _guard(() async {
      final response = await _client.rpc<Object?>(
        'bind_tv_realtime_identity_v2',
        params: <String, dynamic>{'p_device_token': credential},
      );
      return TvRealtimeIdentity.fromJson(
        _requiredMap(response, 'TV Realtime identity'),
        expectedClubId: _requiredExpectedClubId,
      );
    });
  }

  @override
  Future<TvGameProjection> fetchProjection(String credential) {
    return _guard(() async {
      final response = await _client.rpc<Object?>(
        'get_tv_game_projection_v2',
        params: <String, dynamic>{'p_device_token': credential},
      );
      return TvGameProjection.fromJson(
        _requiredMap(response, 'TV projection'),
        expectedClubId: expectedClubId,
      );
    });
  }

  @override
  Stream<TvRealtimeSignal> watchInvalidations({
    required String clubId,
    required String sessionId,
  }) {
    final expected = _requiredExpectedClubId;
    if (clubId != expected || sessionId.trim().isEmpty) {
      throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
    }
    late final StreamController<TvRealtimeSignal> controller;
    RealtimeChannel? channel;
    var removed = false;

    Future<void> removeChannel() async {
      if (removed) return;
      removed = true;
      final active = channel;
      channel = null;
      if (active != null) await _client.removeChannel(active);
    }

    controller = StreamController<TvRealtimeSignal>.broadcast(
      onListen: () {
        final topic = '$clubId:game_session:$sessionId';
        channel =
            _client
                .channel('native-tv:$topic')
                .onPostgresChanges(
                  event: PostgresChangeEvent.insert,
                  schema: 'africlub_game',
                  table: 'game_events',
                  filter: PostgresChangeFilter(
                    type: PostgresChangeFilterType.eq,
                    column: 'topic',
                    value: topic,
                  ),
                  callback: (payload) {
                    if (controller.isClosed) return;
                    try {
                      controller.add(
                        TvRealtimeSignal.invalidation(
                          payload.newRecord,
                          expectedClubId: clubId,
                          expectedSessionId: sessionId,
                        ),
                      );
                    } catch (error, stackTrace) {
                      controller.addError(error, stackTrace);
                    }
                  },
                )
              ..subscribe((status, error) {
                if (controller.isClosed) return;
                if (status == RealtimeSubscribeStatus.subscribed) {
                  controller.add(
                    TvRealtimeSignal.subscribed(
                      clubId: clubId,
                      sessionId: sessionId,
                    ),
                  );
                  return;
                }
                if (status == RealtimeSubscribeStatus.channelError ||
                    status == RealtimeSubscribeStatus.closed ||
                    status == RealtimeSubscribeStatus.timedOut) {
                  controller.addError(
                    TvRuntimeFailure(
                      TvRuntimeFailureKind.unavailable,
                      error ?? status,
                    ),
                  );
                }
              });
      },
      onCancel: () async {
        await removeChannel();
        if (!controller.isClosed) await controller.close();
      },
    );

    return controller.stream;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on TvRuntimeFailure {
      rethrow;
    } on PostgrestException catch (error) {
      throw TvRuntimeFailure(TvRuntimeFailureKind.unavailable, error);
    } on FormatException catch (error) {
      throw TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse, error);
    } catch (error) {
      throw TvRuntimeFailure(TvRuntimeFailureKind.unavailable, error);
    }
  }
}

abstract interface class TvCredentialStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureTvCredentialStore implements TvCredentialStore {
  SecureTvCredentialStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

String createInstallationNonce([Random? random]) {
  final secureRandom = random ?? Random.secure();
  final bytes = List<int>.generate(32, (_) => secureRandom.nextInt(256));
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

Map<String, dynamic> _requiredMap(Object? value, String label) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('$label returned an invalid object.');
}

String _requiredString(
  Map<String, dynamic> json,
  String key, {
  int? exactLength,
  int? maxLength,
}) {
  final value = json[key]?.toString().trim();
  if (value == null ||
      value.isEmpty ||
      (exactLength != null && value.length != exactLength) ||
      (maxLength != null && value.length > maxLength)) {
    throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
  }
  return value;
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int _requiredNonNegativeInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  if (parsed == null || parsed < 0) {
    throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
  }
  return parsed;
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final parsed = DateTime.tryParse(json[key]?.toString() ?? '');
  if (parsed == null) {
    throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
  }
  return parsed.toUtc();
}

DateTime? _nullableDateTime(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed == null) {
    throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
  }
  return parsed.toUtc();
}

void _rejectSensitiveProjection(Map<String, dynamic> json) {
  const forbidden = <String>{
    'device_credential',
    'credential_token',
    'credential_token_hash',
    'pairing_code',
    'owner_user_id',
    'phone',
    'email',
  };

  void inspect(Object? value) {
    if (value is Map) {
      for (final entry in value.entries) {
        if (forbidden.contains(entry.key.toString().toLowerCase())) {
          throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
        }
        inspect(entry.value);
      }
    } else if (value is Iterable) {
      for (final item in value) {
        inspect(item);
      }
    }
  }

  inspect(json);
}

void _rejectSensitiveInvalidation(Map<String, dynamic> json) {
  const forbidden = <String>{
    'correct_option_key',
    'correct_answer',
    'answer',
    'public_alias',
    'display_name',
    'owner_user_id',
    'phone',
    'email',
  };

  void inspect(Object? value) {
    if (value is Map) {
      for (final entry in value.entries) {
        if (forbidden.contains(entry.key.toString().toLowerCase())) {
          throw const TvRuntimeFailure(TvRuntimeFailureKind.invalidResponse);
        }
        inspect(entry.value);
      }
    } else if (value is Iterable) {
      for (final item in value) {
        inspect(item);
      }
    }
  }

  inspect(json);
}

bool isValidTvCredential(String? value) =>
    value != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
