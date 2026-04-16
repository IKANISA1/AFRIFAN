import 'package:flutter/material.dart';

import '../models/biopay_enrollment_draft.dart';
import '../models/biopay_payment_review_args.dart';
import '../widgets/biopay_camera_pipeline.dart';

/// Scan mode: enrollment collects 5 samples, pay matches against DB.
enum BioPayScanMode { enroll, pay }

/// BioPay Scan — fullscreen camera pipeline for face capture.
class BioPayScanScreen extends StatelessWidget {
  const BioPayScanScreen({
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
  Widget build(BuildContext context) {
    return BioPayCameraPipeline(
      mode: mode,
      enrollmentDraft: enrollmentDraft,
      onEnrollmentSuccess: onEnrollmentSuccess,
      onMatchSuccess: onMatchSuccess,
      onCancel: onCancel,
    );
  }
}
