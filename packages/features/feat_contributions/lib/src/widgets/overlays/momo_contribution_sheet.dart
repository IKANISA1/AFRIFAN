import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final amount = await showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => _AmountEntrySheet(title: title),
  );

  if (amount == null || !context.mounted) return;

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => _UssdConfirmationSheet(
      amount: amount,
      title: title,
      // §2.4 LOCKED — no hardcoded MOMO. Caller must supply recipientMomo.
      recipientMomo: recipientMomo ?? '',
    ),
  );

  if (confirmed != true || !context.mounted) return;

  // Launch the MOMO dialer with dynamic USSD
  // §2.4 LOCKED — no hardcoded MOMO fallback.
  final recipient = recipientMomo ?? '';
  final launched = await MomoDialerService.launchMomoUssd(
    recipient: recipient,
    amount: amount,
  );

  if (!launched) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Could not open the MOMO dialer. No contribution was submitted.',
        ),
        backgroundColor: ColorTokens.error,
      ),
    );
    return;
  }

  // Record the contribution in the database
  var recordedPending = false;
  if (groupId != null && context.mounted) {
    try {
      final container = ProviderScope.containerOf(context);
      final repo = container.read(clubRepositoryProvider);
      final userId = container.read(currentUserProvider)?.id;

      if (userId != null) {
        final ref = 'MOMO-${DateTime.now().millisecondsSinceEpoch}';
        await repo.contribute(
          groupId: groupId,
          userId: userId,
          amount: amount,
          paymentReference: ref,
        );
        recordedPending = true;
      }
    } catch (e) {
      debugPrint('[ContributionOverlay] Failed to record contribution: $e');
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
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              'HOW MUCH TO CONTRIBUTE?',
              style: TypographyTokens.monolithFont(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: ColorTokens.onSurface,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(widget.title, style: TypographyTokens.bodySmall()),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              currency.format(_amount),
              style: TypographyTokens.monolithFont(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: ColorTokens.clubAccent,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Wrap(
              spacing: SpacingTokens.spacing2,
              children: [1000, 2000, 5000, 10000]
                  .map(
                    (value) => ChoiceChip(
                      selected: _amount == value,
                      label: Text('+${value.toString()}'),
                      onSelected: (_) => setState(() => _amount = value),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: SpacingTokens.spacing5),
            ClaymorphicButton(
              label: 'LAUNCH MOMO DIALER',
              width: double.infinity,
              onPressed: () => Navigator.of(context).pop(_amount),
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
    required this.recipientMomo,
  });

  final int amount;
  final String title;
  final String recipientMomo;

  @override
  Widget build(BuildContext context) {
    // Build dynamic USSD string from country catalog
    final country = AfriCountryCatalog.defaultCountry;
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
              style: TypographyTokens.monolithFont(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: ColorTokens.onSurface,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              ussdCode,
              style: TypographyTokens.numericAlias(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(title, style: TypographyTokens.bodySmall()),
            const SizedBox(height: SpacingTokens.spacing5),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('CANCEL'),
                  ),
                ),
                const SizedBox(width: SpacingTokens.spacing3),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('DIAL NOW'),
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
// Private Widgets — Success Dialog
// ═══════════════════════════════════════════════════════════════

class _ContributionSuccessDialog extends StatelessWidget {
  const _ContributionSuccessDialog({
    required this.amount,
    required this.title,
    required this.recordedPending,
  });

  final int amount;
  final String title;
  final bool recordedPending;

  @override
  Widget build(BuildContext context) {
    final currency = CurrencyFormatter(
      currencyCode: context.afriCurrencyCode,
      currencySymbol: context.afriCurrencySymbol,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassCard(
        animate: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              recordedPending
                  ? Icons.hourglass_top_rounded
                  : Icons.open_in_new_rounded,
              color: recordedPending
                  ? ColorTokens.warning
                  : ColorTokens.clubAccent,
              size: 64,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              recordedPending
                  ? 'PENDING CONFIRMATION'
                  : 'PAYMENT HANDOFF STARTED',
              style: TypographyTokens.monolithFont(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: ColorTokens.onSurface,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              currency.format(amount),
              style: TypographyTokens.monolithFont(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: ColorTokens.clubAccent,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(title, style: TypographyTokens.bodySmall()),
            const SizedBox(height: SpacingTokens.spacing3),
            Text(
              recordedPending
                  ? 'Logged as pending. Moves to confirmed after receipt match.'
                  : 'Complete the MoMo prompt. Retry from the circle if matching fails.',
              textAlign: TextAlign.center,
              style: TypographyTokens.bodyMedium(),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            ClaymorphicButton(
              label: 'BACK TO CIRCLE',
              width: double.infinity,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
