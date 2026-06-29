import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Contribution history for the Membership Hub.
///
/// Mirrors the fanafrika `MembershipHub.tsx` HistoryRow component — displays
/// date, amount, contribution label, and verified status for each contribution.
class ContributionHistorySection extends StatelessWidget {
  const ContributionHistorySection({
    super.key,
    required this.contributions,
    this.currencySymbol = 'RWF',
  });

  final List<ContributionRecord> contributions;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    if (contributions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONTRIBUTION HISTORY',
          style: TypographyTokens.titleMedium().copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        ...contributions.map(
          (c) => _ContributionRow(record: c, currencySymbol: currencySymbol),
        ),
      ],
    );
  }
}

class ContributionRecord {
  const ContributionRecord({
    required this.date,
    required this.amount,
    required this.label,
    required this.status,
  });

  final String date;
  final int amount;
  final String label;

  /// One of: 'verified', 'pending', 'failed'
  final String status;
}

class _ContributionRow extends StatelessWidget {
  const _ContributionRow({required this.record, required this.currencySymbol});

  final ContributionRecord record;
  final String currencySymbol;

  Color _statusColor() {
    return switch (record.status.toLowerCase()) {
      'verified' => ColorTokens.success,
      'pending' => ColorTokens.warning,
      'failed' => ColorTokens.error,
      _ => ColorTokens.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
      child: GlassCard(
        animate: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${record.amount} $currencySymbol',
                    style: TypographyTokens.titleSmall(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing1 / 2),
                  Text(record.date, style: TypographyTokens.bodySmall()),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  record.label.toUpperCase(),
                  style: TypographyTokens.labelMedium(
                    ColorTokens.clubAccent,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: SpacingTokens.spacing1 / 2),
                Text(
                  record.status,
                  style: TypographyTokens.labelSmall(
                    _statusColor(),
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
