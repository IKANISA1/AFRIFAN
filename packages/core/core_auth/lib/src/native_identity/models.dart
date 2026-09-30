import 'dart:convert';

enum NativeIdentityOutcome { notSent, rejected, unknown }

/// Finite public failures. Never construct an error from a provider/body message.
enum NativeIdentityError {
  disabled,
  invalidConfiguration,
  invalidContract,
  invalidInput,
  storageUnavailable,
  storageConflict,
  storageReadbackFailed,
  transportUnavailable,
  responseDeadline,
  responseTooLarge,
  identityChanged,
  invalidationUnavailable,
  pendingOperation,
  recoveryExpired,
  reauthenticationRequired,
  locallySignedOut,
  invalidCode,
  challengeUnavailable,
  challengeConsumed,
  idempotencyConflict,
  unauthenticated,
  accountUnavailable,
  recentVerificationRequired,
  rateLimited,
  serviceUnavailable,
  requestRejected,
  revocationUnknown,
}

final class NativeIdentityFailure implements Exception {
  const NativeIdentityFailure(
    this.code, [
    this.outcome = NativeIdentityOutcome.notSent,
  ]);
  final NativeIdentityError code;
  final NativeIdentityOutcome outcome;
  @override
  String toString() => 'NativeIdentityFailure(${code.name}, ${outcome.name})';
}

void identityRequire(
  bool condition, [
  NativeIdentityError code = NativeIdentityError.invalidContract,
]) {
  if (!condition) throw NativeIdentityFailure(code);
}

bool identityMatches(String pattern, Object? value) =>
    value is String && RegExp(pattern).stringMatch(value) == value;

bool identityUuid(Object? value) => identityMatches(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  value,
);

bool identitySecret(Object? value) {
  if (!identityMatches(r'^[A-Za-z0-9_-]{43}$', value)) return false;
  try {
    final bytes = base64Url.decode('${value! as String}=');
    return bytes.length == 32 &&
        base64Url.encode(bytes).replaceAll('=', '') == value;
  } catch (_) {
    return false;
  }
}

bool identityToken(Object? value, String sessionId) {
  if (value is! String || value.length != 80) return false;
  final parts = value.split('.');
  return parts.length == 2 &&
      parts.first == sessionId &&
      identityUuid(parts.first) &&
      identitySecret(parts.last);
}

bool identityKey(Object? value) =>
    identityMatches(r'^[A-Za-z0-9_-]{16,128}$', value);
bool identityTime(Object? value) =>
    value is int && value >= 0 && value <= 253402300799999;

Map<String, Object?> identityObject(Object? value, List<String> keys) {
  identityRequire(value is Map<String, dynamic>);
  final map = value! as Map<String, dynamic>;
  identityRequire(map.length == keys.length && keys.every(map.containsKey));
  return Map<String, Object?>.from(map);
}

Object? identityDecode(String value) {
  try {
    identityRequire(
      value.length <= 16384 && utf8.encode(value).length <= 16384,
    );
    final decoded = jsonDecode(value);
    // jsonDecode validates syntax but collapses duplicate fields. Walk the
    // original, validated tokens to reject ambiguous keys, including escapes.
    _IdentityJsonKeys(value).validate();
    return decoded;
  } catch (_) {
    throw const NativeIdentityFailure(NativeIdentityError.invalidContract);
  }
}

final class _IdentityJsonKeys {
  _IdentityJsonKeys(this.text);
  final String text;
  var offset = 0;
  void _space() {
    while (offset < text.length &&
        [9, 10, 13, 32].contains(text.codeUnitAt(offset))) {
      offset++;
    }
  }

  void validate() {
    _value(0);
    _space();
    identityRequire(offset == text.length);
  }

  String _string() {
    final start = offset++;
    while (offset < text.length) {
      final unit = text.codeUnitAt(offset++);
      if (unit == 92) {
        offset++; // escaped quote/backslash cannot terminate the string
      } else if (unit == 34) {
        return jsonDecode(text.substring(start, offset)) as String;
      }
    }
    throw const NativeIdentityFailure(NativeIdentityError.invalidContract);
  }

