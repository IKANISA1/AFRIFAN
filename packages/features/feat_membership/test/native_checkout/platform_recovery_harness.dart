import 'dart:async';
import 'dart:io';
import 'package:feat_membership/native_membership.dart';

const scope = 'africlub-membership-v1:24:20000000-0000-4000-8000-000000000001';
const other =
    'africlub-payment-handoff-v1:24:20000000-0000-4000-8000-000000000001';
void need(bool value) {
  if (!value) throw StateError('Assertion failed');
}

Future<void> refuses(Future<void> Function() work) async {
  try {
    await work();
  } on NativeMembershipException {
    return;
  }
  throw StateError('Expected refusal');
}

// Channel double only: not encrypted storage, OS locking or Android execution evidence.
final class FakeChannel implements RecoveryPlatformChannel {
  final Map<String, String> values = {};
  String? acquisition, token, activeScope;
  bool failWrite = false, failRelease = false, malformed = false;
  int acquisitions = 0, releases = 0;
  @override
  Future<Object?> invoke(String method, Map<String, Object?> a) async {
    if (method == 'tryAcquire') {
      acquisitions++;
      if (malformed) return {'version': 1, 'busy': false, 'lease': 'wrong'};
      if (token != null) return {'version': 1, 'busy': true, 'lease': null};
      acquisition = a['acquisitionId'] as String;
      activeScope = a['scope'] as String;
      token = newOperationId();
      return {'version': 1, 'busy': false, 'lease': token};
    }
    if (method == 'release') {
      releases++;
      if (failRelease) {
        throw const RecoveryPlatformFailure('recovery_unavailable');
      }
      if (acquisition == a['acquisitionId']) {
        acquisition = null;
        token = null;
        activeScope = null;
      }
      return {'version': 1, 'released': true};
    }
    if (a['lease'] != token || a['scope'] != activeScope || token == null) {
      throw const RecoveryPlatformFailure('recovery_lock_required');
    }
    if (method == 'load') return {'version': 1, 'value': values[a['scope']]};
    if (method == 'compareAndSet') {
      if (failWrite) {
        throw const RecoveryPlatformFailure('recovery_write_unknown');
      }
      final s = a['scope'] as String;
      final changed = values[s] == a['expected'];
      if (changed) values[s] = a['value'] as String;
      return {'version': 1, 'updated': changed};
    }
    throw const RecoveryPlatformFailure('recovery_invalid_request');
  }
}

Future<void> main() async {
  var passed = 0;
  Future<void> test(String name, Future<void> Function() f) async {
    await f();
    passed++;
    stdout.writeln('PASS $name');
  }

  await test('disabled adapter sends nothing', () async {
    final c = FakeChannel();
    final s = PlatformNativeRecoveryStore(c);
    await refuses(() async {
      await s.runExclusive(scope, () async => 1);
    });
    need(c.acquisitions == 0);
  });
  await test('reads require current lease', () async {
    final s = PlatformNativeRecoveryStore(FakeChannel(), enabled: true);
    await refuses(() async {
      await s.load(scope);
    });
  });
  await test('durable interface CAS and mismatch', () async {
    final c = FakeChannel();
    final s = PlatformNativeRecoveryStore(c, enabled: true);
    await s.runExclusive(scope, () async {
      need(await s.load(scope) == null);
      need(await s.compareAndSet(scope, null, 'pending'));
      need(!await s.compareAndSet(scope, null, 'wrong'));
    });
    need(c.token == null);
  });
  await test('different scope denied within lease', () async {
    final s = PlatformNativeRecoveryStore(FakeChannel(), enabled: true);
    await s.runExclusive(scope, () async {
      await refuses(() async {
        await s.load(other);
      });
    });
  });
  await test('nested adapter rejected', () async {
    final c = FakeChannel();
    final s = PlatformNativeRecoveryStore(c, enabled: true);
    final t = PlatformNativeRecoveryStore(c, enabled: true);
    await s.runExclusive(scope, () async {
      await refuses(() async {
        await t.runExclusive(other, () async => 1);
      });
    });
  });
  await test('exception releases lease', () async {
    final c = FakeChannel();
    final s = PlatformNativeRecoveryStore(c, enabled: true);
    try {
      await s.runExclusive(scope, () async => throw StateError('test'));
    } on StateError {
      // The synthetic failure must release the lease before returning.
    }
    need(c.token == null && c.releases == 1);
  });
  await test(
    'escaped asynchronous context cannot reuse released lease',
    () async {
      final c = FakeChannel();
      final s = PlatformNativeRecoveryStore(c, enabled: true);
      final gate = Completer<void>();
      late Future<void> pending;
      await s.runExclusive(scope, () async {
        pending = () async {
          await gate.future;
          await refuses(() async {
            await s.load(scope);
          });
        }();
      });
      gate.complete();
      await pending;
    },
  );
  await test('UTF8 size not only character count', () async {
    final s = PlatformNativeRecoveryStore(FakeChannel(), enabled: true);
    await s.runExclusive(scope, () async {
      await refuses(() async {
        await s.compareAndSet(scope, null, List.filled(1025, 'é').join());
      });
    });
  });
  await test('corrupt channel token stops work', () async {
    final c = FakeChannel()..malformed = true;
    final s = PlatformNativeRecoveryStore(c, enabled: true);
    var ran = false;
    await refuses(() async {
      await s.runExclusive(scope, () async {
        ran = true;
      });
    });
    need(!ran && c.releases == 1);
  });
  await test('uncertain release is not a successful operation', () async {
    final c = FakeChannel()..failRelease = true;
    final s = PlatformNativeRecoveryStore(c, enabled: true);
    await refuses(() async {
      await s.runExclusive(scope, () async => 1);
    });
  });
  await test('write error still releases and never returns false', () async {
    final c = FakeChannel()..failWrite = true;
    final s = PlatformNativeRecoveryStore(c, enabled: true);
    await refuses(() async {
      await s.runExclusive(scope, () async {
        await s.compareAndSet(scope, null, 'pending');
      });
    });
    need(c.token == null);
  });
  await test('different user rejected scope syntax', () async {
    final c = FakeChannel();
    final s = PlatformNativeRecoveryStore(c, enabled: true);
    await refuses(() async {
      await s.runExclusive('../../secret', () async => 1);
    });
    need(c.acquisitions == 0);
  });
  stdout.writeln('SUMMARY passed=$passed failed=0 skipped=0');
}
