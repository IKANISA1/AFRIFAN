import 'dart:async';
import 'dart:convert';

import 'package:core_auth/native_identity.dart';

const fixtureNow = 1780000000000;
const fixtureUser = '11111111-1111-4111-8111-111111111111';
const fixtureSession = '22222222-2222-4222-8222-222222222222';
const fixtureChallenge = '33333333-3333-4333-8333-333333333333';
const fixturePhone = '+10000000001';

String syntheticSecret(int byte) =>
    base64Url.encode(List.filled(32, byte)).replaceAll('=', '');
Map<String, Object?> credentialFixture({
  int generation = 0,
  int? authenticatedAt,
  int clubId = 24,
}) => {
  'schemaVersion': 1,
  'sessionId': fixtureSession,
  'accessToken': '$fixtureSession.${syntheticSecret(10 + generation * 2)}',
  'refreshToken': '$fixtureSession.${syntheticSecret(11 + generation * 2)}',
  'userId': fixtureUser,
  'clubId': clubId,
  'accessExpiresAt': fixtureNow + 300000,
  'refreshExpiresAt': fixtureNow + 86400000,
  'authenticatedAt': authenticatedAt ?? fixtureNow,
};
Map<String, Object?> sessionFixture({int? authenticatedAt, int clubId = 24}) =>
    {
      'schemaVersion': 1,
      'userId': fixtureUser,
      'clubId': clubId,
      'sessionId': fixtureSession,
      'phoneVerified': true,
      'role': 'supporter',
      'authenticatedAt': authenticatedAt ?? fixtureNow,
    };
Map<String, Object?> challengeFixture({int clubId = 24}) => {
  'schemaVersion': 1,
  'challengeId': fixtureChallenge,
  'clubId': clubId,
  'expiresAt': fixtureNow + 600000,
  'delivery': 'queued_or_pending',
};
NativeIdentityResponse jsonResponse(
  Object? value, {
  int status = 200,
  Map<String, String>? headers,
}) => NativeIdentityResponse(
  status,
  headers ??
      {
        'content-type': 'application/json; charset=utf-8',
        'cache-control': 'no-store',
      },
  jsonEncode(value),
);
NativeIdentityScope fixtureScope({
  int clubId = 24,
  String app = 'com.africlub.rayon',
  String origin = 'https://identity.test.invalid',
}) => NativeIdentityScope(
  applicationId: app,
  approvedOrigin: Uri.parse(origin),
  clubId: clubId,
);

final class TestEntropy implements NativeIdentityEntropy {
  var keys = 0;
  @override
  String requestKey() => 'test_operation_key_${++keys}'.padRight(32, 'x');
  @override
  String clientSecret() => syntheticSecret(4);
}

final class TestTransport implements NativeIdentityTransport {
  int clubId = 24;
  final requests = <NativeIdentityRequest>[];
  FutureOr<NativeIdentityResponse> Function(NativeIdentityRequest request)?
  handler;
  int generation = 0;
  @override
  Future<NativeIdentityResponse> send(
    NativeIdentityRequest request,
    Duration timeout,
  ) async {
    requests.add(request);
    if (handler != null) return handler!(request);
    if (request.uri.path.endsWith('/otp/challenges')) {
      return jsonResponse(challengeFixture(clubId: clubId), status: 202);
    }
    if (request.uri.path.endsWith('/otp/verifications')) {
      return jsonResponse(credentialFixture(clubId: clubId));
    }
    if (request.uri.path.endsWith('/sessions/refresh')) {
      return jsonResponse(
        credentialFixture(generation: ++generation, clubId: clubId),
      );
    }
    if (request.uri.path.endsWith('/sessions/revoke')) {
      final body = jsonDecode(request.body!) as Map<String, dynamic>;
      return jsonResponse({
        'schemaVersion': 1,
        'scope': body['scope'],
        'revoked': true,
      });
    }
    return jsonResponse(sessionFixture(clubId: clubId));
  }
}

