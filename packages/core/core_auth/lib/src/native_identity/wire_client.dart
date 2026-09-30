import 'dart:async';
import 'dart:convert';

import 'models.dart';
import 'ports.dart';

/// Native only. This API never automatically retries or refreshes credentials.
final class NativeIdentityWireClient {
  NativeIdentityWireClient({
    required this.scope,
    required this.transport,
    this.enabled = false,
    this.timeout = const Duration(seconds: 8),
    int Function()? nowMilliseconds,
  }) : nowMilliseconds = nowMilliseconds ?? _systemTime {
    identityRequire(
      timeout.inMilliseconds > 0 && timeout.inMilliseconds <= 30000,
      NativeIdentityError.invalidConfiguration,
    );
  }
  static int _systemTime() => DateTime.now().millisecondsSinceEpoch;
  final NativeIdentityScope scope;
  final NativeIdentityTransport transport;
  final bool enabled;
  final Duration timeout;
  final int Function() nowMilliseconds;

  Future<Object?> _request(
    String operation, {
    Map<String, Object?>? body,
    String? key,
    String? accessToken,
    required int expectedStatus,
  }) async {
    if (!enabled) {
      throw const NativeIdentityFailure(NativeIdentityError.disabled);
    }
    final mutation = body != null;
    final outcome = mutation
        ? NativeIdentityOutcome.unknown
        : NativeIdentityOutcome.notSent;
    final headers = <String, String>{
      'x-africlub-client': 'native-v1',
      'accept': 'application/json',
      if (mutation) 'content-type': 'application/json',
      if (key != null) 'idempotency-key': key,
      if (accessToken != null) 'authorization': 'Bearer $accessToken',
    };
    final encoded = body == null ? null : jsonEncode(body);
    identityRequire(
      encoded == null || utf8.encode(encoded).length <= 4096,
      NativeIdentityError.invalidInput,
    );
    final request = NativeIdentityRequest(
      scope.origin.resolve('/v1/auth/clubs/${scope.clubId}/$operation'),
      mutation ? 'POST' : 'GET',
      headers,
      encoded,
    );
    NativeIdentityResponse response;
    try {
      response = await transport.send(request, timeout).timeout(timeout);
    } on TimeoutException {
      throw NativeIdentityFailure(
        NativeIdentityError.responseDeadline,
        outcome,
      );
    } catch (_) {
      throw NativeIdentityFailure(
        NativeIdentityError.transportUnavailable,
        outcome,
      );
    }
    try {
      identityRequire(
        response.body.length <= 16384 &&
            utf8.encode(response.body).length <= 16384,
        NativeIdentityError.responseTooLarge,
      );
      identityRequire(
        response.headers['content-type']?.split(';').first.trim() ==
                'application/json' &&
            response.headers['cache-control']
                    ?.split(',')
                    .map((s) => s.trim())
                    .contains('no-store') ==
                true &&
            !response.headers.containsKey('set-cookie') &&
            (!response.headers.containsKey('content-encoding') ||
                response.headers['content-encoding'] == 'identity'),
      );
      final value = identityDecode(response.body);
      if (response.status != expectedStatus) {
        final error = identityObject(value, ['schemaVersion', 'error']);
        identityRequire(
          error['schemaVersion'] is int &&
              error['schemaVersion'] == 1 &&
              error['error'] is String,
        );
        final code =
            _publicErrors[error['error']] ??
            NativeIdentityError.requestRejected;
        final rejected =
            response.status >= 400 &&
            response.status < 500 &&
            response.status != 408;
        throw NativeIdentityFailure(
          code,
          rejected ? NativeIdentityOutcome.rejected : outcome,
        );
      }
      return value;
    } on NativeIdentityFailure catch (error) {
      if (error.outcome == NativeIdentityOutcome.rejected) rethrow;
      throw NativeIdentityFailure(error.code, outcome);
    } catch (_) {
      throw NativeIdentityFailure(NativeIdentityError.invalidContract, outcome);
    }
  }

  static const _publicErrors = {
    'invalid_code': NativeIdentityError.invalidCode,
    'challenge_unavailable': NativeIdentityError.challengeUnavailable,
    'challenge_consumed': NativeIdentityError.challengeConsumed,
    'idempotency_conflict': NativeIdentityError.idempotencyConflict,
    'unauthenticated': NativeIdentityError.unauthenticated,
    'account_unavailable': NativeIdentityError.accountUnavailable,
    'recent_verification_required':
        NativeIdentityError.recentVerificationRequired,
    'reauthentication_required': NativeIdentityError.reauthenticationRequired,
    'rate_limited': NativeIdentityError.rateLimited,
    'service_unavailable': NativeIdentityError.serviceUnavailable,
  };

