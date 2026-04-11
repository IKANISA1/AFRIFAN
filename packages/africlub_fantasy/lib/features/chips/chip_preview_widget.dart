import 'package:africlub_fantasy/core/constants.dart';
import 'package:flutter/material.dart';

class ChipPreviewWidget extends StatelessWidget {
  const ChipPreviewWidget({
    required this.label,
    required this.projectedPoints,
    super.key,
  });

  final String label;
  final int projectedPoints;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FantasySpacing.md),
      decoration: BoxDecoration(
        color: FantasyColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FantasyColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: FantasyTypography.caption.copyWith(
              color: FantasyColors.textSecondary,
            ),
          ),
          const SizedBox(height: FantasySpacing.sm),
          Text(
            '+$projectedPoints pts',
            style: FantasyTypography.scoreSm.copyWith(
              color: FantasyColors.successGreen,
            ),
          ),
        ],
      ),
    );
  }
}
