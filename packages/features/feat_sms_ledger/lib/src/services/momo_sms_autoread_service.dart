import 'dart:async';
import 'dart:io' show Platform;

import 'package:another_telephony/telephony.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/momo_sms_ingestion_repository.dart';
import 'momo_sms_background_processor.dart';
import 'momo_sms_deps.dart';
import 'momo_sms_retry_queue.dart';
import 'momo_sms_sync_support.dart';
import 'momo_sms_telemetry.dart';

const _syncStateBoxName = 'momo_sms_sync_state';

typedef MomoSmsPermissionStatusReader = Future<PermissionStatus> Function();

typedef MomoSmsPermissionRequester = Future<PermissionStatus> Function();
typedef MomoSmsAutoreadSupportChecker = bool Function();
typedef MomoSmsInboxLoader = Future<List<SmsMessage>> Function(DateTime cutoff);

@pragma('vm:entry-point')
Future<void> momoSmsBackgroundMessageHandler(SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await MomoSmsBackgroundProcessor.handle(message);
}

enum MomoInboxSyncTrigger { initialPermissionGrant, manual }

class MomoInboxSyncResult {
  const MomoInboxSyncResult({
    required this.scannedMessages,
    required this.uploadedMessages,
    required this.duplicateMessages,
    this.oldestMessageAt,
    this.newestMessageAt,
    this.incremental = false,
  });

  final int scannedMessages;
  final int uploadedMessages;
  final int duplicateMessages;
  final DateTime? oldestMessageAt;
  final DateTime? newestMessageAt;
  final bool incremental;
}

class MomoSmsAutoreadService {
  MomoSmsAutoreadService({
    required SupabaseClient client,
    required AppAccessService appAccessService,
    Telephony? telephony,
    MomoSmsIngestionRepository? ingestionRepository,
    CrashlyticsService? crashlytics,
    OperationalHealthService? operationalHealthService,
    OpenHiveBox<String>? openBox,
    MomoSmsSyncStateStore? syncStateStore,
    MomoSmsSyncRunAuditWriter? syncRunAuditWriter,
    Future<bool> Function()? consentCallback,
    MomoSmsPermissionStatusReader? smsPermissionStatus,
    MomoSmsPermissionRequester? requestSmsPermission,
    MomoSmsAutoreadSupportChecker? supportsSmsAutoread,
    MomoSmsInboxLoader? inboxLoader,
    this.countryCode,
  })  : _client = client,
        _appAccessService = appAccessService,
        _telephony = telephony ?? Telephony.instance,
        _ingestionRepository =
            ingestionRepository ?? MomoSmsIngestionRepository(client: client),
        _crashlytics = crashlytics,
        _operationalHealthService = operationalHealthService ??
            OperationalHealthService(client: client),
        _openBox = openBox ?? openHiveBox<String>,
        _syncStateStore = syncStateStore ??
            MomoSmsSyncStateStore(
              openBox: openBox ?? openHiveBox<String>,
              boxName: _syncStateBoxName,
            ),
        _syncRunAuditWriter = syncRunAuditWriter ??
            MomoSmsSyncRunAuditWriter.supabase(
              client: client,
              crashlytics: crashlytics,
            ),
        _consentCallback = consentCallback,
        _smsPermissionStatus =
            smsPermissionStatus ?? (() => Permission.sms.status),
        _requestSmsPermission =
            requestSmsPermission ?? (() => Permission.sms.request()),
        _supportsSmsAutoreadOverride = supportsSmsAutoread,
        _inboxLoader = inboxLoader;

  final SupabaseClient _client;
  final AppAccessService _appAccessService;
  final Telephony _telephony;
  final MomoSmsIngestionRepository _ingestionRepository;
  final CrashlyticsService? _crashlytics;
  final OperationalHealthService _operationalHealthService;
  final OpenHiveBox<String> _openBox;
  final MomoSmsSyncStateStore _syncStateStore;
  final MomoSmsSyncRunAuditWriter _syncRunAuditWriter;
  final Future<bool> Function()? _consentCallback;
  final MomoSmsPermissionStatusReader _smsPermissionStatus;
  final MomoSmsPermissionRequester _requestSmsPermission;
  final MomoSmsAutoreadSupportChecker? _supportsSmsAutoreadOverride;
  final MomoSmsInboxLoader? _inboxLoader;

