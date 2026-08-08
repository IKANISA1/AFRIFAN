import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OnboardingSlideId { belong, know, live }

enum OnboardingContentStatus { current, localFallback }

enum OnboardingContentNotice { offlineSaved, whatsAppUnavailable }

class OnboardingContentSnapshot {
  const OnboardingContentSnapshot({
    required this.slides,
    this.status = OnboardingContentStatus.current,
    this.notice,
    this.whatsAppSignInAvailable = true,
  });

  static const defaultSlides = <OnboardingSlideId>[
    OnboardingSlideId.belong,
    OnboardingSlideId.know,
    OnboardingSlideId.live,
  ];

  factory OnboardingContentSnapshot.current({
    bool whatsAppSignInAvailable = true,
  }) {
    return OnboardingContentSnapshot(
      slides: defaultSlides,
      notice: whatsAppSignInAvailable
          ? null
          : OnboardingContentNotice.whatsAppUnavailable,
      whatsAppSignInAvailable: whatsAppSignInAvailable,
    );
  }

  factory OnboardingContentSnapshot.localFallback() {
    return const OnboardingContentSnapshot(
      slides: defaultSlides,
      status: OnboardingContentStatus.localFallback,
      notice: OnboardingContentNotice.offlineSaved,
      whatsAppSignInAvailable: false,
    );
  }

  final List<OnboardingSlideId> slides;
  final OnboardingContentStatus status;
  final OnboardingContentNotice? notice;
  final bool whatsAppSignInAvailable;

  bool get isEmpty => slides.isEmpty;
}

enum OnboardingContentFailureKind {
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class OnboardingContentFailure implements Exception {
  const OnboardingContentFailure(this.kind);

  final OnboardingContentFailureKind kind;

  static OnboardingContentFailure fromError(Object error) {
    if (error is OnboardingContentFailure) return error;
    if (error is TimeoutException) {
      return const OnboardingContentFailure(
        OnboardingContentFailureKind.securityTimeout,
      );
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const OnboardingContentFailure(
        OnboardingContentFailureKind.permissionDenied,
      );
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision')) {
      return const OnboardingContentFailure(
        OnboardingContentFailureKind.conflict,
      );
    }
    return const OnboardingContentFailure(OnboardingContentFailureKind.unknown);
  }

  @override
  String toString() => 'OnboardingContentFailure(${kind.name})';
}

class OnboardingContentRepository {
  const OnboardingContentRepository({
    this.whatsAppSignInEnabled = const bool.fromEnvironment(
      'CLUB_WHATSAPP_AUTH_ENABLED',
      defaultValue: true,
    ),
  });

  final bool whatsAppSignInEnabled;

  Future<OnboardingContentSnapshot> load() async {
    if (!ConnectivityService.isOnline) {
      return OnboardingContentSnapshot.localFallback();
    }
    return OnboardingContentSnapshot.current(
      whatsAppSignInAvailable: whatsAppSignInEnabled,
    );
  }
}

final onboardingContentRepositoryProvider =
    Provider<OnboardingContentRepository>((ref) {
      return const OnboardingContentRepository();
    });

class OnboardingContentNotifier
    extends AsyncNotifier<OnboardingContentSnapshot> {
  OnboardingContentNotifier({
    Duration loadTimeout = const Duration(seconds: 12),
  }) : _loadTimeout = loadTimeout;

  final Duration _loadTimeout;
  Timer? _loadTimeoutTimer;
  bool _refreshing = false;

  @override
  Future<OnboardingContentSnapshot> build() {
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
    state = const AsyncLoading<OnboardingContentSnapshot>().copyWithPrevious(
      state,
    );
    try {
      state = AsyncData(await _load());
    } catch (error, stackTrace) {
      state = previous != null && !previous.isEmpty
          ? AsyncError<OnboardingContentSnapshot>(
              error,
              stackTrace,
            ).copyWithPrevious(AsyncData(previous))
          : AsyncError(error, stackTrace);
    } finally {
      _refreshing = false;
    }
  }

  Future<OnboardingContentSnapshot> _load() async {
    try {
      return await _withLoadTimeout(
        ref.read(onboardingContentRepositoryProvider).load(),
      );
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'OnboardingContentProvider',
        'Welcome content load failed.',
        error,
        stackTrace,
      );
      throw OnboardingContentFailure.fromError(error);
    }
  }

  Future<OnboardingContentSnapshot> _withLoadTimeout(
    Future<OnboardingContentSnapshot> operation,
  ) {
    _loadTimeoutTimer?.cancel();
    final completer = Completer<OnboardingContentSnapshot>();
    final timer = Timer(_loadTimeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('Onboarding content load timed out.', _loadTimeout),
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

final onboardingContentProvider =
    AsyncNotifierProvider<OnboardingContentNotifier, OnboardingContentSnapshot>(
      () {
        return OnboardingContentNotifier();
      },
    );
