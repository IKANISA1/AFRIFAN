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
import '../screens/biopay_scan_screen.dart';
import '../services/biopay_auth_gate_service.dart';
import '../services/biopay_face_detection_service.dart';
import '../services/biopay_liveness_service.dart';
import 'biopay_reference_ui.dart';
import 'biopay_scan_footer.dart';
import 'biopay_scanner_shell.dart';

class BioPayCameraPipeline extends ConsumerStatefulWidget {
  const BioPayCameraPipeline({
    required this.mode,
    this.enrollmentDraft,
    this.onEnrollmentSuccess,
    this.onMatchSuccess,
    this.onCancel,
    super.key,
  });

  final BioPayScanMode mode;
  final BioPayEnrollmentDraft? enrollmentDraft;
  final VoidCallback? onEnrollmentSuccess;
  final ValueChanged<BioPayPaymentReviewArgs>? onMatchSuccess;
  final VoidCallback? onCancel;

  @override
  ConsumerState<BioPayCameraPipeline> createState() =>
      _BioPayCameraPipelineState();
}

class _BioPayCameraPipelineState extends ConsumerState<BioPayCameraPipeline> {
  CameraController? _controller;
  bool _isInitializingCamera = false;
  String? _cameraError;
  String? _pipelineError;
  BioPayLivenessChallenge? _livenessChallenge;

  // Scanner state
  BioPayScannerTone _tone = BioPayScannerTone.searching;
  String _statusLabel = 'Preparing...';
  String _helperText = '';

  // Frame processing
  late final BioPayFaceDetectionService _faceDetection;
  late final BioPayLivenessService _livenessService;
  bool _isProcessingFrame = false;
  bool _isSubmitting = false;
  DateTime? _lastFrameProcessedAt;

  // Enrollment
  final List<Float32List> _enrollmentEmbeddings = [];
  int _capturedEnrollmentFrames = 0;
  DateTime? _lastEnrollmentCaptureAt;

  // Match throttle
  DateTime? _lastMatchAttemptAt;

  bool get _isEnroll => widget.mode == BioPayScanMode.enroll;

  @override
  void initState() {
    super.initState();
    final stableFrames = ref.read(BioPayStableFramesProvider).valueOrNull ?? 3;
    _faceDetection = BioPayFaceDetectionService(
      stableFramesRequired: stableFrames,
    );
    _livenessService = BioPayLivenessService(
      mode: _isEnroll
          ? BioPayLivenessMode.enrollment
          : BioPayLivenessMode.payment,
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
            .read(BioPayRepositoryProvider)
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
          tone: BioPayScannerTone.blocked,
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
          _setScannerState(
            tone: _scannerToneForLiveness(assessment.level),
            statusLabel: assessment.statusLabel,
            helperText: '',
          );
        }
      }

