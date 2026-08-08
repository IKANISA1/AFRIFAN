import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_operations_models.dart';
import '../repositories/game_operations_repository.dart';

enum GameOperationsLoadStatus { idle, loading, ready, empty, failure }

class DisplayInventoryState {
  const DisplayInventoryState({
    this.status = GameOperationsLoadStatus.idle,
    this.inventory,
    this.failure,
    this.mutating = false,
  });

  final GameOperationsLoadStatus status;
  final OwnedDisplayInventory? inventory;
  final GameOperationsFailure? failure;
  final bool mutating;

  bool get requiresAuthoritativeRefresh =>
      failure?.kind == GameOperationsFailureKind.offline ||
      failure?.kind == GameOperationsFailureKind.timeout ||
      failure?.kind == GameOperationsFailureKind.conflict;

  bool get canStartPairingOperation =>
      !mutating &&
      failure == null &&
      status != GameOperationsLoadStatus.loading;

  bool get canManageDisplay =>
      !mutating &&
      failure == null &&
      status != GameOperationsLoadStatus.loading;

  DisplayInventoryState copyWith({
    GameOperationsLoadStatus? status,
    OwnedDisplayInventory? inventory,
    bool clearInventory = false,
    GameOperationsFailure? failure,
    bool clearFailure = false,
    bool? mutating,
  }) {
    return DisplayInventoryState(
      status: status ?? this.status,
      inventory: clearInventory ? null : inventory ?? this.inventory,
      failure: clearFailure ? null : failure ?? this.failure,
      mutating: mutating ?? this.mutating,
    );
  }
}

class DisplayInventoryController extends StateNotifier<DisplayInventoryState> {
  DisplayInventoryController(
    this._gateway, {
    DisplayInventoryState initialState = const DisplayInventoryState(),
  }) : super(initialState);

  final GameOperationsGateway _gateway;
  final _operationIntents = _OperationIntentRegistry();

  Future<void> load() async {
    state = state.copyWith(
      status: GameOperationsLoadStatus.loading,
      clearFailure: true,
    );
    try {
      final inventory = await _gateway.fetchOwnedDisplays();
      state = state.copyWith(
        status: inventory.displays.isEmpty
            ? GameOperationsLoadStatus.empty
            : GameOperationsLoadStatus.ready,
        inventory: inventory,
        clearFailure: true,
      );
    } on Object catch (error) {
      final failure = _failureFrom(error);
      state = state.copyWith(
        status: GameOperationsLoadStatus.failure,
        failure: failure,
        clearInventory:
            failure.kind == GameOperationsFailureKind.permissionDenied,
      );
    }
  }

  Future<bool> claim({
    required String challenge,
    required String displayName,
    required String scopeType,
    String? venueId,
  }) async {
    if (!state.canStartPairingOperation) return false;
    return _mutate(() async {
      await _gateway.claimDisplay(
        challenge: challenge,
        displayName: displayName,
        scopeType: scopeType,
        venueId: venueId,
      );
    });
  }

  Future<bool> update({
    required String displayId,
    required String displayName,
    required String scopeType,
    String? venueId,
  }) async {
    if (state.mutating ||
        state.status == GameOperationsLoadStatus.loading ||
        state.requiresAuthoritativeRefresh) {
      return false;
    }
    const slot = 'display-update';
    final intent = _operationIntents.resolve(
      slot: slot,
      fingerprint: [
        displayId,
        displayName.trim(),
        scopeType,
        venueId?.trim() ?? '',
      ].join('|'),
    );
    final succeeded = await _mutate(() async {
      await _gateway.updateDisplay(
        displayId: displayId,
        displayName: displayName,
        scopeType: scopeType,
        venueId: venueId,
        idempotencyKey: intent.key,
      );
    });
    if (succeeded) _operationIntents.complete(slot, intent);
    return succeeded;
  }

