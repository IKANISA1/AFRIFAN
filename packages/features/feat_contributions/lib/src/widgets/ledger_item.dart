import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Ledger item — a single transaction row in the contribution ledger.
class LedgerItem extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const LedgerItem({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
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
                  style: TypographyTokens.editorialFont(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: ColorTokens.onSurface,
                  ),
                ),
                if (date != null)
                  Text(
                    DateFormat('MMM d, HH:mm').format(date),
                    style: TypographyTokens.editorialFont(
                      fontSize: 15,
                      color: ColorTokens.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),

          // Amount
          Text(
            'FRw ${NumberFormat('#,##0').format(amount)}',
            style: TypographyTokens.monolithFont(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isConfirmed ? ColorTokens.success : primary,
            ),
          ),
        ],
      ),
    );
  }
}
