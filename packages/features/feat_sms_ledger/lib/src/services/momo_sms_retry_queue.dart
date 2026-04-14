import 'dart:convert';

import 'package:core_utils/core_utils.dart';

import '../repositories/momo_sms_ingestion_repository.dart';
import 'momo_sms_deps.dart';

/// Constants for the SMS retry queue (Hive-based).
const momoSmsRetryQueueBoxName = 'momo_sms_retry_queue';
const momoSmsRetryQueueMaxSize = 200;
const momoSmsRetryQueueTelemetryThresholds = <int>{1, 10, 25, 50, 100, 200};

/// Manages a Hive-based retry queue for MoMo SMS captures that failed
/// to ingest on the first attempt.
class MomoSmsRetryQueue {
  const MomoSmsRetryQueue({
    required OpenHiveBox<String> openBox,
    this.boxName = momoSmsRetryQueueBoxName,
    this.maxSize = momoSmsRetryQueueMaxSize,
  }) : _openBox = openBox;

  final OpenHiveBox<String> _openBox;
  final String boxName;
  final int maxSize;

  /// Returns the current retry queue size.
  Future<int> size() async {
    try {
      final box = await _openBox(boxName);
      return box.length;
    } catch (_) {
      return 0;
    }
  }

  /// Enqueues a capture for later retry.
  /// Returns `true` if the capture was queued, `false` if the queue is full
  /// or the key already exists.
  Future<bool> enqueue(MomoSmsCapture capture) async {
    try {
      final box = await _openBox(boxName);
      final alreadyQueued = box.containsKey(capture.deviceMessageKey);
      if (!alreadyQueued && box.length >= maxSize) {
        return false;
      }

      await box.put(
        capture.deviceMessageKey,
        jsonEncode({
          'sender': capture.sender,
          'body': capture.body,
          'deviceMessageKey': capture.deviceMessageKey,
          'receivedAt': capture.receivedAt.toUtc().toIso8601String(),
          'ingestionSource': capture.ingestionSource,
        }),
      );
      return true;
    } catch (error) {
      AfriLogger.warn('MoMoSMS', 'Retry queue write failed: $error');
      return false;
    }
  }

  /// Drains all queued captures, attempting to re-ingest each one.
  /// Returns a [RetryQueueDrainResult] summarizing what happened.
  Future<RetryQueueDrainResult> drain(
    MomoSmsIngestionRepository ingestionRepository,
  ) async {
    final box = await _openBox(boxName);
    if (box.isEmpty) {
      return const RetryQueueDrainResult(
        queuedBefore: 0,
        queuedAfter: 0,
      );
    }

    final queuedBefore = box.length;
    final keys = box.keys.toList();
    for (final key in keys) {
      final json = box.get(key);
      if (json == null) continue;

      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        final capture = MomoSmsCapture(
          sender: map['sender'] as String,
          body: map['body'] as String,
          deviceMessageKey: map['deviceMessageKey'] as String,
          receivedAt: DateTime.parse(map['receivedAt'] as String),
          ingestionSource: map['ingestionSource'] as String,
        );
        await ingestionRepository.ingestCapture(capture: capture);
        await box.delete(key);
      } catch (error) {
        // Leave in queue for next drain attempt.
        AfriLogger.warn('MoMoSMS', 'Retry failed for key=$key: $error');
      }
    }

    return RetryQueueDrainResult(
      queuedBefore: queuedBefore,
      queuedAfter: box.length,
    );
  }
}

/// Result of a retry queue drain operation.
class RetryQueueDrainResult {
  const RetryQueueDrainResult({
    required this.queuedBefore,
    required this.queuedAfter,
  });

  final int queuedBefore;
  final int queuedAfter;

  int get drainedCount => queuedBefore - queuedAfter;
  bool get allCleared => queuedAfter == 0;
  bool get hadEntries => queuedBefore > 0;
}
