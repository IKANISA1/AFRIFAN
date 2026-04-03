import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../models/biopay_enrollment_draft.dart';
import '../models/biopay_face_frame_analysis.dart';
import '../models/biopay_liveness_challenge.dart';
import '../models/biopay_payment_review_args.dart';
import '../providers/biopay_providers.dart';
import '../services/biopay_auth_gate_service.dart';
import '../services/biopay_face_detection_service.dart';
import '../services/biopay_liveness_service.dart';
import '../widgets/biopay_overlays.dart';
import '../widgets/biopay_scanner_shell.dart';

/// Scan mode: enrollment collects 5 samples, pay matches against DB.
enum BiopayScanMode { enroll, pay }

/// BioPay Scan — fullscreen camera pipeline for face capture.
class BiopayScanScreen extends ConsumerStatefulWidget {
  const BiopayScanScreen({
    required this.mode,
    this.enrollmentDraft,
    this.onEnrollmentSuccess,
    this.onMatchSuccess,
    this.onCancel,
    super.key,
  });

  final BiopayScanMode mode;
  final BiopayEnrollmentDraft? enrollmentDraft;
  final VoidCallback? onEnrollmentSuccess;
  final ValueChanged<BiopayPaymentReviewArgs>? onMatchSuccess;
  final VoidCallback? onCancel;

  @override
  ConsumerState<BiopayScanScreen> createState() => _BiopayScanScreenState();
}

class _BiopayScanScreenState extends ConsumerState<BiopayScanScreen> {
  CameraController? _controller;
  bool _isInitializingCamera = false;
  String? _cameraError;
  String? _pipelineError;
  BiopayLivenessChallenge? _livenessChallenge;

  // Scanner state
  BiopayScannerTone _tone = BiopayScannerTone.searching;
  String _statusLabel = 'Preparing...';
  String _helperText = '';

  // Frame processing
  late final BiopayFaceDetectionService _faceDetection;
  late final BiopayLivenessService _livenessService;
  bool _isProcessingFrame = false;
  bool _isSubmitting = false;
  DateTime? _lastFrameProcessedAt;
  BiopayLivenessAssessment? _livenessAssessment;

  // Enrollment
  final List<Float32List> _enrollmentEmbeddings = [];
  int _capturedEnrollmentFrames = 0;
  DateTime? _lastEnrollmentCaptureAt;

  // Match throttle
  DateTime? _lastMatchAttemptAt;

  bool get _isEnroll => widget.mode == BiopayScanMode.enroll;

  @override
  void initState() {
    super.initState();
    final stableFrames = ref.read(biopayStableFramesProvider).valueOrNull ?? 3;
    _faceDetection = BiopayFaceDetectionService(
      stableFramesRequired: stableFrames,
    );
    _livenessService = BiopayLivenessService(
      mode: _isEnroll
          ? BiopayLivenessMode.enrollment
          : BiopayLivenessMode.payment,
    );
    unawaited(_prepareSecureScan());
  }

  Future<void> _prepareSecureScan({bool forceChallengeRefresh = false}) async {
    final currentController = _controller;
    _controller = null;
    try {
      await currentController?.stopImageStream();
    } catch (_) {}
    if (currentController != null) {
      await currentController.dispose();
    }

    setState(() {
      _isInitializingCamera = true;
      _cameraError = null;
      _pipelineError = null;
      _statusLabel = 'Securing session...';
      _helperText = '';
    });

    try {
      if (forceChallengeRefresh || _livenessChallenge?.isExpired != false) {
        final challenge = await ref
            .read(biopayRepositoryProvider)
            .createLivenessChallenge(
              mode: _isEnroll ? 'enrollment' : 'payment',
            );
        _livenessChallenge = challenge;
        _livenessService.setServerChallenge(
          token: challenge.token,
          expiresAt: challenge.expiresAt,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraError = 'Session failed: $error';
        _isInitializingCamera = false;
      });
      return;
    }

    await _initCamera();
  }

