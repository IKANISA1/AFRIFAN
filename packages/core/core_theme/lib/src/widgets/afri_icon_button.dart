import 'package:flutter/material.dart';

import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/spacing_tokens.dart';
import 'afri_press_feedback.dart';

/// Shared compact icon button for app bars, cards, and toolbars.
class AfriIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool filled;

  const AfriIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      onTap: onTap,
      tooltip: tooltip,
      builder: (context, state) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? ColorTokens.surfaceContainerLow : Colors.transparent,
          borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
          border: state.isFocused
              ? BorderTokens.focusAll(
                  color: ColorTokens.primaryContainer,
                  opacity: 0.9,
                )
              : BorderTokens.ghost(width: BorderTokens.standard),
        ),
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing2),
          child: Icon(
            icon,
            size: 20,
            color: onTap == null
                ? ColorTokens.onSurfaceVariant
                : ColorTokens.onSurface,
          ),
        ),
      ),
    );
  }
}
