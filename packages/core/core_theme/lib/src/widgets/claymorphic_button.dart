import 'package:flutter/material.dart';

import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_press_feedback.dart';

/// Primary tactile CTA with a glowing violet clay finish.
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
    final fromColor = color ?? Theme.of(context).colorScheme.primary;
    final toColor = Color.alphaBlend(
      ColorTokens.primaryContainer.withValues(alpha: 0.82),
      fromColor,
    );
    final horizontalPadding = width == null ? 40.0 : 28.0;

    return AfriPressFeedback(
      onTap: onPressed,
      semanticsLabel: label,
      tooltip: label,
      excludeChildSemantics: true,
      scaleEnd: 0.985,
      builder: (context, state) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        width: width,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 18,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [fromColor, toColor],
          ),
          borderRadius: ShapeTokens.buttonRadius,
          border: state.isFocused
              ? BorderTokens.focusAll(
                  color: ColorTokens.onSurface,
                  opacity: 0.75,
                  width: BorderTokens.standard,
                )
              : BorderTokens.ghost(opacity: 0.08),
          boxShadow: [
            ...AfriShadows.primaryGlow(toColor),
            BoxShadow(
              color: Colors.white.withValues(
                alpha: state.isPressed ? 0.08 : 0.16,
              ),
              blurRadius: 18,
              spreadRadius: -14,
              offset: const Offset(-8, -10),
              blurStyle: BlurStyle.inner,
            ),
            BoxShadow(
              color: ColorTokens.ambientShadow.withValues(
                alpha: state.isPressed ? 0.20 : 0.30,
              ),
              blurRadius: 24,
              spreadRadius: -16,
              offset: const Offset(12, 16),
              blurStyle: BlurStyle.inner,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: width == null ? MainAxisSize.min : MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) ...[
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ] else if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Text(
                preserveCase ? label : label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TypographyTokens.labelLarge().copyWith(
                  color: Colors.white,
                  letterSpacing: letterSpacing ?? (preserveCase ? 0.8 : 1.6),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
