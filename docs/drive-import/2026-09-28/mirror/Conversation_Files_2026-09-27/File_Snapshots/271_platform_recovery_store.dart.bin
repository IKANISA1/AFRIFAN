import 'dart:async';
import 'dart:convert';
import 'models.dart';
import 'ports.dart';
import 'recovery.dart';

/// Native bridge transport, not an in-memory production implementation.
abstract interface class RecoveryPlatformChannel {
  Future<Object?> invoke(String method, Map<String, Object?> arguments);
}
final class RecoveryPlatformFailure implements Exception {
  const RecoveryPlatformFailure(this.code);
  final String code;
}
final class _ActiveRecoveryLease {
  _ActiveRecoveryLease(this.store, this.scope, this.token);
  final Object store;
  final String scope, token;
  bool active = true;
}

/// Adapts the native global lock and encrypted CAS store to the existing checkout
/// ports. Construct once per composition. No key or path crosses this interface.
/// A timeout never authorizes clearing a pending operation or recreating its key.
final class PlatformNativeRecoveryStore implements NativeRecoveryStore {
  PlatformNativeRecoveryStore(this.channel, {this.enabled = false,
    this.acquireTimeout = const Duration(seconds: 10),
    this.callTimeout = const Duration(seconds: 5)}) {
    requireContract(acquireTimeout.inMilliseconds > 0 && acquireTimeout.inMilliseconds <= 30000 &&
      callTimeout.inMilliseconds > 0 && callTimeout.inMilliseconds <= 10000, 'recovery_not_configured');
  }
  final RecoveryPlatformChannel channel;
  final bool enabled;
  final Duration acquireTimeout, callTimeout;
  static final Object _zoneKey = Object();
  static final _scope = RegExp(r'^africlub-(membership|payment-handoff)-v1:[1-9][0-9]{0,14}:([0-9a-f-]{36})$');
  static const _errors = {
    'recovery_invalid_request', 'recovery_invalid_scope', 'recovery_invalid_value',
    'recovery_corrupt', 'recovery_crypto_unavailable', 'recovery_key_unavailable',
    'recovery_key_conflict', 'recovery_state_missing', 'recovery_write_unknown',
    'recovery_capacity', 'recovery_directory_unavailable', 'recovery_lock_required',
    'recovery_lock_lost', 'recovery_unavailable', 'recovery_platform_unsupported',
    'recovery_device_locked', 'recovery_disabled', 'recovery_busy',
    'recovery_channel_unavailable'
  };
  void _gate(String scope) {
    requireContract(enabled, 'recovery_disabled');
    final m = _scope.firstMatch(scope);
    requireContract(m != null && m.group(0) == scope && isUuid(m.group(2)), 'recovery_invalid_scope');
  }
  void _value(String value) {
    final bytes = utf8.encode(value);
    requireContract(bytes.isNotEmpty && bytes.length <= 2048 && utf8.decode(bytes) == value, 'recovery_invalid_value');
  }
  Future<Map<String, Object?>> _call(String method, Map<String, Object?> args, List<String> keys) async {
    try {
      final result = await channel.invoke(method, args).timeout(callTimeout);
      if (result is! Map || result.keys.any((key) => key is! String)) {
        throw const NativeMembershipException('recovery_channel_invalid', RequestOutcome.unknown);
      }
      final map = exactObject(Map<String, Object?>.from(result), keys);
      requireContract(map['version'] == 1, 'recovery_channel_invalid');
      return map;
    } on RecoveryPlatformFailure catch (e) {
      throw NativeMembershipException(_errors.contains(e.code) ? e.code : 'recovery_unavailable',
        e.code == 'recovery_write_unknown' ? RequestOutcome.unknown : RequestOutcome.notSent);
    } on TimeoutException {
      throw const NativeMembershipException('recovery_channel_unknown', RequestOutcome.unknown);
    } on NativeMembershipException {
      // A malformed acknowledgement after a write cannot establish rollback.
      if (method == 'compareAndSet') {
        throw const NativeMembershipException('recovery_channel_unknown', RequestOutcome.unknown);
      }
      rethrow;
    } catch (_) {
      throw const NativeMembershipException('recovery_channel_unknown', RequestOutcome.unknown);
    }
  }
  _ActiveRecoveryLease _lease(String scope) {
    _gate(scope);
    final lease = Zone.current[_zoneKey];
    requireContract(lease is _ActiveRecoveryLease && lease.active &&
      identical(lease.store, this) && lease.scope == scope, 'recovery_lock_required');
    return lease as _ActiveRecoveryLease;
  }
  @override
  Future<T> runExclusive<T>(String scope, Future<T> Function() work) async {
    _gate(scope);
    // Nested acquisition would deadlock the global installation lock, including
    // nested access through another adapter instance. Do not silently make it reentrant.
    requireContract(Zone.current[_zoneKey] == null, 'recovery_nested_lock');
    final acquisition = newOperationId(), clock = Stopwatch()..start();
    _ActiveRecoveryLease? lease;
    try {
      while (true) {
        final result = await _call('tryAcquire', {'scope': scope, 'acquisitionId': acquisition}, ['version', 'busy', 'lease']);
        requireContract(result['busy'] is bool, 'recovery_channel_invalid');
        if (result['busy'] == false) {
          requireContract(isUuid(result['lease']), 'recovery_channel_invalid');
          lease = _ActiveRecoveryLease(this, scope, result['lease']! as String);
          break;
        }
        requireContract(result['lease'] == null, 'recovery_channel_invalid');
        requireContract(clock.elapsed < acquireTimeout, 'recovery_busy');
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      return await runZoned<Future<T>>(work, zoneValues: {_zoneKey: lease});
    } finally {
      if (lease != null) lease.active = false;
      // Original acquisition key also releases an acquired token whose reply was lost.
      // Native queue ordering keeps this after earlier work. Failure stays UNKNOWN.
      try {
        final result = await _call('release', {'scope': scope, 'acquisitionId': acquisition}, ['version', 'released']);
        requireContract(result['released'] == true, 'recovery_release_unknown');
      } catch (_) {
        throw const NativeMembershipException('recovery_release_unknown', RequestOutcome.unknown);
      }
    }
  }
  @override
  Future<String?> load(String scope) async {
    final lease = _lease(scope);
    final result = await _call('load', {'scope': scope, 'lease': lease.token}, ['version', 'value']);
    requireContract(result['value'] == null || result['value'] is String, 'recovery_channel_invalid');
    final value = result['value'] as String?;
    if (value != null) _value(value);
    return value;
  }
  @override
  Future<bool> compareAndSet(String scope, String? expected, String value) async {
    final lease = _lease(scope);
    _value(value); if (expected != null) _value(expected);
    final result = await _call('compareAndSet', {'scope': scope, 'lease': lease.token,
      'expected': expected, 'value': value}, ['version', 'updated']);
    if (result['updated'] is! bool) {
      throw const NativeMembershipException('recovery_channel_unknown', RequestOutcome.unknown);
    }
    return result['updated']! as bool;
  }
}
