import 'package:africlub_fantasy/core/constants.dart';
import 'package:flutter/material.dart';

class ScoreTickerWidget extends StatelessWidget {
  const ScoreTickerWidget({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: FantasySpacing.md,
        vertical: FantasySpacing.md,
      ),
      decoration: BoxDecoration(
        color: FantasyColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FantasyColors.border),
      ),
      child: Text(
        label,
        style: FantasyTypography.scoreSm.copyWith(
          color: FantasyColors.textPrimary,
        ),
      ),
    );
  }
}
