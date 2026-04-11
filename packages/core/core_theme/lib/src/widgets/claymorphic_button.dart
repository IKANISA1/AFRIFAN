import 'package:flutter/material.dart';

import '../tokens/border_tokens.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_press_feedback.dart';

/// Backward-compatible primary CTA with a cleaner minimalist treatment.
class ClaymorphicButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final IconData? icon;
  final bool isLoading;
  final double? width;
  final bool preserveCase;
  final double? letterSpacing;

  const ClaymorphicButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color,
    this.icon,
    this.isLoading = false,
    this.width,
    this.preserveCase = false,
    this.letterSpacing,
  });

  @override
  Widget build(BuildContext context) {
    final background = color ?? Theme.of(context).colorScheme.primary;
    final enabled = onPressed != null && !isLoading;

    return AfriPressFeedback(
      onTap: enabled ? onPressed : null,
      semanticsLabel: label,
      tooltip: label,
      excludeChildSemantics: true,
      scaleEnd: 0.985,
      builder: (context, state) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        width: width,
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing5,
          vertical: 16,
        ),
        decoration: BoxDecoration(
          color: enabled ? background : background.withValues(alpha: 0.45),
          borderRadius: ShapeTokens.buttonRadius,
          border: state.isFocused
              ? BorderTokens.focusAll(
                  color: Colors.white,
                  opacity: 0.9,
                  width: BorderTokens.standard,
                )
              : BorderTokens.ghost(width: BorderTokens.standard, opacity: 0.75),
          boxShadow: enabled ? AfriShadows.primaryGlow(background) : null,
        ),
        child: Row(
          mainAxisSize: width == null ? MainAxisSize.min : MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) ...[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing3),
            ] else if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: SpacingTokens.spacing2),
            ],
            Flexible(
              child: Text(
                preserveCase ? label : label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TypographyTokens.labelLarge(Colors.white).copyWith(
                  letterSpacing: letterSpacing ?? (preserveCase ? 0.2 : 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
