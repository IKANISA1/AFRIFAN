import 'dart:async';

import 'package:flutter/foundation.dart';

import 'connectivity_service.dart';

enum OfflineRecoveryPhase {
  initialLoading,
  fresh,
  refreshing,
  stale,
  offline,
  error,
}

/// Fail-safe state controller for read-heavy, network-backed product surfaces.
///
/// It preserves the last successful value during slow refreshes and failures,
/// labels retained values as stale, blocks network work while offline, and
/// automatically refreshes once connectivity returns.
class OfflineRecoveryController<T> extends ChangeNotifier {
  OfflineRecoveryController({
    required Future<T> Function() load,
    ValueListenable<bool>? connectivity,
    T? initialData,
    DateTime? initialSyncedAt,
  }) : _load = load,
       _connectivity = connectivity ?? ConnectivityService.onlineNotifier,
       _data = initialData,
       _lastSyncedAt = initialSyncedAt,
       _phase = initialData == null
           ? OfflineRecoveryPhase.initialLoading
           : OfflineRecoveryPhase.stale {
    _wasOnline = _connectivity.value;
    _connectivity.addListener(_handleConnectivityChange);
  }

  final Future<T> Function() _load;
  final ValueListenable<bool> _connectivity;

  T? _data;
  Object? _lastError;
  StackTrace? _lastStackTrace;
  DateTime? _lastSyncedAt;
  late bool _wasOnline;
  OfflineRecoveryPhase _phase;
  Future<void>? _activeLoad;
  bool _disposed = false;

  T? get data => _data;
  Object? get lastError => _lastError;
  StackTrace? get lastStackTrace => _lastStackTrace;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  OfflineRecoveryPhase get phase => _phase;
  bool get hasData => _data != null;
  bool get isOnline => _connectivity.value;
  bool get networkActionsEnabled => isOnline;
  bool get isRefreshing => _phase == OfflineRecoveryPhase.refreshing;
  bool get isStale => _phase == OfflineRecoveryPhase.stale;

  Future<void> start() => refresh();

  Future<void> refresh() {
    final activeLoad = _activeLoad;
    if (activeLoad != null) return activeLoad;

    final operation = _refresh();
    _activeLoad = operation;
    return operation.whenComplete(() {
      if (identical(_activeLoad, operation)) {
        _activeLoad = null;
      }
    });
  }

  Future<void> _refresh() async {
    if (!isOnline) {
      _phase = hasData
          ? OfflineRecoveryPhase.stale
          : OfflineRecoveryPhase.offline;
      _notify();
      return;
    }

    _phase = hasData
        ? OfflineRecoveryPhase.refreshing
        : OfflineRecoveryPhase.initialLoading;
    _lastError = null;
    _lastStackTrace = null;
    _notify();

    try {
      final next = await _load();
      if (_disposed) return;
      _data = next;
      _lastSyncedAt = DateTime.now().toUtc();
      _phase = OfflineRecoveryPhase.fresh;
    } catch (error, stackTrace) {
      if (_disposed) return;
      _lastError = error;
      _lastStackTrace = stackTrace;
      _phase = hasData
          ? OfflineRecoveryPhase.stale
          : isOnline
          ? OfflineRecoveryPhase.error
          : OfflineRecoveryPhase.offline;
    }
    _notify();
  }

  void _handleConnectivityChange() {
    final online = _connectivity.value;
    final restored = !_wasOnline && online;
    _wasOnline = online;

    if (!online) {
      _phase = hasData
          ? OfflineRecoveryPhase.stale
          : OfflineRecoveryPhase.offline;
      _notify();
      return;
    }

    if (restored) {
      unawaited(refresh());
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _connectivity.removeListener(_handleConnectivityChange);
    super.dispose();
  }
}
