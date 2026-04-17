import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/widgets.dart';

import 'firebase_bootstrap_service.dart';

/// Service for logging general usage and tracking user journeys.
class FirebaseAnalyticsService {
  FirebaseAnalyticsService._();

  static FirebaseAnalytics? get _analytics {
    if (!FirebaseBootstrapService.isInitialized) {
      return null;
    }
    return FirebaseAnalytics.instance;
  }

  /// Sets the user identifier for analytics.
  static Future<void> setUserId(String? userId) async {
    try {
      await _analytics?.setUserId(id: userId);
    } catch (e, stack) {
      AfriLogger.error('Analytics', 'Failed to set user ID: $e', e, stack);
    }
  }

  /// Logs a custom event.
  static Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics?.logEvent(name: name, parameters: parameters);
    } catch (e) {
      AfriLogger.warn('Analytics', 'Failed to log event "$name": $e');
    }
  }

  /// Marks the current screen in analytics.
  static Future<void> setCurrentScreen(
    String screenName, {
    String screenClassOverride = 'Flutter',
  }) async {
    try {
      await _analytics?.logScreenView(
        screenName: screenName,
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
  }) =>
      logEvent('prediction_placed', parameters: <String, Object>{
        'market_slug': marketSlug,
        'selected_outcome': selectedOutcome,
        'fet_staked': fetStaked,
      });

  /// Prediction settled (won/lost).
  static Future<void> logPredictionSettled({
    required String status,
    required int fetEarned,
  }) =>
      logEvent('prediction_settled', parameters: <String, Object>{
        'status': status,
        'fet_earned': fetEarned,
      });

  /// FET wallet transfer sent.
  static Future<void> logWalletTransfer({
    required int amount,
    required String direction,
  }) =>
      logEvent('wallet_transfer', parameters: <String, Object>{
        'amount': amount,
        'direction': direction,
      });

  /// Challenge created by user.
  static Future<void> logChallengeCreated({required int stakeFet}) =>
      logEvent('challenge_created', parameters: <String, Object>{
        'stake_fet': stakeFet,
      });

  /// User joined a challenge.
  static Future<void> logChallengeJoined({required String challengeId}) =>
      logEvent('challenge_joined', parameters: <String, Object>{
        'challenge_id': challengeId,
      });

  /// Membership created or renewed.
  static Future<void> logMembershipAction({required String action}) =>
      logEvent('membership_action', parameters: <String, Object>{
        'action': action,
      });

  /// MoMo SMS parsed successfully.
  static Future<void> logMomoSmsParsed({
    required String provider,
    required int amount,
  }) =>
      logEvent('momo_sms_parsed', parameters: <String, Object>{
        'provider': provider,
        'amount': amount,
      });

  /// Feature flag check — logs when a disabled feature is accessed.
  static Future<void> logFeatureGated({required String featureKey}) =>
      logEvent('feature_gated', parameters: <String, Object>{
        'feature_key': featureKey,
      });
}

class _AnalyticsRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name != null) {
      unawaited(FirebaseAnalyticsService.setCurrentScreen(route.settings.name!));
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute?.settings.name != null) {
      unawaited(FirebaseAnalyticsService.setCurrentScreen(newRoute!.settings.name!));
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute?.settings.name != null) {
      unawaited(FirebaseAnalyticsService.setCurrentScreen(previousRoute!.settings.name!));
    }
  }
}
