import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Camera frame guidance states from face detection.
enum BioPayFaceGuidance {
  searching,
  multipleFaces,
  tooDark,
  tooBright,
  tooFar,
  headTurned,
  eyesClosed,
  stable,
}

/// Analysis result for a single camera frame.
class BioPayFaceFrameAnalysis {
  const BioPayFaceFrameAnalysis({
    required this.guidance,
    required this.faceCount,
    required this.brightness,
    required this.faceAreaRatio,
    required this.stableCount,
    required this.rotationDegrees,
    this.headYaw,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
    this.face,
  });

  final BioPayFaceGuidance guidance;
  final Face? face;
  final int faceCount;
  final double brightness;
  final double faceAreaRatio;
  final int stableCount;
  final int rotationDegrees;
  final double? headYaw;
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;

  bool get isStable => guidance == BioPayFaceGuidance.stable && face != null;
  double get absHeadYaw => (headYaw ?? 0).abs();
}
