import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Initializes Firebase App Check for request attestation.
///
/// Uses debug providers in debug builds and production attestors otherwise.
class AppCheckService {
  AppCheckService._();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    if (Firebase.apps.isEmpty) {
      debugPrint('[AppCheck] Firebase not initialized — skipping activation.');
      return;
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
      debugPrint('[AppCheck] Activated.');
    } catch (error) {
      debugPrint('[AppCheck] Activation failed: $error');
    }
  }

  static Future<String?> getLimitedUseToken() async {
    if (!_initialized) return null;

    try {
      return await FirebaseAppCheck.instance.getLimitedUseToken();
    } catch (error) {
      debugPrint('[AppCheck] Limited-use token fetch failed: $error');
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
