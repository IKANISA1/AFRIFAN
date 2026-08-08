import 'dart:async';

import '../models/live_game_v2_models.dart';
import 'live_game_v2_reconciler.dart';

enum LiveGameSyncStatus {
  idle,
  loading,
  ready,
  refreshing,
  reconnecting,
  offline,
  failure,
  disposed,
}

enum LiveGameSyncFailureKind {
  permissionDenied,
  contract,
  timeout,
  unavailable,
  unknown,
}

class LiveGameSyncFailure implements Exception {
  const LiveGameSyncFailure(this.kind);

  final LiveGameSyncFailureKind kind;

  @override
  String toString() => 'LiveGameSyncFailure: ${kind.name}';
}

class ParticipantLiveGameSyncState {
  const ParticipantLiveGameSyncState({
    required this.status,
    this.projection,
    this.failureKind,
  });

  const ParticipantLiveGameSyncState.idle()
    : status = LiveGameSyncStatus.idle,
      projection = null,
      failureKind = null;

  final LiveGameSyncStatus status;
  final ParticipantGameProjection? projection;
  final LiveGameSyncFailureKind? failureKind;

  bool get hasRetainedProjection => projection != null;
}

abstract interface class ParticipantLiveGameGateway {
  Future<ParticipantGameProjection> fetchProjection();

  Stream<LiveGameInvalidationHint> watchInvalidationHints();
}

class ParticipantLiveGameSynchronizer {
  ParticipantLiveGameSynchronizer({
    required ParticipantLiveGameGateway gateway,
    required String expectedClubId,
    required String sessionId,
    Duration fetchTimeout = const Duration(seconds: 8),
    Duration missedEventRecoveryInterval = const Duration(seconds: 30),
  }) : _gateway = gateway,
       _fetchTimeout = fetchTimeout,
       _missedEventRecoveryInterval = missedEventRecoveryInterval,
       _reconciler = ParticipantProjectionReconciler(
         expectedClubId: expectedClubId,
         sessionId: sessionId,
       ) {
    if (missedEventRecoveryInterval <= Duration.zero) {
      throw ArgumentError.value(
        missedEventRecoveryInterval,
        'missedEventRecoveryInterval',
      );
    }
  }

  final ParticipantLiveGameGateway _gateway;
  final Duration _fetchTimeout;
  final Duration _missedEventRecoveryInterval;
  final ParticipantProjectionReconciler _reconciler;
  final StreamController<ParticipantLiveGameSyncState> _states =
      StreamController<ParticipantLiveGameSyncState>.broadcast(sync: true);

  ParticipantLiveGameSyncState _state =
      const ParticipantLiveGameSyncState.idle();
  StreamSubscription<LiveGameInvalidationHint>? _hintSubscription;
  Future<void>? _refreshInFlight;
  Timer? _missedEventRecoveryTimer;
  bool _started = false;
  bool _disposed = false;
  bool _automaticRecoveryPaused = false;

  ParticipantLiveGameSyncState get state => _state;

  Stream<ParticipantLiveGameSyncState> get states => _states.stream;

  Future<void> start() async {
    _ensureActive();
    if (_started) return;
    _started = true;
    _hintSubscription = _gateway.watchInvalidationHints().listen(
      (hint) => unawaited(_handleHint(hint)),
      onError: (Object _, StackTrace _) {
        if (_disposed) return;
        _emit(
          ParticipantLiveGameSyncState(
            status: LiveGameSyncStatus.reconnecting,
            projection: _reconciler.current,
            failureKind: LiveGameSyncFailureKind.unavailable,
          ),
        );
        unawaited(_recoverAfterHintFailure());
      },
    );
    await refresh();
  }

  Future<void> refresh() {
    _ensureActive();
    final existing = _refreshInFlight;
    if (existing != null) return existing;

    _missedEventRecoveryTimer?.cancel();
    _missedEventRecoveryTimer = null;
    final refresh = _performRefresh();
    _refreshInFlight = refresh;
    return refresh;
  }