  Future<bool> revoke(String displayId) async {
    if (state.mutating ||
        state.status == GameOperationsLoadStatus.loading ||
        state.requiresAuthoritativeRefresh) {
      return false;
    }
    const slot = 'display-revoke';
    final intent = _operationIntents.resolve(
      slot: slot,
      fingerprint: displayId,
    );
    final succeeded = await _mutate(() async {
      await _gateway.revokeDisplay(
        displayId: displayId,
        idempotencyKey: intent.key,
      );
    });
    if (succeeded) _operationIntents.complete(slot, intent);
    return succeeded;
  }

  Future<bool> recover({
    required String displayId,
    required String challenge,
  }) async {
    if (state.mutating ||
        state.status == GameOperationsLoadStatus.loading ||
        state.requiresAuthoritativeRefresh) {
      return false;
    }
    final normalizedChallenge = challenge.trim().toUpperCase();
    if (normalizedChallenge.length != 8) return false;
    const slot = 'display-recover';
    final intent = _operationIntents.resolve(
      slot: slot,
      fingerprint: '$displayId|$normalizedChallenge',
    );
    final succeeded = await _mutate(() async {
      await _gateway.recoverDisplay(
        displayId: displayId,
        challenge: normalizedChallenge,
        idempotencyKey: intent.key,
      );
    });
    if (succeeded) _operationIntents.complete(slot, intent);
    return succeeded;
  }

  Future<bool> _mutate(Future<void> Function() action) async {
    if (state.mutating) return false;
    state = state.copyWith(mutating: true, clearFailure: true);
    try {
      await action();
      await load();
      state = state.copyWith(mutating: false);
      return true;
    } on Object catch (error) {
      final failure = _failureFrom(error);
      state = state.copyWith(mutating: false, failure: failure);
      return false;
    }
  }
}

class ManagedGamesState {
  const ManagedGamesState({
    this.status = GameOperationsLoadStatus.idle,
    this.inventory,
    this.failure,
  });

  final GameOperationsLoadStatus status;
  final ManagedGamesInventory? inventory;
  final GameOperationsFailure? failure;

  bool get canUseInventory =>
      failure == null && status != GameOperationsLoadStatus.loading;

  bool get canPlanSession => inventory?.canPlan == true && canUseInventory;

