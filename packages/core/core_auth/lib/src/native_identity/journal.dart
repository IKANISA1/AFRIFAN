import 'dart:convert';

import 'models.dart';

enum NativeIdentityOperation { challenge, verification, refresh, revoke }

/// Contains protected recovery material. Never use it as telemetry or UI state.
final class NativeIdentityPending {
  NativeIdentityPending({
    required this.operation,
    required this.requestKey,
    required this.preparedAt,
    required this.firstSentAt,
    required Map<String, Object?> body,
  }) : body = Map.unmodifiable(body);
  final NativeIdentityOperation operation;
  final String? requestKey;
  final int preparedAt;
  final int? firstSentAt;
  final Map<String, Object?> body;
  NativeIdentityPending markSending(int now) => NativeIdentityPending(
    operation: operation,
    requestKey: requestKey,
    preparedAt: preparedAt,
    firstSentAt: firstSentAt ?? now,
    body: body,
  );
  Map<String, Object?> toProtectedJson() => {
    'operation': operation.name,
    'requestKey': requestKey,
    'preparedAt': preparedAt,
    'firstSentAt': firstSentAt,
    'body': body,
  };
  factory NativeIdentityPending.parse(Object? value) {
    final v = identityObject(value, [
      'operation',
      'requestKey',
      'preparedAt',
      'firstSentAt',
      'body',
    ]);
    identityRequire(
      v['operation'] is String &&
          NativeIdentityOperation.values.any(
            (kind) => kind.name == v['operation'],
          ) &&
          identityTime(v['preparedAt']) &&
          (v['firstSentAt'] == null || identityTime(v['firstSentAt'])),
    );
    final operation = NativeIdentityOperation.values.firstWhere(
      (kind) => kind.name == v['operation'],
    );
    identityRequire(
      operation == NativeIdentityOperation.revoke
          ? v['requestKey'] == null
          : identityKey(v['requestKey']),
    );
    final required = switch (operation) {
      NativeIdentityOperation.challenge => ['phone', 'clientSecret'],
      NativeIdentityOperation.verification => [
        'challengeId',
        'code',
        'clientSecret',
      ],
      NativeIdentityOperation.refresh => ['credentials'],
      NativeIdentityOperation.revoke => ['accessToken', 'scope'],
    };
    final body = identityObject(v['body'], required);
    switch (operation) {
      case NativeIdentityOperation.challenge:
        identityRequire(
          identityMatches(r'^\+[1-9]\d{7,14}$', body['phone']) &&
              identitySecret(body['clientSecret']),
        );
      case NativeIdentityOperation.verification:
        identityRequire(
          identityUuid(body['challengeId']) &&
              identityMatches(r'^\d{6}$', body['code']) &&
              identitySecret(body['clientSecret']),
        );
      case NativeIdentityOperation.refresh:
        identityRequire(body['credentials'] is Map<String, dynamic>);
      case NativeIdentityOperation.revoke:
        final token = body['accessToken'];
        identityRequire(
          token is String &&
              token.split('.').length == 2 &&
              identityToken(token, token.split('.').first) &&
              body['scope'] is String &&
              NativeIdentityRevokeScope.values.any(
                (scope) => scope.name == body['scope'],
              ),
        );
    }
    final prepared = v['preparedAt']! as int;
    final sent = v['firstSentAt'] as int?;
    identityRequire(sent == null || sent >= prepared);
    return NativeIdentityPending(
      operation: operation,
      requestKey: v['requestKey'] as String?,
      preparedAt: prepared,
      firstSentAt: sent,
      body: body,
    );
  }
  @override
  String toString() => 'NativeIdentityPending(${operation.name}, [protected])';
}

/// The whole journal is encrypted/protected by the injected OS store.
/// Encoding here is a wire format for that store, never a plaintext fallback.
final class NativeIdentityJournal {
  const NativeIdentityJournal({
    required this.scope,
    this.revision = 0,
    this.locallySignedOut = true,
    this.credentials,
    this.challenge,
    this.challengeSecret,
    this.pending,
    this.revocation = NativeIdentityRevocation.notAttempted,
  });
  final NativeIdentityScope scope;
  final int revision;
  final bool locallySignedOut;
  final NativeIdentityCredentials? credentials;
  final NativeIdentityChallenge? challenge;
  final String? challengeSecret;
  final NativeIdentityPending? pending;
  final NativeIdentityRevocation revocation;

