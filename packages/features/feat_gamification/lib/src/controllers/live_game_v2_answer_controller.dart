import 'dart:async';

import '../models/live_game_v2_models.dart';

enum ParticipantAnswerSubmissionStatus {
  idle,
  submitting,
  accepted,
  uncertain,
  failure,
  disposed,
}

enum ParticipantAnswerSubmissionFailureKind {
  invalidAction,
  conflict,
  permissionDenied,
  timeout,
  contract,
  unavailable,
  unknown,
}

class ParticipantAnswerSubmissionFailure implements Exception {
  const ParticipantAnswerSubmissionFailure(this.kind);

  final ParticipantAnswerSubmissionFailureKind kind;

  @override
  String toString() => 'ParticipantAnswerSubmissionFailure: ${kind.name}';
}

class ParticipantAnswerSubmissionRequest {
  const ParticipantAnswerSubmissionRequest({
    required this.clubId,
    required this.sessionId,
    required this.questionId,
    required this.optionKey,
    required this.expectedSessionVersion,
    required this.expectedQuestionVersion,
    required this.idempotencyKey,
  });

  final String clubId;
  final String sessionId;
  final String questionId;
  final String optionKey;
  final int expectedSessionVersion;
  final int expectedQuestionVersion;
  final String idempotencyKey;

  Map<String, Object> toJson() => <String, Object>{
    'club_id': clubId,
    'session_id': sessionId,
    'question_id': questionId,
    'option_key': optionKey,
    'expected_session_version': expectedSessionVersion,
    'expected_question_version': expectedQuestionVersion,
    'idempotency_key': idempotencyKey,
  };
}

abstract interface class ParticipantAnswerSubmissionGateway {
  Future<ParticipantGameProjection> submitAnswer(
    ParticipantAnswerSubmissionRequest request,
  );
}

class ParticipantAnswerSubmissionState {
  const ParticipantAnswerSubmissionState({
    required this.status,
    required this.projection,
    this.selectedOptionKey,
    this.failureKind,
  });

  final ParticipantAnswerSubmissionStatus status;
  final ParticipantGameProjection projection;
  final String? selectedOptionKey;
  final ParticipantAnswerSubmissionFailureKind? failureKind;

  bool get requiresAuthoritativeRefresh =>
      status == ParticipantAnswerSubmissionStatus.uncertain;
}

class ParticipantAnswerSubmissionOutcome {
  const ParticipantAnswerSubmissionOutcome._({
    required this.accepted,
    this.failureKind,
  });

  const ParticipantAnswerSubmissionOutcome.accepted() : this._(accepted: true);

  const ParticipantAnswerSubmissionOutcome.rejected(
    ParticipantAnswerSubmissionFailureKind failureKind,
  ) : this._(accepted: false, failureKind: failureKind);

  final bool accepted;
  final ParticipantAnswerSubmissionFailureKind? failureKind;
}

class ParticipantAnswerSubmissionController {
  ParticipantAnswerSubmissionController({
    required ParticipantAnswerSubmissionGateway gateway,
    required ParticipantGameProjection initialProjection,
    required String expectedClubId,
    required String sessionId,
    Duration submissionTimeout = const Duration(seconds: 8),
  }) : _gateway = gateway,
       _expectedClubId = expectedClubId.trim(),
       _sessionId = sessionId.trim(),
       _submissionTimeout = submissionTimeout,
       _state = ParticipantAnswerSubmissionState(
         status: ParticipantAnswerSubmissionStatus.idle,
         projection: initialProjection,
       ) {
    _assertScope(initialProjection);
  }

  final ParticipantAnswerSubmissionGateway _gateway;
  final String _expectedClubId;
  final String _sessionId;
  final Duration _submissionTimeout;
  final StreamController<ParticipantAnswerSubmissionState> _states =
      StreamController<ParticipantAnswerSubmissionState>.broadcast(sync: true);

  ParticipantAnswerSubmissionState _state;
  Future<ParticipantAnswerSubmissionOutcome>? _submissionInFlight;
  String? _inFlightOptionKey;
  bool _disposed = false;

  ParticipantAnswerSubmissionState get state => _state;

  Stream<ParticipantAnswerSubmissionState> get states => _states.stream;

  Future<ParticipantAnswerSubmissionOutcome> submit(String optionKey) {
    _ensureActive();
    final normalizedOptionKey = optionKey.trim();
    final existing = _submissionInFlight;
    if (existing != null) {
      if (_inFlightOptionKey == normalizedOptionKey) return existing;
      return Future<ParticipantAnswerSubmissionOutcome>.value(
        const ParticipantAnswerSubmissionOutcome.rejected(
          ParticipantAnswerSubmissionFailureKind.conflict,
        ),
      );
    }

    final projection = _state.projection;
    final question = projection.question;
    if (!projection.canSubmitAnswer ||
        question == null ||
        normalizedOptionKey.isEmpty ||
        !question.options.any((option) => option.key == normalizedOptionKey)) {
      return Future<ParticipantAnswerSubmissionOutcome>.value(
        const ParticipantAnswerSubmissionOutcome.rejected(
          ParticipantAnswerSubmissionFailureKind.invalidAction,
        ),
      );
    }

    final request = ParticipantAnswerSubmissionRequest(
      clubId: _expectedClubId,
      sessionId: _sessionId,
      questionId: question.id,
      optionKey: normalizedOptionKey,
      expectedSessionVersion: projection.version.sessionVersion,
      expectedQuestionVersion: projection.version.questionVersion,
      idempotencyKey: <String>[
        'participant-answer',
        _sessionId,
        question.id,
        projection.version.questionVersion.toString(),
      ].join(':'),
    );
    _inFlightOptionKey = normalizedOptionKey;
    final submission = _performSubmission(request);
    _submissionInFlight = submission;
    return submission;
  }

