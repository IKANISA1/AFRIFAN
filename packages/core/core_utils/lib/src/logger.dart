import 'package:flutter/foundation.dart';

/// Structured logger — wraps [debugPrint] behind [kDebugMode] guard.
///
/// All feature and core packages should use [AfriLogger] instead of
/// bare [debugPrint] / [print] calls. In release mode, messages are
/// silently discarded (zero overhead).
///
/// Usage:
/// ```dart
/// AfriLogger.info('LatestIntelSection', 'Loaded 12 articles');
/// AfriLogger.error('AuthRepo', 'Token refresh failed', exception);
/// ```
class AfriLogger {
  AfriLogger._();

  /// Log an informational message (debug builds only).
  static void info(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[$tag] $message');
    }
  }

  /// Log a warning message (debug builds only).
  static void warn(String tag, String message) {
    if (kDebugMode) {
      debugPrint('⚠️ [$tag] $message');
    }
  }

  /// Log an error with optional exception (debug builds only).
  static void error(
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    if (kDebugMode) {
      debugPrint('❌ [$tag] $message');
      if (error != null) debugPrint('  Error: $error');
      if (stack != null) debugPrint('  Stack: $stack');
    }
  }
}
