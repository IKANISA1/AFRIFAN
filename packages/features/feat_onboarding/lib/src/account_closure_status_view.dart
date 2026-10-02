import 'package:core_auth/core_auth.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Status recovery uses only the opaque locally retained capability.
class AccountClosureStatusView extends StatefulWidget {
  const AccountClosureStatusView({
    required this.receipt,
    required this.onRefresh,
    required this.onForget,
    required this.onSignIn,
    super.key,
  });
  final AccountClosureReceipt receipt;
  final Future<AccountClosureReceipt> Function(AccountClosureReceipt) onRefresh;
  final Future<void> Function() onForget;
  final VoidCallback onSignIn;
  @override
  State<AccountClosureStatusView> createState() =>
      _AccountClosureStatusViewState();
}

class _AccountClosureStatusViewState extends State<AccountClosureStatusView> {
  late AccountClosureReceipt receipt = widget.receipt;
  bool busy = false;
  bool unavailable = false;
  Future<void> refresh() async {
    if (busy) return;
    setState(() {
      busy = true;
      unavailable = false;
    });
    try {
      final updated = await widget.onRefresh(receipt);
      if (mounted) setState(() => receipt = updated);
    } catch (_) {
      if (mounted) setState(() => unavailable = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final message = switch (receipt.status) {
      'completed' => l10n.accountClosureStatusCompleted,
      'failed' => l10n.editProfileDeletionFailedMessage,
      'deletion_pending' => l10n.accountClosureStatusSubmitted,
      _ => l10n.accountClosureStatusUnconfirmed,
    };
    return AfriScreenScaffold(
      showBackButton: false,
      title: l10n.accountClosureStatusTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 24),
          Text(message, key: const ValueKey('account-closure-status-message')),
          const SizedBox(height: 24),
          SelectableText(l10n.editProfileDeletionReference(receipt.requestId)),
          if (unavailable)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(l10n.accountClosureStatusUnavailable),
            ),
          const SizedBox(height: 24),
          AfriButton(
            label: l10n.accountClosureStatusRefresh,
            enabled: !busy,
            isLoading: busy,
            labelMaxLines: 3,
            onTap: refresh,
          ),
          if (!receipt.isConfirmed)
            AfriButton(
              label: l10n.onboardingContinueWhatsApp,
              variant: AfriButtonVariant.ghost,
              enabled: !busy,
              labelMaxLines: 3,
              onTap: widget.onSignIn,
            ),
          AfriButton(
            label: l10n.accountClosureStatusForget,
            variant: AfriButtonVariant.ghost,
            enabled: !busy,
            labelMaxLines: 3,
            onTap: () async {
              await widget.onForget();
            },
          ),
        ],
      ),
    );
  }
}
