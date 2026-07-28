import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ProfileRouteContentStatus { current, localFallback }

class ProfileRouteContentSnapshot {
  const ProfileRouteContentSnapshot({
    required this.profile,
    this.status = ProfileRouteContentStatus.current,
    this.editingEnabled = true,
    this.message,
  });

  factory ProfileRouteContentSnapshot.current({
    required UserProfile? profile,
    bool editingEnabled = true,
    String? message,
  }) {
    return ProfileRouteContentSnapshot(
      profile: profile,
      editingEnabled: editingEnabled,
      message: message,
    );
  }

  factory ProfileRouteContentSnapshot.localFallback(UserProfile profile) {
    return ProfileRouteContentSnapshot(
      profile: profile,
      status: ProfileRouteContentStatus.localFallback,
      editingEnabled: false,
      message: 'Offline. Your saved profile stays visible. Reconnect to edit.',
    );
  }

  final UserProfile? profile;
  final ProfileRouteContentStatus status;
  final bool editingEnabled;
  final String? message;

  bool get isEmpty => profile == null;
}

enum ProfileRouteContentFailureKind {
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class ProfileRouteContentFailure implements Exception {
  const ProfileRouteContentFailure(this.kind);

  final ProfileRouteContentFailureKind kind;

  static ProfileRouteContentFailure fromError(Object error) {
    if (error is ProfileRouteContentFailure) return error;
    if (error is TimeoutException) {
      return const ProfileRouteContentFailure(
        ProfileRouteContentFailureKind.securityTimeout,
      );
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const ProfileRouteContentFailure(
        ProfileRouteContentFailureKind.permissionDenied,
      );
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision')) {
      return const ProfileRouteContentFailure(
        ProfileRouteContentFailureKind.conflict,
      );
    }
    return const ProfileRouteContentFailure(
      ProfileRouteContentFailureKind.unknown,
    );
  }

  static ProfileRouteContentFailure fromMessage(String? message) {
    if (message == null) {
      return const ProfileRouteContentFailure(
        ProfileRouteContentFailureKind.unknown,
      );
    }
    return fromError(StateError(message));
  }

  @override
  String toString() => 'ProfileRouteContentFailure(${kind.name})';
}

class ProfileRouteContentRepository {
  const ProfileRouteContentRepository({
    this.editingEnabled = const bool.fromEnvironment(
      'AFRICLUB_PROFILE_EDIT_ENABLED',
      defaultValue: true,
    ),
  });

  final bool editingEnabled;

  Future<ProfileRouteContentSnapshot> load(Ref ref) async {
    final profile = ref.read(currentUserProvider);
    if (profile != null && !ConnectivityService.isOnline) {
      return ProfileRouteContentSnapshot.localFallback(profile);
    }
    return ProfileRouteContentSnapshot.current(
      profile: profile,
      editingEnabled: editingEnabled,
      message: editingEnabled
          ? null
          : 'Profile editing is unavailable. Your saved profile stays visible.',
    );
  }
}

final profileRouteContentRepositoryProvider =
    Provider<ProfileRouteContentRepository>((ref) {
      return const ProfileRouteContentRepository();
    });

class ProfileRouteContentNotifier
    extends AsyncNotifier<ProfileRouteContentSnapshot> {
  ProfileRouteContentNotifier({
    Duration loadTimeout = const Duration(seconds: 12),
  }) : _loadTimeout = loadTimeout;

  final Duration _loadTimeout;
  Timer? _loadTimeoutTimer;
  bool _refreshing = false;

  @override
  Future<ProfileRouteContentSnapshot> build() {
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
    state = const AsyncLoading<ProfileRouteContentSnapshot>().copyWithPrevious(
      state,
    );
    try {
      state = AsyncData(await _load());
    } catch (error, stackTrace) {
      state = previous != null
          ? AsyncError<ProfileRouteContentSnapshot>(
              error,
              stackTrace,
            ).copyWithPrevious(AsyncData(previous))
          : AsyncError(error, stackTrace);
    } finally {
      _refreshing = false;
    }
  }

  Future<ProfileRouteContentSnapshot> _load() async {
    try {
      return await _withLoadTimeout(
        ref.read(profileRouteContentRepositoryProvider).load(ref),
      );
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'ProfileRouteContentProvider',
        'Profile route content load failed.',
        error,
        stackTrace,
      );
      throw ProfileRouteContentFailure.fromError(error);
    }
  }

  Future<ProfileRouteContentSnapshot> _withLoadTimeout(
    Future<ProfileRouteContentSnapshot> operation,
  ) {
    _loadTimeoutTimer?.cancel();
    final completer = Completer<ProfileRouteContentSnapshot>();
    final timer = Timer(_loadTimeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('Profile content load timed out.', _loadTimeout),
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

final profileRouteContentProvider =
    AsyncNotifierProvider<
      ProfileRouteContentNotifier,
      ProfileRouteContentSnapshot
    >(() {
      return ProfileRouteContentNotifier();
    });
