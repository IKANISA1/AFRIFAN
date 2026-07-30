import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/live_game_v2_discovery_models.dart';
import 'live_game_v2_answer_controller.dart';
import 'live_game_v2_discovery_controller.dart';
import 'live_game_v2_participant_controller.dart';
import 'live_game_v2_synchronizer.dart';

enum ParticipantGameEntryStatus {
  idle,
  discovering,
  ready,
  empty,
  scheduled,
  entering,
  live,
  offline,
  failure,
  disposed,
}

enum ParticipantGameEntryFailureKind {
  notEligible,
  aliasMismatch,
  permissionDenied,
  unavailable,
  unknown,
}

class ParticipantGameEntryState {
  const ParticipantGameEntryState({
    required this.status,
    this.feed,
    this.selectedSession,
    this.runtime,
    this.discoveryFailureKind,
    this.entryFailureKind,
  });

  const ParticipantGameEntryState.initial()
    : status = ParticipantGameEntryStatus.idle,
      feed = null,
      selectedSession = null,
      runtime = null,
      discoveryFailureKind = null,
      entryFailureKind = null;

  final ParticipantGameEntryStatus status;
  final ParticipantGameDiscoveryFeed? feed;
  final ParticipantGameDiscoveryItem? selectedSession;
  final ParticipantLiveGameRuntimeState? runtime;
  final ParticipantDiscoveryFailureKind? discoveryFailureKind;
  final ParticipantGameEntryFailureKind? entryFailureKind;

  bool get acceptsParticipantCode => false;

  bool get hasRetainedDiscovery => feed != null;

  bool get isLive => status == ParticipantGameEntryStatus.live;
}

abstract interface class ParticipantLiveGameRuntimeFactory {
  ParticipantLiveGameController create({
    required String clubId,
    required String sessionId,
  });
}

