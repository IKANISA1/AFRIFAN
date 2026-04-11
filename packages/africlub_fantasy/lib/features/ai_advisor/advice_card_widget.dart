import 'package:africlub_fantasy/core/constants.dart';
import 'package:flutter/material.dart';

class AdviceCardWidget extends StatelessWidget {
  const AdviceCardWidget({
    required this.advice,
    required this.onCopy,
    super.key,
  });

  final String advice;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FantasySpacing.md),
      decoration: BoxDecoration(
        color: FantasyColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: FantasyColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            advice,
            style: FantasyTypography.body.copyWith(
              color: FantasyColors.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: FantasySpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded),
              color: FantasyColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