  /// ISO country code (e.g. 'RW') to tag every captured SMS with.
  final String? countryCode;

  static const _initialInboxSyncLookback = Duration(days: 365);

  bool _isListening = false;
  bool _isSyncingInbox = false;
  bool _requestedPermissionThisLaunch = false;
  String? _activeUserId;
  String? _initialSyncScheduledForUserId;

  Future<bool> refresh({
    bool forcePermissionRequest = false,
    Future<bool> Function()? onShowRationale,
  }) async {
    if (!_supportsSmsAutoread) {
      await stop();
      return false;
    }

    if (!EnvConfig.enableAndroidMomoSmsAutoread) {
      await stop();
      return false;
    }

    final session = _client.auth.currentSession;
    if (session == null) {
      await stop(resetPermissionPromptState: true);
      return false;
    }

    final smsEnabledInApp = await _appAccessService.isEnabled(
      AppAccessPermission.sms,
    );
    if (!smsEnabledInApp) {
      await stop();
      return false;
    }

    final permissionGranted = await _ensureSmsPermission(
      forceRequest: forcePermissionRequest,
      onShowRationale: onShowRationale ?? _consentCallback,
    );
    if (!permissionGranted) {
      await stop();
      return false;
    }

    if (!_isListening || _activeUserId != session.user.id) {
      _telephony.listenIncomingSms(
        onNewMessage: _handleForegroundMessage,
        onBackgroundMessage: momoSmsBackgroundMessageHandler,
      );
      _isListening = true;
      _activeUserId = session.user.id;
      await _crashlytics?.log(
        'momo_sms: Android SMS autoread active for ${session.user.id}',
      );
    }

    final syncState = await _readSyncState(session.user.id);
    if (!syncState.hasInitialBackfill &&
        _initialSyncScheduledForUserId != session.user.id) {
      _initialSyncScheduledForUserId = session.user.id;
      unawaited(_runInitialInboxSync());
    }

    // Drain any queued messages from previous background failures (G8).
    unawaited(_drainRetryQueue());
    return true;
  }

  Future<bool> enable({
    Future<bool> Function()? onShowRationale,
  }) async {
    if (!_supportsSmsAutoread || !EnvConfig.enableAndroidMomoSmsAutoread) {
      return false;
    }

    if (_client.auth.currentSession == null) {
      return false;
    }

    await _appAccessService.setEnabled(AppAccessPermission.sms, true);

    final activated = await refresh(
      forcePermissionRequest: true,
      onShowRationale: onShowRationale ?? _consentCallback,
    );
    if (!activated) {
      await _appAccessService.setEnabled(AppAccessPermission.sms, false);
      await stop(resetPermissionPromptState: true);
      return false;
    }

    return true;
  }

