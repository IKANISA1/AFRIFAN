import 'dart:async';
import 'dart:convert';

import 'package:core_auth/native_identity.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';
import 'wire_client_test.dart' show failure;

void main() {
  test(
    'whole-operation timeout after POST retains unknown and prevents late publish',
    () async {
      final f = IdentityFixture(timeout: const Duration(seconds: 1));
      f.store.seedCredentials();
      final reply = Completer<NativeIdentityResponse>();
      f.transport.handler = (_) => reply.future;
      final controller = NativeIdentityController(
        client: f.client,
        store: f.store,
        entropy: f.entropy,
        enabled: true,
        operationTimeout: const Duration(milliseconds: 15),
      );
      await expectLater(
        controller.rotateCredentials(),
        throwsA(
          failure(
            NativeIdentityError.storageUnavailable,
            NativeIdentityOutcome.unknown,
          ),
        ),
      );
      expect(f.transport.requests.length, 1);
      expect(f.store.journal().pending != null, true);
      reply.complete(jsonResponse(credentialFixture(generation: 1)));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(controller.identity, null);
      expect(f.store.journal().pending != null, true);
      expect(f.transport.requests.length, 1);
    },
  );
  test(
    'a faulty store invoking work after acquisition timeout cannot send',
    () async {
      final f = IdentityFixture();
      final store = _DelayedExclusiveStore(f.store);
      final controller = NativeIdentityController(
        client: f.client,
        store: store,
        entropy: f.entropy,
        enabled: true,
        operationTimeout: const Duration(milliseconds: 10),
      );
      await expectLater(
        controller.issueChallenge(fixturePhone),
        throwsA(failure(NativeIdentityError.storageUnavailable)),
      );
      store.release.complete();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(f.transport.requests.length, 0);
      expect(f.store.writes, 0);
    },
  );
  test(
    'default controller is disabled and protected store is unavailable',
    () async {
      final f = IdentityFixture();
      final disabled = NativeIdentityController(client: f.client);
      await expectLater(
        () => disabled.issueChallenge(fixturePhone),
        throwsA(failure(NativeIdentityError.disabled)),
      );
      expect(await disabled.readAccessCredential(), null);
      final unavailable = NativeIdentityController(
        client: f.client,
        enabled: true,
      );
      await expectLater(
        unavailable.issueChallenge(fixturePhone),
        throwsA(failure(NativeIdentityError.storageUnavailable)),
      );
      expect(f.transport.requests.length, 0);
    },
  );
  for (final defect in ['read', 'write', 'cas', 'readback', 'capabilities']) {
    test(
      'no challenge request is sent when protected store $defect fails',
      () async {
        final f = IdentityFixture();
        switch (defect) {
          case 'read':
            f.store.failRead = 1;
          case 'write':
            f.store.failWrite = 1;
          case 'cas':
            f.store.falseWrite = 1;
          case 'readback':
            f.store.corruptReadback = 2;
          case 'capabilities':
            f.store.available = false;
        }
        await expectLater(
          f.controller.issueChallenge(fixturePhone),
          throwsA(isA<NativeIdentityFailure>()),
        );
        expect(f.transport.requests.length, 0);
      },
    );
  }
  test(
    'challenge original secret and issuance key are durable before any request',
    () async {
      final f = IdentityFixture();
      f.transport.handler = (request) {
        final pending = f.store.journal().pending!;
        expect(pending.operation, NativeIdentityOperation.challenge);
        expect(pending.firstSentAt, fixtureNow);
        expect(pending.requestKey == request.headers['idempotency-key'], true);
        expect(jsonEncode(pending.body) == request.body, true);
        expect(f.store.reads >= 3, true);
        return jsonResponse(challengeFixture(), status: 202);
      };
      await f.controller.issueChallenge(fixturePhone);
      expect(f.store.journal().pending, null);
      expect(f.store.journal().challenge != null, true);
      expect(f.store.journal().challengeSecret == syntheticSecret(4), true);
    },
  );
  for (final lostWrite in [1, 2]) {
    test(
      'lost challenge journal acknowledgement $lostWrite rereads and resumes original key',
      () async {
        final f = IdentityFixture();
        f.store.loseWriteAcknowledgement = lostWrite;
        await expectLater(
          f.controller.issueChallenge(fixturePhone),
          throwsA(isA<NativeIdentityFailure>()),
        );
        expect(f.transport.requests.length, 0);
        final priorKey = f.store.journal().pending!.requestKey;
        f.store.loseWriteAcknowledgement = null;
        final restarted = f.newController();
        expect(await restarted.recoverPending(), null);
        expect(f.transport.requests.length, 1);
        expect(
          f.transport.requests.single.headers['idempotency-key'] == priorKey,
          true,
        );
        expect(f.entropy.keys, 1);
      },
    );
  }
  test(
    'lost challenge response is never retried on construction or read callback',
    () async {
      final f = IdentityFixture();
      f.transport.handler = (_) =>
          throw StateError('private transport fixture');
      await expectLater(
        f.controller.issueChallenge(fixturePhone),
        throwsA(
          failure(
            NativeIdentityError.transportUnavailable,
            NativeIdentityOutcome.unknown,
          ),
        ),
      );
      final original = f.transport.requests.single;
      final restarted = f.newController();
      expect(await restarted.readAccessCredential(), null);
      expect(f.transport.requests.length, 1);
      f.transport.handler = (_) =>
          jsonResponse(challengeFixture(), status: 202);
      await restarted.recoverPending();
      expect(f.transport.requests.length, 2);
      expect(f.transport.requests.last.body == original.body, true);
      expect(
        f.transport.requests.last.headers['idempotency-key'] ==
            original.headers['idempotency-key'],
        true,
      );
    },
  );
  test('verification original code and key are durable before send', () async {
    final f = IdentityFixture();
    await f.controller.issueChallenge(fixturePhone);
    f.transport.handler = (request) {
      if (request.method == 'GET') return jsonResponse(sessionFixture());
      final pending = f.store.journal().pending!;
      expect(pending.operation, NativeIdentityOperation.verification);
      expect(jsonEncode(pending.body) == request.body, true);
      expect(pending.requestKey == request.headers['idempotency-key'], true);
      return jsonResponse(credentialFixture());
    };
    final identity = await f.controller.verifyCode('123456');
    expect(identity.clubId, 24);
    expect(f.controller.identity != null, true);
    expect(f.store.journal().challenge, null);
  });
  test(
    'lost verification response survives restart and reuses exact code and key',
    () async {
      final f = IdentityFixture();
      await f.controller.issueChallenge(fixturePhone);
      f.transport.handler = (_) =>
          throw StateError('private transport fixture');
      await expectLater(
        f.controller.verifyCode('123456'),
        throwsA(isA<NativeIdentityFailure>()),
      );
      final original = f.transport.requests.last;
      final restarted = f.newController();
      expect(restarted.identity, null);
      expect(await restarted.readAccessCredential(), null);
      f.transport.handler = null;
      final identity = await restarted.recoverPending();
      expect(identity != null, true);
      final recovered = f.transport.requests[f.transport.requests.length - 2];
      expect(recovered.body == original.body, true);
      expect(
        recovered.headers['idempotency-key'] ==
            original.headers['idempotency-key'],
        true,
      );
      expect(f.entropy.keys, 2);
    },
  );
  test(
    'committed credentials with lost storage acknowledgement recover by GET only',
    () async {
      final f = IdentityFixture();
      await f.controller.issueChallenge(fixturePhone);
      f.store.loseWriteAcknowledgement = f.store.writes + 3;
      await expectLater(
        f.controller.verifyCode('123456'),
        throwsA(
          failure(
            NativeIdentityError.storageUnavailable,
            NativeIdentityOutcome.unknown,
          ),
        ),
      );
      expect(f.controller.identity, null);
      expect(f.store.journal().pending, null);
      expect(f.store.journal().credentials != null, true);
      final requests = f.transport.requests.length;
      f.store.loseWriteAcknowledgement = null;
      final restarted = f.newController();
      await restarted.recoverPending();
      expect(f.transport.requests.length, requests + 1);
      expect(f.transport.requests.last.method, 'GET');
    },
  );
  test(
    'never publishes credentials before seven field GET and storage readback match',
    () async {
      final f = IdentityFixture();
      await f.controller.issueChallenge(fixturePhone);
      final sessionReply = Completer<NativeIdentityResponse>();
      f.transport.handler = (request) => request.method == 'GET'
          ? sessionReply.future
          : jsonResponse(credentialFixture());
      final operation = f.controller.verifyCode('123456');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(f.store.journal().credentials != null, true);
      expect(f.controller.identity, null);
      final bad = sessionFixture()..['sessionId'] = fixtureChallenge;
      sessionReply.complete(jsonResponse(bad));
      await expectLater(operation, throwsA(isA<NativeIdentityFailure>()));
      expect(f.controller.identity, null);
    },
  );
  test(
    'failed GET after credential commit preserves bundle and unknown command outcome',
    () async {
      final f = IdentityFixture();
      await f.controller.issueChallenge(fixturePhone);
      f.transport.handler = (request) => request.method == 'GET'
          ? throw StateError('private fixture lost session read')
          : jsonResponse(credentialFixture());
      await expectLater(
        f.controller.verifyCode('123456'),
        throwsA(
          failure(
            NativeIdentityError.transportUnavailable,
            NativeIdentityOutcome.unknown,
          ),
        ),
      );
      expect(f.controller.identity, null);
      expect(f.store.journal().credentials != null, true);
      expect(f.store.journal().pending, null);
      f.transport.handler = null;
      final count = f.transport.requests.length;
      await f.newController().recoverPending();
      expect(f.transport.requests.length, count + 1);
      expect(f.transport.requests.last.method, 'GET');
    },
  );
  test(
    'read-only credential callback performs zero network mutations or requests',
    () async {
      final f = IdentityFixture();
      f.store.seedCredentials();
      final token = await f.controller.readAccessCredential();
      expect(token != null, true);
      expect(f.transport.requests.length, 0);
      f.now += 300000;
      expect(await f.controller.readAccessCredential(), null);
      expect(f.transport.requests.length, 0);
      await expectLater(
        f.controller.inspectCurrentSession(),
        throwsA(failure(NativeIdentityError.reauthenticationRequired)),
      );
      expect(f.transport.requests.length, 0);
    },
  );
  test(
    'expired access rotates only after explicit command with persisted old token and key',
    () async {
      final f = IdentityFixture();
      f.store.seedCredentials();
      f.now += 300001;
      f.transport.handler = (request) {
        if (request.method == 'GET') return jsonResponse(sessionFixture());
        final pending = f.store.journal().pending!;
        expect(pending.operation, NativeIdentityOperation.refresh);
        final old = NativeIdentityCredentials.parse(
          pending.body['credentials'],
          24,
        );
        expect(
          (jsonDecode(request.body!) as Map<String, dynamic>)['refreshToken'] ==
              old.refreshToken,
          true,
        );
        expect(request.headers['idempotency-key'] == pending.requestKey, true);
        final next = credentialFixture(generation: 1)
          ..['accessExpiresAt'] = f.now + 300000;
        return jsonResponse(next);
      };
      await f.controller.rotateCredentials();
      expect(f.transport.requests.length, 2);
      expect(f.controller.identity?.authenticatedAt, fixtureNow);
    },
  );
  test(
    'lost refresh response cannot be replaced by another operation key',
    () async {
      final f = IdentityFixture();
      f.store.seedCredentials();
      f.transport.handler = (_) =>
          throw StateError('private fixture response loss');
      await expectLater(
        f.controller.rotateCredentials(),
        throwsA(isA<NativeIdentityFailure>()),
      );
      final request = f.transport.requests.single;
      final restarted = f.newController();
      await expectLater(
        restarted.rotateCredentials(),
        throwsA(failure(NativeIdentityError.pendingOperation)),
      );
      expect(f.transport.requests.length, 1);
      f.transport.handler = null;
      await restarted.recoverPending();
      expect(
        f.transport.requests[1].headers['idempotency-key'] ==
            request.headers['idempotency-key'],
        true,
      );
      expect(f.transport.requests[1].body == request.body, true);
      expect(f.entropy.keys, 1);
    },
  );
  for (final elapsed in [60000, 60001, -1]) {
    test(
      'recovery at elapsed $elapsed refuses server mutation and requires fresh verification',
      () async {
        final f = IdentityFixture();
        f.store.seedCredentials();
        f.transport.handler = (_) =>
            throw StateError('private fixture response loss');
        await expectLater(
          f.controller.rotateCredentials(),
          throwsA(isA<NativeIdentityFailure>()),
        );
        f.now += elapsed;
        await expectLater(
          f.newController().recoverPending(),
          throwsA(
            failure(
              NativeIdentityError.recoveryExpired,
              NativeIdentityOutcome.unknown,
            ),
          ),
        );
        expect(f.transport.requests.length, 1);
        expect(f.store.journal().pending != null, true);
      },
    );
  }
  test(
    'two controllers serialize through store and unresolved refresh blocks a second rotation',
    () async {
      final f = IdentityFixture(timeout: const Duration(seconds: 1));
      f.store.seedCredentials();
      final reply = Completer<NativeIdentityResponse>();
      f.transport.handler = (_) => reply.future;
      final a = f.controller.rotateCredentials();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final b = f.newController().rotateCredentials();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(f.transport.requests.length, 1);
      expect(f.store.maximumActive, 1);
      reply.completeError(StateError('private fixture response loss'));
      await expectLater(a, throwsA(isA<NativeIdentityFailure>()));
      await expectLater(
        b,
        throwsA(failure(NativeIdentityError.pendingOperation)),
      );
      expect(f.transport.requests.length, 1);
    },
  );
  test(
    'known invalid code clears pending verification but keeps the bound challenge',
    () async {
      final f = IdentityFixture();
      await f.controller.issueChallenge(fixturePhone);
      f.transport.handler = (_) => jsonResponse({
        'schemaVersion': 1,
        'error': 'invalid_code',
      }, status: 401);
      await expectLater(
        f.controller.verifyCode('123456'),
        throwsA(
          failure(
            NativeIdentityError.invalidCode,
            NativeIdentityOutcome.rejected,
          ),
        ),
      );
      expect(f.store.journal().pending, null);
      expect(f.store.journal().challenge != null, true);
      f.transport.handler = null;
      await f.controller.verifyCode('123457');
      expect(f.controller.identity != null, true);
    },
  );
  test(
    'lost revoke acknowledgement remains unknown and local signout is explicit',
    () async {
      final f = IdentityFixture();
      f.store.seedCredentials();
      await f.controller.inspectCurrentSession();
      f.transport.handler = (_) =>
          throw StateError('private fixture response loss');
      final result = await f.controller.revoke(
        NativeIdentityRevokeScope.current,
      );
      expect(result.locallySignedOut, true);
      expect(result.serverRevocation, NativeIdentityRevocation.unknown);
      expect(f.controller.identity, null);
      expect(await f.controller.readAccessCredential(), null);
      final before = f.transport.requests.length;
      await expectLater(
        f.newController().recoverPending(),
        throwsA(
          failure(
            NativeIdentityError.revocationUnknown,
            NativeIdentityOutcome.unknown,
          ),
        ),
      );
      expect(f.transport.requests.length, before);
    },
  );
  test(
    'confirmed server revoke is recorded separately and removes local credentials',
    () async {
      final f = IdentityFixture();
      f.store.seedCredentials();
      final result = await f.controller.revoke(NativeIdentityRevokeScope.all);
      expect(result.serverRevocation, NativeIdentityRevocation.confirmed);
      expect(f.store.journal().revocation, NativeIdentityRevocation.confirmed);
      expect(f.store.journal().credentials, null);
      expect(f.store.journal().pending, null);
      expect(await f.controller.readAccessCredential(), null);
    },
  );
  test(
    'revoke others requires recent verification; refreshing cannot renew phone proof',
    () async {
      final f = IdentityFixture();
      f.store.seedCredentials(authenticatedAt: fixtureNow - 300001);
      await expectLater(
        f.controller.revoke(NativeIdentityRevokeScope.others),
        throwsA(failure(NativeIdentityError.recentVerificationRequired)),
      );
      expect(f.transport.requests.length, 0);
    },
  );
  test('local signout makes no server claim and no network call', () async {
    final f = IdentityFixture();
    f.store.seedCredentials();
    await f.controller.signOutLocally();
    expect(f.store.journal().locallySignedOut, true);
    expect(f.store.journal().revocation, NativeIdentityRevocation.notAttempted);
    expect(await f.controller.readAccessCredential(), null);
    expect(f.transport.requests.length, 0);
  });
  test(
    'explicit abandon clears unknown local recovery but makes no revocation claim',
    () async {
      final f = IdentityFixture();
      f.store.seedCredentials();
      f.transport.handler = (_) =>
          throw StateError('private fixture response loss');
      await expectLater(
        f.controller.rotateCredentials(),
        throwsA(isA<NativeIdentityFailure>()),
      );
      await f.controller.abandonPendingForFreshVerification();
      expect(f.store.journal().pending, null);
      expect(f.store.journal().credentials, null);
      expect(
        f.store.journal().revocation,
        NativeIdentityRevocation.notAttempted,
      );
      expect(f.transport.requests.length, 1);
      f.transport.handler = null;
      await f.controller.issueChallenge(fixturePhone);
      expect(f.transport.requests.length, 2);
    },
  );
  for (final binding in ['club', 'origin', 'application']) {
    test(
      'journal rejects different protected $binding binding before network IO',
      () async {
        final f = IdentityFixture();
        f.store.seedCredentials();
        final raw = jsonDecode(f.store.raw!) as Map<String, dynamic>;
        final scope = raw['binding'] as Map<String, dynamic>;
        switch (binding) {
          case 'club':
            scope['clubId'] = 25;
          case 'origin':
            scope['origin'] = 'https://other.test.invalid';
          case 'application':
            scope['applicationId'] = 'com.africlub.other';
        }
        f.store.raw = jsonEncode(raw);
        await expectLater(
          f.controller.inspectCurrentSession(),
          throwsA(failure(NativeIdentityError.invalidContract)),
        );
        expect(f.transport.requests.length, 0);
      },
    );
  }
  test(
    'invalidation callback runs before rotation touches storage or network',
    () async {
      late IdentityFixture f;
      var invalidations = 0;
      f = IdentityFixture(
        invalidated: () {
          invalidations++;
          expect(f.controller.identity, null);
        },
      );
      f.store.seedCredentials();
      await f.controller.inspectCurrentSession();
      final reads = f.store.reads;
      f.store.afterRead = (index) async {
        if (index == reads + 1) expect(invalidations, 2);
      };
      await f.controller.rotateCredentials();
      expect(invalidations, 2);
    },
  );
  test(
    'failed membership invalidation callback fails closed before network or storage',
    () async {
      final f = IdentityFixture(
        invalidated: () => throw StateError('private fixture callback'),
      );
      await expectLater(
        () => f.controller.issueChallenge(fixturePhone),
        throwsA(failure(NativeIdentityError.invalidationUnavailable)),
      );
      expect(f.transport.requests.length, 0);
      expect(f.store.reads, 0);
    },
  );

  for (final phase in ['read1', 'write1', 'read2', 'write2', 'read3', 'post']) {
    for (final action in ['dispose', 'identityChange']) {
      test('$action fences challenge after $phase await', () async {
        final f = IdentityFixture();
        void invalidate() => action == 'dispose'
            ? f.controller.dispose()
            : f.controller.invalidateIdentity();
        f.store.afterRead = (index) async {
          if (phase == 'read$index') invalidate();
        };
        f.store.afterWrite = (index) async {
          if (phase == 'write$index') invalidate();
        };
        f.transport.handler = (_) {
          if (phase == 'post') invalidate();
          return jsonResponse(challengeFixture(), status: 202);
        };
        await expectLater(
          f.controller.issueChallenge(fixturePhone),
          throwsA(failure(NativeIdentityError.identityChanged)),
        );
        expect(f.controller.identity, null);
        expect(f.transport.requests.length, phase == 'post' ? 1 : 0);
      });
    }
  }
  for (final phase in ['write3', 'read4', 'get', 'read5']) {
    for (final action in ['dispose', 'identityChange']) {
      test(
        '$action fences verification publication after $phase await',
        () async {
          final f = IdentityFixture();
          await f.controller.issueChallenge(fixturePhone);
          f.store.reads = 0;
          f.store.writes = 0;
          void invalidate() => action == 'dispose'
              ? f.controller.dispose()
              : f.controller.invalidateIdentity();
          f.store.afterRead = (index) async {
            if (phase == 'read$index') invalidate();
          };
          f.store.afterWrite = (index) async {
            if (phase == 'write$index') invalidate();
          };
          f.transport.handler = (request) {
            if (request.method == 'GET') {
              if (phase == 'get') invalidate();
              return jsonResponse(sessionFixture());
            }
            return jsonResponse(credentialFixture());
          };
          await expectLater(
            f.controller.verifyCode('123456'),
            throwsA(
              failure(
                NativeIdentityError.identityChanged,
                NativeIdentityOutcome.unknown,
              ),
            ),
          );
          expect(f.controller.identity, null);
        },
      );
    }
  }
  test(
    'bounded store acknowledgement deadline prevents network and late publication',
    () async {
      final f = IdentityFixture();
      final stalled = Completer<void>();
      f.store.afterWrite = (_) => stalled.future;
      final controller = NativeIdentityController(
        client: f.client,
        store: f.store,
        entropy: f.entropy,
        enabled: true,
        storeTimeout: const Duration(milliseconds: 15),
      );
      await expectLater(
        controller.issueChallenge(fixturePhone),
        throwsA(failure(NativeIdentityError.storageUnavailable)),
      );
      expect(f.transport.requests.length, 0);
      stalled.complete();
      await Future<void>.delayed(Duration.zero);
      expect(f.transport.requests.length, 0);
      expect(controller.identity, null);
    },
  );
}

/// TEST ONLY: intentionally violates bounded acquisition to exercise late fences.
final class _DelayedExclusiveStore implements NativeCredentialStore {
  _DelayedExclusiveStore(this.delegate);
  final TestCredentialStore delegate;
  final release = Completer<void>();
  @override
  NativeCredentialStoreCapabilities get capabilities => delegate.capabilities;
  @override
  Future<T> runExclusive<T>(
    NativeIdentityScope scope,
    Duration acquisitionTimeout,
    Future<T> Function(NativeCredentialTransaction transaction) work,
  ) async {
    await release.future;
    return delegate.runExclusive(scope, acquisitionTimeout, work);
  }
}
