import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';

import '../models/fet_models.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Transaction row
// ══════════════════════════════════════════════════════════════════════════════

/// Single points transaction row for audited reward activity.
class WalletTransactionRow extends StatelessWidget {
  const WalletTransactionRow({
    super.key,
    required this.transaction,
    required this.formatFet,
  });

  final FetWalletTransaction transaction;
  final String Function(int value) formatFet;

  Color _transactionColor() {
    return transaction.direction == FetWalletEntryDirection.credit
        ? ColorTokens.success
        : ColorTokens.warning;
  }

  IconData _transactionIcon() {
    switch (transaction.entryType) {
      case 'partner_promotion_earn':
        return AfriIcons.rewards;
      case 'partner_pool_entry':
        return AfriIcons.predict;
      case 'partner_pool_payout':
        return AfriIcons.earn;
      case 'partner_pool_refund':
        return AfriIcons.refresh;
      case 'transfer_in':
        return AfriIcons.receiveFet;
      case 'transfer_out':
        return AfriIcons.sendFet;
      case 'redeem':
        return AfriIcons.redeem;
      case 'admin_adjustment':
        return AfriIcons.adjustment;
      case 'opening_balance':
        return AfriIcons.openingBalance;
      case 'earn':
      default:
        return AfriIcons.earn;
    }
  }

  String _formatCounterparty() {
    final displayName = transaction.counterpartyDisplayName;
    final alias = transaction.counterpartyPublicUserId;
    if (displayName != null && displayName.trim().isNotEmpty) {
      return alias != null && alias.trim().isNotEmpty
          ? '$displayName · #$alias'
          : displayName;
    }
    if (alias != null && alias.trim().isNotEmpty) {
      return '#$alias';
    }
    return 'Supporter';
  }

  @override
  Widget build(BuildContext context) {
    final color = _transactionColor();

    return GlassCard(
      animate: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: SpacingTokens.spacing10 + SpacingTokens.spacing1,
            width: SpacingTokens.spacing10 + SpacingTokens.spacing1,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.18),
            ),
            child: Icon(_transactionIcon(), color: color),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.headline,
                  style: TypographyTokens.bodyLarge().copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (transaction.counterpartyUserId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: SpacingTokens.spacing1),
                    child: Text(
                      _formatCounterparty(),
                      style: TypographyTokens.bodySmall(
                        ColorTokens.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (transaction.note != null)
                  Padding(
                    padding: const EdgeInsets.only(top: SpacingTokens.spacing1),
                    child: Text(
                      transaction.note!,
                      style: TypographyTokens.bodySmall(
                        ColorTokens.onSurfaceVariant,
                      ),
                    ),
                  ),
                const SizedBox(height: SpacingTokens.spacing1),
                Text(
                  transaction.createdAt == null
                      ? 'Just now'
                      : AfriDateFormatter.timeAgo(transaction.createdAt!),
                  style: TypographyTokens.bodySmall(
                    ColorTokens.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                context.afriL10n.gameWalletSignedPoints(
                  transaction.direction == FetWalletEntryDirection.debit
                      ? '-'
                      : '+',
                  formatFet(transaction.amount),
                ),
                style: TypographyTokens.titleLarge(
                  color,
                ).copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: SpacingTokens.spacing1),
              Text(
                context.afriL10n.gameWalletBalance(
                  formatFet(transaction.balanceAfter),
                ),
                style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
