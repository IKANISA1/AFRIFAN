import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/live_game_v2_models.dart';
import 'live_game_v2_answer_controller.dart';
import 'live_game_v2_synchronizer.dart';

class ParticipantLiveGameRuntimeState {
  const ParticipantLiveGameRuntimeState({
    required this.syncStatus,
    required this.answerStatus,
    this.projection,
    this.syncFailureKind,
    this.answerFailureKind,
    this.selectedOptionKey,
  });

  const ParticipantLiveGameRuntimeState.initial()
    : syncStatus = LiveGameSyncStatus.idle,
      answerStatus = ParticipantAnswerSubmissionStatus.idle,
      projection = null,
      syncFailureKind = null,
      answerFailureKind = null,
      selectedOptionKey = null;

  final LiveGameSyncStatus syncStatus;
  final ParticipantAnswerSubmissionStatus answerStatus;
  final ParticipantGameProjection? projection;
  final LiveGameSyncFailureKind? syncFailureKind;
  final ParticipantAnswerSubmissionFailureKind? answerFailureKind;
  final String? selectedOptionKey;

  bool get hasRetainedProjection => projection != null;

  bool get requiresAuthoritativeRefresh =>
      answerStatus == ParticipantAnswerSubmissionStatus.uncertain;

  bool get actionsBlocked {
    if (syncStatus != LiveGameSyncStatus.ready) return true;
    if (answerStatus == ParticipantAnswerSubmissionStatus.submitting ||
        answerStatus == ParticipantAnswerSubmissionStatus.uncertain ||
        answerStatus == ParticipantAnswerSubmissionStatus.failure ||
        answerStatus == ParticipantAnswerSubmissionStatus.disposed) {
      return true;
    }
    return !(projection?.canSubmitAnswer ?? false);
  }
}

class ParticipantLiveGameController
    extends StateNotifier<ParticipantLiveGameRuntimeState> {
  ParticipantLiveGameController({
    required ParticipantLiveGameGateway syncGateway,
    required ParticipantAnswerSubmissionGateway answerGateway,
    required String expectedClubId,
    required String sessionId,
    Duration fetchTimeout = const Duration(seconds: 8),
    Duration missedEventRecoveryInterval = const Duration(seconds: 30),
    Duration submissionTimeout = const Duration(seconds: 8),
    bool autoStart = true,
  }) : _answerGateway = answerGateway,
       _expectedClubId = expectedClubId.trim(),
       _sessionId = sessionId.trim(),
       _submissionTimeout = submissionTimeout,
       _synchronizer = ParticipantLiveGameSynchronizer(
         gateway: syncGateway,
         expectedClubId: expectedClubId,
         sessionId: sessionId,
         fetchTimeout: fetchTimeout,
         missedEventRecoveryInterval: missedEventRecoveryInterval,
       ),
       super(const ParticipantLiveGameRuntimeState.initial()) {
    _syncSubscription = _synchronizer.states.listen(_handleSyncState);
    if (autoStart) unawaited(start());
  }

  final ParticipantAnswerSubmissionGateway _answerGateway;
  final String _expectedClubId;
  final String _sessionId;
  final Duration _submissionTimeout;
  final ParticipantLiveGameSynchronizer _synchronizer;

  StreamSubscription<ParticipantLiveGameSyncState>? _syncSubscription;
  StreamSubscription<ParticipantAnswerSubmissionState>? _answerSubscription;
  ParticipantAnswerSubmissionController? _answerController;
  bool _started = false;
  bool _disposed = false;

  Future<void> start() async {
    _ensureActive();
    if (_started) return;
    _started = true;
    await _synchronizer.start();
  }

  Future<void> refresh() {
    _ensureActive();
    return _synchronizer.refresh();
  }

  void markOffline() {
    _ensureActive();
    _synchronizer.markOffline();
  }

  Future<void> reconnect() {
    _ensureActive();
    return _synchronizer.reconnect();
  }

  Future<ParticipantAnswerSubmissionOutcome> submitAnswer(String optionKey) {
    _ensureActive();
    if (state.actionsBlocked) {
      return Future<ParticipantAnswerSubmissionOutcome>.value(
        ParticipantAnswerSubmissionOutcome.rejected(_blockedFailureKind()),
      );
    }
    final controller = _answerController;
    if (controller == null) {
      return Future<ParticipantAnswerSubmissionOutcome>.value(
        const ParticipantAnswerSubmissionOutcome.rejected(
          ParticipantAnswerSubmissionFailureKind.invalidAction,
        ),
      );
    }
    return controller.submit(optionKey);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_syncSubscription?.cancel());
    unawaited(_answerSubscription?.cancel());
    unawaited(_answerController?.dispose());
    unawaited(_synchronizer.dispose());
    _syncSubscription = null;
    _answerSubscription = null;
    _answerController = null;
    super.dispose();
  }

  void _handleSyncState(ParticipantLiveGameSyncState syncState) {
    if (_disposed) return;
    final projection = syncState.projection;
    if (projection != null) {
      _applyAuthoritativeProjection(projection);
    }

    final answerState = _answerController?.state;
    state = ParticipantLiveGameRuntimeState(
      syncStatus: syncState.status,
      answerStatus:
          answerState?.status ?? ParticipantAnswerSubmissionStatus.idle,
      projection: answerState?.projection ?? projection,
      syncFailureKind: syncState.failureKind,
      answerFailureKind: answerState?.failureKind,
      selectedOptionKey: answerState?.selectedOptionKey,
    );
  }

  void _applyAuthoritativeProjection(ParticipantGameProjection projection) {
    final controller = _answerController;
    if (controller == null) {
      final created = ParticipantAnswerSubmissionController(
        gateway: _answerGateway,
        initialProjection: projection,
        expectedClubId: _expectedClubId,
        sessionId: _sessionId,
        submissionTimeout: _submissionTimeout,
      );
      _answerController = created;
      _answerSubscription = created.states.listen(_handleAnswerState);
      return;
    }

    if (controller.state.status ==
            ParticipantAnswerSubmissionStatus.uncertain ||
        controller.state.status == ParticipantAnswerSubmissionStatus.failure) {
      controller.resetFromAuthoritativeProjection(projection);
      return;
    }
    controller.reconcileProjection(projection);
  }

  void _handleAnswerState(ParticipantAnswerSubmissionState answerState) {
    if (_disposed) return;
    state = ParticipantLiveGameRuntimeState(
      syncStatus: state.syncStatus,
      answerStatus: answerState.status,
      projection: answerState.projection,
      syncFailureKind: state.syncFailureKind,
      answerFailureKind: answerState.failureKind,
      selectedOptionKey: answerState.selectedOptionKey,
    );
  }

  ParticipantAnswerSubmissionFailureKind _blockedFailureKind() {
    if (state.syncFailureKind == LiveGameSyncFailureKind.permissionDenied) {
      return ParticipantAnswerSubmissionFailureKind.permissionDenied;
    }
    if (state.syncStatus == LiveGameSyncStatus.offline ||
        state.syncStatus == LiveGameSyncStatus.reconnecting ||
        state.syncStatus == LiveGameSyncStatus.failure) {
      return ParticipantAnswerSubmissionFailureKind.unavailable;
    }
    if (state.answerFailureKind != null) {
      return state.answerFailureKind!;
    }
    return ParticipantAnswerSubmissionFailureKind.invalidAction;
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('Participant live game controller is disposed.');
    }
  }
}
