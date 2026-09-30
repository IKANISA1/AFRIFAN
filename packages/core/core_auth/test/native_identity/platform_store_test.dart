import 'dart:async';

import 'package:core_auth/native_identity_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _token = '30000000-0000-4000-8000-000000000001';
NativeIdentityScope _scope([String app = 'rw.ikanisa.rayonSports.qa.codex']) =>
    NativeIdentityScope(
      applicationId: app,
      approvedOrigin: Uri.parse('https://identity.invalid'),
      clubId: 24,
    );

// Synthetic FIFO native owner and unprotected memory only. These tests establish
// protocol/deadline behavior, never Keystore/Keychain/device acceptance.
final class _Backend {
  String? owner, acquisition, scope;
  final values = <String, String>{};
}

final class _Channel implements NativeCredentialChannel {
  _Channel(this.backend, this.boundScope, this.owner);
  final _Backend backend;
  final NativeIdentityScope boundScope;
  final String owner;
  final methods = <String>[];
  Future<void> _tail = Future.value();
  bool unlocked = true;
  bool loseCasAck = false;
  bool loseAcquireAck = false;
  bool malformedCasAck = false;
  bool malformedDrainAck = false;
  Duration acquireReplyDelay = Duration.zero;
  Completer<void>? heldCas;
  Map<String, Object?>? describeOverride;
  @override
  Future<Object?> invoke(String method, Map<String, Object?> a) {
    methods.add(method);
    final execution = _tail.then<Object?>((_) async {
      if (a['scope'] != boundScope.storeScope) {
        throw const NativeCredentialChannelFailure(
          'credential_binding_mismatch',
        );
      }
      if (!unlocked && method != 'drain' && method != 'release') {
        throw const NativeCredentialChannelFailure('credential_device_locked');
      }
      switch (method) {
        case 'describe':
          return describeOverride ??
              {
                'version': 1,
                'scope': boundScope.storeScope,
                'applicationId': boundScope.applicationId,
                'maxJournalBytes': 8192,
                'policy': 'ios_passcode_keychain_no_backup_v1',
              };
        case 'tryAcquire':
          if (backend.owner != null &&
              (backend.owner != owner ||
                  backend.acquisition != a['acquisitionId'])) {
            return {'version': 1, 'busy': true, 'lease': null};
          }
          backend.owner = owner;
          backend.acquisition = a['acquisitionId']! as String;
          backend.scope = a['scope']! as String;
          return {'version': 1, 'busy': false, 'lease': _token};
        case 'read':
        case 'compareAndSet':
          if (backend.owner != owner || a['lease'] != _token) {
            throw const NativeCredentialChannelFailure(
              'credential_lock_required',
            );
          }
          if (method == 'read') {
            return {
              'version': 1,
              'value': backend.values[boundScope.storeScope],
            };
          }
          await heldCas?.future;
          if (backend.values[boundScope.storeScope] != a['expected']) {
            return {'version': 1, 'updated': false};
          }
          backend.values[boundScope.storeScope] = a['value']! as String;
          return {'version': 1, 'updated': malformedCasAck ? 'unknown' : true};
        case 'drain':
          return {'version': 1, 'settled': !malformedDrainAck};
        case 'release':
          if (backend.owner == owner &&
              backend.acquisition == a['acquisitionId']) {
            backend.owner = backend.acquisition = backend.scope = null;
          }
          return {'version': 1, 'released': true};
        default:
          throw const NativeCredentialChannelFailure(
            'credential_invalid_request',
          );
      }
    });
    // Native execution settles independently from reply delivery.
    _tail = execution.then<void>((_) {}, onError: (Object _) {});
    if (method == 'compareAndSet' && loseCasAck) {
      return execution.then((_) => Completer<Object?>().future);
    }
    if (method == 'tryAcquire' && loseAcquireAck) {
      return execution.then((_) => Completer<Object?>().future);
    }
    if (method == 'tryAcquire' && acquireReplyDelay > Duration.zero) {
      return execution.then((v) async {
        await Future<void>.delayed(acquireReplyDelay);
        return v;
      });
    }
    return execution;
  }
}