  bool reconcileProjection(ParticipantGameProjection projection) {
    _ensureActive();
    _assertScope(projection);
    if (!projection.shouldReplace(_state.projection)) return false;
    _emit(
      ParticipantAnswerSubmissionState(
        status: _submissionInFlight == null
            ? ParticipantAnswerSubmissionStatus.idle
            : ParticipantAnswerSubmissionStatus.submitting,
        projection: projection,
        selectedOptionKey: _inFlightOptionKey,
      ),
    );
    return true;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _state = ParticipantAnswerSubmissionState(
      status: ParticipantAnswerSubmissionStatus.disposed,
      projection: _state.projection,
      selectedOptionKey: _state.selectedOptionKey,
      failureKind: _state.failureKind,
    );
    await _states.close();
  }

  Future<ParticipantAnswerSubmissionOutcome> _performSubmission(
    ParticipantAnswerSubmissionRequest request,
  ) async {
    _emit(
      ParticipantAnswerSubmissionState(
        status: ParticipantAnswerSubmissionStatus.submitting,
        projection: _state.projection,
        selectedOptionKey: request.optionKey,
      ),
    );

    try {
      final authoritative = await _gateway
          .submitAnswer(request)
          .timeout(_submissionTimeout);
      _assertScope(authoritative);
      final current = _state.projection;
      final resolved = authoritative.shouldReplace(current)
          ? authoritative
          : _isAnswerConfirmed(current)
          ? current
          : null;
      if (resolved == null || !_isAnswerConfirmed(resolved)) {
        throw const LiveGameContractViolation(
          'Answer response did not confirm the authoritative submission.',
        );
      }
      _emit(
        ParticipantAnswerSubmissionState(
          status: ParticipantAnswerSubmissionStatus.accepted,
          projection: resolved,
          selectedOptionKey: request.optionKey,
        ),
      );
      return const ParticipantAnswerSubmissionOutcome.accepted();
    } on TimeoutException {
      return _reject(
        ParticipantAnswerSubmissionFailureKind.timeout,
        uncertain: true,
        selectedOptionKey: request.optionKey,
      );
    } on ParticipantAnswerSubmissionFailure catch (failure) {
      return _reject(
        failure.kind,
        uncertain:
            failure.kind == ParticipantAnswerSubmissionFailureKind.timeout,
        selectedOptionKey: request.optionKey,
      );
    } on LiveGameContractViolation {
      return _reject(
        ParticipantAnswerSubmissionFailureKind.contract,
        selectedOptionKey: request.optionKey,
      );
    } catch (error) {
      return _reject(
        _classifyFailure(error),
        selectedOptionKey: request.optionKey,
      );
    } finally {
      _submissionInFlight = null;
      _inFlightOptionKey = null;
    }
  }

  ParticipantAnswerSubmissionOutcome _reject(
    ParticipantAnswerSubmissionFailureKind kind, {
    required String selectedOptionKey,
    bool uncertain = false,
  }) {
    _emit(
      ParticipantAnswerSubmissionState(
        status: uncertain
            ? ParticipantAnswerSubmissionStatus.uncertain
            : ParticipantAnswerSubmissionStatus.failure,
        projection: _state.projection,
        selectedOptionKey: selectedOptionKey,
        failureKind: kind,
      ),
    );
    return ParticipantAnswerSubmissionOutcome.rejected(kind);
  }

  void _assertScope(ParticipantGameProjection projection) {
    if (projection.version.clubId != _expectedClubId ||
        projection.version.sessionId != _sessionId) {
      throw const LiveGameContractViolation(
        'Participant answer projection is outside the expected scope.',
      );
    }
  }

  void _emit(ParticipantAnswerSubmissionState next) {
    if (_disposed) return;
    _state = next;
    _states.add(next);
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('Participant answer controller is disposed.');
    }
  }
}

bool _isAnswerConfirmed(ParticipantGameProjection projection) {
  return switch (projection.answerState) {
    ParticipantAnswerState.submitted ||
    ParticipantAnswerState.accepted ||
    ParticipantAnswerState.revealed => true,
    ParticipantAnswerState.notAnswered ||
    ParticipantAnswerState.rejected => false,
  };
}

ParticipantAnswerSubmissionFailureKind _classifyFailure(Object error) {
  final normalized = error.toString().toLowerCase();
  if (normalized.contains('permission') ||
      normalized.contains('forbidden') ||
      normalized.contains('unauthorized') ||
      normalized.contains('row-level security') ||
      normalized.contains('rls')) {
    return ParticipantAnswerSubmissionFailureKind.permissionDenied;
  }
  if (normalized.contains('conflict') ||
      normalized.contains('stale') ||
      normalized.contains('version') ||
      normalized.contains('already') ||
      normalized.contains('closed')) {
    return ParticipantAnswerSubmissionFailureKind.conflict;
  }
  if (normalized.contains('unavailable') ||
      normalized.contains('offline') ||
      normalized.contains('network')) {
    return ParticipantAnswerSubmissionFailureKind.unavailable;
  }
  return ParticipantAnswerSubmissionFailureKind.unknown;
}
