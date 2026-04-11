import 'package:africlub_fantasy/core/constants.dart';
import 'package:flutter/material.dart';

class BracketNodeWidget extends StatelessWidget {
  const BracketNodeWidget({
    required this.label,
    this.highlight = false,
    super.key,
  });

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(FantasySpacing.sm),
      decoration: BoxDecoration(
        color: highlight
            ? FantasyColors.wcGold.withValues(alpha: 0.18)
            : FantasyColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? FantasyColors.wcGold : FantasyColors.border,
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: FantasyTypography.caption.copyWith(
          color: FantasyColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
