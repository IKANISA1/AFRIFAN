import 'dart:developer' as developer;

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
    _log(tag, message, level: 800, mirrorToConsole: kDebugMode);
  }

  /// Log a warning message.
  static void warn(String tag, String message) {
    _log(tag, message, level: 900, mirrorToConsole: true);
  }

  /// Log an error with optional exception.
  static void error(
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    _log(
      tag,
      message,
      level: 1000,
      error: error,
      stack: stack,
      mirrorToConsole: true,
    );
  }

  static void _log(
    String tag,
    String message, {
    required int level,
    Object? error,
    StackTrace? stack,
    required bool mirrorToConsole,
  }) {
    developer.log(
      message,
      name: tag,
      level: level,
      error: error,
      stackTrace: stack,
    );

    if (!mirrorToConsole) {
      return;
    }

    final prefix = switch (level) {
      >= 1000 => '[ERROR]',
      >= 900 => '[WARN]',
      _ => '[INFO]',
    };
    debugPrint('$prefix [$tag] $message');
    if (error != null) {
      debugPrint('  Error: $error');
    }
    if (stack != null && kDebugMode) {
      debugPrint('  Stack: $stack');
    }
  }
}
