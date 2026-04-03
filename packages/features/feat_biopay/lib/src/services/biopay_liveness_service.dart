import 'dart:math' as math;

import '../models/biopay_face_frame_analysis.dart';

/// Liveness mode: enrollment requires more steps.
enum BiopayLivenessMode { enrollment, payment }

/// Feedback level shown to the user.
enum BiopayLivenessFeedbackLevel { searching, ready, blocked }

/// User-facing liveness assessment.
class BiopayLivenessAssessment {
  const BiopayLivenessAssessment({
    required this.level,
    required this.statusLabel,
    required this.helperText,
  });

  final BiopayLivenessFeedbackLevel level;
  final String statusLabel;
  final String helperText;
}

enum _BiopayLivenessStep { blink, turnSide, recenter }

/// 3-step passive liveness challenge: blink → turn → recenter.
///
/// - Enrollment: blink + turn + recenter (3 steps)
/// - Payment: blink + turn (2 steps — faster checkout)
class BiopayLivenessService {
  BiopayLivenessService({required this.mode, int maxFramesWithoutProgress = 45})
    : _maxFramesWithoutProgress = maxFramesWithoutProgress;

  static const challengeVersion = 'challenge_pad_v1';
  static const _eyesOpenThreshold = 0.68;
  static const _eyesClosedThreshold = 0.36;
  static const _headTurnThreshold = 18.0;
  static const _recenterThreshold = 8.0;

  final BiopayLivenessMode mode;
  final int _maxFramesWithoutProgress;

  bool _isSatisfied = false;
  bool _blinkArmed = false;
  bool _blinkClosedObserved = false;
  int _stepIndex = 0;
  int _framesEvaluated = 0;
  int _framesWithoutProgress = 0;
  double _maxAbsHeadYaw = 0;
  DateTime? _completedAt;
  String? _challengeToken;
  DateTime? _challengeExpiresAt;

  bool get isSatisfied => _isSatisfied;

  Map<String, Object?>? get submissionMetadata {
    if (!_isSatisfied ||
        _completedAt == null ||
        _challengeToken == null ||
        (_challengeExpiresAt != null &&
            DateTime.now().isAfter(_challengeExpiresAt!))) {
      return null;
    }

    return <String, Object?>{
      'version': challengeVersion,
      'mode': mode.name,
      'result': 'passed',
      'completed_steps': _requiredSteps
          .map((step) => _stepCode(step))
          .toList(growable: false),
      'frames_evaluated': _framesEvaluated,
      'max_abs_head_yaw': double.parse(_maxAbsHeadYaw.toStringAsFixed(2)),
      'blink_detected': true,
      'completed_at': _completedAt!.toUtc().toIso8601String(),
      'challenge_token': _challengeToken,
    };
  }

  void setServerChallenge({
    required String token,
    required DateTime expiresAt,
  }) {
    _challengeToken = token.trim().isEmpty ? null : token.trim();
    _challengeExpiresAt = expiresAt.toUtc();
  }

  void clearServerChallenge() {
    _challengeToken = null;
    _challengeExpiresAt = null;
  }

  void reset() {
    _isSatisfied = false;
    _blinkArmed = false;
    _blinkClosedObserved = false;
    _stepIndex = 0;
    _framesEvaluated = 0;
    _framesWithoutProgress = 0;
    _maxAbsHeadYaw = 0;
    _completedAt = null;
  }

  BiopayLivenessAssessment? evaluate(BiopayFaceFrameAnalysis analysis) {
    if (_isSatisfied) return null;

    if (!_canEvaluateChallenge(analysis)) {
      reset();
      return null;
    }

    _framesEvaluated += 1;
    _maxAbsHeadYaw = math.max(_maxAbsHeadYaw, analysis.absHeadYaw);

    final step = _requiredSteps[_stepIndex];
    final advanced = switch (step) {
      _BiopayLivenessStep.blink => _advanceBlink(analysis),
      _BiopayLivenessStep.turnSide => _advanceTurnSide(analysis),
      _BiopayLivenessStep.recenter => _advanceRecenter(analysis),
    };

    if (advanced) {
      _framesWithoutProgress = 0;
      _stepIndex += 1;
      if (_stepIndex >= _requiredSteps.length) {
        _isSatisfied = true;
        _completedAt = DateTime.now();
        return null;
      }
      return _buildAssessment(_requiredSteps[_stepIndex], analysis);
    } else {
      _framesWithoutProgress += 1;
      if (_framesWithoutProgress >= _maxFramesWithoutProgress) {
        reset();
        return const BiopayLivenessAssessment(
          level: BiopayLivenessFeedbackLevel.blocked,
          statusLabel: 'Liveness challenge restarted',
          helperText:
              'Liveness check failed. Re-center your face and try again.',
        );
      }
    }

    return _buildAssessment(step, analysis);
  }

