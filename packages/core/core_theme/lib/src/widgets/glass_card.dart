
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../tokens/spacing_tokens.dart';
import 'clay_card.dart';

/// A glassmorphic card following the ROUGEBLACK Glass Mandate.
///
/// - BackdropFilter blur: 12px
/// - Fill: white at 0.06 opacity
/// - Border: "Ghost Border" — white at 0.15 opacity
/// - Corner radius: xl (20px / 1.5rem)
/// - No internal divider lines
/// - Ambient shadow: rgba(7,11,40,0.8) with 40px blur
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? borderColor;
  final VoidCallback? onTap;
  final bool animate;

  /// Optional accessibility label forwarded to the underlying [ClayCard].
  final String? semanticsLabel;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderColor,
    this.onTap,
    this.animate = true,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final Widget card = ClayCard(
      width: width,
      height: height,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(SpacingTokens.spacing6),
      onTap: onTap,
      semanticsLabel: semanticsLabel,
      child: child,
    );

    if (animate) {
      final mediaQuery = MediaQuery.maybeOf(context);
      final reduceMotion =
          mediaQuery?.disableAnimations == true ||
          mediaQuery?.accessibleNavigation == true;

      if (!reduceMotion) {
        return card
            .animate()
            .fadeIn(duration: 400.ms, curve: Curves.easeOut)
            .slideY(begin: 0.05, end: 0, duration: 400.ms, curve: Curves.easeOut);
      }
    }

    return card;
  }
}