  Future<T> _parse<T>(
    Future<Object?> input,
    T Function(Object?) parse, {
    bool mutation = true,
  }) async {
    final value = await input;
    try {
      return parse(value);
    } catch (_) {
      throw NativeIdentityFailure(
        NativeIdentityError.invalidContract,
        mutation
            ? NativeIdentityOutcome.unknown
            : NativeIdentityOutcome.notSent,
      );
    }
  }

  Future<NativeIdentityChallenge> challenge(
    String phone,
    String clientSecret,
    String requestKey,
  ) {
    identityRequire(
      identityMatches(r'^\+[1-9]\d{7,14}$', phone) &&
          identitySecret(clientSecret) &&
          identityKey(requestKey),
      NativeIdentityError.invalidInput,
    );
    return _parse(
      _request(
        'otp/challenges',
        body: {'phone': phone, 'clientSecret': clientSecret},
        key: requestKey,
        expectedStatus: 202,
      ),
      (value) {
        final challenge = NativeIdentityChallenge.parse(value, scope.clubId);
        identityRequire(challenge.expiresAt > nowMilliseconds());
        return challenge;
      },
    );
  }

  Future<NativeIdentityCredentials> verify(
    String challengeId,
    String code,
    String clientSecret,
    String requestKey,
  ) {
    identityRequire(
      identityUuid(challengeId) &&
          identityMatches(r'^\d{6}$', code) &&
          identitySecret(clientSecret) &&
          identityKey(requestKey),
      NativeIdentityError.invalidInput,
    );
    return _parse(
      _request(
        'otp/verifications',
        body: {
          'challengeId': challengeId,
          'code': code,
          'clientSecret': clientSecret,
        },
        key: requestKey,
        expectedStatus: 200,
      ),
      _currentCredentials,
    );
  }

  NativeIdentityCredentials _currentCredentials(Object? value) {
    final credentials = NativeIdentityCredentials.parse(value, scope.clubId);
    identityRequire(
      credentials.accessExpiresAt > nowMilliseconds() &&
          credentials.refreshExpiresAt > nowMilliseconds() &&
          credentials.authenticatedAt <= nowMilliseconds() + 5000,
    );
    return credentials;
  }

  Future<NativeIdentityCredentials> refresh(
    NativeIdentityCredentials previous,
    String requestKey,
  ) {
    identityRequire(
      previous.clubId == scope.clubId && identityKey(requestKey),
      NativeIdentityError.invalidInput,
    );
    return _parse(
      _request(
        'sessions/refresh',
        body: {'refreshToken': previous.refreshToken},
        key: requestKey,
        expectedStatus: 200,
      ),
      (value) {
        final next = _currentCredentials(value);
        identityRequire(
          next.sessionId == previous.sessionId &&
              next.userId == previous.userId &&
              next.authenticatedAt == previous.authenticatedAt &&
              next.accessToken != previous.accessToken &&
              next.refreshToken != previous.refreshToken,
        );
        return next;
      },
    );
  }

  Future<NativeSupporterIdentity> session(
    NativeIdentityCredentials credentials,
  ) {
    identityRequire(
      credentials.clubId == scope.clubId,
      NativeIdentityError.invalidInput,
    );
    identityRequire(
      credentials.accessExpiresAt > nowMilliseconds() &&
          credentials.authenticatedAt <= nowMilliseconds() + 5000,
      NativeIdentityError.reauthenticationRequired,
    );
    return _parse(
      _request(
        'session',
        accessToken: credentials.accessToken,
        expectedStatus: 200,
      ),
      (value) => NativeSupporterIdentity.parse(value, credentials),
      mutation: false,
    );
  }

  Future<void> revoke(String token, NativeIdentityRevokeScope scope) {
    final parts = token.split('.');
    identityRequire(
      parts.length == 2 && identityToken(token, parts.first),
      NativeIdentityError.invalidInput,
    );
    return _parse(
      _request(
        'sessions/revoke',
        body: {'scope': scope.name},
        accessToken: token,
        expectedStatus: 200,
      ),
      (value) {
        final v = identityObject(value, ['schemaVersion', 'scope', 'revoked']);
        identityRequire(
          v['schemaVersion'] is int &&
              v['schemaVersion'] == 1 &&
              v['scope'] is String &&
              v['scope'] == scope.name &&
              v['revoked'] is bool &&
              v['revoked'] == true,
        );
      },
    );
  }
}