  void markOffline() {
    _ensureActive();
    _automaticRecoveryPaused = true;
    _missedEventRecoveryTimer?.cancel();
    _missedEventRecoveryTimer = null;
    _emit(
      ParticipantLiveGameSyncState(
        status: LiveGameSyncStatus.offline,
        projection: _reconciler.current,
      ),
    );
  }

  Future<void> reconnect() async {
    _ensureActive();
    _automaticRecoveryPaused = false;
    _emit(
      ParticipantLiveGameSyncState(
        status: LiveGameSyncStatus.reconnecting,
        projection: _reconciler.current,
      ),
    );
    await refresh();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _missedEventRecoveryTimer?.cancel();
    _missedEventRecoveryTimer = null;
    await _hintSubscription?.cancel();
    _hintSubscription = null;
    _state = ParticipantLiveGameSyncState(
      status: LiveGameSyncStatus.disposed,
      projection: _reconciler.current,
    );
    await _states.close();
  }

  Future<void> _performRefresh() async {
    final current = _reconciler.current;
    _emit(
      ParticipantLiveGameSyncState(
        status: current == null
            ? LiveGameSyncStatus.loading
            : LiveGameSyncStatus.refreshing,
        projection: current,
      ),
    );

    try {
      final projection = await _gateway.fetchProjection().timeout(
        _fetchTimeout,
        onTimeout: () =>
            throw const LiveGameSyncFailure(LiveGameSyncFailureKind.timeout),
      );
      final decision = _reconciler.apply(projection);
      if (decision == LiveGameProjectionDecision.rejectedScope) {
        throw const LiveGameSyncFailure(
          LiveGameSyncFailureKind.permissionDenied,
        );
      }
      _emit(
        ParticipantLiveGameSyncState(
          status: LiveGameSyncStatus.ready,
          projection: _reconciler.current,
        ),
      );
    } on LiveGameSyncFailure catch (failure) {
      _emitFailure(failure.kind);
    } on LiveGameContractViolation {
      _emitFailure(LiveGameSyncFailureKind.contract);
    } on TimeoutException {
      _emitFailure(LiveGameSyncFailureKind.timeout);
    } catch (_) {
      _emitFailure(LiveGameSyncFailureKind.unknown);
    } finally {
      _refreshInFlight = null;
      _scheduleMissedEventRecovery();
    }
  }

  Future<void> _handleHint(LiveGameInvalidationHint hint) async {
    if (_disposed || !_reconciler.shouldReconcile(hint)) return;
    await refresh();
  }

  Future<void> _recoverAfterHintFailure() async {
    if (_disposed) return;
    await refresh();
  }

  void _scheduleMissedEventRecovery() {
    _missedEventRecoveryTimer?.cancel();
    _missedEventRecoveryTimer = null;
    if (_disposed || _automaticRecoveryPaused) return;
    final projection = _reconciler.current;
    if (projection == null || _isTerminal(projection.version.phase)) return;

    var delay = _missedEventRecoveryInterval;
    final deadline = projection.version.phaseDeadline;
    if (deadline != null) {
      final deadlineDelay =
          deadline.difference(projection.version.serverTime) +
          const Duration(seconds: 1);
      if (deadlineDelay > Duration.zero && deadlineDelay < delay) {
        delay = deadlineDelay;
      }
    }
    _missedEventRecoveryTimer = Timer(delay, () {
      _missedEventRecoveryTimer = null;
      if (_disposed || _automaticRecoveryPaused) return;
      unawaited(refresh());
    });
  }

  bool _isTerminal(LiveGamePhase phase) =>
      phase == LiveGamePhase.completed || phase == LiveGamePhase.cancelled;

  void _emitFailure(LiveGameSyncFailureKind kind) {
    if (_disposed) return;
    _emit(
      ParticipantLiveGameSyncState(
        status: LiveGameSyncStatus.failure,
        projection: _reconciler.current,
        failureKind: kind,
      ),
    );
  }

  void _emit(ParticipantLiveGameSyncState next) {
    if (_disposed) return;
    _state = next;
    _states.add(next);
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('Live game synchronizer is disposed.');
    }
  }
}