  List<_BiopayLivenessStep> get _requiredSteps =>
      mode == BiopayLivenessMode.enrollment
      ? const <_BiopayLivenessStep>[
          _BiopayLivenessStep.blink,
          _BiopayLivenessStep.turnSide,
          _BiopayLivenessStep.recenter,
        ]
      : const <_BiopayLivenessStep>[
          _BiopayLivenessStep.blink,
          _BiopayLivenessStep.turnSide,
        ];

  bool _canEvaluateChallenge(BiopayFaceFrameAnalysis analysis) {
    if (analysis.faceCount != 1) return false;
    return switch (analysis.guidance) {
      BiopayFaceGuidance.multipleFaces => false,
      BiopayFaceGuidance.tooDark => false,
      BiopayFaceGuidance.tooBright => false,
      BiopayFaceGuidance.tooFar => false,
      _ => true,
    };
  }

  bool _advanceBlink(BiopayFaceFrameAnalysis analysis) {
    if (_eyesAreOpen(analysis)) {
      if (_blinkArmed && _blinkClosedObserved) return true;
      _blinkArmed = true;
      return false;
    }
    if (_blinkArmed && _eyesAreClosed(analysis)) {
      _blinkClosedObserved = true;
    }
    return false;
  }

  bool _advanceTurnSide(BiopayFaceFrameAnalysis analysis) {
    return analysis.absHeadYaw >= _headTurnThreshold;
  }

  bool _advanceRecenter(BiopayFaceFrameAnalysis analysis) {
    return analysis.absHeadYaw <= _recenterThreshold && _eyesAreOpen(analysis);
  }

  BiopayLivenessAssessment _buildAssessment(
    _BiopayLivenessStep step,
    BiopayFaceFrameAnalysis analysis,
  ) {
    return switch (step) {
      _BiopayLivenessStep.blink => _buildBlinkAssessment(analysis),
      _BiopayLivenessStep.turnSide => const BiopayLivenessAssessment(
        level: BiopayLivenessFeedbackLevel.ready,
        statusLabel: 'Turn your head slightly',
        helperText:
            'Turn your head slightly to verify liveness.',
      ),
      _BiopayLivenessStep.recenter => const BiopayLivenessAssessment(
        level: BiopayLivenessFeedbackLevel.ready,
        statusLabel: 'Look straight again',
        helperText:
            'Center your face in the oval to continue.',
      ),
    };
  }

  BiopayLivenessAssessment _buildBlinkAssessment(
    BiopayFaceFrameAnalysis analysis,
  ) {
    if (analysis.leftEyeOpenProbability == null ||
        analysis.rightEyeOpenProbability == null) {
      return const BiopayLivenessAssessment(
        level: BiopayLivenessFeedbackLevel.blocked,
        statusLabel: 'Keep both eyes visible',
        helperText:
            'Both eyes must be visible for the blink challenge.',
      );
    }

    if (!_blinkArmed) {
      return const BiopayLivenessAssessment(
        level: BiopayLivenessFeedbackLevel.searching,
        statusLabel: 'Hold steady with eyes open',
        helperText:
            'BioPay is arming the live blink challenge before it allows a capture.',
      );
    }

    if (!_blinkClosedObserved) {
      return const BiopayLivenessAssessment(
        level: BiopayLivenessFeedbackLevel.ready,
        statusLabel: 'Blink once',
        helperText:
            'Blink naturally to confirm a live face.',
      );
    }

    return const BiopayLivenessAssessment(
      level: BiopayLivenessFeedbackLevel.ready,
      statusLabel: 'Open your eyes again',
      helperText:
          'Blink detected. Open your eyes to finish.',
    );
  }

  bool _eyesAreOpen(BiopayFaceFrameAnalysis analysis) {
    final left = analysis.leftEyeOpenProbability;
    final right = analysis.rightEyeOpenProbability;
    return left != null &&
        right != null &&
        left >= _eyesOpenThreshold &&
        right >= _eyesOpenThreshold;
  }

  bool _eyesAreClosed(BiopayFaceFrameAnalysis analysis) {
    final left = analysis.leftEyeOpenProbability;
    final right = analysis.rightEyeOpenProbability;
    return left != null &&
        right != null &&
        left <= _eyesClosedThreshold &&
        right <= _eyesClosedThreshold;
  }

  String _stepCode(_BiopayLivenessStep step) {
    return switch (step) {
      _BiopayLivenessStep.blink => 'blink',
      _BiopayLivenessStep.turnSide => 'turn_side',
      _BiopayLivenessStep.recenter => 'recenter',
    };
  }
}
