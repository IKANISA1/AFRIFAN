import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
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
        await _initializeDeferredBackend(config);
      }
    }
  }

  Future<void>? scheduleDeferredInitialization(ClubConfig config) {
    if (!options.initializeBackend ||
        !options.deferNonCriticalBackendInitialization) {
      return null;
    }

    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        _runDeferredInitialization(config).whenComplete(completer.complete),
      );
    });
    WidgetsBinding.instance.scheduleFrame();
    return completer.future;
  }

  Future<void> _configureDeviceChrome() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

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

    final countryRepo = CountryRepository(client: SupabaseClientFactory.client);
    await countryRepo.loadAndInject();

    if (options.initializeSmsAutoread) {
      _initializeSmsAutoread(config);
    }
  }

  Future<void> _runDeferredInitialization(ClubConfig config) async {
    try {
      await _initializeDeferredBackend(config);
    } catch (error) {
      debugPrint(
        '[Bootstrap] Deferred startup initialization failed (non-fatal): $error',
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

    if (!config.hasBiopay) {
      _authLifecycleSubscription = null;
      return;
    }

    final cacheService = BiopayCacheService();
    _authLifecycleSubscription = SupabaseClientFactory.authStateChanges.listen((
      auth,
    ) {
      if (auth.event == AuthChangeEvent.signedOut) {
        unawaited(cacheService.clear());
      }
    });
  }

  void _initializeSmsAutoread(ClubConfig config) {
    try {
      if (!EnvConfig.enableAndroidMomoSmsAutoread) {
        debugPrint('[Bootstrap] SMS autoread disabled for this build.');
        return;
      }

      final client = SupabaseClientFactory.client;
      final smsService = MomoSmsAutoreadService(
        client: client,
        appAccessService: AppAccessService(openBox: openHiveBox<bool>),
        countryCode: config.countryCode,
      );
      final reconciliationService = LedgerReconciliationService(client: client);

      client.auth.onAuthStateChange.listen((event) {
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
    } catch (error) {
      debugPrint('[Bootstrap] SMS autoread init failed (non-fatal): $error');
    }
  }

  void _runReconciliation(LedgerReconciliationService service) {
    Future<void>.delayed(const Duration(seconds: 5), () async {
      try {
        final count = await service.reconcilePending();
        if (count > 0) {
          debugPrint('[Bootstrap] Reconciled $count contributions.');
        }
      } catch (error) {
        debugPrint('[Bootstrap] Reconciliation failed (non-fatal): $error');
      }
    });
  }
}
