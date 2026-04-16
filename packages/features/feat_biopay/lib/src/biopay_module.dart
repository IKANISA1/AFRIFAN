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
///   /BioPay              → Hub (face/NFC/QR selection)
///   /BioPay/profile      → Biometric & Financial Configurations
///   /BioPay/register     → Enrollment registration form
///   /BioPay/scan?mode=   → Face capture camera (enroll or pay)
class BioPayModule extends FeatureModule {
  @override
  String get featureKey => 'BioPay';

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/BioPay',
      builder: (context, state) => const BioPayScreen(),
      routes: [
        GoRoute(
          path: 'profile',
          name: 'biopay_profile',
          builder: (context, state) => const BioPayProfileScreen(),
        ),
        GoRoute(
          path: 'register',
          name: 'BioPay_register',
          builder: (context, state) =>
              const BioPayFeatureGate(child: BioPayRegisterScreen()),
        ),
        GoRoute(
          path: 'review',
          name: 'BioPay_review',
          builder: (context, state) {
            final args = state.extra;
            if (args is! BioPayPaymentReviewArgs) {
              return const BioPayRecoveryScreen(
                args: BioPayRecoveryArgs(
                  issue: BioPayRecoveryIssue.feature,
                  title: 'Review Data Missing',
                  message:
                      'Could not restore payment context. Start again from BioPay.',
                  primaryLabel: 'Back to BioPay',
                  primaryRoute: '/BioPay',
                ),
              );
            }
            return BioPayFeatureGate(child: BioPayPaymentReviewScreen(args: args));
          },
        ),
        GoRoute(
          path: 'result',
          name: 'BioPay_result',
          builder: (context, state) {
            final args = state.extra;
            if (args is! BioPayTaskResultArgs) {
              return const BioPayRecoveryScreen(
                args: BioPayRecoveryArgs(
                  issue: BioPayRecoveryIssue.feature,
                  title: 'BioPay Status Lost',
                  message: 'Could not restore result. Return to BioPay.',
                  primaryLabel: 'Back to BioPay',
                  primaryRoute: '/BioPay',
                ),
              );
            }
            return BioPayResultScreen(args: args);
          },
        ),
        GoRoute(
          path: 'recovery',
          name: 'BioPay_recovery',
          builder: (context, state) {
            final args = state.extra;
            if (args is! BioPayRecoveryArgs) {
              return const BioPayRecoveryScreen(
                args: BioPayRecoveryArgs(
                  issue: BioPayRecoveryIssue.feature,
                  title: 'Recovery Context Missing',
                  message: 'Could not load recovery guidance. Return to BioPay.',
                  primaryLabel: 'Back to BioPay',
                  primaryRoute: '/BioPay',
                ),
              );
            }
            return BioPayRecoveryScreen(args: args);
          },
        ),
        GoRoute(
          path: 'scan',
          name: 'BioPay_scan',
          builder: (context, state) {
            final modeParam = state.uri.queryParameters['mode'] ?? 'enroll';
            final mode = modeParam == 'pay'
                ? BioPayScanMode.pay
                : BioPayScanMode.enroll;
            final draft = state.extra as BioPayEnrollmentDraft?;

            return BioPayFeatureGate(
              child: BioPayScanScreen(mode: mode, enrollmentDraft: draft),
            );
          },
        ),
        GoRoute(
          path: 'qr',
          builder: (context, state) =>
              const BioPayFeatureGate(child: BioPayQrScreen()),
          routes: [
            GoRoute(
              path: 'scan',
              builder: (context, state) =>
                  const BioPayFeatureGate(child: BioPayQrScanScreen()),
            ),
          ],
        ),
        GoRoute(
          path: 'nfc',
          builder: (context, state) =>
              const BioPayFeatureGate(child: BioPayNfcScreen()),
        ),
      ],
    ),
  ];
}
