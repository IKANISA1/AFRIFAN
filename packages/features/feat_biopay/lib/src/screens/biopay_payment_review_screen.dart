import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/biopay_payment_review_args.dart';
import '../models/biopay_recovery_args.dart';
import '../models/biopay_task_result.dart';
import '../providers/biopay_providers.dart';
import '../services/biopay_auth_gate_service.dart';
import '../services/biopay_payment_handoff_service.dart';

/// BioPay Payment Review — summary card + amount + CTA.
class BiopayPaymentReviewScreen extends ConsumerStatefulWidget {
  const BiopayPaymentReviewScreen({required this.args, super.key});

  final BiopayPaymentReviewArgs args;

  @override
  ConsumerState<BiopayPaymentReviewScreen> createState() =>
      _BiopayPaymentReviewScreenState();
}

class _BiopayPaymentReviewScreenState
    extends ConsumerState<BiopayPaymentReviewScreen> {
  late final TextEditingController _amountController;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.args.suggestedAmount?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int? get _parsedAmount => int.tryParse(_amountController.text.trim());

  Future<void> _submit() async {
    final args = widget.args;
    final editableAmount = args.canEditAmount
        ? _parsedAmount
        : args.lockedAmount;

    if (args.canEditAmount && (editableAmount == null || editableAmount <= 0)) {
      setState(() => _error = 'Enter an amount.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

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
              title: 'DEVICE AUTH REQUIRED',
              message: 'Set up device security first.',
              primaryLabel: 'BACK',
              primaryRoute: '/biopay',
              secondaryLabel: 'RETRY',
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
      var resultCurrencyCode = args.currencyCode;
      String? resultCurrencySymbol = args.currencySymbol;

      if (args.matchResult != null) {
        final matchReceipt = args.matchReceipt;
        if (matchReceipt == null || matchReceipt.isEmpty) {
          throw StateError('Match receipt unavailable.');
        }
        final intent = await repository.createPaymentIntent(
          matchReceipt: matchReceipt,
          amount: editableAmount,
        );
        if (intent.isExpired) {
          throw StateError('Payment intent expired.');
        }
        launched = await handoffService.payIntent(intent);
        if (launched) {
          await repository.markIntentDialed(intent.intentId);
        }
        resultCurrencyCode = intent.currencyCode ?? args.currencyCode;
        resultCurrencySymbol = intent.currencySymbol ?? args.currencySymbol;
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
        resultCurrencyCode = resolution.currencyCode ?? args.currencyCode;
        resultCurrencySymbol = resolution.currencySymbol ?? args.currencySymbol;
      }

      if (!mounted) return;
      if (!launched) {
        throw StateError('Could not open payment dialer.');
      }

      context.go(
        '/biopay/result',
        extra: BiopayTaskResultArgs(
          tone: BiopayTaskResultTone.success,
          title: 'PAYMENT OPENED',
          message: 'Complete the transfer in your payment app.',
          primaryLabel: args.successPrimaryLabel,
          primaryRoute: args.successPrimaryRoute,
          secondaryLabel: args.secondaryLabel,
          secondaryRoute: args.secondaryRoute,
          alias: args.formattedAlias,
          maskedRecipientValue: args.maskedRecipientValue,
          amount: editableAmount,
          currencyCode: resultCurrencyCode,
          currencySymbol: resultCurrencySymbol,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      context.go(
        '/biopay/result',
        extra: BiopayTaskResultArgs(
          tone: BiopayTaskResultTone.error,
          title: 'PAYMENT FAILED',
          message: error.toString(),
          primaryLabel: 'TRY AGAIN',
          primaryRoute: widget.args.secondaryRoute ?? '/biopay',
          secondaryLabel: 'BACK',
          secondaryRoute: '/biopay',
          alias: widget.args.formattedAlias,
          maskedRecipientValue: widget.args.maskedRecipientValue,
          amount: editableAmount,
          currencyCode: widget.args.currencyCode,
          currencySymbol: widget.args.currencySymbol,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: ColorTokens.onSurface),
          onPressed: () => context.go('/biopay'),
        ),
        title: Text(
          'CONFIRM PAYMENT',
          style: TypographyTokens.headlineLarge(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 1),

              // Alias
              Text(
                args.formattedAlias,
                style: TypographyTokens.numericAlias(fontSize: 32),
              ),

              const SizedBox(height: SpacingTokens.spacing6),

              // Details card
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailLine(
                      label: args.routeLabel,
                      value: args.maskedRecipientValue,
                    ),
                    if (!args.canEditAmount) ...[
                      const SizedBox(height: SpacingTokens.spacing4),
                      _DetailLine(
                        label: 'AMOUNT',
                        value: args.lockedAmountLabel,
                      ),
                    ],
                  ],
                ),
              ),

              if (args.canEditAmount) ...[
                const SizedBox(height: SpacingTokens.spacing6),
                Text(
                  'AMOUNT',
                  style: TypographyTokens.labelSmall().copyWith(
                    color: primaryColor,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.spacing5,
                    vertical: SpacingTokens.spacing4,
                  ),
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    style: TypographyTokens.displaySmall().copyWith(
                      fontSize: 28,
                    ),
                    decoration: InputDecoration.collapsed(
                      hintText: '5000',
                      hintStyle: TypographyTokens.displaySmall().copyWith(
                        fontSize: 28,
                        color: ColorTokens.onSurfaceVariant
                            .withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: SpacingTokens.spacing4),
                Text(
                  _error!,
                  style: TypographyTokens.bodySmall().copyWith(
                    color: ColorTokens.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const Spacer(flex: 2),

              // CTA
              ClaymorphicButton(
                label: _isSubmitting ? 'Opening...' : 'Confirm & Pay',
                onPressed: _isSubmitting ? null : _submit,
                isLoading: _isSubmitting,
                width: double.infinity,
              ),

              const SizedBox(height: SpacingTokens.spacing3),

              // Cancel
              Center(
                child: TextButton(
                  onPressed:
                      _isSubmitting ? null : () => context.go('/biopay'),
                  child: Text(
                    'Cancel',
                    style: TypographyTokens.labelLarge().copyWith(
                      color: ColorTokens.onSurfaceVariant,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: SpacingTokens.spacing6),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Detail line ──

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TypographyTokens.labelSmall().copyWith(
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TypographyTokens.bodyLarge().copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
