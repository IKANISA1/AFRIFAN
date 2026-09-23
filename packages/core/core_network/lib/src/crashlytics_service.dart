import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'firebase_observability_config.dart';

/// Production crash reporting via Firebase Crashlytics.
///
/// Mirrors the static singleton pattern used by [AppCheckService] and
/// [FirebaseAnalyticsService]. Automatically disabled on web and when
/// Firebase is not initialized.
class CrashlyticsService {
  CrashlyticsService._();

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  /// Initialize Crashlytics after Firebase bootstrap.
  ///
  /// This should be called once during app startup, after
  /// [FirebaseBootstrapService.initialize].
  static Future<bool> initialize() async {
    if (_initialized) return true;
    if (kIsWeb || Firebase.apps.isEmpty) return false;

    if (!FirebaseObservabilityConfig.enabled) {
      AfriLogger.info(
        'Crashlytics',
        'Skipped; Firebase observability is disabled.',
      );
      return false;
    }

    try {
      // Disable collection in debug builds to avoid polluting dashboards.
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        kReleaseMode,
      );
      _initialized = true;
      AfriLogger.info('Crashlytics', 'Initialized (collection=$kReleaseMode).');
    } catch (error, stackTrace) {
      AfriLogger.error(
        'Crashlytics',
        'Initialization failed.',
        error,
        stackTrace,
      );
    }

    return _initialized;
  }

  /// Record a non-fatal error for production diagnostics.
  ///
  /// Use this for caught exceptions that represent real failures but are
  /// handled gracefully (e.g., network errors, parse failures).
  static Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    if (!_isAvailable) return;

    try {
      final safeError = StateError('runtime_failure:${error.runtimeType}');
      await FirebaseCrashlytics.instance.recordError(
        safeError,
        stackTrace,
        reason: sanitizeDiagnosticMessage(reason),
        fatal: fatal,
      );
    } catch (_) {
      // Best-effort — never crash reporting the crash.
    }
  }

  /// Record a Flutter framework error.
  ///
  /// Designed to be called from [FlutterError.onError].
  static Future<void> recordFlutterError(FlutterErrorDetails details) async {
    if (!_isAvailable) return;

    await recordError(
      StateError('flutter_framework_failure:${details.exception.runtimeType}'),
      details.stack,
      reason: 'flutter_framework_error',
      fatal: true,
    );
  }

  /// Clears the optional Crashlytics user identifier.
  ///
  /// Account or profile identifiers are deliberately never forwarded. The
  /// method retains its existing signature so authentication call sites can
  /// close diagnostic identity during sign-out without creating a second
  /// privacy-sensitive code path during sign-in.
  static Future<void> setUserId(String? userId) async {
    if (!_isAvailable) return;
    if (userId != null) return;

    try {
      await FirebaseCrashlytics.instance.setUserIdentifier('');
    } catch (_) {
      // Best-effort.
    }
  }

  /// Log a diagnostic message that will be attached to the next crash.
  static Future<void> log(String message) async {
    if (!_isAvailable) return;
    final safeMessage = sanitizeDiagnosticMessage(message);
    if (safeMessage == null) return;

    try {
      unawaited(FirebaseCrashlytics.instance.log(safeMessage));
    } catch (_) {
      // Best-effort.
    }
  }

  static bool get _isAvailable => _initialized && !kIsWeb;

  @visibleForTesting
  static String? sanitizeDiagnosticMessage(String? value) {
    final normalized = value?.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized == null || normalized.isEmpty) return null;

    final lowered = normalized.toLowerCase();
    const forbiddenFragments = <String>[
      'access_token',
      'authorization',
      'bearer ',
      'email=',
      'jwt',
      'phone=',
      'refresh_token',
      'service'
          '_role',
      'user_id',
    ];
    if (forbiddenFragments.any(lowered.contains) ||
        normalized.contains('@') ||
        lowered.contains('http://') ||
        lowered.contains('https://') ||
        RegExp(r'\b\+?\d{9,15}\b').hasMatch(normalized) ||
        RegExp(
          r'\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b',
          caseSensitive: false,
        ).hasMatch(normalized)) {
      return null;
    }

    final safe = normalized.replaceAll(RegExp(r'\d+'), '#');
    return safe.length <= 96 ? safe : safe.substring(0, 96);
  }
}
