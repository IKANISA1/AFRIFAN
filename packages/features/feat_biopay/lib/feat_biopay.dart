/// BioPay — Biometric face recognition and universal payment handoff.
///
/// Feature surface:
/// - Hub + 9 supporting screens (profile, register, scan, QR, QR scan, NFC,
///   review, result, recovery)
/// - Shared models for profile, handoff, intent, review, and task state
/// - Services for auth gating, face pipeline, NFC, cache, and payment handoff
/// - Riverpod providers for app config, profile state, and runtime services
library;

export 'src/biopay_module.dart';
export 'src/models/biopay_enrollment_draft.dart';
export 'src/models/biopay_face_frame_analysis.dart';
export 'src/models/biopay_handoff_resolution.dart';
export 'src/models/biopay_handoff_token.dart';
export 'src/models/biopay_liveness_challenge.dart';
export 'src/models/biopay_match_result.dart';
export 'src/models/biopay_model_contract.dart';
export 'src/models/biopay_money.dart';
export 'src/models/biopay_payment_intent.dart';
export 'src/models/biopay_payment_review_args.dart';
export 'src/models/biopay_profile.dart';
export 'src/models/biopay_recovery_args.dart';
export 'src/models/biopay_task_result.dart';
export 'src/providers/biopay_providers.dart';
export 'src/repositories/biopay_repository.dart';
export 'src/screens/biopay_nfc_screen.dart';
export 'src/screens/biopay_payment_review_screen.dart';
export 'src/screens/biopay_profile_screen.dart';
export 'src/screens/biopay_qr_scan_screen.dart';
export 'src/screens/biopay_qr_screen.dart';
export 'src/screens/biopay_recovery_screen.dart';
export 'src/screens/biopay_register_screen.dart';
export 'src/screens/biopay_result_screen.dart';
export 'src/screens/biopay_scan_screen.dart';
export 'src/screens/biopay_screen.dart';
export 'src/services/biopay_auth_gate_service.dart';
export 'src/services/biopay_cache_service.dart';
export 'src/services/biopay_embedding_service.dart';
export 'src/services/biopay_face_alignment_service.dart';
export 'src/services/biopay_face_detection_service.dart';
export 'src/services/biopay_liveness_service.dart';
export 'src/services/biopay_nfc_hce_service.dart';
export 'src/services/biopay_nfc_service.dart';
export 'src/services/biopay_payment_handoff_service.dart';
export 'src/services/biopay_rate_limiter.dart';
export 'src/widgets/biopay_scanner_shell.dart';