class ParticipantGameEntryController
    extends StateNotifier<ParticipantGameEntryState> {
  ParticipantGameEntryController({
    required ParticipantDiscoveryGateway discoveryGateway,
    required ParticipantLiveGameRuntimeFactory runtimeFactory,
    required String expectedClubId,
    Duration discoveryTimeout = const Duration(seconds: 8),
    bool autoStart = true,
  }) : _runtimeFactory = runtimeFactory,
       _expectedClubId = expectedClubId.trim(),
       _discovery = ParticipantDiscoveryController(
         gateway: discoveryGateway,
         expectedClubId: expectedClubId,
         fetchTimeout: discoveryTimeout,
       ),
       super(const ParticipantGameEntryState.initial()) {
    _discoverySubscription = _discovery.states.listen(_handleDiscoveryState);
    if (autoStart) unawaited(start());
  }

  final ParticipantLiveGameRuntimeFactory _runtimeFactory;
  final String _expectedClubId;
  final ParticipantDiscoveryController _discovery;

  StreamSubscription<ParticipantDiscoveryState>? _discoverySubscription;
  ParticipantLiveGameController? _runtime;
  void Function()? _removeRuntimeListener;
  bool _started = false;
  bool _disposed = false;

  Future<void> start() async {
    _ensureActive();
    if (_started) {
      await _discovery.start();
      return;
    }
    _started = true;
    await _discovery.start();
  }

  Future<void> refreshDiscovery() {
    _ensureActive();
    return _discovery.refresh();
  }

  void markOffline() {
    _ensureActive();
    _discovery.markOffline();
    _runtime?.markOffline();
  }

  Future<void> reconnect() async {
    _ensureActive();
    await _discovery.reconnect();
    await _runtime?.reconnect();
  }

  Future<bool> openEligibleSession(String sessionId) async {
    _ensureActive();
    await start();
    final selected = _discovery.resolveSessionIdentity(sessionId);
    if (selected == null) {
      state = ParticipantGameEntryState(
        status: ParticipantGameEntryStatus.failure,
        feed: state.feed,
        entryFailureKind: ParticipantGameEntryFailureKind.notEligible,
      );
      return false;
    }

    if (selected.availability == ParticipantDiscoveryAvailability.scheduled) {
      _disposeRuntime();
      state = ParticipantGameEntryState(
        status: ParticipantGameEntryStatus.scheduled,
        feed: state.feed,
        selectedSession: selected,
      );
      return true;
    }

    if (_runtime != null &&
        state.selectedSession?.sessionId == selected.sessionId) {
      return true;
    }

    _disposeRuntime();
    final runtime = _runtimeFactory.create(
      clubId: _expectedClubId,
      sessionId: selected.sessionId,
    );
    _runtime = runtime;
    _removeRuntimeListener = runtime.addListener(
      _handleRuntimeState,
      fireImmediately: false,
    );
    state = ParticipantGameEntryState(
      status: ParticipantGameEntryStatus.entering,
      feed: state.feed,
      selectedSession: selected,
      runtime: runtime.state,
    );
    await runtime.start();
    return state.entryFailureKind == null;
  }

  Future<ParticipantAnswerSubmissionOutcome> submitAnswer(String optionKey) {
    _ensureActive();
    final runtime = _runtime;
    if (runtime == null) {
      return Future<ParticipantAnswerSubmissionOutcome>.value(
        const ParticipantAnswerSubmissionOutcome.rejected(
          ParticipantAnswerSubmissionFailureKind.invalidAction,
        ),
      );
    }
    return runtime.submitAnswer(optionKey);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_discoverySubscription?.cancel());
    unawaited(_discovery.dispose());
    _discoverySubscription = null;
    _disposeRuntime();
    super.dispose();
  }

  void _handleDiscoveryState(ParticipantDiscoveryState discoveryState) {
    if (_disposed) return;
    final status = switch (discoveryState.status) {
      ParticipantDiscoveryStatus.idle ||
      ParticipantDiscoveryStatus.loading ||
      ParticipantDiscoveryStatus.refreshing ||
      ParticipantDiscoveryStatus.reconnecting =>
        ParticipantGameEntryStatus.discovering,
      ParticipantDiscoveryStatus.ready => ParticipantGameEntryStatus.ready,
      ParticipantDiscoveryStatus.empty => ParticipantGameEntryStatus.empty,
      ParticipantDiscoveryStatus.offline => ParticipantGameEntryStatus.offline,
      ParticipantDiscoveryStatus.failure => ParticipantGameEntryStatus.failure,
      ParticipantDiscoveryStatus.disposed =>
        ParticipantGameEntryStatus.disposed,
    };
    final activeRuntime = _runtime;
    state = ParticipantGameEntryState(
      status: activeRuntime == null ? status : state.status,
      feed: discoveryState.feed,
      selectedSession: state.selectedSession,
      runtime: activeRuntime?.state,
      discoveryFailureKind: discoveryState.failureKind,
      entryFailureKind: state.entryFailureKind,
    );
  }

  void _handleRuntimeState(ParticipantLiveGameRuntimeState runtimeState) {
    if (_disposed) return;
    final projection = runtimeState.projection;
    final feedAlias = state.feed?.publicAlias;
    if (projection != null &&
        feedAlias != null &&
        projection.publicAlias != feedAlias) {
      final mismatchedRuntime = _runtime;
      scheduleMicrotask(() {
        if (_runtime == mismatchedRuntime) _disposeRuntime();
      });
      state = ParticipantGameEntryState(
        status: ParticipantGameEntryStatus.failure,
        feed: state.feed,
        selectedSession: state.selectedSession,
        entryFailureKind: ParticipantGameEntryFailureKind.aliasMismatch,
      );
      return;
    }

    final status = switch (runtimeState.syncStatus) {
      LiveGameSyncStatus.idle ||
      LiveGameSyncStatus.loading ||
      LiveGameSyncStatus.refreshing ||
      LiveGameSyncStatus.reconnecting => ParticipantGameEntryStatus.entering,
      LiveGameSyncStatus.ready => ParticipantGameEntryStatus.live,
      LiveGameSyncStatus.offline => ParticipantGameEntryStatus.offline,
      LiveGameSyncStatus.failure => ParticipantGameEntryStatus.failure,
      LiveGameSyncStatus.disposed => ParticipantGameEntryStatus.disposed,
    };
    state = ParticipantGameEntryState(
      status: status,
      feed: state.feed,
      selectedSession: state.selectedSession,
      runtime: runtimeState,
      entryFailureKind:
          runtimeState.syncFailureKind ==
              LiveGameSyncFailureKind.permissionDenied
          ? ParticipantGameEntryFailureKind.permissionDenied
          : runtimeState.syncStatus == LiveGameSyncStatus.failure
          ? ParticipantGameEntryFailureKind.unavailable
          : null,
    );
  }

  void _disposeRuntime() {
    _removeRuntimeListener?.call();
    _removeRuntimeListener = null;
    _runtime?.dispose();
    _runtime = null;
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('Participant game entry controller is disposed.');
    }
  }
}
