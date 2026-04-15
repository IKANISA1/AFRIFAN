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
