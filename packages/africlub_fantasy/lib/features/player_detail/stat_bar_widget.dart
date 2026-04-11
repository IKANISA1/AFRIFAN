import 'package:africlub_fantasy/core/constants.dart';
import 'package:flutter/material.dart';

class StatBarWidget extends StatelessWidget {
  const StatBarWidget({
    required this.label,
    required this.value,
    required this.max,
    super.key,
  });

  final String label;
  final double value;
  final double max;

  @override
  Widget build(BuildContext context) {
    final progress = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: FantasyTypography.caption.copyWith(
                  color: FantasyColors.textSecondary,
                ),
              ),
            ),
            Text(
              value.toStringAsFixed(value % 1 == 0 ? 0 : 1),
              style: FantasyTypography.caption.copyWith(
                color: FantasyColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: FantasySpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: FantasyColors.surfaceAlt,
            valueColor: const AlwaysStoppedAnimation<Color>(
              FantasyColors.successGreen,
            ),
          ),
        ),
      ],
    );
  }
}
