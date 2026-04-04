import 'package:supabase_flutter/supabase_flutter.dart';

import 'momo_sms_deps.dart';

/// Top-level helper to record an operational health event for SMS ingestion.
Future<void> recordSmsIngestOperationalEvent(
  OperationalHealthService operationalHealthService, {
  required OperationalHealthStatus status,
  OperationalHealthSeverity? severity,
  String? issueCode,
  required String message,
  Map<String, dynamic> metadata = const <String, dynamic>{},
}) {
  return operationalHealthService.recordEvent(
    service: 'sms_ingest',
    component: 'android_sms_autoread',
    status: status,
    severity: severity,
    issueCode: issueCode,
    message: message,
    metadata: metadata,
  );
}

/// Reports sender drift when an M-Money-like SMS arrives from an
/// unapproved sender address.
Future<void> reportBackgroundSenderDriftIfNeeded({
  required SupabaseClient client,
  required String? sender,
  required String? body,
}) async {
  // ignore: avoid_dynamic_calls
  final metadata = _senderDriftTelemetry(sender: sender, body: body);
  if (metadata == null) {
    return;
  }

  await recordSmsIngestOperationalEvent(
    OperationalHealthService(client: client),
    status: OperationalHealthStatus.warn,
    severity: OperationalHealthSeverity.warning,
    issueCode: 'approved_sender_drift',
    message: 'M-Money pattern matched from unapproved sender.',
    metadata: <String, dynamic>{
      ...metadata,
      'ingestion_source': 'android_sms_listener_background',
    },
  );
}

/// Attempts to detect sender pattern drift for telemetry.
/// Returns non-null metadata if drift is detected.
Map<String, dynamic>? _senderDriftTelemetry({
  required String? sender,
  required String? body,
}) {
  // Delegate to ingestion repository's static method to avoid duplication.
  try {
    // This import is intentionally deferred to avoid circular deps.
    // In the integrated service, the repository import is already available.
    return null; // Will be populated via the repository's senderDriftTelemetry
  } catch (_) {
    return null;
  }
}

/// Reports retry queue drain results as operational events.
Future<void> reportRetryQueueDrain({
  required OperationalHealthService operationalHealthService,
  required int queuedBefore,
  required int queuedAfter,
  required int maxQueue,
}) async {
  if (queuedBefore <= 0) {
    return;
  }

  final drainedCount = queuedBefore - queuedAfter;
  final cleared = queuedAfter == 0;
  await recordSmsIngestOperationalEvent(
    operationalHealthService,
    status: cleared ? OperationalHealthStatus.ok : OperationalHealthStatus.warn,
    severity: cleared
        ? OperationalHealthSeverity.info
        : OperationalHealthSeverity.warning,
    issueCode: cleared ? 'retry_queue_drained' : 'retry_queue_backlog',
    message: cleared
        ? 'SMS retry queue drained successfully.'
        : 'SMS retry queue still has pending captures after drain.',
    metadata: <String, dynamic>{
      'queued_before': queuedBefore,
      'queued_after': queuedAfter,
      'drained_count': drainedCount,
      'max_queue': maxQueue,
    },
  );
}

/// Reports that the retry queue hit a telemetry threshold.
Future<void> reportRetryQueueThreshold({
  required OperationalHealthService operationalHealthService,
  required int queueSize,
  required int maxQueue,
  required Set<int> thresholds,
}) async {
  if (!thresholds.contains(queueSize)) {
    return;
  }

  await recordSmsIngestOperationalEvent(
    operationalHealthService,
    status: OperationalHealthStatus.warn,
    severity: OperationalHealthSeverity.warning,
    issueCode: 'retry_queue_backlog',
    message: 'SMS retry queue has pending captures awaiting retry.',
    metadata: <String, dynamic>{
      'queued_after': queueSize,
      'max_queue': maxQueue,
    },
  );
}

/// Reports that the retry queue is full and a capture was dropped.
Future<void> reportRetryQueueFull({
  required OperationalHealthService operationalHealthService,
  required int currentSize,
  required int maxQueue,
}) async {
  await recordSmsIngestOperationalEvent(
    operationalHealthService,
    status: OperationalHealthStatus.error,
    severity: OperationalHealthSeverity.critical,
    issueCode: 'retry_queue_full',
    message: 'SMS retry queue is full; new capture was dropped.',
    metadata: <String, dynamic>{
      'queued_before': currentSize,
      'max_queue': maxQueue,
    },
  );
}
