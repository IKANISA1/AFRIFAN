import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Interactive pill button for selecting a prediction market outcome.
///
/// Shows the outcome label and uses the design system's club accent
/// for the selected state. Touch feedback via [AfriPressFeedback].
class MarketOptionPill extends StatelessWidget {
  const MarketOptionPill({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? ColorTokens.clubAccent.withValues(alpha: 0.18)
              : ColorTokens.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? BorderTokens.all(color: ColorTokens.clubAccent, width: 1.5)
              : BorderTokens.ghost(),
        ),
        child: Text(
          label.toUpperCase(),
          style: TypographyTokens.editorialFont(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? ColorTokens.clubAccent
                : ColorTokens.onSurfaceVariant,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}
