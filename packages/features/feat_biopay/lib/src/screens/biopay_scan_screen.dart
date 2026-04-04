import 'package:flutter/material.dart';

import '../models/biopay_enrollment_draft.dart';
import '../models/biopay_payment_review_args.dart';
import '../widgets/biopay_camera_pipeline.dart';

/// Scan mode: enrollment collects 5 samples, pay matches against DB.
enum BiopayScanMode { enroll, pay }

/// BioPay Scan — fullscreen camera pipeline for face capture.
class BiopayScanScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return BiopayCameraPipeline(
      mode: mode,
      enrollmentDraft: enrollmentDraft,
      onEnrollmentSuccess: onEnrollmentSuccess,
      onMatchSuccess: onMatchSuccess,
      onCancel: onCancel,
    );
  }
}
