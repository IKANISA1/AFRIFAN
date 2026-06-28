import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Ledger item — a single transaction row in the contribution ledger.
class LedgerItem extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const LedgerItem({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final currency = CurrencyFormatter(
      currencyCode: context.afriCurrencyCode,
      currencySymbol: context.afriCurrencySymbol,
    );
    final amount = (transaction['amount'] as num?)?.toInt() ?? 0;
    final status = transaction['status']?.toString() ?? 'pending';
    final alias =
        transaction['display_name']?.toString() ??
        transaction['alias']?.toString() ??
        '---';
    final date = DateTime.tryParse(transaction['created_at']?.toString() ?? '');

    final isConfirmed = status == 'confirmed' || status == 'completed';

    return GlassCard(
      animate: false,
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing4,
        vertical: SpacingTokens.spacing3,
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConfirmed ? ColorTokens.success : ColorTokens.warning,
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),

          // Alias
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alias,
                  style: TypographyTokens.bodyLarge().copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (date != null)
                  Text(
                    DateFormat('MMM d, HH:mm').format(date),
                    style: TypographyTokens.bodyLarge(
                      ColorTokens.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),

          // Amount
          Text(
            currency.format(amount),
            style: TypographyTokens.titleLarge(
              isConfirmed ? ColorTokens.success : ColorTokens.clubAccent,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
