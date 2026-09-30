import 'dart:async';
import 'dart:convert';

import 'models.dart';
import 'ports.dart';

/// Dedicated, per-engine FIFO credential channel. Native `drain` is a queue
/// barrier, including when an earlier operation's acknowledgement was lost.
abstract interface class NativeCredentialChannel {
  Future<Object?> invoke(String method, Map<String, Object?> arguments);
}

final class NativeCredentialChannelFailure implements Exception {
  const NativeCredentialChannelFailure(this.code);
  final String code;
  @override
  String toString() => 'NativeCredentialChannelFailure([finite])';
}

/// A policy handshake is a source contract, never physical device acceptance.
/// Production callers must separately supply acceptedDevicePolicy, which is
/// false by default. Disabled construction performs no channel/storage work.
final class PlatformNativeCredentialStore implements NativeCredentialStore {
  PlatformNativeCredentialStore._(
    this.channel,
    this.scope,
    this.callTimeout,
    this._accepted,
  );

  static Future<PlatformNativeCredentialStore> open({
    required NativeCredentialChannel channel,
    required NativeIdentityScope scope,
    bool enabled = false,
    bool acceptedDevicePolicy = false,
    Duration callTimeout = const Duration(seconds: 2),
  }) async {
    identityRequire(
      callTimeout.inMilliseconds > 0 && callTimeout.inMilliseconds <= 5000,
      NativeIdentityError.invalidConfiguration,
    );
    if (!enabled || !acceptedDevicePolicy) {
      return PlatformNativeCredentialStore._(
        channel,
        scope,
        callTimeout,
        false,
      );
    }
    final result = await _reply(
      Future<Object?>.sync(
        () => channel.invoke('describe', {'scope': scope.storeScope}),
      ),
      callTimeout,
      ['version', 'scope', 'applicationId', 'maxJournalBytes', 'policy'],
    );
    identityRequire(
      result['applicationId'] == scope.applicationId &&
          result['scope'] == scope.storeScope &&
          result['maxJournalBytes'] is int &&
          result['maxJournalBytes'] == 8192 &&
          {
            'android_keystore_aead_foreground_v1',
            'ios_passcode_keychain_no_backup_v1',
          }.contains(result['policy']),
      NativeIdentityError.storageUnavailable,
    );
    return PlatformNativeCredentialStore._(channel, scope, callTimeout, true);
  }

  final NativeCredentialChannel channel;
  final NativeIdentityScope scope;
  final Duration callTimeout;
  final bool _accepted;
  static final Object _zoneKey = Object();

  @override
  NativeCredentialStoreCapabilities get capabilities => _accepted
      ? const NativeCredentialStoreCapabilities(
          osProtected: true,
          atomicDurableCompareAndSet: true,
          processSafeExclusive: true,
          applicationOriginClubBinding: true,
          boundedOperations: true,
        )
      : const NativeCredentialStoreCapabilities.unavailable();

  static Map<String, Object?> _decode(Object? value, List<String> keys) {
    if (value is! Map ||
        value.keys.any((key) => key is! String) ||
        value.length != keys.length ||
        !keys.every(value.containsKey) ||
        value['version'] is! int ||
        value['version'] != 1) {
      throw const NativeIdentityFailure(
        NativeIdentityError.storageUnavailable,
        NativeIdentityOutcome.unknown,
      );
    }
    return Map<String, Object?>.from(value);
  }

  static Future<Map<String, Object?>> _reply(
    Future<Object?> request,
    Duration deadline,
    List<String> keys,
  ) async {
    try {
      return _decode(await request.timeout(deadline), keys);
    } catch (_) {
      throw const NativeIdentityFailure(
        NativeIdentityError.storageUnavailable,
        NativeIdentityOutcome.unknown,
      );
    }
  }

  Future<Map<String, Object?>> _call(
    String method,
    Map<String, Object?> args,
    List<String> keys, [
    Duration? deadline,
  ]) => _reply(
    Future<Object?>.sync(() => channel.invoke(method, args)),
    deadline ?? callTimeout,
    keys,
  );

  void _gate(NativeIdentityScope requested) {
    identityRequire(_accepted, NativeIdentityError.storageUnavailable);
    identityRequire(
      requested.storeScope == scope.storeScope,
      NativeIdentityError.invalidConfiguration,
    );
  }

