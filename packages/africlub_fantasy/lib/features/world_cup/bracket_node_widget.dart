import 'package:africlub_fantasy/core/constants.dart';
import 'package:flutter/material.dart';

class BracketNodeWidget extends StatelessWidget {
  const BracketNodeWidget({
    required this.label,
    this.subtitle,
    this.statusLabel,
    this.highlight = false,
    super.key,
  });

  final String label;
  final String? subtitle;
  final String? statusLabel;
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            textAlign: TextAlign.center,
            style: FantasyTypography.caption.copyWith(
              color: FantasyColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: FantasyTypography.label.copyWith(
                color: FantasyColors.textSecondary,
              ),
            ),
          ],
          if (statusLabel != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              statusLabel!,
              textAlign: TextAlign.center,
              style: FantasyTypography.label.copyWith(
                color: highlight
                    ? FantasyColors.wcGold
                    : FantasyColors.successGreen,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
