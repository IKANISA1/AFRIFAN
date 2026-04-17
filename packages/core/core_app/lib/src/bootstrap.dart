import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:core_auth/core_auth.dart';
import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_network/core_network.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/foundation.dart' show debugPrint, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'deep_link_service.dart';
import 'startup_coordinator.dart';

bool _globalErrorHandlersInstalled = false;

class AfriClubBootstrapOptions {
  const AfriClubBootstrapOptions({
    this.modules = const <FeatureModule>[],
    this.moduleBuilder,
    this.startupOptions = const AppStartupOptions(),
    this.authRepository,
    this.providerOverrides = const <Override>[],
    this.initialLocation,
    this.deepLinkParser,
    this.deepLinkService,
  });

  final List<FeatureModule> modules;

  /// Optional: A function that rebuilds the module list based on the
  /// admin-controlled platform feature configuration snapshot.
  ///
  /// When provided, this takes precedence over the static [modules] list
  /// and is called after the platform config is fetched from Supabase.
  final List<FeatureModule> Function(Map<String, dynamic>? snapshot)?
  moduleBuilder;

  final AppStartupOptions startupOptions;
  final AuthRepository? authRepository;
  final List<Override> providerOverrides;
  final String? initialLocation;
  final DeepLinkParser? deepLinkParser;
  final DeepLinkService? deepLinkService;
}

/// Bootstrap the AFRICLUB app with club config.
///
/// The startup coordinator owns side effects, while the module registry owns
/// feature composition. This keeps each club entrypoint declarative.
Future<void> bootstrap(
  ClubConfig config, {
  required AfriClubBootstrapOptions options,
}) async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      if (kReleaseMode) {
        debugPrint = (String? message, {int? wrapWidth}) {};
      }
      _installGlobalErrorHandlers();

      const rawClubId = String.fromEnvironment('CLUB_ID');
      const rawSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
      const rawSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

      if (rawClubId.isEmpty) {
        throw StateError(
          'CLUB_ID must be provided via --dart-define or '
          '--dart-define-from-file before bootstrapping the app.',
        );
      }
      if (rawSupabaseUrl.isEmpty) {
        throw StateError(
          'SUPABASE_URL must be provided via --dart-define or '
          '--dart-define-from-file before bootstrapping the app.',
        );
      }
      if (rawSupabaseAnonKey.isEmpty) {
        throw StateError(
          'SUPABASE_ANON_KEY must be provided via --dart-define or '
          '--dart-define-from-file before bootstrapping the app.',
        );
      }

      final normalizedClubId = int.tryParse(config.clubId);
      if (config.appName.trim().isEmpty) {
        throw StateError('ClubConfig.appName must not be empty.');
      }
      if (config.clubName.trim().isEmpty) {
        throw StateError('ClubConfig.clubName must not be empty.');
      }
      if (config.crestAsset.trim().isEmpty) {
        throw StateError('ClubConfig.crestAsset must not be empty.');
      }
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
      AfriCountryCatalog.setPreferredCountryCode(config.countryCode);

      final builtinCountries = await loadBuiltInCountries();
      AfriCountryCatalog.addCountries(builtinCountries);

      final startupCoordinator = AppStartupCoordinator(
        options: options.startupOptions,
      );
      await startupCoordinator.initialize(config);

      // Fetch the platform feature config from Supabase.
      // This runs AFTER Supabase initialization (inside startupCoordinator)
      // and BEFORE runApp, so the first frame already uses config-driven modules.
      Map<String, dynamic>? platformConfigSnapshot;
      if (SupabaseClientFactory.isInitialized) {
        try {
          final featureConfigRepo = FeatureConfigRepository();
          final snapshot = await featureConfigRepo.loadConfig(
            clubId: normalizedClubId,
            channel: 'mobile',
          );
          if (snapshot.isNotEmpty) {
            platformConfigSnapshot = snapshot.toJson();
            AfriLogger.info(
              'Bootstrap',
              'Platform config loaded: ${snapshot.features.length} features.',
            );
          }
        } catch (error) {
          AfriLogger.warn(
            'Bootstrap',
            'Platform config fetch failed (non-fatal): $error. '
                'Using compile-time feature flags.',
          );
        }
      } else {
        AfriLogger.info(
          'Bootstrap',
          'Skipping platform config fetch because backend initialization '
              'is disabled for this startup mode.',
        );
      }

      // Rebuild module list with config-aware enablement.
      // If platformConfigSnapshot is null, falls back to compile-time flags.
      final modules = options.moduleBuilder != null
          ? options.moduleBuilder!(platformConfigSnapshot)
          : (options.modules.isNotEmpty ? options.modules : <FeatureModule>[]);

      final deepLinkParser =
          options.deepLinkParser ?? DeepLinkParser.fromEnvironment();
      final deepLinkService = deepLinkParser.isEnabled
          ? (options.deepLinkService ?? PlatformDeepLinkService())
          : null;

      // Run the app
      runApp(
        AfriClubApp(
          config: config,
          modules: modules,
          authRepository: options.authRepository,
          providerOverrides: options.providerOverrides,
          initialLocation: options.initialLocation,
          deepLinkParser: deepLinkService == null ? null : deepLinkParser,
          deepLinkService: deepLinkService,
          platformConfigSnapshot: platformConfigSnapshot,
        ),
      );
      unawaited(startupCoordinator.scheduleDeferredInitialization(config));
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
    unawaited(CrashlyticsService.recordFlutterError(details));
    unawaited(
      _reportUnhandledError(
        component: 'flutter_error',
        error: details.exception,
        stackTrace: details.stack ?? StackTrace.current,
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(CrashlyticsService.recordError(error, stackTrace, fatal: true));
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

final List<Map<String, dynamic>> _pendingPreInitErrors = [];

Future<void> _reportUnhandledError({
  required String component,
  required Object error,
  required StackTrace stackTrace,
}) async {
  final summarizedStackTrace = _summarizeStackTrace(stackTrace);

  AfriLogger.error(
    'Bootstrap',
    'Unhandled error in $component.',
    error,
    stackTrace,
  );
  if (!SupabaseClientFactory.isInitialized) {
    _pendingPreInitErrors.add({
      'component': component,
      'error': error,
      'stackTrace': stackTrace,
    });
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
      'stack_trace': summarizedStackTrace,
    },
  );
}

Future<void> flushPendingPreInitErrors() async {
  if (_pendingPreInitErrors.isEmpty || !SupabaseClientFactory.isInitialized) {
    return;
  }

  final flushQueue = List<Map<String, dynamic>>.from(_pendingPreInitErrors);
  _pendingPreInitErrors.clear();

  for (final error in flushQueue) {
    await _reportUnhandledError(
      component: error['component'] as String,
      error: error['error'] as Object,
      stackTrace: error['stackTrace'] as StackTrace,
    );
  }
}

String _summarizeStackTrace(StackTrace stackTrace) {
  final lines = stackTrace
      .toString()
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .take(20)
      .toList(growable: false);
  final summary = lines.join('\n');
  if (summary.length <= 4000) {
    return summary;
  }
  return '${summary.substring(0, 4000)}...';
}
