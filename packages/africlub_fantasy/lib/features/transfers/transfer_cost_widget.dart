import 'package:africlub_fantasy/core/constants.dart';
import 'package:flutter/material.dart';

class TransferCostWidget extends StatelessWidget {
  const TransferCostWidget({
    required this.freeRemaining,
    required this.transferCost,
    this.freeRemainingLabel,
    this.statusLabel,
    this.bankBalance,
    this.teamValue,
    super.key,
  });

  final int freeRemaining;
  final int transferCost;
  final String? freeRemainingLabel;
  final String? statusLabel;
  final int? bankBalance;
  final int? teamValue;

  @override
  Widget build(BuildContext context) {
    final isPenalty = transferCost < 0;
    final freeTransfersLabel =
        freeRemainingLabel ?? '$freeRemaining free remaining';
    final financeSummary = <String>[
      if (bankBalance != null)
        'Bank: £${(bankBalance! / 10).toStringAsFixed(1)}M',
      if (teamValue != null)
        'Team value: £${(teamValue! / 10).toStringAsFixed(1)}M',
    ].join(' · ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: FantasySpacing.md,
        vertical: FantasySpacing.md,
      ),
      decoration: BoxDecoration(
        color: FantasyColors.surface,
        border: const Border(top: BorderSide(color: FantasyColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Transfers: $freeTransfersLabel · Cost: ${transferCost >= 0 ? '+' : ''}$transferCost pts',
            style: FantasyTypography.body.copyWith(
              color: isPenalty
                  ? FantasyColors.dangerRed
                  : FantasyColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (statusLabel != null || financeSummary.isNotEmpty) ...<Widget>[
            const SizedBox(height: FantasySpacing.xs),
            Text(
              <String>[
                if (statusLabel != null && statusLabel!.isNotEmpty)
                  statusLabel!,
                if (financeSummary.isNotEmpty) financeSummary,
              ].join(' · '),
              style: FantasyTypography.caption.copyWith(
                color: FantasyColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