      if (_livenessService.isSatisfied && analysis.isStable && !_isSubmitting) {
        final embeddingService = ref.read(BioPayEmbeddingServiceProvider);
        if (!embeddingService.isLoaded) {
          await embeddingService.loadModel();
          if (!embeddingService.isLoaded || !mounted) return;
        }

        final face = analysis.face;
        if (face == null) return;

        final alignmentService = ref.read(BioPayFaceAlignmentServiceProvider);
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
          tone: BioPayScannerTone.error,
          statusLabel: 'Error',
          helperText: '',
        );
      }
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _updateScannerFromAnalysis(BioPayFaceFrameAnalysis analysis) {
    final stableFramesRequired =
        ref.read(BioPayStableFramesProvider).valueOrNull ?? 3;

    switch (analysis.guidance) {
      case BioPayFaceGuidance.multipleFaces:
        _setScannerState(
          tone: BioPayScannerTone.blocked,
          statusLabel: 'One face only',
          helperText: '',
        );
      case BioPayFaceGuidance.tooDark:
        _setScannerState(
          tone: BioPayScannerTone.blocked,
          statusLabel: 'Too dark',
          helperText: '',
        );
      case BioPayFaceGuidance.tooBright:
        _setScannerState(
          tone: BioPayScannerTone.blocked,
          statusLabel: 'Too bright',
          helperText: '',
        );
      case BioPayFaceGuidance.tooFar:
        _setScannerState(
          tone: BioPayScannerTone.blocked,
          statusLabel: 'Move closer',
          helperText: '',
        );
      case BioPayFaceGuidance.headTurned:
        _setScannerState(
          tone: BioPayScannerTone.blocked,
          statusLabel: 'Face the camera',
          helperText: '',
        );
      case BioPayFaceGuidance.eyesClosed:
        _setScannerState(
          tone: BioPayScannerTone.blocked,
          statusLabel: 'Open your eyes',
          helperText: '',
        );
      case BioPayFaceGuidance.stable:
        _setScannerState(
          tone: BioPayScannerTone.ready,
          statusLabel: _isEnroll
              ? '${(_capturedEnrollmentFrames + 1).clamp(1, 5)} of 5'
              : 'Matching...',
          helperText: '',
        );
      case BioPayFaceGuidance.searching:
        _setScannerState(
          tone: BioPayScannerTone.searching,
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
        tone: BioPayScannerTone.error,
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
          tone: BioPayScannerTone.ready,
          statusLabel: '$_capturedEnrollmentFrames of 5',
          helperText: '',
        );
        setState(() {});
        return;
      }
    }

    _isSubmitting = true;
    _setScannerState(
      tone: BioPayScannerTone.ready,
      statusLabel: 'Finalizing...',
      helperText: '',
    );

    try {
      final embeddingService = ref.read(BioPayEmbeddingServiceProvider);
      final averaged = embeddingService.generateAveragedEmbedding(
        _enrollmentEmbeddings.take(5).toList(growable: false),
      );

      final authResult = await ref
          .read(BioPayAuthGateServiceProvider)
          .authorize(BioPayAuthAction.enrollment);

      if (!mounted) return;

      if (!authResult.isAuthorized) {
        _setScannerState(
          tone: BioPayScannerTone.blocked,
          statusLabel: 'Auth required',
          helperText: '',
        );
        return;
      }

      final profile = await ref
          .read(BioPayRepositoryProvider)
          .enroll(
            draft: draft,
            embedding: averaged,
            livenessMetadata: _livenessService.submissionMetadata,
          );

      ref.invalidate(BioPayProfileProvider);

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
          context.go('/BioPay');
        }
      }
    } catch (error) {
      if (!mounted) return;
      _setScannerState(
        tone: BioPayScannerTone.error,
        statusLabel: 'Enrollment failed',
        helperText: '',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
        ref.read(BioPayMatchThresholdProvider).valueOrNull ?? 0.72;

    try {
      _setScannerState(
        tone: BioPayScannerTone.ready,
        statusLabel: 'Matching...',
        helperText: '',
      );

      final result = await ref
          .read(BioPayRepositoryProvider)
          .match(
            embedding: embeddingList,
            livenessMetadata: _livenessService.submissionMetadata,
          );

      if (!mounted) return;

      if (!result.match ||
          result.profile == null ||
          result.score < matchThreshold) {
        _setScannerState(
          tone: BioPayScannerTone.error,
          statusLabel: 'No match found',
          helperText: '',
        );
        return;
      }

      final matchReceipt = result.matchReceipt;
      if (matchReceipt == null || matchReceipt.isEmpty) {
        _setScannerState(
          tone: BioPayScannerTone.error,
          statusLabel: 'Receipt missing',
          helperText: '',
        );
        return;
      }

      await _controller?.stopImageStream();
      if (!mounted) return;

      if (widget.onMatchSuccess != null) {
        widget.onMatchSuccess!(
          BioPayPaymentReviewArgs.faceMatch(matchResult: result),
        );
      } else {
        context.pushReplacement(
          '/BioPay/review',
          extra: BioPayPaymentReviewArgs.faceMatch(matchResult: result),
        );
      }
    } catch (error) {
      if (!mounted) return;
      _setScannerState(
        tone: BioPayScannerTone.error,
        statusLabel: 'Match failed',
        helperText: '',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _setScannerState({
    required BioPayScannerTone tone,
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

  BioPayScannerTone _scannerToneForLiveness(BioPayLivenessFeedbackLevel level) {
    return switch (level) {
      BioPayLivenessFeedbackLevel.searching => BioPayScannerTone.searching,
      BioPayLivenessFeedbackLevel.ready => BioPayScannerTone.ready,
      BioPayLivenessFeedbackLevel.blocked => BioPayScannerTone.blocked,
    };
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
        context.go('/BioPay');
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
        ? BioPayScannerTone.error
        : isCameraReady
        ? _tone
        : BioPayScannerTone.searching;

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
              child: BioPayScannerShell(
                controller: _controller,
                isCameraReady: isCameraReady,
                statusLabel: statusLabel,
                helperText: _helperText,
                tone: tone,
                sampleCount: _capturedEnrollmentFrames,
                totalSamples: 5,
                isEnrollMode: _isEnroll,
                footer: BioPayScanFooter(
                  isCameraReady: isCameraReady,
                  errorMessage: _cameraError ?? _pipelineError,
                  onEnableCamera: () =>
                      _prepareSecureScan(forceChallengeRefresh: true),
                ),
              ),
            ),

            // ── Back button ──
            Positioned(
              top: MediaQuery.of(context).padding.top + 24,
              left: 28,
              child: BioPayReferenceDarkBackButton(onTap: _closeScanner),
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
}
