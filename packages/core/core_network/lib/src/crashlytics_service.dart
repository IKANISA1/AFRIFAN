import 'package:core_utils/core_utils.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

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
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: reason,
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

    try {
      await FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    } catch (_) {
      // Best-effort.
    }
  }

  /// Set the user identifier for crash reports.
  static Future<void> setUserId(String? userId) async {
    if (!_isAvailable) return;

    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(userId ?? '');
    } catch (_) {
      // Best-effort.
    }
  }

  /// Log a diagnostic message that will be attached to the next crash.
  static Future<void> log(String message) async {
    if (!_isAvailable) return;

    try {
      FirebaseCrashlytics.instance.log(message);
    } catch (_) {
      // Best-effort.
    }
  }

  static bool get _isAvailable => _initialized && !kIsWeb;
}
