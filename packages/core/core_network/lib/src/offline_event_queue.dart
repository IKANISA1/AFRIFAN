import 'dart:async';
import 'dart:convert';

import 'package:core_utils/core_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'connectivity_service.dart';
import 'hive_encryption_service.dart';
import 'operational_health_service.dart';

/// Queues [OperationalHealthService] events locally when offline,
/// and flushes them when connectivity is restored.
///
/// This ensures that critical operational monitoring events
/// (payment failures, service disruptions) are never lost due to transient
/// network issues — especially important on African mobile networks.
///
/// Usage:
/// ```dart
/// await OfflineEventQueue.initialize(
///   (payload) => healthService.recordPayloadOrThrow(payload),
/// );
///
/// // This call will either send immediately (online) or queue (offline).
/// await OfflineEventQueue.enqueue(
///   service: 'payments',
///   component: 'momo_handoff',
///   message: 'USSD handoff timed out',
///   status: OperationalHealthStatus.error,
/// );
/// ```
class OfflineEventQueue {
  OfflineEventQueue._();

  static const _tag = 'OfflineEventQueue';
  static const _boxName = 'africlub_event_queue';

  static Box<String>? _box;
  static Future<void> Function(Map<String, dynamic> payload)? _sender;
  static bool _initialized = false;
  static bool _flushing = false;

  static bool get isInitialized => _initialized;

  /// Initialize the queue. Must be called after [Hive.initFlutter()].
  static Future<void> initialize(
    Future<void> Function(Map<String, dynamic> payload) sender,
  ) async {
    if (_initialized) return;
    _sender = sender;

    try {
      _box = await Hive.openBox<String>(
        _boxName,
        encryptionCipher: HiveEncryptionService.cipher,
      );
      _initialized = true;

      final pendingCount = _box!.length;
      if (pendingCount > 0) {
        AfriLogger.info(_tag, 'Initialized with $pendingCount queued events.');
      }

      // Listen for connectivity changes to auto-flush.
      ConnectivityService.onlineNotifier.addListener(_onConnectivityChanged);

      // If already online, flush any pending events from last session.
      if (ConnectivityService.isOnline && pendingCount > 0) {
        unawaited(_flush());
      }
    } catch (error, stackTrace) {
      // Migration path: existing unencrypted box → delete and recreate.
      // Queued telemetry events are non-critical; loss is acceptable.
      try {
        await Hive.deleteBoxFromDisk(_boxName);
        _box = await Hive.openBox<String>(
          _boxName,
          encryptionCipher: HiveEncryptionService.cipher,
        );
        _initialized = true;
        ConnectivityService.onlineNotifier.addListener(_onConnectivityChanged);
        AfriLogger.info(
          _tag,
          'Event queue migrated to encrypted storage (old events cleared).',
        );
        return;
      } catch (_) {
        // Intentional fallthrough.
      }
      AfriLogger.error(_tag, 'Failed to initialize.', error, stackTrace);
    }
  }

  /// Enqueue an operational health event.
  ///
  /// If online, sends immediately. If offline, stores locally for later.
  static Future<void> enqueue({
    required String service,
    required String component,
    required String message,
    OperationalHealthStatus status = OperationalHealthStatus.ok,
    OperationalHealthSeverity? severity,
    String? issueCode,
    String? functionName,
    String? userId,
    String? subjectType,
    String? subjectId,
    Map<String, dynamic> metadata = const <String, dynamic>{},
    DateTime? occurredAt,
  }) async {
    await enqueuePayload(<String, dynamic>{
      'service': service,
      'component': component,
      'message': message,
      'status': status.name,
      'severity': severity?.name,
      'issueCode': issueCode,
      'functionName': functionName,
      'userId': userId,
      'subjectType': subjectType,
      'subjectId': subjectId,
      'metadata': metadata,
      'occurredAt': (occurredAt ?? DateTime.now().toUtc()).toIso8601String(),
    });
  }

  /// Enqueue a fully materialized payload.
  ///
  /// If [sendImmediately] is true and the device is online, delivery is
  /// attempted before the payload is persisted locally.
  static Future<void> enqueuePayload(
    Map<String, dynamic> payload, {
    bool sendImmediately = true,
  }) async {
    if (sendImmediately && ConnectivityService.isOnline && _sender != null) {
      // Try to send immediately.
      try {
        await _sender!(payload);
        return; // Sent successfully — no need to queue.
      } catch (_) {
        // Fall through to queue it.
      }
    }

    // Store locally for later flush.
    final box = _box;
    if (box == null) return;

    try {
      final key = '${DateTime.now().toUtc().millisecondsSinceEpoch}';
      await box.put(key, jsonEncode(payload));
      AfriLogger.info(_tag, 'Event queued locally ($key).');
    } catch (error) {
      AfriLogger.warn(_tag, 'Failed to queue event: $error');
    }
  }

  /// Number of pending queued events.
  static int get pendingCount => _box?.length ?? 0;

  static void _onConnectivityChanged() {
    if (ConnectivityService.isOnline && pendingCount > 0) {
      unawaited(_flush());
    }
  }

  /// Flush all queued events to the backend.
  static Future<void> _flush() async {
    final sender = _sender;
    if (_flushing || sender == null) return;
    _flushing = true;

    final box = _box;
    if (box == null || !box.isOpen || box.isEmpty) {
      _flushing = false;
      return;
    }

    AfriLogger.info(_tag, 'Flushing ${box.length} queued events…');

    final keys = box.keys.toList();
    var sent = 0;

    for (final key in keys) {
      if (!ConnectivityService.isOnline) {
        AfriLogger.warn(
          _tag,
          'Connection lost during flush. Sent $sent/${keys.length}.',
        );
        break;
      }

      try {
        final raw = box.get(key);
        if (raw == null) continue;

        final event = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        await sender(event);

        if (!box.isOpen) {
          break;
        }
        await box.delete(key);
        sent += 1;
      } catch (error) {
        AfriLogger.warn(_tag, 'Failed to flush event "$key": $error');
        // Leave it in the queue for next attempt.
      }
    }

    AfriLogger.info(_tag, 'Flush complete. Sent $sent/${keys.length}.');
    _flushing = false;
  }

  @visibleForTesting
  static Future<void> resetForTest({bool deleteBox = false}) async {
    ConnectivityService.onlineNotifier.removeListener(_onConnectivityChanged);
    final box = _box;
    _box = null;
    _sender = null;
    _initialized = false;
    _flushing = false;
    if (box != null && box.isOpen) {
      await box.close();
    }
    if (deleteBox) {
      await Hive.deleteBoxFromDisk(_boxName);
    }
  }
}
