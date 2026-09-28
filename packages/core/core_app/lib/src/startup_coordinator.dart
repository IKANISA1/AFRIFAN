import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'bootstrap.dart';
import 'deferred_feature_initializer.dart';

const Duration _criticalStartupServiceTimeout = Duration(seconds: 4);

class AppStartupOptions {
  const AppStartupOptions({
    this.configureDeviceChrome = true,
    this.initializePersistence = true,
    this.initializeBackend = true,
    this.deferNonCriticalBackendInitialization = true,
    this.firebaseOptions,
    this.criticalBackendOverride,
    this.deferredBackendOverride,
    this.featureInitializer = const DeferredFeatureInitializer(),
  });

  const AppStartupOptions.integrationTest()
    : configureDeviceChrome = false,
      initializePersistence = false,
      initializeBackend = false,
      deferNonCriticalBackendInitialization = false,
      firebaseOptions = null,
      criticalBackendOverride = null,
      deferredBackendOverride = null,
      featureInitializer = const DeferredFeatureInitializer();

  final bool configureDeviceChrome;
  final bool initializePersistence;
  final bool initializeBackend;
  final bool deferNonCriticalBackendInitialization;
  final FirebaseOptions? firebaseOptions;
  final Future<void> Function(ClubConfig config)? criticalBackendOverride;
  final Future<void> Function(ClubConfig config)? deferredBackendOverride;

  /// Feature-specific initialization callbacks injected by the app entry point.
  /// This decouples core_app from feature packages.
  final DeferredFeatureInitializer featureInitializer;
}

/// Centralizes startup side effects so app bootstrap stays declarative.
class AppStartupCoordinator {
  AppStartupCoordinator({this.options = const AppStartupOptions()});

  final AppStartupOptions options;
  Future<void>? _deferredInitializationTask;
  Future<void>? _scheduledDeferredInitialization;

  Future<void> initialize(ClubConfig config) async {
    ColorTokens.init();

    if (options.configureDeviceChrome) {
      await _configureDeviceChrome();
    }
    if (options.initializePersistence) {
      await _initializePersistence();
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
        statusBarColor: ColorTokens.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: ColorTokens.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  Future<void> _initializePersistence() async {
    await Hive.initFlutter();
    await HiveEncryptionService.initialize();
    await HiveCacheService.initialize();
  }

  Future<void> _initializeCriticalBackend(ClubConfig config) async {
    if (options.criticalBackendOverride case final override?) {
      await override(config);
      return;
    }

    final firebaseReady = await _runBestEffortStartupTask<bool>(
      label: 'Firebase',
      operation: () =>
          FirebaseBootstrapService.initialize(options: options.firebaseOptions),
      fallback: false,
    );
    final appCheckReady = await _runBestEffortStartupTask<bool>(
      label: 'AppCheck',
      operation: AppCheckService.initialize,
      fallback: false,
    );
    await _runBestEffortStartupTask<bool>(
      label: 'Crashlytics',
      operation: CrashlyticsService.initialize,
      fallback: false,
    );
    await _runBestEffortStartupTask<void>(
      label: 'Connectivity',
      operation: ConnectivityService.initialize,
    );

    if (kReleaseMode && !firebaseReady && !appCheckReady) {
      AfriLogger.warn(
        'Bootstrap',
        'Firebase and App Check are unavailable for this release build.',
      );
    }

    await SupabaseClientFactory.initialize(
      supabaseUrl: config.supabaseUrl,
      supabaseAnonKey: config.supabaseAnonKey,
    );
    await OfflineEventQueue.initialize(
      OperationalHealthService(
        client: SupabaseClientFactory.client,
      ).recordPayloadOrThrow,
    );

    // E-001: Flush any errors that were logged locally before Supabase was ready.
    await flushPendingPreInitErrors();
  }

  Future<void> _initializeDeferredBackend(ClubConfig config) async {
    if (options.deferredBackendOverride case final override?) {
      await override(config);
      return;
    }

    // Delegate auth lifecycle observer registration to feature initializer.
    await options.featureInitializer.onRegisterAuthLifecycleObservers?.call();

    await PushNotificationService.initialize(clubId: config.clubId);

    final countryRepo = CountryRepository(client: SupabaseClientFactory.client);
    await countryRepo.loadAndInject();
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
}

Future<T> _runBestEffortStartupTask<T>({
  required String label,
  required Future<T> Function() operation,
  T? fallback,
}) async {
  try {
    return await operation().timeout(_criticalStartupServiceTimeout);
  } on TimeoutException catch (error, stackTrace) {
    AfriLogger.warn(
      'Bootstrap',
      '$label startup exceeded ${_criticalStartupServiceTimeout.inSeconds}s; '
          'continuing without blocking first frame.',
      error,
      stackTrace,
    );
  } catch (error, stackTrace) {
    AfriLogger.warn(
      'Bootstrap',
      '$label startup failed; continuing without blocking first frame.',
      error,
      stackTrace,
    );
  }

  if (fallback is T) {
    return fallback;
  }
  return null as T;
}