  NativeIdentityJournal next({
    required bool locallySignedOut,
    NativeIdentityCredentials? credentials,
    NativeIdentityChallenge? challenge,
    String? challengeSecret,
    NativeIdentityPending? pending,
    NativeIdentityRevocation revocation = NativeIdentityRevocation.notAttempted,
  }) => NativeIdentityJournal(
    scope: scope,
    revision: revision + 1,
    locallySignedOut: locallySignedOut,
    credentials: credentials,
    challenge: challenge,
    challengeSecret: challengeSecret,
    pending: pending,
    revocation: revocation,
  );

  String encodeProtected() => jsonEncode({
    'schemaVersion': 1,
    'binding': scope.toJson(),
    'revision': revision,
    'locallySignedOut': locallySignedOut,
    'credentials': credentials?.toProtectedJson(),
    'challenge': challenge?.toJson(),
    'challengeSecret': challengeSecret,
    'pending': pending?.toProtectedJson(),
    'revocation': revocation.name,
  });
  factory NativeIdentityJournal.decodeProtected(
    String raw,
    NativeIdentityScope scope,
  ) {
    identityRequire(raw.length <= 8192 && utf8.encode(raw).length <= 8192);
    final v = identityObject(identityDecode(raw), [
      'schemaVersion',
      'binding',
      'revision',
      'locallySignedOut',
      'credentials',
      'challenge',
      'challengeSecret',
      'pending',
      'revocation',
    ]);
    scope.checkBinding(v['binding']);
    identityRequire(
      v['schemaVersion'] is int &&
          v['schemaVersion'] == 1 &&
          v['revision'] is int &&
          (v['revision']! as int) >= 0 &&
          (v['revision']! as int) < 9007199254740991 &&
          v['locallySignedOut'] is bool &&
          v['revocation'] is String &&
          NativeIdentityRevocation.values.any(
            (state) => state.name == v['revocation'],
          ),
    );
    final credentials = v['credentials'] == null
        ? null
        : NativeIdentityCredentials.parse(v['credentials'], scope.clubId);
    final challenge = v['challenge'] == null
        ? null
        : NativeIdentityChallenge.parse(v['challenge'], scope.clubId);
    identityRequire(
      challenge == null
          ? v['challengeSecret'] == null
          : identitySecret(v['challengeSecret']),
    );
    final pending = v['pending'] == null
        ? null
        : NativeIdentityPending.parse(v['pending']);
    if (pending?.operation == NativeIdentityOperation.refresh) {
      final old = NativeIdentityCredentials.parse(
        pending!.body['credentials'],
        scope.clubId,
      );
      identityRequire(
        credentials != null &&
            old.accessToken == credentials.accessToken &&
            old.refreshToken == credentials.refreshToken &&
            old.userId == credentials.userId,
      );
    }
    if (pending?.operation == NativeIdentityOperation.verification) {
      identityRequire(
        challenge != null &&
            pending!.body['challengeId'] == challenge.challengeId &&
            pending.body['clientSecret'] == v['challengeSecret'],
      );
    }
    if (pending?.operation == NativeIdentityOperation.revoke) {
      identityRequire(v['locallySignedOut'] == true && credentials == null);
    }
    return NativeIdentityJournal(
      scope: scope,
      revision: v['revision']! as int,
      locallySignedOut: v['locallySignedOut']! as bool,
      credentials: credentials,
      challenge: challenge,
      challengeSecret: v['challengeSecret'] as String?,
      pending: pending,
      revocation: NativeIdentityRevocation.values.firstWhere(
        (state) => state.name == v['revocation'],
      ),
    );
  }
  @override
  String toString() => 'NativeIdentityJournal([protected])';
}