  /// A failed drain never authorizes release. The uncancelled cleanup remains
  /// behind native work after the caller's deadline. No timer clears the lock.
  Future<void> _cleanup(String acquisition) async {
    final args = {'scope': scope.storeScope, 'acquisitionId': acquisition};
    final barrier = _decode(await channel.invoke('drain', args), [
      'version',
      'settled',
    ]);
    identityRequire(
      barrier['settled'] == true,
      NativeIdentityError.storageUnavailable,
    );
    final reply = _decode(await channel.invoke('release', args), [
      'version',
      'released',
    ]);
    identityRequire(
      reply['released'] == true,
      NativeIdentityError.storageUnavailable,
    );
  }

  @override
  Future<T> runExclusive<T>(
    NativeIdentityScope requested,
    Duration acquisitionTimeout,
    Future<T> Function(NativeCredentialTransaction transaction) work,
  ) async {
    _gate(requested);
    identityRequire(
      acquisitionTimeout.inMilliseconds > 0 &&
          acquisitionTimeout.inMilliseconds <= 5000 &&
          Zone.current[_zoneKey] == null,
      NativeIdentityError.invalidConfiguration,
    );
    final acquisition = SecureNativeIdentityEntropy().requestKey();
    final clock = Stopwatch()..start();
    _CredentialTransaction? transaction;
    try {
      while (true) {
        final remaining = acquisitionTimeout - clock.elapsed;
        identityRequire(
          remaining > Duration.zero,
          NativeIdentityError.storageUnavailable,
        );
        final reply = await _call(
          'tryAcquire',
          {'scope': scope.storeScope, 'acquisitionId': acquisition},
          ['version', 'busy', 'lease'],
          remaining < callTimeout ? remaining : callTimeout,
        );
        identityRequire(
          reply['busy'] is bool,
          NativeIdentityError.storageUnavailable,
        );
        if (reply['busy'] == false) {
          identityRequire(
            identityUuid(reply['lease']),
            NativeIdentityError.storageUnavailable,
          );
          // A delayed acknowledgement cannot invoke work after the budget.
          identityRequire(
            clock.elapsed < acquisitionTimeout,
            NativeIdentityError.storageUnavailable,
          );
          transaction = _CredentialTransaction(this, reply['lease']! as String);
          return await runZoned(
            () => work(transaction!),
            zoneValues: {_zoneKey: transaction},
          );
        }
        identityRequire(
          reply['lease'] == null,
          NativeIdentityError.storageUnavailable,
        );
        final pause = acquisitionTimeout - clock.elapsed;
        if (pause > Duration.zero) {
          await Future<void>.delayed(
            pause < const Duration(milliseconds: 20)
                ? pause
                : const Duration(milliseconds: 20),
          );
        }
      }
    } finally {
      transaction?.active = false;
      // timeout() observes but never cancels cleanup or the queue barrier.
      await _reply(
        _cleanup(
          acquisition,
        ).then<Object?>((_) => {'version': 1, 'released': true}),
        callTimeout,
        ['version', 'released'],
      );
    }
  }
}

final class _CredentialTransaction implements NativeCredentialTransaction {
  _CredentialTransaction(this.store, this.token);
  final PlatformNativeCredentialStore store;
  final String token;
  bool active = true;
  void _check() {
    identityRequire(
      active &&
          identical(Zone.current[PlatformNativeCredentialStore._zoneKey], this),
      NativeIdentityError.storageUnavailable,
    );
  }

  void _value(String value) {
    final bytes = utf8.encode(value);
    identityRequire(
      bytes.isNotEmpty && bytes.length <= 8192 && utf8.decode(bytes) == value,
      NativeIdentityError.invalidInput,
    );
  }

  @override
  Future<String?> read() async {
    _check();
    final result = await store._call(
      'read',
      {'scope': store.scope.storeScope, 'lease': token},
      ['version', 'value'],
    );
    _check();
    identityRequire(
      result['value'] == null || result['value'] is String,
      NativeIdentityError.storageUnavailable,
    );
    final value = result['value'] as String?;
    if (value != null) _value(value);
    return value;
  }

  @override
  Future<bool> compareAndSet(String? expected, String replacement) async {
    _check();
    if (expected != null) _value(expected);
    _value(replacement);
    final result = await store._call(
      'compareAndSet',
      {
        'scope': store.scope.storeScope,
        'lease': token,
        'expected': expected,
        'value': replacement,
      },
      ['version', 'updated'],
    );
    _check();
    if (result['updated'] is! bool) {
      throw const NativeIdentityFailure(
        NativeIdentityError.storageUnavailable,
        NativeIdentityOutcome.unknown,
      );
    }
    return result['updated']! as bool;
  }
}
