import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Logs finite diagnostic categories without arbitrary caller content.
///
/// All feature and core packages should use [AfriLogger] instead of
/// bare [debugPrint] / [print] calls. Free-form messages, exception text and
/// supplied stacks may contain credentials or private account data, so they
/// never reach either the developer sink or the console, including in debug
/// builds. Known component labels, severity and finite error categories remain
/// available. Informational diagnostics are disabled outside debug builds.
///
/// Usage:
/// ```dart
/// AfriLogger.info('LatestIntelSection', 'Loaded 12 articles');
/// AfriLogger.error('AuthRepo', 'Token refresh failed', exception);
/// ```
class AfriLogger {
  AfriLogger._();

  // Only reviewed source component names can become diagnostic labels.
  // Dynamic caller tags cannot introduce account identifiers or metric labels.
  static const _components = <String>{
    'AdminCmsNotifier',
    'AdminCompetitionsNotifier',
    'AdminContributionsNotifier',
    'AdminDashboardGateway',
    'AdminDashboardNotifier',
    'AdminFeatureDetailNotifier',
    'AdminFeaturesNotifier',
    'AdminMatchesNotifier',
    'AdminNotificationsNotifier',
    'AdminRepository',
    'AdminSettlementNotifier',
    'AfriClubApp',
    'Analytics',
    'AppCheck',
    'AppShell',
    'AuthNotifier',
    'AuthRepo',
    'AuthRepository',
    'Bootstrap',
    'CartScreen',
    'ClubRepository',
    'Connectivity',
    'ContributionOverlay',
    'ContributionsHubScreen',
    'CountryRepository',
    'Crashlytics',
    'Firebase',
    'GroupDetailController',
    'HiveEncryption',
    'HomeContentRepository',
    'HomeFeedProvider',
    'LatestIntelSection',
    'MatchDetailController',
    'MomoContributionSheet',
    'OfflineEventQueue',
    'OnboardingContentProvider',
    'OperationalHealth',
    'PredictionDetailController',
    'ProductDetailScreen',
    'ProfileRouteContentProvider',
    'Push',
    'SettingsRouteContentProvider',
    'ShareCardController',
    'StatementController',
    'SupabaseClientFactory',
  };

  /// Finite details for a previously installed Flutter diagnostic handler.
  ///
  /// Construct a new record: copying the original details would retain private
  /// context, library labels, stack filters or information collectors.
  static FlutterErrorDetails frameworkErrorDetails(
    FlutterErrorDetails details,
  ) {
    return FlutterErrorDetails(
      exception: StateError(
        'native_framework_failure:${_errorCategory(details.exception)}',
      ),
      stack: StackTrace.empty,
      library: 'AFRICLUB',
      silent: details.silent,
    );
  }

  static String _errorCategory(Object? error) => switch (error) {
    null => 'event',
    TimeoutException() => 'timeout',
    FormatException() => 'format',
    ArgumentError() => 'argument',
    StateError() => 'state',
    UnsupportedError() => 'unsupported',
    _ => 'failure',
  };

  /// Log an informational message (debug builds only).
  static void info(String tag, String message) {
    if (!kDebugMode) return;
    _log(tag, message, level: 800, mirrorToConsole: kDebugMode);
  }

  /// Log a warning message.
  ///
  /// Some call sites attach the underlying error/stack even when the warning
  /// is intentionally non-fatal, so keep the signature aligned with [error].
  static void warn(
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    _log(
      tag,
      message,
      level: 900,
      error: error,
      stack: stack,
      mirrorToConsole: kDebugMode,
    );
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
    final component = _components.contains(tag) ? tag : 'Application';
    final severity = switch (level) {
      >= 1000 => 'error',
      >= 900 => 'warning',
      _ => 'information',
    };
    final category = _errorCategory(error);
    final event = 'native_$severity:$category';
    developer.log(event, name: component, level: level);

    if (!mirrorToConsole) {
      return;
    }

    final prefix = switch (level) {
      >= 1000 => '[ERROR]',
      >= 900 => '[WARN]',
      _ => '[INFO]',
    };
    debugPrint('$prefix [$component] $event');
  }
}
