import 'package:africlub_fantasy/core/constants.dart';
import 'package:flutter/material.dart';

class StageAdvanceBanner extends StatelessWidget {
  const StageAdvanceBanner({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 360),
      offset: Offset.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(FantasySpacing.md),
        decoration: BoxDecoration(
          color: FantasyColors.wcGold.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: FantasyColors.wcGold),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: FantasyTypography.body.copyWith(
            color: FantasyColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
