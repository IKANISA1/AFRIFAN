import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/widgets.dart';

import 'firebase_bootstrap_service.dart';
import 'firebase_observability_config.dart';
import 'privacy_safe_analytics.dart';

/// Service for logging general usage and tracking user journeys.
class FirebaseAnalyticsService {
  FirebaseAnalyticsService._();

  static bool _consentGranted = false;

  static bool get consentGranted => _consentGranted;

  static FirebaseAnalytics? get _analytics {
    if (!FirebaseObservabilityConfig.enabled ||
        !FirebaseBootstrapService.isInitialized ||
        !_consentGranted) {
      return null;
    }
    return FirebaseAnalytics.instance;
  }

  /// Applies explicit user consent to the current session.
  ///
  /// The compile-time observability gate remains authoritative. A true value
  /// cannot enable collection in an unverified release build.
  static Future<void> configureConsent({required bool enabled}) async {
    _consentGranted = enabled && FirebaseObservabilityConfig.enabled;
    if (!FirebaseObservabilityConfig.enabled ||
        !FirebaseBootstrapService.isInitialized) {
      return;
    }
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
        _consentGranted,
      );
      if (!_consentGranted) {
        await FirebaseAnalytics.instance.setUserId(id: null);
      }
    } catch (error) {
      _consentGranted = false;
      AfriLogger.warn('Analytics', 'Failed to apply analytics consent: $error');
    }
  }

  /// Retained for source compatibility; personal identifiers are never sent.
  ///
  /// Passing null also closes the session consent gate during sign-out.
  static Future<void> setUserId(String? userId) async {
    if (userId == null) {
      await configureConsent(enabled: false);
    }
  }

  /// Logs a custom event.
  static Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    if (!_consentGranted) return;
    final event = PrivacySafeAnalyticsPolicy.prepare(
      name,
      parameters: parameters,
    );
    if (event == null) {
      AfriLogger.warn('Analytics', 'Rejected event outside privacy contract.');
      return;
    }
    try {
      await _analytics?.logEvent(
        name: event.name,
        parameters: event.parameters.isEmpty ? null : event.parameters,
      );
    } catch (e) {
      AfriLogger.warn('Analytics', 'Failed to log event "$name": $e');
    }
  }

  /// Marks the current screen in analytics.
  static Future<void> setCurrentScreen(
    String screenName, {
    String screenClassOverride = 'Flutter',
  }) async {
    if (!_consentGranted) return;
    final safeScreenName = PrivacySafeAnalyticsPolicy.sanitizeScreenName(
      screenName,
    );
    if (safeScreenName == null) return;
    try {
      await _analytics?.logScreenView(
        screenName: safeScreenName,
        screenClass: screenClassOverride,
      );
    } catch (e) {
      AfriLogger.warn(
        'Analytics',
        'Failed to set current screen "$screenName": $e',
      );
    }
  }

  /// Returns a RouteObserver that logs screen views.
  static RouteObserver<Route<dynamic>> get routeObserver =>
      _AnalyticsRouteObserver();

  // ─── Structured Business Events ───────────────────────────────

  /// User signed in (anonymous, phone OTP, etc.).
  static Future<void> logSignIn({required String method}) =>
      logEvent('sign_in', parameters: <String, Object>{'method': method});

  /// User completed onboarding.
  static Future<void> logOnboardingComplete() =>
      logEvent('onboarding_complete');

  /// Profile updated (display name, avatar, etc.).
  static Future<void> logProfileUpdate({required String field}) =>
      logEvent('profile_update', parameters: <String, Object>{'field': field});

  /// Prediction placed on a fixture market.
  static Future<void> logPredictionPlaced({
    required String marketSlug,
    required String selectedOutcome,
    required int fetStaked,
  }) => logEvent(
    'prediction_placed',
    parameters: <String, Object>{
      'market': marketSlug,
      'outcome': selectedOutcome,
      'value_bucket': PrivacySafeAnalyticsPolicy.valueBucket(fetStaked),
    },
  );

  /// Prediction settled (won/lost).
  static Future<void> logPredictionSettled({
    required String status,
    required int fetEarned,
  }) => logEvent(
    'prediction_settled',
    parameters: <String, Object>{
      'status': status,
      'value_bucket': PrivacySafeAnalyticsPolicy.valueBucket(fetEarned),
    },
  );

  /// FET wallet transfer sent.
  static Future<void> logWalletTransfer({
    required int amount,
    required String direction,
  }) => logEvent(
    'wallet_transfer',
    parameters: <String, Object>{
      'value_bucket': PrivacySafeAnalyticsPolicy.valueBucket(amount),
      'direction': direction,
    },
  );

  /// Challenge created by user.
  static Future<void> logChallengeCreated({required int stakeFet}) => logEvent(
    'challenge_created',
    parameters: <String, Object>{
      'value_bucket': PrivacySafeAnalyticsPolicy.valueBucket(stakeFet),
    },
  );

  /// User joined a challenge.
  static Future<void> logChallengeJoined({required String challengeId}) =>
      logEvent('challenge_joined');

  /// Membership created or renewed.
  static Future<void> logMembershipAction({required String action}) => logEvent(
    'membership_action',
    parameters: <String, Object>{'action': action},
  );

  /// MoMo SMS parsed successfully.
  static Future<void> logMomoSmsParsed({
    required String provider,
    required int amount,
  }) => logEvent(
    'momo_sms_parsed',
    parameters: <String, Object>{
      'provider': provider,
      'value_bucket': PrivacySafeAnalyticsPolicy.valueBucket(amount),
    },
  );

  /// Feature flag check — logs when a disabled feature is accessed.
  static Future<void> logFeatureGated({required String featureKey}) => logEvent(
    'feature_gated',
    parameters: <String, Object>{'feature': featureKey},
  );

  static Future<void> logHomeActionSelected({
    required String action,
    required String layer,
  }) => logEvent(
    'home_action_selected',
    parameters: <String, Object>{'action': action, 'layer': layer},
  );

  static Future<void> logSearchSuccess({
    required String category,
    required int resultCount,
  }) => logEvent(
    'search_success',
    parameters: <String, Object>{
      'category': category,
      'result_count_bucket': PrivacySafeAnalyticsPolicy.resultCountBucket(
        resultCount,
      ),
    },
  );

  static Future<void> logTicketCompletion({
    required String ticketType,
    required String paymentChannel,
  }) => logEvent(
    'ticket_completion',
    parameters: <String, Object>{
      'ticket_type': ticketType,
      'payment_channel': paymentChannel,
    },
  );

  static Future<void> logContributionCompletion({
    required String paymentChannel,
    required int amount,
  }) => logEvent(
    'contribution_completion',
    parameters: <String, Object>{
      'payment_channel': paymentChannel,
      'value_bucket': PrivacySafeAnalyticsPolicy.valueBucket(amount),
    },
  );

  static Future<void> logFanzoneEngagement({
    required String surface,
    required String action,
  }) => logEvent(
    'fanzone_engagement',
    parameters: <String, Object>{'surface': surface, 'action': action},
  );

  static Future<void> logSupportAccess({required String channel}) => logEvent(
    'support_access',
    parameters: <String, Object>{'channel': channel},
  );

  static Future<void> logErrorRecovery({
    required String surface,
    required String outcome,
  }) => logEvent(
    'error_recovery',
    parameters: <String, Object>{'surface': surface, 'outcome': outcome},
  );

  static Future<void> logTaskAbandonment({
    required String task,
    required String stage,
  }) => logEvent(
    'task_abandonment',
    parameters: <String, Object>{'task': task, 'stage': stage},
  );
}

class _AnalyticsRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name != null) {
      unawaited(
        FirebaseAnalyticsService.setCurrentScreen(route.settings.name!),
      );
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute?.settings.name != null) {
      unawaited(
        FirebaseAnalyticsService.setCurrentScreen(newRoute!.settings.name!),
      );
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute?.settings.name != null) {
      unawaited(
        FirebaseAnalyticsService.setCurrentScreen(
          previousRoute!.settings.name!,
        ),
      );
    }
  }
}