  void _value(int depth) {
    identityRequire(depth <= 32);
    _space();
    identityRequire(offset < text.length);
    final first = text.codeUnitAt(offset);
    if (first == 123) {
      offset++;
      _space();
      final keys = <String>{};
      if (text.codeUnitAt(offset) == 125) {
        offset++;
        return;
      }
      while (true) {
        _space();
        identityRequire(text.codeUnitAt(offset) == 34);
        identityRequire(keys.add(_string()));
        _space();
        identityRequire(text.codeUnitAt(offset++) == 58);
        _value(depth + 1);
        _space();
        final delimiter = text.codeUnitAt(offset++);
        if (delimiter == 125) return;
        identityRequire(delimiter == 44);
      }
    }
    if (first == 91) {
      offset++;
      _space();
      if (text.codeUnitAt(offset) == 93) {
        offset++;
        return;
      }
      while (true) {
        _value(depth + 1);
        _space();
        final delimiter = text.codeUnitAt(offset++);
        if (delimiter == 93) return;
        identityRequire(delimiter == 44);
      }
    }
    if (first == 34) {
      _string();
      return;
    }
    // Syntax has already been validated by jsonDecode; consume one scalar.
    final start = offset;
    while (offset < text.length &&
        ![9, 10, 13, 32, 44, 93, 125].contains(text.codeUnitAt(offset))) {
      offset++;
    }
    identityRequire(offset > start);
  }
}

/// A reviewed native application, exact API origin and numeric server club.
/// No product hostname or numeric club is inferred from editable user data.
final class NativeIdentityScope {
  NativeIdentityScope({
    required this.applicationId,
    required Uri approvedOrigin,
    required this.clubId,
  }) : origin = approvedOrigin.replace(path: '', query: null, fragment: null) {
    identityRequire(
      identityMatches(
            r'^[A-Za-z][A-Za-z0-9_]*(?:[.][A-Za-z][A-Za-z0-9_]*)+$',
            applicationId,
          ) &&
          applicationId.length <= 128 &&
          approvedOrigin.scheme == 'https' &&
          approvedOrigin.userInfo.isEmpty &&
          !approvedOrigin.hasQuery &&
          !approvedOrigin.hasFragment &&
          ['', '/'].contains(approvedOrigin.path) &&
          (!approvedOrigin.hasPort || approvedOrigin.port == 443) &&
          identityMatches(
            r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:[.][a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+$',
            approvedOrigin.host,
          ) &&
          !RegExp(r'^[0-9.]+$').hasMatch(approvedOrigin.host) &&
          clubId > 0 &&
          clubId <= 9999999999,
      NativeIdentityError.invalidConfiguration,
    );
  }
  final String applicationId;
  final Uri origin;
  final int clubId;
  String get storeScope => '$applicationId|${origin.origin}|$clubId';
  Map<String, Object?> toJson() => {
    'applicationId': applicationId,
    'origin': origin.origin,
    'clubId': clubId,
  };
  void checkBinding(Object? value) {
    final v = identityObject(value, ['applicationId', 'origin', 'clubId']);
    identityRequire(
      v['applicationId'] == applicationId &&
          v['origin'] == origin.origin &&
          v['clubId'] is int &&
          v['clubId'] == clubId,
    );
  }
}

final class NativeIdentityChallenge {
  const NativeIdentityChallenge._(
    this.challengeId,
    this.clubId,
    this.expiresAt,
  );
  final String challengeId;
  final int clubId, expiresAt;
  factory NativeIdentityChallenge.parse(Object? value, int clubId) {
    final v = identityObject(value, [
      'schemaVersion',
      'challengeId',
      'clubId',
      'expiresAt',
      'delivery',
    ]);
    identityRequire(
      v['schemaVersion'] is int &&
          v['schemaVersion'] == 1 &&
          v['clubId'] is int &&
          v['clubId'] == clubId &&
          identityUuid(v['challengeId']) &&
          identityTime(v['expiresAt']) &&
          v['delivery'] is String &&
          v['delivery'] == 'queued_or_pending',
    );
    return NativeIdentityChallenge._(
      v['challengeId']! as String,
      clubId,
      v['expiresAt']! as int,
    );
  }
  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'challengeId': challengeId,
    'clubId': clubId,
    'expiresAt': expiresAt,
    'delivery': 'queued_or_pending',
  };
}

