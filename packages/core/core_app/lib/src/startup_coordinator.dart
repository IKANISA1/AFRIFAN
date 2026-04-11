import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_biopay/feat_biopay.dart';
import 'package:feat_sms_ledger/feat_sms_ledger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppStartupOptions {
  const AppStartupOptions({
    this.configureDeviceChrome = true,
    this.initializePersistence = true,
    this.initializeBackend = true,
    this.initializeSmsAutoread = true,
    this.deferNonCriticalBackendInitialization = true,
    this.firebaseOptions,
    this.criticalBackendOverride,
    this.deferredBackendOverride,
  });

  const AppStartupOptions.integrationTest()
    : configureDeviceChrome = false,
      initializePersistence = false,
      initializeBackend = false,
      initializeSmsAutoread = false,
      deferNonCriticalBackendInitialization = false,
      firebaseOptions = null,
      criticalBackendOverride = null,
      deferredBackendOverride = null;

  final bool configureDeviceChrome;
  final bool initializePersistence;
  final bool initializeBackend;
  final bool initializeSmsAutoread;
  final bool deferNonCriticalBackendInitialization;
  final FirebaseOptions? firebaseOptions;
  final Future<void> Function(ClubConfig config)? criticalBackendOverride;
  final Future<void> Function(ClubConfig config)? deferredBackendOverride;
}

/// Centralizes startup side effects so app bootstrap stays declarative.
class AppStartupCoordinator {
  AppStartupCoordinator({this.options = const AppStartupOptions()});

  final AppStartupOptions options;
  static StreamSubscription<AuthState>? _authLifecycleSubscription;
  static StreamSubscription<AuthState>? _smsAutoreadAuthSubscription;
  Future<void>? _deferredInitializationTask;
  Future<void>? _scheduledDeferredInitialization;

  Future<void> initialize(ClubConfig config) async {
    ColorTokens.init(config.colors);

    if (options.configureDeviceChrome) {
      await _configureDeviceChrome();
    }
    if (options.initializePersistence) {
      await _initializePersistence();
      if (config.hasBiopay) {
        await _purgeLegacyBiopayCache();
      }
    }
    if (options.initializeBackend) {
      await _initializeCriticalBackend(config);
      if (!options.deferNonCriticalBackendInitialization) {
        await _ensureDeferredBackendInitialized(config);
      }
    }
  }

