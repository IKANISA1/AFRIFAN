import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../models/biopay_face_frame_analysis.dart';

/// Face detection service — wraps Google ML Kit for BioPay.
///
/// Produces [BiopayFaceFrameAnalysis] from camera image frames with
/// face count, brightness estimation, face-area ratio, head rotation,
/// eye-open probabilities, and stability tracking.
class BiopayFaceDetectionService {
  BiopayFaceDetectionService({
    this.stableFramesRequired = 3,
    this.minFaceAreaRatio = 0.08,
    this.maxFaceAreaRatio = 0.60,
    this.headTurnBlockThreshold = 25.0,
    this.brightnessLow = 50.0,
    this.brightnessHigh = 220.0,
  }) : _detector = FaceDetector(
         options: FaceDetectorOptions(
           enableClassification: true,
           enableLandmarks: true,
           enableTracking: true,
           performanceMode: FaceDetectorMode.fast,
         ),
       );

  final FaceDetector _detector;
  final int stableFramesRequired;
  final double minFaceAreaRatio;
  final double maxFaceAreaRatio;
  final double headTurnBlockThreshold;
  final double brightnessLow;
  final double brightnessHigh;

  int _stableCount = 0;
  int? _lastStableTrackingId;

  /// Process a camera image and return face analysis.
  Future<BiopayFaceFrameAnalysis> analyze(
    CameraImage image, {
    required int sensorOrientation,
    required CameraLensDirection lensDirection,
  }) async {
    final inputImage = _buildInputImage(
      image,
      sensorOrientation: sensorOrientation,
      lensDirection: lensDirection,
    );

    if (inputImage == null) {
      _stableCount = 0;
      return const BiopayFaceFrameAnalysis(
        guidance: BiopayFaceGuidance.searching,
        faceCount: 0,
        brightness: 0,
        faceAreaRatio: 0,
        stableCount: 0,
        rotationDegrees: 0,
      );
    }

    final faces = await _detector.processImage(inputImage);
    final brightness = _estimateBrightness(image);
    final frameArea = image.width * image.height;

    if (faces.isEmpty) {
      _stableCount = 0;
      _lastStableTrackingId = null;
      return BiopayFaceFrameAnalysis(
        guidance: BiopayFaceGuidance.searching,
        faceCount: 0,
        brightness: brightness,
        faceAreaRatio: 0,
        stableCount: 0,
        rotationDegrees: sensorOrientation,
      );
    }

    if (faces.length > 1) {
      _stableCount = 0;
      return BiopayFaceFrameAnalysis(
        guidance: BiopayFaceGuidance.multipleFaces,
        faceCount: faces.length,
        brightness: brightness,
        faceAreaRatio: 0,
        stableCount: 0,
        rotationDegrees: sensorOrientation,
      );
    }

    final face = faces.first;
    final faceArea = face.boundingBox.width * face.boundingBox.height;
    final faceAreaRatio = frameArea > 0 ? faceArea / frameArea : 0.0;

    // Brightness check
    if (brightness < brightnessLow) {
      _stableCount = 0;
      return BiopayFaceFrameAnalysis(
        guidance: BiopayFaceGuidance.tooDark,
        face: face,
        faceCount: 1,
        brightness: brightness,
        faceAreaRatio: faceAreaRatio,
        stableCount: 0,
        rotationDegrees: sensorOrientation,
        headYaw: face.headEulerAngleY,
        leftEyeOpenProbability: face.leftEyeOpenProbability,
        rightEyeOpenProbability: face.rightEyeOpenProbability,
      );
    }

    if (brightness > brightnessHigh) {
      _stableCount = 0;
      return BiopayFaceFrameAnalysis(
        guidance: BiopayFaceGuidance.tooBright,
        face: face,
        faceCount: 1,
        brightness: brightness,
        faceAreaRatio: faceAreaRatio,
        stableCount: 0,
        rotationDegrees: sensorOrientation,
        headYaw: face.headEulerAngleY,
        leftEyeOpenProbability: face.leftEyeOpenProbability,
        rightEyeOpenProbability: face.rightEyeOpenProbability,
      );
    }

    // Face too far
    if (faceAreaRatio < minFaceAreaRatio) {
      _stableCount = 0;
      return BiopayFaceFrameAnalysis(
        guidance: BiopayFaceGuidance.tooFar,
        face: face,
        faceCount: 1,
        brightness: brightness,
        faceAreaRatio: faceAreaRatio,
        stableCount: 0,
        rotationDegrees: sensorOrientation,
        headYaw: face.headEulerAngleY,
        leftEyeOpenProbability: face.leftEyeOpenProbability,
        rightEyeOpenProbability: face.rightEyeOpenProbability,
      );
    }

    // Head turned too much
    final absYaw = (face.headEulerAngleY ?? 0).abs();
    if (absYaw > headTurnBlockThreshold) {
      _stableCount = 0;
      return BiopayFaceFrameAnalysis(
        guidance: BiopayFaceGuidance.headTurned,
        face: face,
        faceCount: 1,
        brightness: brightness,
        faceAreaRatio: faceAreaRatio,
        stableCount: 0,
        rotationDegrees: sensorOrientation,
        headYaw: face.headEulerAngleY,
        leftEyeOpenProbability: face.leftEyeOpenProbability,
        rightEyeOpenProbability: face.rightEyeOpenProbability,
      );
    }

    // Eyes closed
    final leftEye = face.leftEyeOpenProbability ?? 1.0;
    final rightEye = face.rightEyeOpenProbability ?? 1.0;
    if (leftEye < 0.4 && rightEye < 0.4) {
      _stableCount = 0;
      return BiopayFaceFrameAnalysis(
        guidance: BiopayFaceGuidance.eyesClosed,
        face: face,
        faceCount: 1,
        brightness: brightness,
        faceAreaRatio: faceAreaRatio,
        stableCount: 0,
        rotationDegrees: sensorOrientation,
        headYaw: face.headEulerAngleY,
        leftEyeOpenProbability: face.leftEyeOpenProbability,
        rightEyeOpenProbability: face.rightEyeOpenProbability,
      );
    }

    // Stability tracking
    final currentTrackingId = face.trackingId;
    if (currentTrackingId == _lastStableTrackingId) {
      _stableCount += 1;
    } else {
      _stableCount = 1;
      _lastStableTrackingId = currentTrackingId;
    }

    final isStable = _stableCount >= stableFramesRequired;

    return BiopayFaceFrameAnalysis(
      guidance: isStable
          ? BiopayFaceGuidance.stable
          : BiopayFaceGuidance.searching,
      face: face,
      faceCount: 1,
      brightness: brightness,
      faceAreaRatio: faceAreaRatio,
      stableCount: _stableCount,
      rotationDegrees: sensorOrientation,
      headYaw: face.headEulerAngleY,
      leftEyeOpenProbability: face.leftEyeOpenProbability,
      rightEyeOpenProbability: face.rightEyeOpenProbability,
    );
  }