  ManagedGamesState copyWith({
    GameOperationsLoadStatus? status,
    ManagedGamesInventory? inventory,
    bool clearInventory = false,
    GameOperationsFailure? failure,
    bool clearFailure = false,
  }) {
    return ManagedGamesState(
      status: status ?? this.status,
      inventory: clearInventory ? null : inventory ?? this.inventory,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

class ManagedGamesController extends StateNotifier<ManagedGamesState> {
  ManagedGamesController(
    this._gateway, {
    ManagedGamesState initialState = const ManagedGamesState(),
  }) : super(initialState);

  final GameOperationsGateway _gateway;

  Future<void> load() async {
    state = state.copyWith(
      status: GameOperationsLoadStatus.loading,
      clearFailure: true,
    );
    try {
      final inventory = await _gateway.fetchManagedGames();
      state = state.copyWith(
        status: inventory.sessions.isEmpty
            ? GameOperationsLoadStatus.empty
            : GameOperationsLoadStatus.ready,
        inventory: inventory,
        clearFailure: true,
      );
    } on Object catch (error) {
      final failure = _failureFrom(error);
      state = state.copyWith(
        status: GameOperationsLoadStatus.failure,
        failure: failure,
        clearInventory:
            failure.kind == GameOperationsFailureKind.permissionDenied,
      );
    }
  }
}

class SessionPlannerState {
  const SessionPlannerState({
    this.status = GameOperationsLoadStatus.idle,
    this.options,
    this.createdSession,
    this.failure,
    this.submitting = false,
  });

  final GameOperationsLoadStatus status;
  final GamePlannerOptions? options;
  final ManagedGameSession? createdSession;
  final GameOperationsFailure? failure;
  final bool submitting;

  bool get requiresAuthoritativeRefresh =>
      failure?.kind == GameOperationsFailureKind.timeout ||
      failure?.kind == GameOperationsFailureKind.conflict;

  bool get canEditPlan =>
      options != null &&
      status != GameOperationsLoadStatus.loading &&
      !requiresAuthoritativeRefresh &&
      failure?.kind != GameOperationsFailureKind.permissionDenied &&
      !submitting;

  bool get canSubmit => canEditPlan;

  SessionPlannerState copyWith({
    GameOperationsLoadStatus? status,
    GamePlannerOptions? options,
    ManagedGameSession? createdSession,
    GameOperationsFailure? failure,
    bool? submitting,
    bool clearOptions = false,
    bool clearCreatedSession = false,
    bool clearFailure = false,
  }) {
    return SessionPlannerState(
      status: status ?? this.status,
      options: clearOptions ? null : options ?? this.options,
      createdSession: clearCreatedSession
          ? null
          : createdSession ?? this.createdSession,
      failure: clearFailure ? null : failure ?? this.failure,
      submitting: submitting ?? this.submitting,
    );
  }
}

class SessionPlannerController extends StateNotifier<SessionPlannerState> {
  SessionPlannerController(
    this._gateway, {
    SessionPlannerState initialState = const SessionPlannerState(),
  }) : super(initialState);

  final GameOperationsGateway _gateway;
  final _operationIntents = _OperationIntentRegistry();

  Future<void> load() async {
    state = state.copyWith(
      status: GameOperationsLoadStatus.loading,
      submitting: false,
      clearFailure: true,
      clearCreatedSession: true,
    );
    try {
      final options = await _gateway.fetchPlannerOptions();
      state = state.copyWith(
        status: options.packs.isEmpty
            ? GameOperationsLoadStatus.empty
            : GameOperationsLoadStatus.ready,
        options: options,
        clearFailure: true,
      );
    } on Object catch (error) {
      final failure = _failureFrom(error);
      state = state.copyWith(
        status: GameOperationsLoadStatus.failure,
        failure: failure,
        clearOptions:
            failure.kind == GameOperationsFailureKind.permissionDenied,
      );
    }
  }

  Future<bool> create({
    required String packId,
    required DateTime scheduledStartAt,
    required String eligibilityScope,
    required List<String> displayIds,
    required List<String> inviteeUserIds,
  }) async {
    if (!state.canSubmit) return false;
    const slot = 'session-create';
    final normalizedDisplayIds = displayIds.toSet().toList()..sort();
    final normalizedInviteeUserIds = inviteeUserIds.toSet().toList()..sort();
    final intent = _operationIntents.resolve(
      slot: slot,
      fingerprint: [
        packId,
        scheduledStartAt.toUtc().toIso8601String(),
        eligibilityScope,
        normalizedDisplayIds.join(','),
        normalizedInviteeUserIds.join(','),
      ].join('|'),
    );
    state = state.copyWith(
      submitting: true,
      clearFailure: true,
      clearCreatedSession: true,
    );
    try {
      final created = await _gateway.createManagedGame(
        packId: packId,
        scheduledStartAt: scheduledStartAt,
        eligibilityScope: eligibilityScope,
        displayIds: normalizedDisplayIds,
        inviteeUserIds: normalizedInviteeUserIds,
        idempotencyKey: intent.key,
      );
      _operationIntents.complete(slot, intent);
      state = state.copyWith(
        status: GameOperationsLoadStatus.ready,
        createdSession: created,
        submitting: false,
        clearFailure: true,
      );
      return true;
    } on Object catch (error) {
      final failure = _failureFrom(error);
      state = state.copyWith(failure: failure, submitting: false);
      return false;
    }
  }
}

class LiveGameControlState {
  const LiveGameControlState({
    this.status = GameOperationsLoadStatus.idle,
    this.session,
    this.failure,
    this.mutating = false,
    this.refreshRequired = false,
  });

  final GameOperationsLoadStatus status;
  final ManagedGameSession? session;
  final GameOperationsFailure? failure;
  final bool mutating;
  final bool refreshRequired;

  bool get requiresAuthoritativeRefresh =>
      refreshRequired ||
      failure?.kind == GameOperationsFailureKind.timeout ||
      failure?.kind == GameOperationsFailureKind.conflict;

  bool get canOperate =>
      session != null &&
      !mutating &&
      status != GameOperationsLoadStatus.loading &&
      failure?.kind != GameOperationsFailureKind.permissionDenied &&
      !requiresAuthoritativeRefresh;

  LiveGameControlState copyWith({
    GameOperationsLoadStatus? status,
    ManagedGameSession? session,
    GameOperationsFailure? failure,
    bool? mutating,
    bool? refreshRequired,
    bool clearSession = false,
    bool clearFailure = false,
  }) {
    return LiveGameControlState(
      status: status ?? this.status,
      session: clearSession ? null : session ?? this.session,
      failure: clearFailure ? null : failure ?? this.failure,
      mutating: mutating ?? this.mutating,
      refreshRequired: refreshRequired ?? this.refreshRequired,
    );
  }
}

class LiveGameControlController extends StateNotifier<LiveGameControlState> {
  LiveGameControlController(
    this._gateway,
    this.sessionId, {
    LiveGameControlState initialState = const LiveGameControlState(),
  }) : super(initialState);

  final GameOperationsGateway _gateway;
  final String sessionId;
  final _operationIntents = _OperationIntentRegistry();

  Future<void> load() async {
    state = state.copyWith(
      status: GameOperationsLoadStatus.loading,
      mutating: false,
      refreshRequired: true,
      clearFailure: true,
    );
    try {
      final session = await _gateway.fetchManagedGame(sessionId);
      state = LiveGameControlState(
        status: GameOperationsLoadStatus.ready,
        session: session,
      );
    } on Object catch (error) {
      final failure = _failureFrom(error);
      state = state.copyWith(
        status: GameOperationsLoadStatus.failure,
        failure: failure,
        mutating: false,
        refreshRequired: true,
        clearSession:
            failure.kind == GameOperationsFailureKind.permissionDenied,
      );
    }
  }

  Future<bool> transition(String phase) async {
    final current = state.session;
    if (!state.canOperate) return false;
    if (current == null ||
        !current.allowedActions.contains(phase) ||
        phase == 'skip_question' ||
        phase == 'end_early') {
      state = LiveGameControlState(
        status: state.status,
        session: current,
        failure: const GameOperationsFailure(
          GameOperationsFailureKind.invalidInput,
        ),
      );
      return false;
    }
    final slot = 'transition:${current.id}:$phase';
    final intent = _operationIntents.resolve(
      slot: slot,
      fingerprint: [
        current.id,
        current.sessionVersion,
        current.currentQuestion?.id ?? '',
        phase,
      ].join('|'),
      phaseDeadline: phase == 'question_open'
          ? () => DateTime.now().toUtc().add(const Duration(seconds: 30))
          : null,
    );
    state = state.copyWith(
      mutating: true,
      refreshRequired: false,
      clearFailure: true,
    );
    try {
      final updated = await _gateway.transitionManagedGame(
        session: current,
        requestedPhase: phase,
        idempotencyKey: intent.key,
        phaseDeadline: intent.phaseDeadline,
      );
      _operationIntents.complete(slot, intent);
      state = LiveGameControlState(
        status: GameOperationsLoadStatus.ready,
        session: updated,
      );
      return true;
    } on Object catch (error) {
      final failure = _failureFrom(error);
      state = state.copyWith(
        status: GameOperationsLoadStatus.failure,
        failure: failure,
        mutating: false,
        refreshRequired:
            failure.kind == GameOperationsFailureKind.timeout ||
            failure.kind == GameOperationsFailureKind.conflict ||
            failure.kind == GameOperationsFailureKind.permissionDenied,
        clearSession:
            failure.kind == GameOperationsFailureKind.permissionDenied,
      );
      return false;
    }
  }

  Future<bool> skipQuestion({
    required String nextSessionQuestionId,
    required String reason,
  }) {
    return _runReasonedException(
      action: 'skip_question',
      reason: reason,
      nextSessionQuestionId: nextSessionQuestionId,
    );
  }

  Future<bool> endEarly({required String reason}) {
    return _runReasonedException(action: 'end_early', reason: reason);
  }

  Future<bool> _runReasonedException({
    required String action,
    required String reason,
    String? nextSessionQuestionId,
  }) async {
    final current = state.session;
    final normalizedReason = reason.trim();
    if (!state.canOperate) return false;
    final isAuthorized =
        current != null &&
        (current.allowedActions.contains(action) ||
            (action == 'end_early' &&
                current.allowedActions.contains('completed') &&
                (current.phase == 'paused' ||
                    (current.phase == 'reveal' &&
                        current.nextQuestion != null))));
    if (current == null ||
        !isAuthorized ||
        normalizedReason.length < 3 ||
        normalizedReason.length > 234 ||
        (action == 'skip_question' &&
            (nextSessionQuestionId == null ||
                nextSessionQuestionId == current.currentQuestion?.id))) {
      state = LiveGameControlState(
        status: state.status,
        session: current,
        failure: const GameOperationsFailure(
          GameOperationsFailureKind.invalidInput,
        ),
      );
      return false;
    }
    final slot = 'exception:${current.id}:$action';
    final intent = _operationIntents.resolve(
      slot: slot,
      fingerprint: [
        current.id,
        current.sessionVersion,
        current.currentQuestion?.id ?? '',
        nextSessionQuestionId ?? '',
        action,
        normalizedReason,
      ].join('|'),
    );
    state = state.copyWith(
      mutating: true,
      refreshRequired: false,
      clearFailure: true,
    );
    try {
      final updated = action == 'skip_question'
          ? await _gateway.skipManagedGameQuestion(
              session: current,
              nextSessionQuestionId: nextSessionQuestionId!,
              idempotencyKey: intent.key,
              reason: normalizedReason,
            )
          : await _gateway.endManagedGameEarly(
              session: current,
              idempotencyKey: intent.key,
              reason: normalizedReason,
            );
      _operationIntents.complete(slot, intent);
      state = LiveGameControlState(
        status: GameOperationsLoadStatus.ready,
        session: updated,
      );
      return true;
    } on Object catch (error) {
      final failure = _failureFrom(error);
      state = state.copyWith(
        status: GameOperationsLoadStatus.failure,
        failure: failure,
        mutating: false,
        refreshRequired:
            failure.kind == GameOperationsFailureKind.timeout ||
            failure.kind == GameOperationsFailureKind.conflict ||
            failure.kind == GameOperationsFailureKind.permissionDenied,
        clearSession:
            failure.kind == GameOperationsFailureKind.permissionDenied,
      );
      return false;
    }
  }
}

class _OperationIntent {
  const _OperationIntent({
    required this.fingerprint,
    required this.key,
    this.phaseDeadline,
  });

  final String fingerprint;
  final String key;
  final DateTime? phaseDeadline;
}

class _OperationIntentRegistry {
  final Map<String, _OperationIntent> _pending = <String, _OperationIntent>{};

  _OperationIntent resolve({
    required String slot,
    required String fingerprint,
    DateTime Function()? phaseDeadline,
  }) {
    final existing = _pending[slot];
    if (existing != null && existing.fingerprint == fingerprint) {
      return existing;
    }
    final intent = _OperationIntent(
      fingerprint: fingerprint,
      key: _idempotency(slot, fingerprint),
      phaseDeadline: phaseDeadline?.call(),
    );
    _pending[slot] = intent;
    return intent;
  }

  void complete(String slot, _OperationIntent intent) {
    if (identical(_pending[slot], intent)) {
      _pending.remove(slot);
    }
  }
}

String _idempotency(String operation, String entity) {
  final end = entity.length > 36 ? 36 : entity.length;
  return '$operation:${entity.substring(0, end)}:'
      '${DateTime.now().toUtc().microsecondsSinceEpoch}';
}

GameOperationsFailure _failureFrom(Object error) {
  if (error is GameOperationsFailure) return error;
  return GameOperationsFailure(GameOperationsFailureKind.unavailable, error);
}
