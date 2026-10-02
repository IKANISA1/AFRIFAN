import 'dart:async';
import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:gotrue/gotrue.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

Map<String, dynamic> session(String user, {bool verified = false}) => {
  'access_token': JWT({
    'sub': user,
    'role': 'authenticated',
    'session_id': '$user-session',
    'aal': verified ? 'aal2' : 'aal1',
    'amr': [
      {
        'method': verified ? 'mfa/totp' : 'otp',
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
    ],
  }).sign(SecretKey('local-test-only')),
  'token_type': 'bearer',
  'refresh_token': '$user-refresh',
  'expires_in': 3600,
  'user': {
    'id': user,
    'aud': 'authenticated',
    'app_metadata': {},
    'user_metadata': {},
    'created_at': '2026-10-01T00:00:00Z',
  },
};

void main() {
  late GoTrueClient client;
  late Completer<http.Response> verifyReply;
  late Completer<void> verifyStarted;
  late List<AuthChangeEvent> events;
  late StreamSubscription<AuthState> subscription;
  setUp(() {
    verifyReply = Completer();
    verifyStarted = Completer();
    events = [];
    client = GoTrueClient(
      url: 'https://auth.test',
      autoRefreshToken: false,
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/verify')) {
          verifyStarted.complete();
          return verifyReply.future;
        }
        if (request.url.path.endsWith('/token')) {
          final body = jsonDecode(request.body) as Map;
          return http.Response(
            jsonEncode(session(body['email'] == 'two@test' ? 'two' : 'one')),
            200,
          );
        }
        if (request.url.path.endsWith('/logout'))
          return http.Response('{}', 200);
        throw StateError('Unexpected actual SDK request ${request.url.path}');
      }),
    );
    subscription = client.onAuthStateChange.listen(
      (state) => events.add(state.event),
    );
  });
  tearDown(() async {
    await subscription.cancel();
    client.dispose();
  });
  Future<AuthMFAVerifyResponse> pendingVerify() async {
    return client.mfa.verify(
      factorId: 'factor',
      challengeId: 'challenge',
      code: '123456',
    );
  }

  Future<void> signIn(String user) => client
      .signInWithPassword(email: '$user@test', password: 'test-only')
      .then((_) {});
  final changed = throwsA(
    isA<AuthException>().having((e) => e.code, 'code', 'local_session_changed'),
  );

  test(
    'actual MFA response promotes only the initiating current session',
    () async {
      await signIn('one');
      final pending = pendingVerify();
      await verifyStarted.future;
      verifyReply.complete(
        http.Response(jsonEncode(session('one', verified: true)), 200),
      );
      await pending;
      await Future<void>.delayed(Duration.zero);
      expect(client.currentUser?.id, 'one');
      expect(
        client.mfa.getAuthenticatorAssuranceLevel().currentLevel,
        AuthenticatorAssuranceLevels.aal2,
      );
      expect(
        client.mfa
            .getAuthenticatorAssuranceLevel()
            .currentAuthenticationMethods
            .single
            .method,
        AMRMethod.mfaTotp,
      );
      expect(events, contains(AuthChangeEvent.mfaChallengeVerified));
    },
  );
  test(
    'delayed MFA after logout cannot restore a session or emit verified authority',
    () async {
      await signIn('one');
      final pending = pendingVerify();
      await verifyStarted.future;
      final assertion = expectLater(pending, changed);
      await client.signOut();
      verifyReply.complete(
        http.Response(jsonEncode(session('one', verified: true)), 200),
      );
      await assertion;
      expect(client.currentSession, isNull);
      expect(events, isNot(contains(AuthChangeEvent.mfaChallengeVerified)));
    },
  );
  test(
    'delayed MFA after account switch preserves replacement account',
    () async {
      await signIn('one');
      final pending = pendingVerify();
      await verifyStarted.future;
      final assertion = expectLater(pending, changed);
      await signIn('two');
      verifyReply.complete(
        http.Response(jsonEncode(session('one', verified: true)), 200),
      );
      await assertion;
      expect(client.currentUser?.id, 'two');
      expect(events, isNot(contains(AuthChangeEvent.mfaChallengeVerified)));
    },
  );
  test(
    'invalidated owned scope cannot save its delayed MFA response',
    () async {
      await signIn('one');
      final owner = client.createSessionMutationScope();
      final pending = owner.run(pendingVerify);
      await verifyStarted.future;
      final assertion = expectLater(pending, changed);
      owner.invalidate();
      verifyReply.complete(
        http.Response(jsonEncode(session('one', verified: true)), 200),
      );
      await assertion;
      expect(
        client.mfa.getAuthenticatorAssuranceLevel().currentLevel,
        AuthenticatorAssuranceLevels.aal1,
      );
      expect(events, isNot(contains(AuthChangeEvent.mfaChallengeVerified)));
    },
  );
  test(
    'verification requires an authenticated session before network',
    () async {
      await expectLater(
        pendingVerify(),
        throwsA(isA<AuthSessionMissingException>()),
      );
      expect(verifyStarted.isCompleted, isFalse);
    },
  );
  test('AMR mapping admits only the explicit TOTP names', () {
    expect(
      AMREntry.fromJson({'method': 'totp', 'timestamp': 1}).method,
      AMRMethod.totp,
    );
    expect(
      AMREntry.fromJson({'method': 'mfa/totp', 'timestamp': 1}).method,
      AMRMethod.mfaTotp,
    );
    expect(
      AMREntry.fromJson({'method': 'totp-ish', 'timestamp': 1}).method,
      AMRMethod.unknown,
    );
  });
}
