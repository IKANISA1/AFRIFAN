import 'package:africlub_fantasy/core/constants.dart';
import 'package:flutter/material.dart';

class BudgetBarWidget extends StatelessWidget {
  const BudgetBarWidget({
    required this.remaining,
    required this.total,
    super.key,
  });

  final int remaining;
  final int total;

  @override
  Widget build(BuildContext context) {
    final safeTotal = total <= 0 ? 1 : total;
    final progress = ((safeTotal - remaining) / safeTotal).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '£${(remaining / 10).toStringAsFixed(1)}M remaining',
                style: FantasyTypography.body.copyWith(
                  color: FantasyColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              'Budget',
              style: FantasyTypography.caption.copyWith(
                color: FantasyColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: FantasySpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: FantasyColors.surfaceAlt,
            valueColor: AlwaysStoppedAnimation<Color>(
              remaining >= 0
                  ? FantasyColors.successGreen
                  : FantasyColors.dangerRed,
            ),
          ),
        ),
      ],
    );
  }
}