/// Protected storage only. This object intentionally never prints credentials.
final class NativeIdentityCredentials {
  const NativeIdentityCredentials._(
    this.sessionId,
    this.accessToken,
    this.refreshToken,
    this.userId,
    this.clubId,
    this.accessExpiresAt,
    this.refreshExpiresAt,
    this.authenticatedAt,
  );
  final String sessionId, accessToken, refreshToken, userId;
  final int clubId, accessExpiresAt, refreshExpiresAt, authenticatedAt;
  factory NativeIdentityCredentials.parse(Object? value, int clubId) {
    final v = identityObject(value, [
      'schemaVersion',
      'sessionId',
      'accessToken',
      'refreshToken',
      'userId',
      'clubId',
      'accessExpiresAt',
      'refreshExpiresAt',
      'authenticatedAt',
    ]);
    identityRequire(
      v['schemaVersion'] is int &&
          v['schemaVersion'] == 1 &&
          v['clubId'] is int &&
          v['clubId'] == clubId &&
          identityUuid(v['sessionId']) &&
          identityUuid(v['userId']) &&
          identityTime(v['accessExpiresAt']) &&
          identityTime(v['refreshExpiresAt']) &&
          identityTime(v['authenticatedAt']),
    );
    final session = v['sessionId']! as String;
    identityRequire(
      identityToken(v['accessToken'], session) &&
          identityToken(v['refreshToken'], session) &&
          v['accessToken'] != v['refreshToken'] &&
          (v['accessExpiresAt']! as int) > (v['authenticatedAt']! as int) &&
          (v['refreshExpiresAt']! as int) >= (v['accessExpiresAt']! as int),
    );
    return NativeIdentityCredentials._(
      session,
      v['accessToken']! as String,
      v['refreshToken']! as String,
      v['userId']! as String,
      clubId,
      v['accessExpiresAt']! as int,
      v['refreshExpiresAt']! as int,
      v['authenticatedAt']! as int,
    );
  }
  Map<String, Object?> toProtectedJson() => {
    'schemaVersion': 1,
    'sessionId': sessionId,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'userId': userId,
    'clubId': clubId,
    'accessExpiresAt': accessExpiresAt,
    'refreshExpiresAt': refreshExpiresAt,
    'authenticatedAt': authenticatedAt,
  };
  @override
  String toString() => 'NativeIdentityCredentials([protected])';
}

/// Verified supporter identity only: no paid entitlement and no operator role.
final class NativeSupporterIdentity {
  const NativeSupporterIdentity._(
    this.userId,
    this.clubId,
    this.sessionId,
    this.authenticatedAt,
  );
  final String userId, sessionId;
  final int clubId, authenticatedAt;
  factory NativeSupporterIdentity.parse(
    Object? value,
    NativeIdentityCredentials credentials,
  ) {
    final v = identityObject(value, [
      'schemaVersion',
      'userId',
      'clubId',
      'sessionId',
      'phoneVerified',
      'role',
      'authenticatedAt',
    ]);
    identityRequire(
      v['schemaVersion'] is int &&
          v['schemaVersion'] == 1 &&
          v['clubId'] is int &&
          v['clubId'] == credentials.clubId &&
          v['userId'] is String &&
          v['userId'] == credentials.userId &&
          v['sessionId'] is String &&
          v['sessionId'] == credentials.sessionId &&
          v['phoneVerified'] is bool &&
          v['phoneVerified'] == true &&
          v['role'] is String &&
          v['role'] == 'supporter' &&
          v['authenticatedAt'] is int &&
          v['authenticatedAt'] == credentials.authenticatedAt,
    );
    return NativeSupporterIdentity._(
      credentials.userId,
      credentials.clubId,
      credentials.sessionId,
      credentials.authenticatedAt,
    );
  }

  /// Explicit mapping for the membership gateway's separate four-field contract.
  Map<String, Object?> toMembershipSessionJson() => {
    'schemaVersion': 1,
    'userId': userId,
    'clubId': clubId,
    'sessionId': sessionId,
  };
}

enum NativeIdentityRevokeScope { current, others, all }

enum NativeIdentityRevocation { notAttempted, unknown, confirmed }

final class NativeIdentityRevocationResult {
  const NativeIdentityRevocationResult(this.serverRevocation);
  final NativeIdentityRevocation serverRevocation;
  bool get locallySignedOut => true;
}
