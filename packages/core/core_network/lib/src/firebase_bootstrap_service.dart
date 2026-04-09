import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Best-effort Firebase bootstrap for features that depend on Firebase-backed
/// services such as App Check.
class FirebaseBootstrapService {
  FirebaseBootstrapService._();

  static bool _didAttemptInitialization = false;
  static bool get isInitialized => Firebase.apps.isNotEmpty;

  /// Initializes the default Firebase app if native configuration is present.
  ///
  /// This is intentionally best-effort so AFRICLUB can still boot on flavors
  /// that have not received Firebase configuration yet.
  static Future<bool> initialize({FirebaseOptions? options}) async {
    if (Firebase.apps.isNotEmpty) {
      return true;
    }

    if (_didAttemptInitialization) {
      return Firebase.apps.isNotEmpty;
    }

    _didAttemptInitialization = true;

    try {
      if (options != null) {
        await Firebase.initializeApp(options: options);
      } else {
        await Firebase.initializeApp();
      }
      debugPrint('[Firebase] Initialized default app.');
    } catch (error) {
      debugPrint('[Firebase] Initialization skipped: $error');
    }

    return Firebase.apps.isNotEmpty;
  }
}
