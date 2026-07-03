import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Full contribution flow: Amount → USSD Confirmation → Record → Success.
///
/// Uses [MomoDialerService] for dynamic USSD building and
/// [ClubRepository.contribute] to persist the contribution.
Future<void> showMomoAmountEntrySheet(
  BuildContext context, {
  required String title,
  String? groupId,
  String? recipientMomo,
}) async {
  final amount = await showAfriBottomSheet<int>(
    context: context,
    builder: (context) => _AmountEntrySheet(title: title),
  );

  if (amount == null || !context.mounted) return;

  final confirmed = await showAfriBottomSheet<bool>(
    context: context,
    builder: (context) {
      final country =
          AfriCountryCatalog.byIsoCode(context.afriCountryCode) ??
          AfriCountryCatalog.defaultCountry;
      return _UssdConfirmationSheet(
        amount: amount,
        title: title,
        country: country,
        // §2.4 LOCKED — no hardcoded MOMO. Caller must supply recipientMomo.
        recipientMomo: recipientMomo ?? '',
      );
    },
  );

  if (confirmed != true || !context.mounted) return;

  // Launch the MOMO dialer with dynamic USSD
  // §2.4 LOCKED — no hardcoded MOMO fallback.
  final recipient = recipientMomo ?? '';
  final launched = await MomoDialerService.launchMomoUssd(
    recipient: recipient,
    amount: amount,
    country:
        AfriCountryCatalog.byIsoCode(context.afriCountryCode) ??
        AfriCountryCatalog.defaultCountry,
  );

  if (!launched) {
    if (!context.mounted) return;
    AfriToast.error(
      context,
      'Could not open the MOMO dialer. Contribution was not submitted.',
    );
    return;
  }

  // Record the contribution in the database
  var recordedPending = false;
  String? contributionId;
  if (groupId != null && context.mounted) {
    try {
      final container = ProviderScope.containerOf(context);
      final repo = container.read(clubRepositoryProvider);
      final userId = container.read(currentUserProvider)?.id;

      if (userId != null) {
        final ref = 'MOMO-${DateTime.now().millisecondsSinceEpoch}';
        contributionId = await repo.contribute(
          groupId: groupId,
          userId: userId,
          amount: amount,
          paymentReference: ref,
        );
        recordedPending = true;
      }
    } catch (e) {
      AfriLogger.warn(
        'ContributionOverlay',
        'Failed to record contribution: $e',
      );
    }
  }

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierColor: ColorTokens.scrim,
    builder: (context) => _ContributionSuccessDialog(
      amount: amount,
      title: title,
      recordedPending: recordedPending,
      contributionId: contributionId,
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
// Private Widgets — Amount entry
// ═══════════════════════════════════════════════════════════════

class _AmountEntrySheet extends StatefulWidget {
  const _AmountEntrySheet({required this.title});

  final String title;

  @override
  State<_AmountEntrySheet> createState() => _AmountEntrySheetState();
}

class _AmountEntrySheetState extends State<_AmountEntrySheet> {
  int _amount = 5000;

  @override
  Widget build(BuildContext context) {
    final currency = CurrencyFormatter(
      currencyCode: context.afriCurrencyCode,
      currencySymbol: context.afriCurrencySymbol,
    );

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing4),
      child: GlassCard(
        animate: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: ColorTokens.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: ShapeTokens.buttonRadius,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              'HOW MUCH TO CONTRIBUTE?',
              style: TypographyTokens.headlineMedium().copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(widget.title, style: TypographyTokens.bodySmall()),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              currency.format(_amount),
              style: TypographyTokens.displayLarge(
                ColorTokens.clubAccent,
              ).copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Wrap(
              spacing: SpacingTokens.spacing2,
              children: [1000, 2000, 5000, 10000]
                  .map(
                    (value) => AfriChoiceChip(
                      selected: _amount == value,
                      label: Text('+$value'),
                      onSelected: (_) => setState(() => _amount = value),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: SpacingTokens.spacing5),
            AfriButton(
              label: 'Launch MOMO dialer',
              fullWidth: true,
              onTap: () => context.pop(_amount),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Private Widgets — USSD Confirmation
// ═══════════════════════════════════════════════════════════════

class _UssdConfirmationSheet extends StatelessWidget {
  const _UssdConfirmationSheet({
    required this.amount,
    required this.title,
    required this.country,
    required this.recipientMomo,
  });

  final int amount;
  final String title;
  final AfriCountry country;
  final String recipientMomo;

  @override
  Widget build(BuildContext context) {
    final ussdCode = country.buildUssdCode(
      recipientMomo: recipientMomo,
      amount: amount,
    );

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing4),
      child: GlassCard(
        animate: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'LAUNCHING MOMO',
              style: TypographyTokens.headlineMedium().copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              ussdCode,
              style: TypographyTokens.titleMedium(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(title, style: TypographyTokens.bodySmall()),
            const SizedBox(height: SpacingTokens.spacing5),
            Row(
              children: [
                Expanded(
                  child: AfriButton(
                    label: 'Cancel',
                    variant: AfriButtonVariant.outline,
                    onTap: () => context.pop(false),
                  ),
                ),
                const SizedBox(width: SpacingTokens.spacing3),
                Expanded(
                  child: AfriButton(
                    label: 'Dial now',
                    onTap: () => context.pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Private Widgets — Payment Verification Dialog
// ═══════════════════════════════════════════════════════════════

class _ContributionSuccessDialog extends StatefulWidget {
  const _ContributionSuccessDialog({
    required this.amount,
    required this.title,
    required this.recordedPending,
    this.contributionId,
  });

  final int amount;
  final String title;
  final bool recordedPending;
  final String? contributionId;

  @override
  State<_ContributionSuccessDialog> createState() =>
      _ContributionSuccessDialogState();
}

class _ContributionSuccessDialogState
    extends State<_ContributionSuccessDialog> {
  /// `pending` → `verified` → `failed` → `timeout`
  String _status = 'pending';
  Timer? _pollTimer;
  int _pollCount = 0;

  // Poll every 5 seconds for up to 2 minutes (24 attempts).
  static const int _maxPolls = 24;
  static const Duration _pollInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    if (widget.recordedPending && widget.contributionId != null) {
      _startPolling();
    } else if (!widget.recordedPending) {
      _status = 'error';
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(_pollInterval, (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    final id = widget.contributionId;
    if (id == null || !mounted) {
      _pollTimer?.cancel();
      return;
    }

    _pollCount++;

    try {
      final container = ProviderScope.containerOf(context);
      final repo = container.read(clubRepositoryProvider);
      final result = await repo.getContributionPaymentStatus(id);

      if (!mounted) return;

      if (result == 'verified') {
        _pollTimer?.cancel();
        setState(() => _status = 'verified');
        return;
      }
      if (result == 'failed') {
        _pollTimer?.cancel();
        setState(() => _status = 'failed');
        return;
      }
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'MomoContributionSheet',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      // Network error during poll — continue polling
    }

    if (_pollCount >= _maxPolls) {
      _pollTimer?.cancel();
      if (mounted) {
        setState(() => _status = 'timeout');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = CurrencyFormatter(
      currencyCode: context.afriCurrencyCode,
      currencySymbol: context.afriCurrencySymbol,
    );

    final IconData icon;
    final Color iconColor;
    final String heading;
    final String body;

    switch (_status) {
      case 'verified':
        icon = AfriIcons.statusSuccess;
        iconColor = ColorTokens.success;
        heading = 'PAYMENT CONFIRMED';
        body =
            'Your contribution of ${currency.format(widget.amount)} '
            'has been verified and recorded.';
        break;
      case 'failed':
        icon = AfriIcons.statusWarning;
        iconColor = ColorTokens.error;
        heading = 'PAYMENT FAILED';
        body =
            'The payment could not be verified. '
            'Check your MoMo balance and try again, or contact support.';
        break;
      case 'timeout':
        icon = AfriIcons.statusPending;
        iconColor = ColorTokens.warning;
        heading = 'STILL PROCESSING';
        body =
            'Your payment is taking longer than usual. '
            'Check the Group ledger for your updated status. '
            'If you completed the MoMo transfer, it will appear shortly.';
        break;
      case 'error':
        icon = AfriIcons.statusWarning;
        iconColor = ColorTokens.error;
        heading = 'COULD NOT RECORD';
        body =
            'The MoMo dialer was launched but the contribution '
            'could not be saved. Return to the Group and try again.';
        break;
      default: // 'pending'
        icon = AfriIcons.statusPending;
        iconColor = ColorTokens.warning;
        heading = 'AWAITING PAYMENT';
        body =
            'Complete the MoMo payment on your phone. '
            'Your contribution appears as "Processing" '
            'until we receive confirmation.';
    }

    return AfriDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 64),
          const SizedBox(height: SpacingTokens.spacing4),
          Text(
            heading,
            style: TypographyTokens.headlineLarge().copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            currency.format(widget.amount),
            style: TypographyTokens.displaySmall(
              ColorTokens.clubAccent,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(widget.title, style: TypographyTokens.bodySmall()),
          const SizedBox(height: SpacingTokens.spacing3),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TypographyTokens.bodyMedium(),
          ),
          if (_status == 'pending') ...[
            const SizedBox(height: SpacingTokens.spacing3),
            const AfriLoadingIndicator(size: 20),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              'Checking payment status…',
              style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
            ),
          ],
          if (_status == 'verified') ...[
            const SizedBox(height: SpacingTokens.spacing3),
            const AfriInfoChip(label: 'VERIFIED', color: ColorTokens.success),
          ],
          const SizedBox(height: SpacingTokens.spacing4),
          AfriButton(
            label: _status == 'verified' ? 'Done' : 'Back to group',
            fullWidth: true,
            onTap: () => context.pop(),
          ),
        ],
      ),
    );
  }
}