Future<PlatformNativeCredentialStore> _open(
  _Channel channel, {
  Duration timeout = const Duration(milliseconds: 30),
}) => PlatformNativeCredentialStore.open(
  channel: channel,
  scope: channel.boundScope,
  enabled: true,
  acceptedDevicePolicy: true,
  callTimeout: timeout,
);

final _failure = isA<NativeIdentityFailure>();
final _unknown = isA<NativeIdentityFailure>().having(
  (e) => e.outcome,
  'outcome',
  NativeIdentityOutcome.unknown,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('disabled and unaccepted defaults perform no native access', () async {
    for (final enabled in [false, true]) {
      final channel = _Channel(_Backend(), _scope(), 'one');
      final store = await PlatformNativeCredentialStore.open(
        channel: channel,
        scope: channel.boundScope,
        enabled: enabled,
      );
      expect(store.capabilities.usable, false);
      await expectLater(
        store.runExclusive(
          channel.boundScope,
          const Duration(seconds: 1),
          (_) async => fail('disabled callback'),
        ),
        throwsA(_failure),
      );
      expect(channel.methods, isEmpty);
    }
  });
  for (final entry in {
    'version': 2,
    'scope': 'wrong',
    'applicationId': 'rw.ikanisa.rayonsports.qa.codex',
    'maxJournalBytes': 2048,
    'policy': 'plaintext',
    'extra': true,
  }.entries) {
    test('reject native policy mismatch ${entry.key}', () async {
      final scope = _scope();
      final channel = _Channel(_Backend(), scope, 'one');
      channel.describeOverride = {
        'version': 1,
        'scope': scope.storeScope,
        'applicationId': scope.applicationId,
        'maxJournalBytes': 8192,
        'policy': 'ios_passcode_keychain_no_backup_v1',
        entry.key: entry.value,
      };
      await expectLater(_open(channel), throwsA(_failure));
      expect(channel.methods, ['describe']);
    });
  }
  test(
    'CAS conflict writes nothing; exact mixed-case scope survives',
    () async {
      final channel = _Channel(_Backend(), _scope(), 'one');
      final store = await _open(channel);
      await store.runExclusive(store.scope, const Duration(seconds: 1), (
        tx,
      ) async {
        expect(await tx.read(), null);
        expect(await tx.compareAndSet(null, 'é'), true);
        expect(await tx.compareAndSet('e\u0301', 'replacement'), false);
        expect(await tx.read(), 'é');
      });
      expect(channel.backend.owner, null);
      expect(channel.methods.sublist(channel.methods.length - 2), [
        'drain',
        'release',
      ]);
    },
  );
  test(
    'wrong club and origin cannot enter callback or native channel',
    () async {
      final channel = _Channel(_Backend(), _scope(), 'one');
      final store = await _open(channel);
      for (final scope in [
        NativeIdentityScope(
          applicationId: store.scope.applicationId,
          approvedOrigin: store.scope.origin,
          clubId: 26,
        ),
        NativeIdentityScope(
          applicationId: store.scope.applicationId,
          approvedOrigin: Uri.parse('https://other.invalid'),
          clubId: 24,
        ),
      ]) {
        await expectLater(
          store.runExclusive(
            scope,
            const Duration(seconds: 1),
            (_) async => fail('wrong scope'),
          ),
          throwsA(_failure),
        );
      }
      expect(channel.methods, ['describe']);
    },
  );
  test(
    '8192-byte limit rejects multibyte overflow and invalid Unicode',
    () async {
      final channel = _Channel(_Backend(), _scope(), 'one');
      final store = await _open(channel);
      await store.runExclusive(store.scope, const Duration(seconds: 1), (
        tx,
      ) async {
        expect(await tx.compareAndSet(null, 'é' * 4096), true);
        for (final value in ['', 'é' * 4097, '\uD800']) {
          await expectLater(tx.compareAndSet(null, value), throwsA(_failure));
        }
      });
      expect(channel.methods.where((m) => m == 'compareAndSet').length, 1);
    },
  );
  test('escaped transaction and foreign zone refuse reads', () async {
    final channel = _Channel(_Backend(), _scope(), 'one');
    final store = await _open(channel);
    final foreignZone = Zone.current;
    late NativeCredentialTransaction escaped;
    await store.runExclusive(store.scope, const Duration(seconds: 1), (
      tx,
    ) async {
      escaped = tx;
      await expectLater(foreignZone.run(tx.read), throwsA(_failure));
    });
    await expectLater(escaped.read(), throwsA(_failure));
    expect(channel.methods, ['describe', 'tryAcquire', 'drain', 'release']);
  });
  test(
    'nested adapters cannot acquire installation lock recursively',
    () async {
      final backend = _Backend();
      final a = await _open(_Channel(backend, _scope(), 'one'));
      final b = await _open(_Channel(backend, _scope(), 'two'));
      await a.runExclusive(a.scope, const Duration(seconds: 1), (_) async {
        await expectLater(
          b.runExclusive(
            b.scope,
            const Duration(seconds: 1),
            (_) async => fail('nested callback'),
          ),
          throwsA(_failure),
        );
      });
      expect(backend.owner, null);
    },
  );
  test('different engines serialize until full work future settles', () async {
    final backend = _Backend();
    final a = await _open(_Channel(backend, _scope(), 'one'));
    final b = await _open(_Channel(backend, _scope(), 'two'));
    final entered = Completer<void>(), complete = Completer<void>();
    var calls = 0;
    final first = a.runExclusive(a.scope, const Duration(seconds: 1), (
      tx,
    ) async {
      entered.complete();
      await complete.future;
      await tx.compareAndSet(null, 'first');
    });
    await entered.future;
    final second = b.runExclusive(b.scope, const Duration(seconds: 1), (
      tx,
    ) async {
      calls++;
      expect(await tx.read(), 'first');
      await tx.compareAndSet('first', 'second');
    });
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(calls, 0);
    complete.complete();
    await Future.wait([first, second]);
    expect(calls, 1);
    expect(backend.values[a.scope.storeScope], 'second');
  });
  test(
    'malformed CAS acknowledgement preserves committed value as unknown',
    () async {
      final channel = _Channel(_Backend(), _scope(), 'one')
        ..malformedCasAck = true;
      final store = await _open(channel);
      await expectLater(
        store.runExclusive(
          store.scope,
          const Duration(seconds: 1),
          (tx) => tx.compareAndSet(null, 'original-pending-key'),
        ),
        throwsA(_unknown),
      );
      expect(
        channel.backend.values[store.scope.storeScope],
        'original-pending-key',
      );
      expect(channel.backend.owner, null);
    },
  );
  test('lost CAS acknowledgement uses FIFO drain before releasing', () async {
    final channel = _Channel(_Backend(), _scope(), 'one')..loseCasAck = true;
    final store = await _open(channel);
    await expectLater(
      store.runExclusive(
        store.scope,
        const Duration(seconds: 1),
        (tx) => tx.compareAndSet(null, 'original-pending-key'),
      ),
      throwsA(_unknown),
    );
    expect(channel.backend.owner, null);
    channel.loseCasAck = false;
    await store.runExclusive(store.scope, const Duration(seconds: 1), (
      tx,
    ) async {
      expect(await tx.read(), 'original-pending-key');
    });
  });
  test(
    'late CAS retains lock beyond deadline; recovery rereads original value',
    () async {
      final backend = _Backend();
      final channel = _Channel(backend, _scope(), 'one')
        ..heldCas = Completer<void>();
      final store = await _open(
        channel,
        timeout: const Duration(milliseconds: 15),
      );
      await expectLater(
        store.runExclusive(
          store.scope,
          const Duration(seconds: 1),
          (tx) => tx.compareAndSet(null, 'original-pending-key'),
        ),
        throwsA(_unknown),
      );
      expect(backend.owner, 'one');
      final other = await _open(_Channel(backend, _scope(), 'two'));
      await expectLater(
        other.runExclusive(
          other.scope,
          const Duration(milliseconds: 15),
          (_) async => fail('late CAS cannot unlock'),
        ),
        throwsA(_failure),
      );
      expect(backend.owner, 'one');
      channel.heldCas!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 15));
      expect(backend.owner, null);
      await other.runExclusive(other.scope, const Duration(seconds: 1), (
        tx,
      ) async {
        expect(await tx.read(), 'original-pending-key');
      });
    },
  );
  test(
    'acquisition includes channel attempt deadline; no late callback',
    () async {
      final channel = _Channel(_Backend(), _scope(), 'one');
      final store = await _open(
        channel,
        timeout: const Duration(milliseconds: 15),
      );
      channel.acquireReplyDelay = const Duration(milliseconds: 80);
      var invoked = false;
      final clock = Stopwatch()..start();
      await expectLater(
        store.runExclusive(store.scope, const Duration(milliseconds: 10), (
          _,
        ) async {
          invoked = true;
        }),
        throwsA(_unknown),
      );
      expect(clock.elapsedMilliseconds, lessThan(60));
      expect(channel.backend.owner, null);
      await Future<void>.delayed(const Duration(milliseconds: 85));
      expect(invoked, false);
    },
  );
  test(
    'callback failure and background both allow cleanup without storage access',
    () async {
      final channel = _Channel(_Backend(), _scope(), 'one');
      final store = await _open(channel);
      await expectLater(
        store.runExclusive(store.scope, const Duration(seconds: 1), (tx) async {
          channel.unlocked = false;
          await tx.read();
        }),
        throwsA(_unknown),
      );
      expect(channel.backend.owner, null);
    },
  );
  test('failed queue barrier never authorizes release', () async {
    final channel = _Channel(_Backend(), _scope(), 'one')
      ..malformedDrainAck = true;
    final store = await _open(channel);
    await expectLater(
      store.runExclusive(
        store.scope,
        const Duration(seconds: 1),
        (tx) => tx.compareAndSet(null, 'retained'),
      ),
      throwsA(_unknown),
    );
    expect(channel.backend.owner, 'one');
    expect(channel.methods, isNot(contains('release')));
    expect(channel.backend.values[store.scope.storeScope], 'retained');
  });
  test(
    'lost acquisition acknowledgement drains and releases the original key without invoking work',
    () async {
      final channel = _Channel(_Backend(), _scope(), 'one')
        ..loseAcquireAck = true;
      final store = await _open(
        channel,
        timeout: const Duration(milliseconds: 15),
      );
      var calls = 0;
      await expectLater(
        store.runExclusive(store.scope, const Duration(milliseconds: 15), (
          _,
        ) async {
          calls++;
        }),
        throwsA(_unknown),
      );
      expect(calls, 0);
      expect(channel.backend.owner, null);
      expect(channel.methods, ['describe', 'tryAcquire', 'drain', 'release']);
    },
  );
  test(
    'an unawaited native CAS cannot release its lease while the OS operation remains active',
    () async {
      final backend = _Backend();
      final channel = _Channel(backend, _scope(), 'one')
        ..heldCas = Completer<void>();
      final store = await _open(
        channel,
        timeout: const Duration(milliseconds: 15),
      );
      final lateFailure = Completer<Object>();
      await expectLater(
        store.runExclusive(store.scope, const Duration(seconds: 1), (tx) async {
          unawaited(
            tx
                .compareAndSet(null, 'same-original-key')
                .then<void>(
                  (_) {
                    lateFailure.complete(
                      StateError('escaped transaction incorrectly succeeded'),
                    );
                  },
                  onError: (Object error) {
                    lateFailure.complete(error);
                  },
                ),
          );
        }),
        throwsA(_unknown),
      );
      expect(backend.owner, 'one');
      expect(channel.methods, isNot(contains('release')));
      channel.heldCas!.complete();
      expect(await lateFailure.future, _failure);
      await Future<void>.delayed(const Duration(milliseconds: 15));
      expect(backend.owner, null);
      expect(backend.values[store.scope.storeScope], 'same-original-key');
    },
  );
  test(
    'Flutter binding uses only dedicated credential channel and finite failures',
    () async {
      const channel = MethodChannel(FlutterNativeCredentialChannel.channelName);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      MethodCall? observed;
      messenger.setMockMethodCallHandler(channel, (call) async {
        observed = call;
        throw PlatformException(code: 'PRIVATE_OS_MESSAGE', message: 'SECRET');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      expect(channel.name, 'africlub/native-identity-credentials/v1');
      await expectLater(
        const FlutterNativeCredentialChannel().invoke('describe', {
          'scope': _scope().storeScope,
        }),
        throwsA(isA<NativeCredentialChannelFailure>()),
      );
      expect(observed?.method, 'describe');
    },
  );
}
