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
  Future<ParticipantGameDiscoveryFeed> fetchEligibleSessions({
    String? sessionId,
  });
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

  Future<ParticipantGameDiscoveryItem?> authorizeSessionIdentity(
    String sessionId,
  ) async {
    _ensureActive();
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) return null;

    _emit(
      ParticipantDiscoveryState(
        status: _current == null
            ? ParticipantDiscoveryStatus.loading
            : ParticipantDiscoveryStatus.refreshing,
        feed: _current,
      ),
    );

    try {
      final targetedFeed = await _gateway
          .fetchEligibleSessions(sessionId: normalizedSessionId)
          .timeout(
            _fetchTimeout,
            onTimeout: () => throw const ParticipantDiscoveryFailure(
              ParticipantDiscoveryFailureKind.timeout,
            ),
          );
      _validateFeed(targetedFeed);
      if (targetedFeed.sessions.any(
        (session) => session.sessionId != normalizedSessionId,
      )) {
        throw const LiveGameContractViolation(
          'Targeted discovery returned an unrelated session.',
        );
      }

      final targetedSession = targetedFeed.sessionById(normalizedSessionId);
      if (targetedSession != null) {
        _current = _mergeTargetedFeed(targetedFeed, targetedSession);
      }
      _emit(
        ParticipantDiscoveryState(
          status: _current == null || _current!.isEmpty
              ? ParticipantDiscoveryStatus.empty
              : ParticipantDiscoveryStatus.ready,
          feed: _current,
        ),
      );
      return _current?.sessionById(normalizedSessionId);
    } on ParticipantDiscoveryFailure catch (failure) {
      _emitFailure(failure.kind);
    } on LiveGameContractViolation {
      _emitFailure(ParticipantDiscoveryFailureKind.contract);
    } on TimeoutException {
      _emitFailure(ParticipantDiscoveryFailureKind.timeout);
    } catch (_) {
      _emitFailure(ParticipantDiscoveryFailureKind.unknown);
    }
    return null;
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
      _validateFeed(feed);
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

  void _validateFeed(ParticipantGameDiscoveryFeed feed) {
    final containsUnauthorizedSession = feed.sessions.any(
      (session) =>
          session.clubId != _expectedClubId || session.eligible == false,
    );
    if (feed.clubId != _expectedClubId || containsUnauthorizedSession) {
      throw const ParticipantDiscoveryFailure(
        ParticipantDiscoveryFailureKind.permissionDenied,
      );
    }
  }

  ParticipantGameDiscoveryFeed _mergeTargetedFeed(
    ParticipantGameDiscoveryFeed targetedFeed,
    ParticipantGameDiscoveryItem targetedSession,
  ) {
    final current = _current;
    if (current == null) return targetedFeed;
    if (current.publicAlias != targetedFeed.publicAlias) {
      throw const LiveGameContractViolation(
        'Targeted discovery changed the participant public alias.',
      );
    }

    final currentSession = current.sessionById(targetedSession.sessionId);
    final selected =
        currentSession != null &&
            currentSession.sessionVersion > targetedSession.sessionVersion
        ? currentSession
        : targetedSession;
    final sessions =
        current.sessions
            .where((session) => session.sessionId != selected.sessionId)
            .toList(growable: true)
          ..add(selected);
    return ParticipantGameDiscoveryFeed(
      clubId: current.clubId,
      feedVersion: targetedFeed.feedVersion > current.feedVersion
          ? targetedFeed.feedVersion
          : current.feedVersion,
      serverTime: targetedFeed.serverTime.isAfter(current.serverTime)
          ? targetedFeed.serverTime
          : current.serverTime,
      publicAlias: current.publicAlias,
      sessions: List<ParticipantGameDiscoveryItem>.unmodifiable(sessions),
    );
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