  Future<void>? scheduleDeferredInitialization(ClubConfig config) {
    if (!options.initializeBackend ||
        !options.deferNonCriticalBackendInitialization) {
      return null;
    }

    if (_scheduledDeferredInitialization != null) {
      return _scheduledDeferredInitialization;
    }

    final completer = Completer<void>();
    _scheduledDeferredInitialization = completer.future;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        _runDeferredInitialization(config).whenComplete(() {
          if (!completer.isCompleted) {
            completer.complete();
          }
        }),
      );
    });
    WidgetsBinding.instance.scheduleFrame();
    return completer.future;
  }

  Future<void> _configureDeviceChrome() async {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: ColorTokens.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  Future<void> _initializePersistence() async {
    await Hive.initFlutter();
  }

  Future<void> _initializeCriticalBackend(ClubConfig config) async {
    if (options.criticalBackendOverride case final override?) {
      await override(config);
      return;
    }

    final firebaseReady = await FirebaseBootstrapService.initialize(
      options: options.firebaseOptions,
    );
    final appCheckReady = await AppCheckService.initialize();

    if (kReleaseMode && config.hasBiopay) {
      if (!firebaseReady) {
        throw StateError(
          'BioPay-enabled release builds require Firebase initialization.',
        );
      }
      if (!appCheckReady) {
        throw StateError(
          'BioPay-enabled release builds require Firebase App Check.',
        );
      }
    }

    await SupabaseClientFactory.initialize(
      supabaseUrl: config.supabaseUrl,
      supabaseAnonKey: config.supabaseAnonKey,
    );
  }

  Future<void> _initializeDeferredBackend(ClubConfig config) async {
    if (options.deferredBackendOverride case final override?) {
      await override(config);
      return;
    }

    await _registerAuthLifecycleObservers(config);
    await PushNotificationService.initialize(clubId: config.clubId);
    await _syncFantasyTopics();

    final countryRepo = CountryRepository(client: SupabaseClientFactory.client);
    await countryRepo.loadAndInject();

    if (options.initializeSmsAutoread) {
      await _initializeSmsAutoread(config);
    }
  }

  Future<void> _ensureDeferredBackendInitialized(ClubConfig config) {
    return _deferredInitializationTask ??= _initializeDeferredBackend(config);
  }

  Future<void> _runDeferredInitialization(ClubConfig config) async {
    try {
      await _ensureDeferredBackendInitialized(config);
    } catch (error, stackTrace) {
      AfriLogger.error(
        'Bootstrap',
        'Deferred startup initialization failed (non-fatal).',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _purgeLegacyBiopayCache() async {
    final cacheService = BiopayCacheService(
      openBox: <T>(String name) async => Hive.openBox<T>(name),
      deleteBox: Hive.deleteBoxFromDisk,
    );
    await cacheService.purgeLegacyPersistentCache();
  }

  Future<void> _registerAuthLifecycleObservers(ClubConfig config) async {
    await _authLifecycleSubscription?.cancel();
    final cacheService = BiopayCacheService();
    _authLifecycleSubscription = SupabaseClientFactory.authStateChanges.listen((
      auth,
    ) {
      if (config.hasBiopay && auth.event == AuthChangeEvent.signedOut) {
        unawaited(cacheService.clear());
      }
      if (auth.event == AuthChangeEvent.signedIn ||
          auth.event == AuthChangeEvent.signedOut ||
          auth.event == AuthChangeEvent.tokenRefreshed ||
          auth.event == AuthChangeEvent.userUpdated) {
        unawaited(_syncFantasyTopics());
      }
    });
  }

  Future<void> _syncFantasyTopics() async {
    try {
      final result = await SupabaseClientFactory.client.rpc(
        'fantasy_get_notification_topics',
      );
      final rows = (result as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);

      if (rows.isNotEmpty) {
        for (final row in rows) {
          final topic = row['topic']?.toString().trim() ?? '';
          if (topic.isEmpty) {
            continue;
          }
          final enabled = row['enabled'] == null || row['enabled'] == true;
          if (enabled) {
            await PushNotificationService.subscribeToTopic(topic);
          } else {
            await PushNotificationService.unsubscribeFromTopic(topic);
          }
        }
        return;
      }
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'Bootstrap',
        'Fantasy topic sync fallback engaged: $error',
      );
      if (kDebugMode) {
        AfriLogger.error(
          'Bootstrap',
          'Fantasy topic sync stack trace.',
          error,
          stackTrace,
        );
      }
    }

    await PushNotificationService.subscribeToTopic('fantasy_pl_2526');
    await PushNotificationService.subscribeToTopic('fantasy_wc_2026');
  }

  Future<void> _initializeSmsAutoread(ClubConfig config) async {
    try {
      if (!EnvConfig.enableAndroidMomoSmsAutoread) {
        AfriLogger.info('Bootstrap', 'SMS autoread disabled for this build.');
        return;
      }

      final client = SupabaseClientFactory.client;
      final smsService = MomoSmsAutoreadService(
        client: client,
        appAccessService: AppAccessService(openBox: openHiveBox<bool>),
        countryCode: config.countryCode,
      );
      final reconciliationService = LedgerReconciliationService(client: client);

      await _smsAutoreadAuthSubscription?.cancel();
      _smsAutoreadAuthSubscription = client.auth.onAuthStateChange.listen((
        event,
      ) {
        if (event.event == AuthChangeEvent.signedIn ||
            event.event == AuthChangeEvent.tokenRefreshed) {
          smsService.refresh();
          _runReconciliation(reconciliationService);
        } else if (event.event == AuthChangeEvent.signedOut) {
          smsService.stop(resetPermissionPromptState: true);
        }
      });

      if (client.auth.currentSession != null) {
        smsService.refresh();
        _runReconciliation(reconciliationService);
      }
    } catch (error, stackTrace) {
      AfriLogger.error(
        'Bootstrap',
        'SMS autoread init failed (non-fatal).',
        error,
        stackTrace,
      );
    }
  }

  void _runReconciliation(LedgerReconciliationService service) {
    Future<void>.delayed(const Duration(seconds: 5), () async {
      try {
        final count = await service.reconcilePending();
        if (count > 0) {
          AfriLogger.info('Bootstrap', 'Reconciled $count contributions.');
        }
      } catch (error, stackTrace) {
        AfriLogger.error(
          'Bootstrap',
          'Reconciliation failed (non-fatal).',
          error,
          stackTrace,
        );
      }
    });
  }
}
