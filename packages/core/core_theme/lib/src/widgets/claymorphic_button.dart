import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../tokens/color_tokens.dart';
import '../tokens/shape_tokens.dart';
import 'afri_press_feedback.dart';

/// A claymorphic button with dual inner shadows for tactile depth.
///
/// "Buttons must feel like physical objects"
/// - Top-left inner shadow: white at 20% opacity, 2px blur, offset 2px
/// - Bottom-right inner shadow: black at 30% opacity, 4px blur, offset 4px
/// - On press: shadows invert to simulate "press-in"
/// - Only ONE primary button per view (Radical Minimalism)
class ClaymorphicButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final IconData? icon;
  final bool isLoading;
  final double? width;

  const ClaymorphicButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color,
    this.icon,
    this.isLoading = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? Theme.of(context).colorScheme.primary;

    return AfriPressFeedback(
      onTap: onPressed,
      semanticsLabel: label,
      tooltip: label,
      excludeChildSemantics: true,
      scaleEnd: 0.98,
      builder: (context, state) => AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: ShapeTokens.buttonRadius,
          border: state.isFocused
              ? Border.all(
                  color: ColorTokens.onSurface.withValues(alpha: 0.8),
                  width: 1.1,
                )
              : null,
          boxShadow: state.isPressed
              ? [
                  // Pressed state: shadows invert
                  BoxShadow(
                    color: ColorTokens.background.withValues(alpha: 0.3),
                    blurRadius: 2,
                    offset: const Offset(-2, -2),
                    blurStyle: BlurStyle.inner,
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(4, 4),
                    blurStyle: BlurStyle.inner,
                  ),
                ]
              : [
                  // Default: top-left light, bottom-right dark
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.2),
                    blurRadius: 2,
                    offset: const Offset(-2, -2),
                    blurStyle: BlurStyle.inner,
                  ),
                  BoxShadow(
                    color: ColorTokens.background.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(4, 4),
                    blurStyle: BlurStyle.inner,
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) ...[
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ] else if (icon != null) ...[
              Icon(icon, color: ColorTokens.onSurface, size: 20),
              const SizedBox(width: 12),
            ],
            Text(
              label.toUpperCase(),
              style: GoogleFonts.barlowCondensed(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ColorTokens.onSurface,
                letterSpacing: 4.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
