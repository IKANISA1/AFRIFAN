import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/biopay_payment_review_args.dart';
import '../models/biopay_recovery_args.dart';
import '../models/biopay_task_result.dart';
import '../providers/biopay_providers.dart';
import '../services/biopay_auth_gate_service.dart';
import '../services/biopay_payment_handoff_service.dart';
import '../widgets/biopay_reference_ui.dart';

class BioPayPaymentReviewScreen extends ConsumerStatefulWidget {
  const BioPayPaymentReviewScreen({required this.args, super.key});

  final BioPayPaymentReviewArgs args;

  @override
  ConsumerState<BioPayPaymentReviewScreen> createState() =>
      _BioPayPaymentReviewScreenState();
}

class _BioPayPaymentReviewScreenState
    extends ConsumerState<BioPayPaymentReviewScreen> {
  bool _isSubmitting = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final args = widget.args;

    try {
      final gate = await ref
          .read(BioPayAuthGateServiceProvider)
          .authorize(BioPayAuthAction.paymentHandoff);

      if (!mounted) return;

      if (!gate.isAuthorized) {
        if (gate.status == BioPayAuthGateStatus.unavailable ||
            gate.status == BioPayAuthGateStatus.lockedOut) {
          context.push(
            '/BioPay/recovery',
            extra: const BioPayRecoveryArgs(
              issue: BioPayRecoveryIssue.deviceAuth,
              title: 'Device Auth Required',
              message: 'Set up device security first.',
              primaryLabel: 'Back',
              primaryRoute: '/BioPay',
              secondaryLabel: 'Retry',
              secondaryRoute: '/BioPay/profile',
            ),
          );
        } else {
          setState(() => _error = gate.message);
        }
        return;
      }

      final handoffService = ref.read(BioPayPaymentHandoffServiceProvider);
      final repository = ref.read(BioPayRepositoryProvider);
      bool launched;

      if (args.matchResult != null) {
        final matchReceipt = args.matchReceipt;
        if (matchReceipt == null || matchReceipt.isEmpty) {
          throw StateError('Match receipt unavailable.');
        }
        final intent = await repository.createPaymentIntent(
          matchReceipt: matchReceipt,
        );
        if (intent.isExpired) {
          throw StateError('Payment intent expired.');
        }
        launched = await handoffService.payIntent(intent);
        if (launched) {
          await repository.markIntentDialed(intent.intentId);
        }
      } else {
        final resolution = args.handoffResolution;
        if (resolution == null) {
          throw StateError('Review data incomplete.');
        }
        launched = await handoffService.executeHandoff(
          method: resolution.paymentMethod == 'deep_link'
              ? PaymentHandoffMethod.deepLink
              : PaymentHandoffMethod.intentDial,
          uri: resolution.launchUri,
        );
      }

      if (!mounted) return;
      if (!launched) {
        throw StateError('Could not open payment dialer.');
      }

      context.go(
        '/BioPay/result',
        extra: const BioPayTaskResultArgs(
          tone: BioPayTaskResultTone.success,
          title: 'Payment Opened',
          message: 'Complete the transfer in your payment app.',
          primaryLabel: 'Done',
          primaryRoute: '/BioPay',
          secondaryLabel: 'Cancel',
          secondaryRoute: '/BioPay',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _userFriendlyError(error);
        _isSubmitting = false;
      });
      return;
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayValue =
        widget.args.matchResult?.profile?.recipientValue ??
        widget.args.handoffResolution?.recipientValue ??
        widget.args.maskedRecipientValue;

    return Scaffold(
      backgroundColor: BioPayReferenceBackground,
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
            child: Column(
              children: [
                SizedBox(
                  height: 52,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: BioPayReferenceLightBackButton(
                      onTap: () => context.go('/BioPay'),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        displayValue,
                        style: BioPayReferenceText(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 36),
                      BioPayReferencePrimaryButton(
                        label: _isSubmitting ? 'Opening Dialer' : 'Tap to Dial',
                        onTap: _isSubmitting ? null : _submit,
                      ),
                      const SizedBox(height: 18),
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => context.go('/BioPay'),
                        child: Text(
                          'Cancel',
                          style: BioPayReferenceText(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: BioPayReferenceMuted,
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: BioPayReferenceText(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.red.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _userFriendlyError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('attestation') || raw.contains('app check')) {
      return 'Device verification failed. Restart the app and try again.';
    }
    if (raw.contains('timeout') || raw.contains('timed out')) {
      return 'The request timed out. Check your connection and try again.';
    }
    if (raw.contains('socket') ||
        raw.contains('network') ||
        raw.contains('connection')) {
      return 'Network error. Check your internet connection and try again.';
    }
    if (raw.contains('permission') || raw.contains('denied')) {
      return 'Permission denied. Ensure the app has the required access.';
    }
    if (raw.contains('payment') && raw.contains('route')) {
      return 'No payment method is configured for this club yet.';
    }
    if (raw.contains('not found') || raw.contains('does not exist')) {
      return 'Payment could not be processed. Try again later.';
    }
    return 'Something went wrong. Please try again or contact support.';
  }
}
