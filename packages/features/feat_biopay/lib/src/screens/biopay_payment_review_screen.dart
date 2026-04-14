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

class BiopayPaymentReviewScreen extends ConsumerStatefulWidget {
  const BiopayPaymentReviewScreen({required this.args, super.key});

  final BiopayPaymentReviewArgs args;

  @override
  ConsumerState<BiopayPaymentReviewScreen> createState() =>
      _BiopayPaymentReviewScreenState();
}

class _BiopayPaymentReviewScreenState
    extends ConsumerState<BiopayPaymentReviewScreen> {
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
          .read(biopayAuthGateServiceProvider)
          .authorize(BiopayAuthAction.paymentHandoff);

      if (!mounted) return;

      if (!gate.isAuthorized) {
        if (gate.status == BiopayAuthGateStatus.unavailable ||
            gate.status == BiopayAuthGateStatus.lockedOut) {
          context.push(
            '/biopay/recovery',
            extra: const BiopayRecoveryArgs(
              issue: BiopayRecoveryIssue.deviceAuth,
              title: 'Device Auth Required',
              message: 'Set up device security first.',
              primaryLabel: 'Back',
              primaryRoute: '/biopay',
              secondaryLabel: 'Retry',
              secondaryRoute: '/biopay/profile',
            ),
          );
        } else {
          setState(() => _error = gate.message);
        }
        return;
      }

      final handoffService = ref.read(biopayPaymentHandoffServiceProvider);
      final repository = ref.read(biopayRepositoryProvider);
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
        '/biopay/result',
        extra: const BiopayTaskResultArgs(
          tone: BiopayTaskResultTone.success,
          title: 'Payment Opened',
          message: 'Complete the transfer in your payment app.',
          primaryLabel: 'Done',
          primaryRoute: '/biopay',
          secondaryLabel: 'Cancel',
          secondaryRoute: '/biopay',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
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
      backgroundColor: biopayReferenceBackground,
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
                    child: BiopayReferenceLightBackButton(
                      onTap: () => context.go('/biopay'),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        displayValue,
                        style: biopayReferenceText(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 36),
                      BiopayReferencePrimaryButton(
                        label: _isSubmitting ? 'Opening Dialer' : 'Tap to Dial',
                        onTap: _isSubmitting ? null : _submit,
                      ),
                      const SizedBox(height: 18),
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => context.go('/biopay'),
                        child: Text(
                          'Cancel',
                          style: biopayReferenceText(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: biopayReferenceMuted,
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: biopayReferenceText(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.red.shade600,
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
}
