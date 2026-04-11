import 'package:core_utils/core_utils.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Initializes Firebase App Check for request attestation.
///
/// Uses debug providers in debug builds and production attestors otherwise.
class AppCheckService {
  AppCheckService._();

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static Future<bool> initialize() async {
    if (_initialized) {
      return true;
    }

    if (Firebase.apps.isEmpty) {
      AfriLogger.warn(
        'AppCheck',
        'Firebase not initialized; skipping activation.',
      );
      return false;
    }

    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleAppAttestProvider(),
      );
      _initialized = true;
      AfriLogger.info('AppCheck', 'Activated.');
    } catch (error, stackTrace) {
      AfriLogger.error('AppCheck', 'Activation failed.', error, stackTrace);
    }

    return _initialized;
  }

  static Future<String?> getLimitedUseToken() async {
    if (!_initialized) return null;

    try {
      return await FirebaseAppCheck.instance.getLimitedUseToken();
    } catch (error, stackTrace) {
      AfriLogger.error(
        'AppCheck',
        'Limited-use token fetch failed.',
        error,
        stackTrace,
      );
      return null;
    }
  }

  static Future<String> requireLimitedUseToken({
    String featureName = 'This action',
  }) async {
    final token = await getLimitedUseToken();
    if (token == null || token.isEmpty) {
      throw StateError(
        '$featureName requires device attestation. Check Firebase App Check configuration and try again.',
      );
    }

    return token;
  }
}
