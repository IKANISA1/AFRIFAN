import 'dart:async';

import '../models/live_game_v2_discovery_models.dart';
import '../models/live_game_v2_models.dart';

enum ParticipantDiscoveryStatus {
  idle,
  loading,
  ready,
  empty,
  refreshing,
  reconnecting,
  offline,
  failure,
  disposed,
}

enum ParticipantDiscoveryFailureKind {
  permissionDenied,
  contract,
  timeout,
  unavailable,
  unknown,
}

class ParticipantDiscoveryFailure implements Exception {
  const ParticipantDiscoveryFailure(this.kind);

  final ParticipantDiscoveryFailureKind kind;

  @override
  String toString() => 'ParticipantDiscoveryFailure: ${kind.name}';
}

class ParticipantDiscoveryState {
  const ParticipantDiscoveryState({
    required this.status,
    this.feed,
    this.failureKind,
  });

  const ParticipantDiscoveryState.idle()
    : status = ParticipantDiscoveryStatus.idle,
      feed = null,
      failureKind = null;

  final ParticipantDiscoveryStatus status;
  final ParticipantGameDiscoveryFeed? feed;
  final ParticipantDiscoveryFailureKind? failureKind;

  bool get hasRetainedFeed => feed != null;
}

abstract interface class ParticipantDiscoveryGateway {
  Future<ParticipantGameDiscoveryFeed> fetchEligibleSessions();
}

class ParticipantDiscoveryController {
  ParticipantDiscoveryController({
    required ParticipantDiscoveryGateway gateway,
    required String expectedClubId,
    Duration fetchTimeout = const Duration(seconds: 8),
  }) : _gateway = gateway,
       _expectedClubId = expectedClubId,
       _fetchTimeout = fetchTimeout;

  final ParticipantDiscoveryGateway _gateway;
  final String _expectedClubId;
  final Duration _fetchTimeout;
  final StreamController<ParticipantDiscoveryState> _states =
      StreamController<ParticipantDiscoveryState>.broadcast(sync: true);

  ParticipantDiscoveryState _state = const ParticipantDiscoveryState.idle();
  ParticipantGameDiscoveryFeed? _current;
  Future<void>? _refreshInFlight;
  bool _started = false;
  bool _disposed = false;

  ParticipantDiscoveryState get state => _state;

  Stream<ParticipantDiscoveryState> get states => _states.stream;

  Future<void> start() {
    _ensureActive();
    if (_started) return _refreshInFlight ?? Future<void>.value();
    _started = true;
    return refresh();
  }

  Future<void> refresh() {
    _ensureActive();
    final existing = _refreshInFlight;
    if (existing != null) return existing;

    final refresh = _performRefresh();
    _refreshInFlight = refresh;
    return refresh;
  }

  void markOffline() {
    _ensureActive();
    _emit(
      ParticipantDiscoveryState(
        status: ParticipantDiscoveryStatus.offline,
        feed: _current,
      ),
    );
  }

  Future<void> reconnect() async {
    _ensureActive();
    _emit(
      ParticipantDiscoveryState(
        status: ParticipantDiscoveryStatus.reconnecting,
        feed: _current,
      ),
    );
    await refresh();
  }

  ParticipantGameDiscoveryItem? resolveSessionIdentity(String sessionId) {
    _ensureActive();
    return _current?.sessionById(sessionId);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _state = ParticipantDiscoveryState(
      status: ParticipantDiscoveryStatus.disposed,
      feed: _current,
    );
    await _states.close();
  }

  Future<void> _performRefresh() async {
    _emit(
      ParticipantDiscoveryState(
        status: _current == null
            ? ParticipantDiscoveryStatus.loading
            : ParticipantDiscoveryStatus.refreshing,
        feed: _current,
      ),
    );

    try {
      final feed = await _gateway.fetchEligibleSessions().timeout(
        _fetchTimeout,
        onTimeout: () => throw const ParticipantDiscoveryFailure(
          ParticipantDiscoveryFailureKind.timeout,
        ),
      );
      final containsUnauthorizedSession = feed.sessions.any(
        (session) =>
            session.clubId != _expectedClubId || session.eligible == false,
      );
      if (feed.clubId != _expectedClubId || containsUnauthorizedSession) {
        throw const ParticipantDiscoveryFailure(
          ParticipantDiscoveryFailureKind.permissionDenied,
        );
      }
      final current = _current;
      if (current == null || feed.isNewerThan(current)) {
        _current = feed;
      }
      _emit(
        ParticipantDiscoveryState(
          status: _current!.isEmpty
              ? ParticipantDiscoveryStatus.empty
              : ParticipantDiscoveryStatus.ready,
          feed: _current,
        ),
      );
    } on ParticipantDiscoveryFailure catch (failure) {
      _emitFailure(failure.kind);
    } on LiveGameContractViolation {
      _emitFailure(ParticipantDiscoveryFailureKind.contract);
    } on TimeoutException {
      _emitFailure(ParticipantDiscoveryFailureKind.timeout);
    } catch (_) {
      _emitFailure(ParticipantDiscoveryFailureKind.unknown);
    } finally {
      _refreshInFlight = null;
    }
  }

  void _emitFailure(ParticipantDiscoveryFailureKind kind) {
    if (_disposed) return;
    _emit(
      ParticipantDiscoveryState(
        status: ParticipantDiscoveryStatus.failure,
        feed: _current,
        failureKind: kind,
      ),
    );
  }

  void _emit(ParticipantDiscoveryState next) {
    if (_disposed) return;
    _state = next;
    _states.add(next);
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('Participant discovery controller is disposed.');
    }
  }
}
