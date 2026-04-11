import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:another_telephony/telephony.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/momo_sms_ingestion_repository.dart';
import 'momo_sms_deps.dart';
import 'momo_sms_retry_queue.dart';
import 'momo_sms_telemetry.dart';

/// Background SMS handler — entry point for the Android telephony plugin.
///
/// This isolate runs when the app is backgrounded. It pre-queues captures
/// to Hive before attempting Supabase ingestion, ensuring zero message loss.
@pragma('vm:entry-point')
Future<void> momoSmsBackgroundMessageHandler(SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await MomoSmsBackgroundProcessor.handle(message);
}

/// Processes incoming SMS messages in the background isolate.
///
/// Strategy:
/// 1. Pre-queue capture to Hive (guarantees no loss)
/// 2. Initialize Supabase client
/// 3. Attempt ingestion
/// 4. On success: remove from queue
/// 5. On failure: leave in queue for foreground drain
class MomoSmsBackgroundProcessor {
  static bool _hiveInitialized = false;
  static bool _supabaseInitialized = false;
  static const InitializeHive _initializeHive = initializeHiveRuntime;
  static const OpenHiveBox<bool> _openAppAccessBox = openHiveBox<bool>;
  static const OpenHiveBox<String> _openRetryQueueBox = openHiveBox<String>;

  static Future<void> handle(SmsMessage message) async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }

    if (!EnvConfig.enableAndroidMomoSmsAutoread) {
      return;
    }

    await _ensureHiveInitialized();
    final appAccessService = AppAccessService(openBox: _openAppAccessBox);
    final smsEnabledInApp = await appAccessService.isEnabled(
      AppAccessPermission.sms,
    );
    if (!smsEnabledInApp) {
      return;
    }

    // Pre-queue the capture to Hive BEFORE Supabase init to guarantee
    // the message is never lost.
    final capture = MomoSmsIngestionRepository.captureFromDeviceMessage(
      sender: message.address,
      body: message.body,
      timestampMillis: message.date,
      ingestionSource: 'android_sms_listener_background',
      countryCode: EnvConfig.countryCode,
    );
    if (capture == null) {
      // Not an approved sender — check for drift telemetry.
      SupabaseClient? driftClient;
      try {
        driftClient = await _ensureSupabaseClient();
      } catch (_) {
        return;
      }
      if (driftClient != null) {
        await reportBackgroundSenderDriftIfNeeded(
          client: driftClient,
          sender: message.address,
          body: message.body,
        );
      }
      return;
    }

    // Pre-queue before any network call.
    try {
      final box = await _openRetryQueueBox(momoSmsRetryQueueBoxName);
      if (box.length < momoSmsRetryQueueMaxSize) {
        final payload = jsonEncode({
          'sender': capture.sender,
          'body': capture.body,
          'deviceMessageKey': capture.deviceMessageKey,
          'receivedAt': capture.receivedAt.toUtc().toIso8601String(),
          'ingestionSource': capture.ingestionSource,
        });
        await box.put(capture.deviceMessageKey, payload);
      }
    } catch (_) {
      // Hive write failed — continue with ingestion attempt anyway.
    }

    SupabaseClient? client;
    try {
      client = await _ensureSupabaseClient();
    } catch (_) {
      // Supabase init failed — capture is already queued for retry.
      return;
    }
    if (client == null || client.auth.currentUser?.id == null) {
      return;
    }

    try {
      final repository = MomoSmsIngestionRepository(client: client);
      await repository.ingestCapture(capture: capture);

      // Ingestion succeeded — remove pre-queued retry entry.
      try {
        final box = await _openRetryQueueBox(momoSmsRetryQueueBoxName);
        await box.delete(capture.deviceMessageKey);
      } catch (_) {
        // Non-critical: entry will be de-duplicated on retry drain.
      }
    } catch (error) {
      AfriLogger.warn(
        'MomoSmsBackground',
        'Background ingestion failed and capture remains queued for retry: $error',
      );
      // Capture was pre-queued before Supabase init, so no need to
      // queue again. Only record telemetry thresholds.
      try {
        final box = await _openRetryQueueBox(momoSmsRetryQueueBoxName);
        final queueSize = box.length;
        if (momoSmsRetryQueueTelemetryThresholds.contains(queueSize)) {
          await recordSmsIngestOperationalEvent(
            OperationalHealthService(client: client),
            status: OperationalHealthStatus.warn,
            severity: OperationalHealthSeverity.warning,
            issueCode: 'retry_queue_backlog',
            message: 'SMS retry queue has pending captures awaiting retry.',
            metadata: <String, dynamic>{
              'queued_after': queueSize,
              'max_queue': momoSmsRetryQueueMaxSize,
            },
          );
        }
      } catch (queueError) {
        AfriLogger.error(
          'MomoSmsBackground',
          'Retry queue telemetry failed.',
          queueError,
        );
      }
    }
  }

  static Future<void> _ensureHiveInitialized() async {
    if (_hiveInitialized) {
      return;
    }
    await _initializeHive();
    _hiveInitialized = true;
  }

  static Future<SupabaseClient?> _ensureSupabaseClient() async {
    final configurationError = EnvConfig.criticalConfigurationError;
    if (configurationError != null) {
      AfriLogger.warn(
        'MomoSmsBackground',
        'Skipping Supabase initialization because runtime configuration is incomplete: $configurationError',
      );
      return null;
    }

    if (!_supabaseInitialized) {
      try {
        await Supabase.initialize(
          url: EnvConfig.supabaseUrl,
          anonKey: EnvConfig.supabaseAnonKey,
        );
      } catch (error) {
        final message = error.toString().toLowerCase();
        if (!message.contains('already initialized')) {
          AfriLogger.error(
            'MomoSmsBackground',
            'Supabase initialization failed in background isolate.',
            error,
          );
          return null;
        }
      }
      _supabaseInitialized = true;
    }

    return Supabase.instance.client;
  }
}
