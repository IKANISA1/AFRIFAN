import 'package:flutter/material.dart';

import '../extensions.dart';
import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/motion_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/size_tokens.dart';
import '../tokens/spacing_tokens.dart';
import 'afri_loading_indicator.dart';
import 'afri_press_feedback.dart';

/// Shared compact icon button for app bars, cards, and toolbars.
class AfriIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool filled;
  final bool isLoading;

  const AfriIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.filled = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      onTap: isLoading ? null : onTap,
      tooltip: tooltip,
      semanticsLabel: tooltip,
      excludeChildSemantics: tooltip != null,
      builder: (context, state) => AnimatedContainer(
        duration: AfriMotion.surfaceResponse,
        width: SizeTokens.touchTargetMin,
        height: SizeTokens.touchTargetMin,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? ColorTokens.surfaceContainerLow : Colors.transparent,
          borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
          border: state.isFocused
              ? BorderTokens.focusAll(
                  color: ColorTokens.primaryContainer,
                  opacity: 0.9,
                  width: context.afriDesignTokens.focusRingWidth,
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing2),
          child: isLoading
              ? const AfriLoadingIndicator(size: SizeTokens.iconMd)
              : Icon(
                  icon,
                  size: SizeTokens.iconMd,
                  color: onTap == null
                      ? ColorTokens.onSurfaceVariant
                      : ColorTokens.onSurface,
                ),
        ),
      ),
    );
  }
}
