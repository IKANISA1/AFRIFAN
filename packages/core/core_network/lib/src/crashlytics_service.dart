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

    await _recordDiagnostic(
      _errorCategory(error),
      reason: sanitizeDiagnosticMessage(reason) ?? 'runtime_error',
      fatal: fatal,
    );
  }

  // The installed SDK replaces an empty stack with StackTrace.current. This
  // nonempty redaction marker parses into zero frames, as verified at its native
  // payload boundary. It never contains caller frames or file paths.
  static final _redactedStack = StackTrace.fromString(
    'diagnostic_stack_redacted',
  );

  static Future<void> _recordDiagnostic(
    String category, {
    required String reason,
    required bool fatal,
  }) async {
    try {
      await FirebaseCrashlytics.instance.recordError(
        'runtime_failure:$category',
        _redactedStack,
        reason: reason,
        fatal: fatal,
        printDetails: false,
      );
    } catch (_) {
      // Best-effort — never crash reporting the crash.
    }
  }

  static String _errorCategory(Object error) => switch (error) {
    TimeoutException() => 'timeout',
    FormatException() => 'format',
    ArgumentError() => 'argument',
    StateError() => 'state',
    UnsupportedError() => 'unsupported',
    _ => 'failure',
  };

  /// Record a Flutter framework error.
  ///
  /// Designed to be called from [FlutterError.onError].
  static Future<void> recordFlutterError(FlutterErrorDetails details) async {
    if (!_isAvailable) return;

    await _recordDiagnostic(
      'framework',
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
      await FirebaseCrashlytics.instance.log(safeMessage);
    } catch (_) {
      // Best-effort.
    }
  }

  static bool get _isAvailable => _initialized && !kIsWeb;

  @visibleForTesting
  static String? sanitizeDiagnosticMessage(String? value) {
    const codes = <String>{
      'runtime_error',
      'flutter_framework_error',
      'network_error',
      'parse_error',
      'operation_failed',
    };
    return codes.contains(value) ? value : null;
  }
}
