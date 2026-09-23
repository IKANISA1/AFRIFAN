import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_actions.dart';
import 'support_whatsapp_provider.dart';

enum SettingsRouteContentStatus { current, localFallback }

class SettingsRouteContentSnapshot {
  const SettingsRouteContentSnapshot({
    required this.supportWhatsApp,
    this.status = SettingsRouteContentStatus.current,
    this.message,
    this.supportEnabled = true,
  });

  factory SettingsRouteContentSnapshot.current({
    required String? supportWhatsApp,
    bool supportEnabled = true,
    String? message,
  }) {
    return SettingsRouteContentSnapshot(
      supportWhatsApp: supportWhatsApp,
      message: message,
      supportEnabled: supportEnabled,
    );
  }

  factory SettingsRouteContentSnapshot.localFallback() {
    final fallback = AppLinks.supportWhatsApp.trim();
    return SettingsRouteContentSnapshot(
      supportWhatsApp: fallback.isEmpty ? null : fallback,
      status: SettingsRouteContentStatus.localFallback,
      supportEnabled: false,
    );
  }

  final String? supportWhatsApp;
  final SettingsRouteContentStatus status;
  final String? message;
  final bool supportEnabled;

  bool get isEmpty {
    return supportEnabled &&
        status == SettingsRouteContentStatus.current &&
        (supportWhatsApp == null || supportWhatsApp!.trim().isEmpty);
  }
}

enum SettingsRouteContentFailureKind {
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class SettingsRouteContentFailure implements Exception {
  const SettingsRouteContentFailure(this.kind);

  final SettingsRouteContentFailureKind kind;

  static SettingsRouteContentFailure fromError(Object error) {
    if (error is SettingsRouteContentFailure) return error;
    if (error is TimeoutException) {
      return const SettingsRouteContentFailure(
        SettingsRouteContentFailureKind.securityTimeout,
      );
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const SettingsRouteContentFailure(
        SettingsRouteContentFailureKind.permissionDenied,
      );
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision')) {
      return const SettingsRouteContentFailure(
        SettingsRouteContentFailureKind.conflict,
      );
    }
    return const SettingsRouteContentFailure(
      SettingsRouteContentFailureKind.unknown,
    );
  }

  @override
  String toString() => 'SettingsRouteContentFailure(${kind.name})';
}

class SettingsRouteContentRepository {
  const SettingsRouteContentRepository({
    this.supportEnabled = const bool.fromEnvironment(
      'CLUB_SUPPORT_ENABLED',
      defaultValue: true,
    ),
  });

  final bool supportEnabled;

  Future<SettingsRouteContentSnapshot> load(Ref ref) async {
    if (!ConnectivityService.isOnline) {
      return SettingsRouteContentSnapshot.localFallback();
    }

    final configured = (await ref.read(supportWhatsAppProvider.future))?.trim();
    return SettingsRouteContentSnapshot.current(
      supportWhatsApp: configured == null || configured.isEmpty
          ? null
          : configured,
      supportEnabled: supportEnabled,
      message: supportEnabled
          ? null
          : 'Help and support is unavailable. Other settings still work.',
    );
  }
}

final settingsRouteContentRepositoryProvider =
    Provider<SettingsRouteContentRepository>((ref) {
      return const SettingsRouteContentRepository();
    });

class SettingsRouteContentNotifier
    extends AsyncNotifier<SettingsRouteContentSnapshot> {
  SettingsRouteContentNotifier({
    Duration loadTimeout = const Duration(seconds: 12),
  }) : _loadTimeout = loadTimeout;

  final Duration _loadTimeout;
  Timer? _loadTimeoutTimer;
  bool _refreshing = false;

  @override
  Future<SettingsRouteContentSnapshot> build() {
    ref.onDispose(() {
      _loadTimeoutTimer?.cancel();
      _loadTimeoutTimer = null;
    });
    return _load();
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    final previous = state.valueOrNull;
    state = const AsyncLoading<SettingsRouteContentSnapshot>().copyWithPrevious(
      state,
    );
    try {
      state = AsyncData(await _load());
    } catch (error, stackTrace) {
      state = previous != null
          ? AsyncError<SettingsRouteContentSnapshot>(
              error,
              stackTrace,
            ).copyWithPrevious(AsyncData(previous))
          : AsyncError(error, stackTrace);
    } finally {
      _refreshing = false;
    }
  }

  Future<SettingsRouteContentSnapshot> _load() async {
    try {
      return await _withLoadTimeout(
        ref.read(settingsRouteContentRepositoryProvider).load(ref),
      );
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'SettingsRouteContentProvider',
        'Settings route content load failed.',
        error,
        stackTrace,
      );
      throw SettingsRouteContentFailure.fromError(error);
    }
  }

  Future<SettingsRouteContentSnapshot> _withLoadTimeout(
    Future<SettingsRouteContentSnapshot> operation,
  ) {
    _loadTimeoutTimer?.cancel();
    final completer = Completer<SettingsRouteContentSnapshot>();
    final timer = Timer(_loadTimeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('Settings content load timed out.', _loadTimeout),
        );
      }
    });
    _loadTimeoutTimer = timer;

    unawaited(
      operation.then(
        (snapshot) {
          if (!completer.isCompleted) {
            completer.complete(snapshot);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        },
      ),
    );

    return completer.future.whenComplete(() {
      timer.cancel();
      if (identical(_loadTimeoutTimer, timer)) {
        _loadTimeoutTimer = null;
      }
    });
  }
}

final settingsRouteContentProvider =
    AsyncNotifierProvider<
      SettingsRouteContentNotifier,
      SettingsRouteContentSnapshot
    >(() {
      return SettingsRouteContentNotifier();
    });