/// TEST ONLY: memory is not OS protection and this process mutex is not a
/// production cross-process lock. Capabilities simulate an accepted port.
final class TestCredentialStore implements NativeCredentialStore {
  String? raw;
  bool available = true;
  int reads = 0, writes = 0, active = 0, maximumActive = 0;
  int? failRead,
      failWrite,
      falseWrite,
      loseWriteAcknowledgement,
      corruptReadback;
  Future<void> Function(int index)? afterRead, afterWrite;
  Future<void> _tail = Future.value();
  @override
  NativeCredentialStoreCapabilities get capabilities => available
      ? const NativeCredentialStoreCapabilities(
          osProtected: true,
          atomicDurableCompareAndSet: true,
          processSafeExclusive: true,
          applicationOriginClubBinding: true,
          boundedOperations: true,
        )
      : const NativeCredentialStoreCapabilities.unavailable();
  @override
  Future<T> runExclusive<T>(
    NativeIdentityScope scope,
    Duration acquisitionTimeout,
    Future<T> Function(NativeCredentialTransaction transaction) work,
  ) async {
    final previous = _tail;
    final release = Completer<void>();
    _tail = previous.then((_) => release.future);
    var acquired = false;
    try {
      await previous.timeout(acquisitionTimeout);
      acquired = true;
      active++;
      if (active > maximumActive) maximumActive = active;
      return await work(_TestTransaction(this));
    } finally {
      if (acquired) active--;
      release.complete();
    }
  }

  NativeIdentityJournal journal([NativeIdentityScope? scope]) =>
      NativeIdentityJournal.decodeProtected(raw!, scope ?? fixtureScope());
  void seedCredentials({int? authenticatedAt}) {
    raw = NativeIdentityJournal(
      scope: fixtureScope(),
      locallySignedOut: false,
      credentials: NativeIdentityCredentials.parse(
        credentialFixture(authenticatedAt: authenticatedAt),
        24,
      ),
    ).encodeProtected();
  }
}

final class _TestTransaction implements NativeCredentialTransaction {
  const _TestTransaction(this.owner);
  final TestCredentialStore owner;
  @override
  Future<String?> read() async {
    final index = ++owner.reads;
    if (owner.failRead == index) {
      throw StateError('private fixture read failure');
    }
    final found = owner.corruptReadback == index ? null : owner.raw;
    await owner.afterRead?.call(index);
    return found;
  }

  @override
  Future<bool> compareAndSet(String? expected, String replacement) async {
    final index = ++owner.writes;
    if (owner.failWrite == index) {
      throw StateError('private fixture write failure');
    }
    if (owner.falseWrite == index || owner.raw != expected) return false;
    owner.raw = replacement;
    await owner.afterWrite?.call(index);
    if (owner.loseWriteAcknowledgement == index) {
      throw StateError('private fixture lost ack');
    }
    return true;
  }
}

final class IdentityFixture {
  IdentityFixture({
    this.timeout = const Duration(milliseconds: 100),
    this.enabled = true,
    this.invalidated,
    NativeIdentityScope? scope,
  }) {
    transport.clubId = scope?.clubId ?? 24;
    client = NativeIdentityWireClient(
      scope: scope ?? fixtureScope(),
      transport: transport,
      enabled: enabled,
      timeout: timeout,
      nowMilliseconds: () => now,
    );
    controller = newController();
  }
  final Duration timeout;
  final bool enabled;
  final void Function()? invalidated;
  int now = fixtureNow;
  final transport = TestTransport();
  final store = TestCredentialStore();
  final entropy = TestEntropy();
  late final NativeIdentityWireClient client;
  late final NativeIdentityController controller;
  NativeIdentityController newController() => NativeIdentityController(
    client: client,
    store: store,
    entropy: entropy,
    enabled: enabled,
    onIdentityInvalidated: invalidated,
  );
  Future<void> login() async {
    await controller.issueChallenge(fixturePhone);
    await controller.verifyCode('123456');
  }
}