  Future<void> syncConsentFromServer() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      await _appAccessService.setEnabled(AppAccessPermission.sms, false);
      return;
    }

    try {
      final row = await _client
          .from('user_privacy_settings')
          .select('momo_sms_autoread_enabled')
          .eq('user_id', session.user.id)
          .maybeSingle();

      final enabled = row is Map<String, dynamic> &&
          row['momo_sms_autoread_enabled'] == true;
      await _appAccessService.setEnabled(AppAccessPermission.sms, enabled);
    } catch (error, stackTrace) {
      await _crashlytics?.recordError(
        error,
        stackTrace: stackTrace,
        reason: 'momo_sms_sync_consent_from_server_failed',
      );
    }
  }

  Future<void> stop({bool resetPermissionPromptState = false}) async {
    if (_supportsSmsAutoread && _isListening) {
      _telephony.listenIncomingSms(
        onNewMessage: _ignoreIncomingMessage,
        listenInBackground: false,
      );
    }

    _isListening = false;
    _activeUserId = null;
    _initialSyncScheduledForUserId = null;

    if (resetPermissionPromptState) {
      _requestedPermissionThisLaunch = false;
    }
  }

  void dispose() {
    unawaited(stop());
  }

  Future<void> disable() async {
    await _appAccessService.setEnabled(AppAccessPermission.sms, false);
    await stop();
  }

  /// Drains the Hive-based retry queue of captures that failed during
  /// background processing (G8). Called on each successful [refresh].
  Future<void> _drainRetryQueue() async {
    try {
      final queue = MomoSmsRetryQueue(openBox: _openBox);
      final result = await queue.drain(_ingestionRepository);
      await reportRetryQueueDrain(
        operationalHealthService: _operationalHealthService,
        queuedBefore: result.queuedBefore,
        queuedAfter: result.queuedAfter,
        maxQueue: momoSmsRetryQueueMaxSize,
      );
    } catch (error) {
      debugPrint('[MoMo SMS] retry queue drain failed: $error');
      await recordSmsIngestOperationalEvent(
        _operationalHealthService,
        status: OperationalHealthStatus.error,
        severity: OperationalHealthSeverity.critical,
        issueCode: 'retry_queue_drain_failed',
        message:
            'SMS retry queue drain failed before all captures could retry.',
      );
    }
  }

  Future<bool> _ensureSmsPermission({
    required bool forceRequest,
    Future<bool> Function()? onShowRationale,
  }) async {
    final status = await _smsPermissionStatus();
    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied || status.isRestricted) {
      return false;
    }

    if (!forceRequest && onShowRationale == null) {
      return false;
    }

    if (!forceRequest && _requestedPermissionThisLaunch) {
      return false;
    }

    // Show pre-permission consent disclosure (Google Play requirement).
    if (onShowRationale != null) {
      final confirmed = await onShowRationale();
      if (!confirmed) {
        return false;
      }
    }

    _requestedPermissionThisLaunch = true;
    final requestStatus = await _requestSmsPermission();
    return requestStatus.isGranted;
  }

  void _handleForegroundMessage(SmsMessage message) {
    unawaited(
      _ingestMessage(
        message,
        ingestionSource: 'android_sms_listener_foreground',
      ),
    );
  }

  void _ignoreIncomingMessage(SmsMessage _) {}

  Future<void> _runInitialInboxSync() async {
    try {
      await syncInbox(trigger: MomoInboxSyncTrigger.initialPermissionGrant);
    } catch (error, stackTrace) {
      _initialSyncScheduledForUserId = null;
      await _crashlytics?.recordError(
        error,
        stackTrace: stackTrace,
        reason: 'momo_sms_initial_inbox_sync_failed',
      );
    }
  }

  Future<MomoInboxSyncResult> syncInbox({
    required MomoInboxSyncTrigger trigger,
    ValueChanged<int>? onProgress,
  }) async {
    if (!_supportsSmsAutoread) {
      throw const MomoSmsSyncException('Android only');
    }
    if (!EnvConfig.enableAndroidMomoSmsAutoread) {
      throw const MomoSmsSyncException('Android SMS sync is disabled.');
    }
    if (_isSyncingInbox) {
      throw const MomoSmsSyncException('Sync already running');
    }

    final session = _client.auth.currentSession;
    if (session == null) {
      throw const MomoSmsSyncException('Sign in first');
    }

    final smsEnabledInApp = await _appAccessService.isEnabled(
      AppAccessPermission.sms,
    );
    if (!smsEnabledInApp) {
      throw const MomoSmsSyncException('Enable SMS sync first');
    }

    final permissionGranted = await _ensureSmsPermission(
      forceRequest: false,
      onShowRationale: _consentCallback,
    );
    if (!permissionGranted) {
      throw const MomoSmsSyncException('SMS access required');
    }

    _isSyncingInbox = true;
    final scanStartedAt = DateTime.now().toUtc();
    final syncState = await _readSyncState(session.user.id);
    final historicalCutoff = scanStartedAt.subtract(_initialInboxSyncLookback);

    // Fix 7: If local sync state is completely empty on a manual trigger,
    // the user likely reinstalled or cleared data. Force a full re-scan
    // to recover any unsynced messages.
    final isReinstallRecovery = trigger == MomoInboxSyncTrigger.manual &&
        !syncState.hasInitialBackfill &&
        syncState.lastSuccessfulSyncAt == null;

    final cutoff = trigger == MomoInboxSyncTrigger.initialPermissionGrant ||
            isReinstallRecovery
        ? historicalCutoff
        : MomoSmsSyncPlanner.resolveManualCutoff(
            syncState: syncState,
            historicalCutoff: historicalCutoff,
          );
    final incremental = trigger == MomoInboxSyncTrigger.manual &&
        !isReinstallRecovery &&
        cutoff.isAfter(historicalCutoff);

    if (isReinstallRecovery) {
      await _crashlytics?.log(
        'momo_sms: reinstall recovery detected, forcing full 365-day scan',
      );
    }

    try {
      final messages = await _loadCandidateInboxMessages(cutoff: cutoff);

      var scannedMessages = 0;
      var uploadedMessages = 0;
      var duplicateMessages = 0;
      DateTime? oldestMessageAt;
      DateTime? newestMessageAt;
      final processedMessageKeys = <String>{};

      for (final message in messages) {
        final capture = MomoSmsIngestionRepository.captureFromDeviceMessage(
          sender: message.address,
          body: message.body,
          timestampMillis: message.date,
          ingestionSource: trigger == MomoInboxSyncTrigger.manual
              ? 'android_sms_manual_sync'
              : 'android_sms_initial_sync',
          countryCode: countryCode,
        );
        if (capture == null) {
          continue;
        }
        if (capture.receivedAt.isBefore(cutoff)) {
          break;
        }
        if (!processedMessageKeys.add(capture.deviceMessageKey)) {
          continue;
        }

        scannedMessages += 1;
        onProgress?.call(scannedMessages);
        oldestMessageAt = _olderOf(oldestMessageAt, capture.receivedAt);
        newestMessageAt = _newerOf(newestMessageAt, capture.receivedAt);

        try {
          final result = await _ingestionRepository.ingestCapture(
            capture: capture,
          );
          if (result == null) {
            continue;
          }
          if (result.inserted) {
            uploadedMessages += 1;
          } else {
            duplicateMessages += 1;
          }
        } on MomoSmsRateLimitException {
          // Rate-limited: break the loop and record a partial sync.
          await _recordSyncRun(
            userId: session.user.id,
            trigger: trigger,
            status: 'rate_limited',
            lookbackDays: MomoSmsSyncPlanner.lookbackDaysFor(
              cutoff: cutoff,
              now: scanStartedAt,
            ),
            incremental: incremental,
            scanStartedAt: scanStartedAt,
            scanCompletedAt: DateTime.now().toUtc(),
            scannedMessages: scannedMessages,
            uploadedMessages: uploadedMessages,
            duplicateMessages: duplicateMessages,
            oldestMessageAt: oldestMessageAt,
            newestMessageAt: newestMessageAt,
            latestKnownMessageAt: _newerOf(
              syncState.latestKnownMessageAt,
              newestMessageAt,
            ),
            errorMessage: 'Rate-limited after $scannedMessages messages',
          );
          await _crashlytics?.log(
            'momo_sms: rate-limited after $scannedMessages messages '
            '(uploaded=$uploadedMessages)',
          );
          return MomoInboxSyncResult(
            scannedMessages: scannedMessages,
            uploadedMessages: uploadedMessages,
            duplicateMessages: duplicateMessages,
            oldestMessageAt: oldestMessageAt,
            newestMessageAt: newestMessageAt,
            incremental: incremental,
          );
        }
      }

      final latestKnownMessageAt = _newerOf(
        syncState.latestKnownMessageAt,
        newestMessageAt,
      );
      final scanCompletedAt = DateTime.now().toUtc();
      await _writeSyncState(
        session.user.id,
        MomoSmsSyncState(
          initialBackfillCompletedAt:
              trigger == MomoInboxSyncTrigger.initialPermissionGrant
                  ? scanCompletedAt
                  : syncState.initialBackfillCompletedAt,
          lastSuccessfulSyncAt: scanCompletedAt,
          latestKnownMessageAt: latestKnownMessageAt,
        ),
      );
      await _recordSyncRun(
        userId: session.user.id,
        trigger: trigger,
        status: 'succeeded',
        lookbackDays: MomoSmsSyncPlanner.lookbackDaysFor(
          cutoff: cutoff,
          now: scanStartedAt,
        ),
        incremental: incremental,
        scanStartedAt: scanStartedAt,
        scanCompletedAt: scanCompletedAt,
        scannedMessages: scannedMessages,
        uploadedMessages: uploadedMessages,
        duplicateMessages: duplicateMessages,
        oldestMessageAt: oldestMessageAt,
        newestMessageAt: newestMessageAt,
        latestKnownMessageAt: latestKnownMessageAt,
      );
      await _crashlytics?.log(
        'momo_sms: ${trigger.name} scanned=$scannedMessages '
        'uploaded=$uploadedMessages duplicates=$duplicateMessages',
      );
      return MomoInboxSyncResult(
        scannedMessages: scannedMessages,
        uploadedMessages: uploadedMessages,
        duplicateMessages: duplicateMessages,
        oldestMessageAt: oldestMessageAt,
        newestMessageAt: newestMessageAt,
        incremental: incremental,
      );
    } catch (error, stackTrace) {
      await _recordSyncRun(
        userId: session.user.id,
        trigger: trigger,
        status: 'failed',
        lookbackDays: MomoSmsSyncPlanner.lookbackDaysFor(
          cutoff: cutoff,
          now: scanStartedAt,
        ),
        incremental: incremental,
        scanStartedAt: scanStartedAt,
        scanCompletedAt: DateTime.now().toUtc(),
        errorMessage: error.toString(),
        latestKnownMessageAt: syncState.latestKnownMessageAt,
      );
      await _crashlytics?.recordError(
        error,
        stackTrace: stackTrace,
        reason: 'momo_sms_inbox_sync_failed',
      );
      rethrow;
    } finally {
      _isSyncingInbox = false;
    }
  }

  Future<void> _ingestMessage(
    SmsMessage message, {
    required String ingestionSource,
  }) async {
    await _reportSenderDriftIfNeeded(
      sender: message.address,
      body: message.body,
      ingestionSource: ingestionSource,
    );
    final capture = MomoSmsIngestionRepository.captureFromDeviceMessage(
      sender: message.address,
      body: message.body,
      timestampMillis: message.date,
      ingestionSource: ingestionSource,
      countryCode: countryCode,
    );
    if (capture == null) {
      return;
    }

    try {
      await _ingestionRepository.ingestCapture(capture: capture);
    } catch (error, stackTrace) {
      await _queueRetryCapture(capture);
      await _crashlytics?.recordError(
        error,
        stackTrace: stackTrace,
        reason: 'momo_sms_ingestion_failed',
      );
    }
  }

  Future<List<SmsMessage>> _loadCandidateInboxMessages({
    required DateTime cutoff,
  }) async {
    if (_inboxLoader != null) {
      return _inboxLoader(cutoff);
    }

    final cutoffMillis = cutoff.millisecondsSinceEpoch.toString();
    const senderIds = MomoSmsIngestionRepository.approvedInboxSenderIds;

    // Fix 8: Query all sender IDs in parallel for faster inbox loading.
    final perSenderResults = await Future.wait(
      senderIds.map((senderId) async {
        final filter = SmsFilter.where(SmsColumn.ADDRESS)
            .equals(senderId)
            .and(SmsColumn.DATE)
            .greaterThanOrEqualTo(cutoffMillis);
        return _telephony.getInboxSms(
          columns: const [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
          filter: filter,
          sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
        );
      }),
    );

    final messages = perSenderResults.expand((m) => m).toList()
      ..sort((a, b) => (b.date ?? 0).compareTo(a.date ?? 0));
    return messages;
  }

  bool get _supportsSmsAutoread {
    final override = _supportsSmsAutoreadOverride;
    if (override != null) {
      return override();
    }
    if (kIsWeb) {
      return false;
    }
    return Platform.isAndroid;
  }

  Future<MomoSmsSyncState> _readSyncState(String userId) {
    return _syncStateStore.read(userId);
  }

  Future<void> _writeSyncState(String userId, MomoSmsSyncState state) {
    return _syncStateStore.write(userId, state);
  }

  Future<void> _recordSyncRun({
    required String userId,
    required MomoInboxSyncTrigger trigger,
    required String status,
    required int lookbackDays,
    required bool incremental,
    required DateTime scanStartedAt,
    DateTime? scanCompletedAt,
    int scannedMessages = 0,
    int uploadedMessages = 0,
    int duplicateMessages = 0,
    DateTime? oldestMessageAt,
    DateTime? newestMessageAt,
    DateTime? latestKnownMessageAt,
    String? errorMessage,
  }) async {
    // Fix 9: Include device metadata in every sync run record.
    final deviceMetadata = <String, dynamic>{
      'platform': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
    };

    await _syncRunAuditWriter.record(
      MomoSmsSyncRunRecord(
        userId: userId,
        trigger: _syncTriggerValue(trigger),
        status: status,
        lookbackDays: lookbackDays,
        incremental: incremental,
        scanStartedAt: scanStartedAt,
        scanCompletedAt: scanCompletedAt,
        scannedMessages: scannedMessages,
        uploadedMessages: uploadedMessages,
        duplicateMessages: duplicateMessages,
        oldestMessageAt: oldestMessageAt,
        newestMessageAt: newestMessageAt,
        latestKnownMessageAt: latestKnownMessageAt,
        errorMessage: errorMessage,
        metadata: deviceMetadata,
      ),
    );
  }

  Future<int> getRetryQueueSize() async {
    if (!_supportsSmsAutoread) {
      return 0;
    }
    return MomoSmsRetryQueue(openBox: _openBox).size();
  }

  Future<void> _queueRetryCapture(MomoSmsCapture capture) async {
    final queue = MomoSmsRetryQueue(openBox: _openBox);
    final queued = await queue.enqueue(capture);
    if (!queued) {
      final size = await queue.size();
      if (size >= momoSmsRetryQueueMaxSize) {
        await reportRetryQueueFull(
          operationalHealthService: _operationalHealthService,
          currentSize: size,
          maxQueue: momoSmsRetryQueueMaxSize,
        );
      }
    } else {
      await reportRetryQueueThreshold(
        operationalHealthService: _operationalHealthService,
        queueSize: await queue.size(),
        maxQueue: momoSmsRetryQueueMaxSize,
        thresholds: momoSmsRetryQueueTelemetryThresholds,
      );
    }
  }

  DateTime? _olderOf(DateTime? left, DateTime? right) {
    if (left == null) {
      return right;
    }
    if (right == null) {
      return left;
    }
    return left.isBefore(right) ? left : right;
  }

  DateTime? _newerOf(DateTime? left, DateTime? right) {
    if (left == null) {
      return right;
    }
    if (right == null) {
      return left;
    }
    return left.isAfter(right) ? left : right;
  }

  String _syncTriggerValue(MomoInboxSyncTrigger trigger) {
    return switch (trigger) {
      MomoInboxSyncTrigger.initialPermissionGrant => 'initial_permission_grant',
      MomoInboxSyncTrigger.manual => 'manual',
    };
  }

  Future<void> _reportSenderDriftIfNeeded({
    required String? sender,
    required String? body,
    required String ingestionSource,
  }) async {
    await reportBackgroundSenderDriftIfNeeded(
      client: _client,
      sender: sender,
      body: body,
    );
  }
}

class MomoSmsSyncException implements Exception {
  const MomoSmsSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}
