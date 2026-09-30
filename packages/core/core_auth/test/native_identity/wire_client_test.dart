import 'dart:async';
import 'dart:convert';

import 'package:core_auth/native_identity.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Matcher failure(NativeIdentityError code, [NativeIdentityOutcome? outcome]) =>
    isA<NativeIdentityFailure>()
        .having((e) => e.code, 'sanitized code', code)
        .having(
          (e) => outcome == null || e.outcome == outcome,
          'expected outcome',
          true,
        );

void main() {
  for (final stale in ['expiredAccess', 'futureProof']) {
    test(
      'session $stale cannot bypass local clock bounds or cause automatic refresh',
      () async {
        final f = IdentityFixture();
        final body = credentialFixture();
        if (stale == 'expiredAccess') {
          body['accessExpiresAt'] = fixtureNow - 1;
          body['authenticatedAt'] = fixtureNow - 100000;
        } else {
          body['authenticatedAt'] = fixtureNow + 6000;
        }
        final credentials = NativeIdentityCredentials.parse(body, 24);
        await expectLater(
          () => f.client.session(credentials),
          throwsA(failure(NativeIdentityError.reauthenticationRequired)),
        );
        expect(f.transport.requests.length, 0);
      },
    );
  }
  for (final duplicate in ['literal', 'escaped']) {
    test(
      'ambiguous duplicated $duplicate identity field is rejected before publication',
      () async {
        final f = IdentityFixture();
        final body = jsonEncode(sessionFixture());
        final key = duplicate == 'literal' ? 'role' : r'\u0072ole';
        final ambiguous =
            '${body.substring(0, body.length - 1)},"$key":"supporter"}';
        f.transport.handler = (_) => NativeIdentityResponse(200, {
          'content-type': 'application/json',
          'cache-control': 'no-store',
        }, ambiguous);
        await expectLater(
          f.client.session(
            NativeIdentityCredentials.parse(credentialFixture(), 24),
          ),
          throwsA(failure(NativeIdentityError.invalidContract)),
        );
      },
    );
  }
  test(
    'duplicated protected journal binding key cannot use last-wins JSON parsing',
    () {
      final scope = fixtureScope();
      final journal = NativeIdentityJournal(scope: scope).encodeProtected();
      final ambiguous = journal.replaceFirst(
        '"clubId":24',
        '"clubId":25,"clubId":24',
      );
      expect(
        () => NativeIdentityJournal.decodeProtected(ambiguous, scope),
        throwsA(failure(NativeIdentityError.invalidContract)),
      );
    },
  );
  test(
    'actual Android and iOS application identifiers retain exact platform case',
    () {
      for (final app in [
        'rw.gikundiro.app',
        'rw.ikanisa.rayonSports',
        'cd.ikanisa.asVita',
        'rw.ikanisa.rayonSports.qa.codex',
        'cd.ikanisa.asVita.qa.codex',
      ]) {
        final scope = fixtureScope(app: app);
        expect(scope.applicationId == app, true);
        expect(scope.storeScope.startsWith('$app|'), true);
      }
      final scope = fixtureScope(app: 'rw.ikanisa.rayonSports');
      expect(
        () => scope.checkBinding({
          'applicationId': 'rw.ikanisa.rayonsports',
          'origin': scope.origin.origin,
          'clubId': scope.clubId,
        }),
        throwsA(failure(NativeIdentityError.invalidContract)),
      );
    },
  );
  test('disabled wire defaults cannot submit a network request', () async {
    final transport = TestTransport();
    final client = NativeIdentityWireClient(
      scope: fixtureScope(),
      transport: transport,
    );
    await expectLater(
      client.challenge(
        fixturePhone,
        syntheticSecret(1),
        'original_operation_key',
      ),
      throwsA(failure(NativeIdentityError.disabled)),
    );
    expect(transport.requests.length, 0);
  });

  for (final origin in [
    'http://identity.test.invalid',
    'https://user@identity.test.invalid',
    'https://identity.test.invalid/path',
    'https://identity.test.invalid?x=1',
    'https://identity.test.invalid#x',
    'https://127.0.0.1',
    'https://identity.test.invalid:8443',
  ]) {
    test(
      'unapproved origin shape ${Uri.parse(origin).scheme} is rejected without IO',
      () {
        expect(
          () => fixtureScope(origin: origin),
          throwsA(failure(NativeIdentityError.invalidConfiguration)),
        );
      },
    );
  }
  for (final club in [0, -1, 10000000000]) {
    test('numeric club boundary $club is rejected', () {
      expect(
        () => fixtureScope(clubId: club),
        throwsA(failure(NativeIdentityError.invalidConfiguration)),
      );
    });
  }
  test(
    'native request has exact route, mandatory marker and no browser credentials',
    () async {
      final f = IdentityFixture();
      await f.client.challenge(
        fixturePhone,
        syntheticSecret(1),
        'original_operation_key',
      );
      final request = f.transport.requests.single;
      expect(request.uri.origin, f.client.scope.origin.origin);
      expect(request.uri.path, '/v1/auth/clubs/24/otp/challenges');
      expect(request.method, 'POST');
      expect(request.headers.keys.toSet(), {
        'x-africlub-client',
        'accept',
        'content-type',
        'idempotency-key',
      });
      expect(request.headers['x-africlub-client'], 'native-v1');
      expect((jsonDecode(request.body!) as Map<String, dynamic>).keys.toSet(), {
        'phone',
        'clientSecret',
      });
      expect(request.toString().contains(fixturePhone), false);
    },
  );
  test('canonical 32 byte secret rejects noncanonical final base64 bits', () {
    final valid = syntheticSecret(0);
    expect(identitySecret(valid), true);
    expect(identitySecret('${valid.substring(0, 42)}B'), false);
    expect(identitySecret('$valid\n'), false);
    expect(identitySecret(List.filled(43, '-').join()), false);
  });
  test('tokens use exact UUID version and canonical secret prefix binding', () {
    final raw = credentialFixture();
    final token = raw['accessToken']! as String;
    expect(identityToken(token, fixtureSession), true);
    expect(identityToken(token, fixtureUser), false);
    expect(identityToken('$token\n', fixtureSession), false);
    expect(identityUuid('22222222-2222-7222-8222-222222222222'), false);
  });

  final invalidBundles = <String, void Function(Map<String, Object?>)>{
    'extra field': (v) => v['role'] = 'admin',
    'schema number type': (v) => v['schemaVersion'] = 1.0,
    'club number type': (v) => v['clubId'] = 24.0,
    'wrong club': (v) => v['clubId'] = 25,
    'session array': (v) => v['sessionId'] = [fixtureSession],
    'wrong access prefix': (v) =>
        v['accessToken'] = '$fixtureUser.${syntheticSecret(10)}',
    'wrong refresh prefix': (v) =>
        v['refreshToken'] = '$fixtureUser.${syntheticSecret(11)}',
    'equal tokens': (v) => v['refreshToken'] = v['accessToken'],
    'timestamp floating type': (v) =>
        v['authenticatedAt'] = fixtureNow.toDouble(),
    'already expired access': (v) => v['accessExpiresAt'] = fixtureNow,
    'future authentication': (v) => v['authenticatedAt'] = fixtureNow + 10000,
    'refresh before access': (v) => v['refreshExpiresAt'] = fixtureNow + 1,
  };
  for (final entry in invalidBundles.entries) {
    test(
      'verification rejects ${entry.key} and retains unknown wire outcome',
      () async {
        final f = IdentityFixture();
        final body = credentialFixture();
        entry.value(body);
        f.transport.handler = (_) => jsonResponse(body);
        await expectLater(
          f.client.verify(
            fixtureChallenge,
            '123456',
            syntheticSecret(1),
            'original_operation_key',
          ),
          throwsA(
            failure(
              NativeIdentityError.invalidContract,
              NativeIdentityOutcome.unknown,
            ),
          ),
        );
        expect(f.transport.requests.length, 1);
      },
    );
  }

  final invalidSessions = <String, void Function(Map<String, Object?>)>{
    'extra entitlement': (v) => v['membershipActivated'] = true,
    'wrong user': (v) => v['userId'] = fixtureChallenge,
    'wrong session': (v) => v['sessionId'] = fixtureChallenge,
    'wrong club': (v) => v['clubId'] = 25,
    'club type': (v) => v['clubId'] = 24.0,
    'schema type': (v) => v['schemaVersion'] = true,
    'role array': (v) => v['role'] = ['supporter'],
    'role escalation': (v) => v['role'] = 'admin',
    'unverified phone': (v) => v['phoneVerified'] = false,
    'verification type': (v) => v['phoneVerified'] = 'true',
    'different proof time': (v) => v['authenticatedAt'] = fixtureNow - 1,
  };
  for (final entry in invalidSessions.entries) {
    test('session checks all seven exact fields: ${entry.key}', () async {
      final f = IdentityFixture();
      final body = sessionFixture();
      entry.value(body);
      f.transport.handler = (_) => jsonResponse(body);
      await expectLater(
        f.client.session(
          NativeIdentityCredentials.parse(credentialFixture(), 24),
        ),
        throwsA(
          failure(
            NativeIdentityError.invalidContract,
            NativeIdentityOutcome.notSent,
          ),
        ),
      );
    });
  }
  test(
    'authenticated supporter maps explicitly into separate four field membership contract',
    () async {
      final f = IdentityFixture();
      final credentials = NativeIdentityCredentials.parse(
        credentialFixture(),
        24,
      );
      final identity = await f.client.session(credentials);
      expect(identity.toMembershipSessionJson().keys.toSet(), {
        'schemaVersion',
        'userId',
        'clubId',
        'sessionId',
      });
      expect(identity.toMembershipSessionJson()['clubId'], 24);
      expect(credentials.toString().contains(credentials.accessToken), false);
    },
  );
  for (final defect in ['session', 'user', 'proof', 'access', 'refresh']) {
    test(
      'rotation rejects altered $defect authority or unchanged credentials',
      () async {
        final f = IdentityFixture();
        final next = credentialFixture(generation: 1);
        final previous = NativeIdentityCredentials.parse(
          credentialFixture(),
          24,
        );
        switch (defect) {
          case 'session':
            next['sessionId'] = fixtureChallenge;
            next['accessToken'] = '$fixtureChallenge.${syntheticSecret(12)}';
            next['refreshToken'] = '$fixtureChallenge.${syntheticSecret(13)}';
          case 'user':
            next['userId'] = fixtureChallenge;
          case 'proof':
            next['authenticatedAt'] = fixtureNow - 1;
          case 'access':
            next['accessToken'] = previous.accessToken;
          case 'refresh':
            next['refreshToken'] = previous.refreshToken;
        }
        f.transport.handler = (_) => jsonResponse(next);
        await expectLater(
          f.client.refresh(previous, 'original_rotation_key'),
          throwsA(
            failure(
              NativeIdentityError.invalidContract,
              NativeIdentityOutcome.unknown,
            ),
          ),
        );
      },
    );
  }
  test(
    'a transport ignoring cancellation still has a finite deadline and one submission',
    () async {
      final f = IdentityFixture(timeout: const Duration(milliseconds: 20));
      final never = Completer<NativeIdentityResponse>();
      f.transport.handler = (_) => never.future;
      final watch = Stopwatch()..start();
      await expectLater(
        f.client.challenge(
          fixturePhone,
          syntheticSecret(1),
          'original_operation_key',
        ),
        throwsA(
          failure(
            NativeIdentityError.responseDeadline,
            NativeIdentityOutcome.unknown,
          ),
        ),
      );
      expect(watch.elapsedMilliseconds < 500, true);
      expect(f.transport.requests.length, 1);
      never.complete(jsonResponse(challengeFixture(), status: 202));
      await Future<void>.delayed(Duration.zero);
      expect(f.transport.requests.length, 1);
    },
  );
  for (final status in [200, 201, 301, 307]) {
    test(
      'challenge requires HTTP 202, rejects mismatched status $status',
      () async {
        final f = IdentityFixture();
        f.transport.handler = (_) =>
            jsonResponse(challengeFixture(), status: status);
        await expectLater(
          f.client.challenge(
            fixturePhone,
            syntheticSecret(1),
            'original_operation_key',
          ),
          throwsA(
            failure(
              NativeIdentityError.invalidContract,
              NativeIdentityOutcome.unknown,
            ),
          ),
        );
        expect(f.transport.requests.length, 1);
      },
    );
  }
  test('oversized response is bounded and never exposes raw body', () async {
    final f = IdentityFixture();
    f.transport.handler = (_) => NativeIdentityResponse(202, {
      'content-type': 'application/json',
      'cache-control': 'no-store',
    }, List.filled(16385, 'x').join());
    await expectLater(
      f.client.challenge(
        fixturePhone,
        syntheticSecret(1),
        'original_operation_key',
      ),
      throwsA(
        failure(
          NativeIdentityError.responseTooLarge,
          NativeIdentityOutcome.unknown,
        ),
      ),
    );
  });
  for (final defect in ['cache', 'cookie', 'encoding', 'contentType']) {
    test('rejects invalid transport response $defect', () async {
      final f = IdentityFixture();
      final headers = {
        'content-type': 'application/json',
        'cache-control': 'no-store',
      };
      switch (defect) {
        case 'cache':
          headers['cache-control'] = 'public';
        case 'cookie':
          headers['set-cookie'] = 'private';
        case 'encoding':
          headers['content-encoding'] = 'gzip';
        case 'contentType':
          headers['content-type'] = 'text/plain';
      }
      f.transport.handler = (_) =>
          jsonResponse(challengeFixture(), status: 202, headers: headers);
      await expectLater(
        f.client.challenge(
          fixturePhone,
          syntheticSecret(1),
          'original_operation_key',
        ),
        throwsA(
          failure(
            NativeIdentityError.invalidContract,
            NativeIdentityOutcome.unknown,
          ),
        ),
      );
    });
  }
  test('unknown server error is mapped to a finite sanitized code', () async {
    final f = IdentityFixture();
    f.transport.handler = (_) => jsonResponse({
      'schemaVersion': 1,
      'error': 'sensitive provider fixture',
    }, status: 400);
    await expectLater(
      f.client.challenge(
        fixturePhone,
        syntheticSecret(1),
        'original_operation_key',
      ),
      throwsA(
        failure(
          NativeIdentityError.requestRejected,
          NativeIdentityOutcome.rejected,
        ),
      ),
    );
  });
  test('server failure after a possible write remains unknown', () async {
    final f = IdentityFixture();
    f.transport.handler = (_) => jsonResponse({
      'schemaVersion': 1,
      'error': 'service_unavailable',
    }, status: 503);
    await expectLater(
      f.client.challenge(
        fixturePhone,
        syntheticSecret(1),
        'original_operation_key',
      ),
      throwsA(
        failure(
          NativeIdentityError.serviceUnavailable,
          NativeIdentityOutcome.unknown,
        ),
      ),
    );
  });
  test(
    'IO port refuses browser credential headers before a network call',
    () async {
      const transport = IoNativeIdentityTransport();
      for (final header in ['cookie', 'origin', 'sec-fetch-site']) {
        await expectLater(
          transport.send(
            NativeIdentityRequest(
              Uri.parse(
                'https://identity.test.invalid/v1/auth/clubs/24/session',
              ),
              'GET',
              {'x-africlub-client': 'native-v1', header: 'fixture'},
              null,
            ),
            const Duration(milliseconds: 10),
          ),
          throwsA(failure(NativeIdentityError.invalidInput)),
        );
      }
    },
  );
}
