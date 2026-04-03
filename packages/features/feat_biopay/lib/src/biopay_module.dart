import 'package:core_router/core_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'models/biopay_enrollment_draft.dart';
import 'models/biopay_payment_review_args.dart';
import 'models/biopay_recovery_args.dart';
import 'models/biopay_task_result.dart';
import 'screens/biopay_nfc_screen.dart';
import 'screens/biopay_payment_review_screen.dart';
import 'screens/biopay_profile_screen.dart';
import 'screens/biopay_qr_scan_screen.dart';
import 'screens/biopay_qr_screen.dart';
import 'screens/biopay_recovery_screen.dart';
import 'screens/biopay_register_screen.dart';
import 'screens/biopay_result_screen.dart';
import 'screens/biopay_scan_screen.dart';
import 'screens/biopay_screen.dart';
import 'widgets/biopay_feature_gate.dart';

/// BioPay feature module — biometric payment tab + sub-routes.
///
/// Routes:
///   /biopay              → Hub (face/NFC/QR selection)
///   /biopay/profile      → Biometric & Financial Configurations
///   /biopay/register     → Enrollment registration form
///   /biopay/scan?mode=   → Face capture camera (enroll or pay)
class BioPayModule extends FeatureModule {
  @override
  String get featureKey => 'biopay';

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/biopay',
    label: 'BIOPAY',
    icon: Icons.face_outlined,
    activeIcon: Icons.face,
    builder: (context, state) => const BioPayScreen(),
  );

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: 'profile',
      name: 'biopay_profile',
      builder: (context, state) => const BiopayProfileScreen(),
    ),
    GoRoute(
      path: 'register',
      name: 'biopay_register',
      builder: (context, state) =>
          const BiopayFeatureGate(child: BiopayRegisterScreen()),
    ),
    GoRoute(
      path: 'review',
      name: 'biopay_review',
      builder: (context, state) {
        final args = state.extra;
        if (args is! BiopayPaymentReviewArgs) {
          return const BiopayRecoveryScreen(
            args: BiopayRecoveryArgs(
              issue: BiopayRecoveryIssue.feature,
              title: 'REVIEW DATA MISSING',
              message:
                  'Could not restore payment context. Start again from BioPay.',
              primaryLabel: 'BACK TO BIOPAY',
              primaryRoute: '/biopay',
            ),
          );
        }
        return BiopayFeatureGate(child: BiopayPaymentReviewScreen(args: args));
      },
    ),
    GoRoute(
      path: 'result',
      name: 'biopay_result',
      builder: (context, state) {
        final args = state.extra;
        if (args is! BiopayTaskResultArgs) {
          return const BiopayRecoveryScreen(
            args: BiopayRecoveryArgs(
              issue: BiopayRecoveryIssue.feature,
              title: 'BIOPAY STATUS LOST',
              message:
                  'Could not restore result. Return to BioPay.',
              primaryLabel: 'BACK TO BIOPAY',
              primaryRoute: '/biopay',
            ),
          );
        }
        return BiopayResultScreen(args: args);
      },
    ),
    GoRoute(
      path: 'recovery',
      name: 'biopay_recovery',
      builder: (context, state) {
        final args = state.extra;
        if (args is! BiopayRecoveryArgs) {
          return const BiopayRecoveryScreen(
            args: BiopayRecoveryArgs(
              issue: BiopayRecoveryIssue.feature,
              title: 'RECOVERY CONTEXT MISSING',
              message:
                  'Could not load recovery guidance. Return to BioPay.',
              primaryLabel: 'BACK TO BIOPAY',
              primaryRoute: '/biopay',
            ),
          );
        }
        return BiopayRecoveryScreen(args: args);
      },
    ),
    GoRoute(
      path: 'scan',
      name: 'biopay_scan',
      builder: (context, state) {
        final modeParam = state.uri.queryParameters['mode'] ?? 'enroll';
        final mode = modeParam == 'pay'
            ? BiopayScanMode.pay
            : BiopayScanMode.enroll;
        final draft = state.extra as BiopayEnrollmentDraft?;

        return BiopayFeatureGate(
          child: BiopayScanScreen(mode: mode, enrollmentDraft: draft),
        );
      },
    ),
    GoRoute(
      path: 'qr',
      builder: (context, state) =>
          const BiopayFeatureGate(child: BiopayQrScreen()),
      routes: [
        GoRoute(
          path: 'scan',
          builder: (context, state) =>
              const BiopayFeatureGate(child: BiopayQrScanScreen()),
        ),
      ],
    ),
    GoRoute(
      path: 'nfc',
      builder: (context, state) =>
          const BiopayFeatureGate(child: BiopayNfcScreen()),
    ),
  ];
}
