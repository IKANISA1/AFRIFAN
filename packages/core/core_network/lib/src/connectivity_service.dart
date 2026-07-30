import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/foundation.dart';

/// Reactive connectivity service providing network state awareness.
///
/// Use [isOnline] for one-shot checks and [onlineStream] for reactive
/// UI updates (e.g., showing offline banners, disabling submit buttons).
///
/// This is intentionally simple — it detects *connectivity*, not
/// *reachability*. A device can have WiFi but no internet. For true
/// reachability, pair with SafeRpc timeout behavior.
class ConnectivityService {
  ConnectivityService._();

  static final _connectivity = Connectivity();
  static const bool _qaForceOfflineRequested = bool.fromEnvironment(
    'AFRICLUB_QA_FORCE_OFFLINE',
  );
  static bool _lastKnownOnline = true;
  static StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Whether this non-release build was compiled for deterministic offline QA.
  ///
  /// The release-mode guard is deliberate: a production binary cannot enable
  /// this override, even if the dart define is accidentally supplied.
  static bool get qaOfflineOverrideActive =>
      !kReleaseMode && _qaForceOfflineRequested;

  /// Current best-known connectivity state.
  ///
  /// Defaults to `true` until proven otherwise — avoids false-negative
  /// blocking on startup.
  static bool get isOnline =>
      qaOfflineOverrideActive ? false : _lastKnownOnline;

  /// Reactive stream of online/offline state changes.
  ///
  /// Emits `true` when connectivity is restored, `false` when lost.
  /// Deduplicated — only emits when the boolean value changes.
  static final ValueNotifier<bool> onlineNotifier = ValueNotifier<bool>(
    !qaOfflineOverrideActive,
  );

  /// Initialize the connectivity listener.
  ///
  /// Should be called once during app startup (in [AppStartupCoordinator]).
  static Future<void> initialize() async {
    if (_subscription != null) return; // Already initialized.

    if (qaOfflineOverrideActive) {
      _lastKnownOnline = false;
      onlineNotifier.value = false;
      AfriLogger.info(
        'Connectivity',
        'Offline QA override active for this non-release build.',
      );
      return;
    }

    try {
      final results = await _connectivity.checkConnectivity();
      _update(results);
    } catch (e) {
      AfriLogger.warn('Connectivity', 'Initial check failed: $e');
      // Assume online — better UX than blocking on a failed check.
    }

    _subscription = _connectivity.onConnectivityChanged.listen(
      _update,
      onError: (Object error) {
        AfriLogger.warn('Connectivity', 'Stream error: $error');
      },
    );
  }

  /// Dispose the connectivity listener (for tests / cleanup).
  @visibleForTesting
  static Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  @visibleForTesting
  static void setOnlineForTest(bool value) {
    final effectiveValue = qaOfflineOverrideActive ? false : value;
    _lastKnownOnline = effectiveValue;
    onlineNotifier.value = effectiveValue;
  }

  static void _update(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);

    if (online != _lastKnownOnline) {
      _lastKnownOnline = online;
      onlineNotifier.value = online;

      AfriLogger.info(
        'Connectivity',
        online ? 'Connection restored.' : 'Connection lost.',
      );
    }
  }
}
