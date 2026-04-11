import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:core_auth/core_auth.dart';
import 'package:core_modules/core_modules.dart';
import 'package:core_network/core_network.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'startup_coordinator.dart';

bool _globalErrorHandlersInstalled = false;

class AfriClubBootstrapOptions {
  const AfriClubBootstrapOptions({
    this.startupOptions = const AppStartupOptions(),
    this.modulesOverride,
    this.authRepository,
    this.providerOverrides = const <Override>[],
    this.initialLocation,
  });

  final AppStartupOptions startupOptions;
  final List<FeatureModule>? modulesOverride;
  final AuthRepository? authRepository;
  final List<Override> providerOverrides;
  final String? initialLocation;
}

/// Bootstrap the AFRICLUB app with club config.
///
/// The startup coordinator owns side effects, while the module registry owns
/// feature composition. This keeps each club entrypoint declarative.
Future<void> bootstrap(
  ClubConfig config, {
  AfriClubBootstrapOptions options = const AfriClubBootstrapOptions(),
}) async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      _installGlobalErrorHandlers();

      final normalizedClubId = int.tryParse(config.clubId);
      assert(
        config.appName.trim().isNotEmpty,
        'ClubConfig.appName must not be empty.',
      );
      assert(
        config.clubName.trim().isNotEmpty,
        'ClubConfig.clubName must not be empty.',
      );
      assert(
        config.crestAsset.trim().isNotEmpty,
        'ClubConfig.crestAsset must not be empty.',
      );
      if (normalizedClubId == null) {
        throw StateError(
          'ClubConfig.clubId must be a numeric string matching the backend id. '
          'Got "${config.clubId}".',
        );
      }
      RuntimeBranding.configure(
        appName: config.appName,
        clubName: config.clubName,
        crestAsset: config.crestAsset,
        countryCode: config.countryCode,
        currencyCode: config.currency,
        currencySymbol: config.currencySymbol,
      );

      final startupCoordinator = AppStartupCoordinator(
        options: options.startupOptions,
      );
      await startupCoordinator.initialize(config);
      final modules =
          options.modulesOverride ?? AppModuleRegistry.build(config);

      // Run the app
      runApp(
        AfriClubApp(
          config: config,
          modules: modules,
          authRepository: options.authRepository,
          providerOverrides: options.providerOverrides,
          initialLocation: options.initialLocation,
        ),
      );
      startupCoordinator.scheduleDeferredInitialization(config);
    },
    (error, stackTrace) {
      unawaited(
        _reportUnhandledError(
          component: 'bootstrap_zone',
          error: error,
          stackTrace: stackTrace,
        ),
      );
    },
  );
}

void _installGlobalErrorHandlers() {
  if (_globalErrorHandlersInstalled) {
    return;
  }
  _globalErrorHandlersInstalled = true;

  final previousFlutterErrorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    previousFlutterErrorHandler?.call(details);
    unawaited(
      _reportUnhandledError(
        component: 'flutter_error',
        error: details.exception,
        stackTrace: details.stack ?? StackTrace.current,
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(
      _reportUnhandledError(
        component: 'platform_dispatcher',
        error: error,
        stackTrace: stackTrace,
      ),
    );
    return true;
  };
}

Future<void> _reportUnhandledError({
  required String component,
  required Object error,
  required StackTrace stackTrace,
}) async {
  AfriLogger.error(
    'Bootstrap',
    'Unhandled error in $component.',
    error,
    stackTrace,
  );
  if (!SupabaseClientFactory.isInitialized) {
    return;
  }

  await OperationalHealthService(
    client: SupabaseClientFactory.client,
  ).recordEvent(
    service: 'mobile_app',
    component: component,
    message: error.toString(),
    status: OperationalHealthStatus.error,
    severity: OperationalHealthSeverity.critical,
    issueCode: 'unhandled_exception',
    metadata: <String, dynamic>{
      'error': error.toString(),
      'stack_trace': stackTrace.toString(),
    },
  );
}
