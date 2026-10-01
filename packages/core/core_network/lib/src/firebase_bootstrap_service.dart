import 'package:core_utils/core_utils.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_performance/firebase_performance.dart';
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
      await _disablePerformanceCollection();
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
      AfriLogger.info('Firebase', 'Initialized default app.');
    } catch (error, stackTrace) {
      AfriLogger.warn('Firebase', 'Initialization skipped.');
      if (kDebugMode) {
        AfriLogger.error(
          'Firebase',
          'Initialization stack trace.',
          error,
          stackTrace,
        );
      }
    }

    if (Firebase.apps.isNotEmpty) {
      await _disablePerformanceCollection();
    }
    return Firebase.apps.isNotEmpty;
  }

  static Future<void> _disablePerformanceCollection() async {
    if (kIsWeb) return;
    try {
      // Native manifests also permanently deactivate automatic instrumentation
      // before Firebase starts. This clears any previously enabled collection
      // state; the general observability flag only controls finite telemetry.
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(false);
    } catch (error, stackTrace) {
      AfriLogger.warn('Firebase', 'Performance collection disable skipped.');
      if (kDebugMode) {
        AfriLogger.error(
          'Firebase',
          'Performance disable failed.',
          error,
          stackTrace,
        );
      }
    }
  }
}