  /// Reset stability tracking.
  void resetStability() {
    _stableCount = 0;
    _lastStableTrackingId = null;
  }

  /// Release ML Kit resources.
  Future<void> close() => _detector.close();

  // ─── Private helpers ──────────────────────────────────────

  InputImage? _buildInputImage(
    CameraImage image, {
    required int sensorOrientation,
    required CameraLensDirection lensDirection,
  }) {
    final format = _mapBgraFormat(image.format.group);
    if (format == null) return null;

    final rotation = _mapRotation(sensorOrientation);
    if (rotation == null) return null;

    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: ui.Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  InputImageFormat? _mapBgraFormat(ImageFormatGroup format) {
    if (Platform.isIOS) return InputImageFormat.bgra8888;
    if (Platform.isAndroid) return InputImageFormat.nv21;
    return null;
  }

  InputImageRotation? _mapRotation(int sensorOrientation) {
    return switch (sensorOrientation) {
      0 => InputImageRotation.rotation0deg,
      90 => InputImageRotation.rotation90deg,
      180 => InputImageRotation.rotation180deg,
      270 => InputImageRotation.rotation270deg,
      _ => null,
    };
  }

  double _estimateBrightness(CameraImage image) {
    if (image.planes.isEmpty) return 128.0;
    final bytes = image.planes.first.bytes;
    if (bytes.isEmpty) return 128.0;

    // Sample every 32nd byte for performance
    int sum = 0;
    int count = 0;
    for (var i = 0; i < bytes.length; i += 32) {
      sum += bytes[i];
      count++;
    }
    return count > 0 ? sum / count : 128.0;
  }
}