  Future<void> _initCamera() async {
    setState(() => _isInitializingCamera = true);

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameraError = 'No camera available.';
          _isInitializingCamera = false;
        });
        return;
      }

      final preferredDirection = _isEnroll
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      final selectedCamera = cameras.firstWhere(
        (c) => c.lensDirection == preferredDirection,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await controller.initialize();

      if (!mounted) {
        controller.dispose();
        return;
      }

      _controller = controller;
      await controller.startImageStream(_onCameraFrame);

      setState(() {
        _isInitializingCamera = false;
        _statusLabel = _isEnroll ? 'Center your face' : 'Point at face';
        _helperText = '';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraError = 'Camera failed: $e';
          _isInitializingCamera = false;
        });
      }
    }
  }

  void _onCameraFrame(CameraImage image) async {
    if (_isProcessingFrame || _isSubmitting) return;

    final now = DateTime.now();
    if (_lastFrameProcessedAt != null &&
        now.difference(_lastFrameProcessedAt!) <
            const Duration(milliseconds: 120)) {
      return;
    }

    _isProcessingFrame = true;
    _lastFrameProcessedAt = now;

    try {
      if (_livenessChallenge == null || _livenessChallenge!.isExpired) {
        _livenessService.reset();
        _setScannerState(
          tone: BiopayScannerTone.blocked,
          statusLabel: 'Session expired',
          helperText: '',
        );
        await _prepareSecureScan(forceChallengeRefresh: true);
        return;
      }

      final camera = _controller?.description;
      if (camera == null) return;

      final analysis = await _faceDetection.analyze(
        image,
        sensorOrientation: camera.sensorOrientation,
        lensDirection: camera.lensDirection,
      );

      if (!mounted) return;

      _updateScannerFromAnalysis(analysis);

      if (analysis.isStable) {
        final assessment = _livenessService.evaluate(analysis);
        if (assessment != null) {
          _livenessAssessment = assessment;
          _setScannerState(
            tone: _scannerToneForLiveness(assessment.level),
            statusLabel: assessment.statusLabel,
            helperText: '',
          );
        }
      }

      if (_livenessService.isSatisfied && analysis.isStable && !_isSubmitting) {
        _livenessAssessment = null;
        final embeddingService = ref.read(biopayEmbeddingServiceProvider);
        if (!embeddingService.isLoaded) {
          await embeddingService.loadModel();
          if (!embeddingService.isLoaded || !mounted) return;
        }

        final face = analysis.face;
        if (face == null) return;

        final alignmentService = ref.read(biopayFaceAlignmentServiceProvider);
        final tensor = await alignmentService.extractAlignedFaceTensor(
          frame: image,
          face: face,
          rotationDegrees: analysis.rotationDegrees,
        );

        final embedding = embeddingService.generateEmbedding(tensor);

        if (_isEnroll) {
          await _handleEnrollmentEmbedding(Float32List.fromList(embedding));
        } else {
          await _handleMatchEmbedding(Float32List.fromList(embedding));
        }
      }
    } catch (e) {
      if (mounted) {
        _setScannerState(
          tone: BiopayScannerTone.error,
          statusLabel: 'Error',
          helperText: '',
        );
      }
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _updateScannerFromAnalysis(BiopayFaceFrameAnalysis analysis) {
    final stableFramesRequired =
        ref.read(biopayStableFramesProvider).valueOrNull ?? 3;

    switch (analysis.guidance) {
      case BiopayFaceGuidance.multipleFaces:
        _livenessAssessment = null;
        _setScannerState(
          tone: BiopayScannerTone.blocked,
          statusLabel: 'One face only',
          helperText: '',
        );
      case BiopayFaceGuidance.tooDark:
        _livenessAssessment = null;
        _setScannerState(
          tone: BiopayScannerTone.blocked,
          statusLabel: 'Too dark',
          helperText: '',
        );
      case BiopayFaceGuidance.tooBright:
        _livenessAssessment = null;
        _setScannerState(
          tone: BiopayScannerTone.blocked,
          statusLabel: 'Too bright',
          helperText: '',
        );
      case BiopayFaceGuidance.tooFar:
        _livenessAssessment = null;
        _setScannerState(
          tone: BiopayScannerTone.blocked,
          statusLabel: 'Move closer',
          helperText: '',
        );
      case BiopayFaceGuidance.headTurned:
        _livenessAssessment = null;
        _setScannerState(
          tone: BiopayScannerTone.blocked,
          statusLabel: 'Face the camera',
          helperText: '',
        );
      case BiopayFaceGuidance.eyesClosed:
        _livenessAssessment = null;
        _setScannerState(
          tone: BiopayScannerTone.blocked,
          statusLabel: 'Open your eyes',
          helperText: '',
        );
      case BiopayFaceGuidance.stable:
        _setScannerState(
          tone: BiopayScannerTone.ready,
          statusLabel: _isEnroll
              ? '${(_capturedEnrollmentFrames + 1).clamp(1, 5)} of 5'
              : 'Matching...',
          helperText: '',
        );
      case BiopayFaceGuidance.searching:
        _livenessAssessment = null;
        _setScannerState(
          tone: BiopayScannerTone.searching,
          statusLabel: analysis.faceCount == 1 && analysis.stableCount > 0
              ? 'Hold still... ${analysis.stableCount}/$stableFramesRequired'
              : (_isEnroll ? 'Center your face' : 'Point at face'),
          helperText: '',
        );
    }
  }

  Future<void> _handleEnrollmentEmbedding(Float32List embedding) async {
    final draft = widget.enrollmentDraft;
    if (draft == null) {
      _setScannerState(
        tone: BiopayScannerTone.error,
        statusLabel: 'Missing data',
        helperText: '',
      );
      return;
    }

    if (_enrollmentEmbeddings.length < 5) {
      final now = DateTime.now();
      if (_lastEnrollmentCaptureAt != null &&
          now.difference(_lastEnrollmentCaptureAt!) <
              const Duration(milliseconds: 500)) {
        return;
      }

      _lastEnrollmentCaptureAt = now;
      _enrollmentEmbeddings.add(embedding);
      _capturedEnrollmentFrames = _enrollmentEmbeddings.length;
      HapticFeedback.mediumImpact();

      if (_capturedEnrollmentFrames < 5) {
        _setScannerState(
          tone: BiopayScannerTone.ready,
          statusLabel: '$_capturedEnrollmentFrames of 5',
          helperText: '',
        );
        setState(() {});
        return;
      }
    }

    _isSubmitting = true;
    _setScannerState(
      tone: BiopayScannerTone.ready,
      statusLabel: 'Finalizing...',
      helperText: '',
    );

    try {
      final embeddingService = ref.read(biopayEmbeddingServiceProvider);
      final averaged = embeddingService.generateAveragedEmbedding(
        _enrollmentEmbeddings.take(5).toList(growable: false),
      );

      final authResult = await ref
          .read(biopayAuthGateServiceProvider)
          .authorize(BiopayAuthAction.enrollment);

      if (!mounted) return;

      if (!authResult.isAuthorized) {
        _setScannerState(
          tone: BiopayScannerTone.blocked,
          statusLabel: 'Auth required',
          helperText: '',
        );
        return;
      }

      final profile = await ref
          .read(biopayRepositoryProvider)
          .enroll(
            draft: draft,
            embedding: averaged,
            livenessMetadata: _livenessService.submissionMetadata,
          );

      ref.invalidate(biopayProfileProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enrolled ${profile.formattedAlias}'),
          backgroundColor: ColorTokens.success,
        ),
      );
      if (widget.onEnrollmentSuccess != null) {
        widget.onEnrollmentSuccess!();
      } else {
        if (context.canPop()) {
          context.pop(true);
        } else {
          context.go('/biopay');
        }
      }
    } catch (error) {
      if (!mounted) return;
      _setScannerState(
        tone: BiopayScannerTone.error,
        statusLabel: 'Enrollment failed',
        helperText: '',
      );
    } finally {
      _isSubmitting = false;
    }
  }

  Future<void> _handleMatchEmbedding(Float32List embedding) async {
    final now = DateTime.now();
    if (_lastMatchAttemptAt != null &&
        now.difference(_lastMatchAttemptAt!) <
            const Duration(milliseconds: 900)) {
      return;
    }
    _lastMatchAttemptAt = now;
    _isSubmitting = true;

    final embeddingList = embedding.toList(growable: false);
    final matchThreshold =
        ref.read(biopayMatchThresholdProvider).valueOrNull ?? 0.72;

    try {
      _setScannerState(
        tone: BiopayScannerTone.ready,
        statusLabel: 'Matching...',
        helperText: '',
      );

      final result = await ref
          .read(biopayRepositoryProvider)
          .match(
            embedding: embeddingList,
            livenessMetadata: _livenessService.submissionMetadata,
          );

      if (!mounted) return;

      if (!result.match ||
          result.profile == null ||
          result.score < matchThreshold) {
        _setScannerState(
          tone: BiopayScannerTone.error,
          statusLabel: 'No match found',
          helperText: '',
        );
        return;
      }

      final matchReceipt = result.matchReceipt;
      if (matchReceipt == null || matchReceipt.isEmpty) {
        _setScannerState(
          tone: BiopayScannerTone.error,
          statusLabel: 'Receipt missing',
          helperText: '',
        );
        return;
      }

      await _controller?.stopImageStream();
      if (!mounted) return;

      if (widget.onMatchSuccess != null) {
        widget.onMatchSuccess!(BiopayPaymentReviewArgs.faceMatch(matchResult: result));
      } else {
        context.pushReplacement(
          '/biopay/review',
          extra: BiopayPaymentReviewArgs.faceMatch(matchResult: result),
        );
      }
    } catch (error) {
      if (!mounted) return;
      _setScannerState(
        tone: BiopayScannerTone.error,
        statusLabel: 'Match failed',
        helperText: '',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _setScannerState({
    required BiopayScannerTone tone,
    required String statusLabel,
    required String helperText,
  }) {
    if (!mounted) return;
    final needsUpdate =
        _tone != tone ||
        _statusLabel != statusLabel ||
        _helperText != helperText;
    if (!needsUpdate) return;
    setState(() {
      _tone = tone;
      _statusLabel = statusLabel;
      _helperText = helperText;
    });
  }

  BiopayScannerTone _scannerToneForLiveness(BiopayLivenessFeedbackLevel level) {
    return switch (level) {
      BiopayLivenessFeedbackLevel.searching => BiopayScannerTone.searching,
      BiopayLivenessFeedbackLevel.ready => BiopayScannerTone.ready,
      BiopayLivenessFeedbackLevel.blocked => BiopayScannerTone.blocked,
    };
  }

  int _resolveLivenessStep(String statusLabel) {
    final label = statusLabel.toLowerCase();
    if (label.contains('blink') || label.contains('eyes')) return 1;
    if (label.contains('turn')) return 2;
    if (label.contains('look straight')) return 3;
    return 1;
  }

  void _closeScanner() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _controller = null;
    _faceDetection.close();
    if (widget.onCancel != null) {
      widget.onCancel!();
    } else {
      if (context.canPop()) {
        context.pop(false);
      } else {
        context.go('/biopay');
      }
    }
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _faceDetection.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCameraReady =
        _controller != null &&
        _controller!.value.isInitialized &&
        !_isInitializingCamera;

    final tone = _cameraError != null
        ? BiopayScannerTone.error
        : isCameraReady
        ? _tone
        : BiopayScannerTone.searching;

    final statusLabel = _cameraError != null
        ? 'Camera unavailable'
        : isCameraReady
        ? _statusLabel
        : 'Preparing...';

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _closeScanner();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: BiopayScannerShell(
                controller: _controller,
                isCameraReady: isCameraReady,
                statusLabel: statusLabel,
                helperText: _helperText,
                tone: tone,
                sampleCount: _capturedEnrollmentFrames,
                totalSamples: 5,
                isEnrollMode: _isEnroll,
                footer: _buildFooter(context, isCameraReady: isCameraReady),
              ),
            ),
            if (_livenessAssessment != null)
              Positioned.fill(
                child: BiopayLivenessPromptOverlay(
                  title: _livenessAssessment!.statusLabel,
                  helperText: '',
                  currentStep: _resolveLivenessStep(
                    _livenessAssessment!.statusLabel,
                  ),
                  totalSteps: _isEnroll ? 3 : 2,
                  stepLabels: _isEnroll
                      ? const ['POSITION', 'ANGLES', 'CONFIRM']
                      : const ['LOCK', 'CONFIRM'],
                ),
              ),

            // ── Back button ──
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              child: GestureDetector(
                onTap: _closeScanner,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: ColorTokens.glassFill,
                    shape: BoxShape.circle,
                    border: Border.all(color: ColorTokens.ghostBorder),
                  ),
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),

            // ── Initializing indicator ──
            if (_isInitializingCamera)
              Positioned(
                top: MediaQuery.of(context).padding.top + 64,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Securing...',
                          style: TypographyTokens.labelMedium().copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget? _buildFooter(
    BuildContext context, {
    required bool isCameraReady,
  }) {
    final errorMessage = _cameraError ?? _pipelineError;

    if (!isCameraReady) {
      return Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () =>
                    _prepareSecureScan(forceChallengeRefresh: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(ShapeTokens.radiusXl),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Enable Camera',
                  style: TypographyTokens.labelLarge().copyWith(
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: SpacingTokens.spacing3),
              Text(
                errorMessage,
                style: TypographyTokens.bodySmall().copyWith(
                  color: ColorTokens.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing4),
        child: Text(
          errorMessage,
          style: TypographyTokens.bodySmall().copyWith(
            color: ColorTokens.error,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return null;
  }
}
