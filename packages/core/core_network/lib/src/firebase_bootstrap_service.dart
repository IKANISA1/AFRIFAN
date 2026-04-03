import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Best-effort Firebase bootstrap for features that depend on Firebase-backed
/// services such as App Check.
class FirebaseBootstrapService {
  FirebaseBootstrapService._();

  static bool _didAttemptInitialization = false;

  /// Initializes the default Firebase app if native configuration is present.
  ///
  /// This is intentionally best-effort so AFRICLUB can still boot on flavors
  /// that have not received Firebase configuration yet.
  static Future<void> initialize() async {
    if (Firebase.apps.isNotEmpty || _didAttemptInitialization) {
      return;
    }

    _didAttemptInitialization = true;

    try {
      await Firebase.initializeApp();
      debugPrint('[Firebase] Initialized default app.');
    } catch (error) {
      debugPrint('[Firebase] Initialization skipped: $error');
    }
  }
}
