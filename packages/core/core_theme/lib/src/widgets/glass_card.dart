import 'package:flutter/material.dart';

import '../extensions.dart';
import '../tokens/border_tokens.dart';
import '../tokens/motion_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/spacing_tokens.dart';
import 'afri_press_feedback.dart';

/// Elevated surface used for **content containers** — read-only grouped
/// information, transaction rows, fixture rows, stat displays, and any
/// surface where the primary interaction is reading, not tapping.
///
/// For **interactive surfaces** (tappable tiles, action shortcuts, navigation
/// cards), prefer [AfriSurfaceCard].
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? borderColor;
  final VoidCallback? onTap;
  final bool animate;
  final String? semanticsLabel;
  final FocusNode? focusNode;

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
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Padding(
      padding: margin ?? EdgeInsets.zero,
      child: onTap == null
          ? _GlassSurface(
              width: width,
              height: height,
              padding: padding,
              borderColor: borderColor,
              child: child,
            )
          : AfriPressFeedback(
              onTap: onTap,
              focusNode: focusNode,
              semanticsLabel: semanticsLabel,
              tooltip: semanticsLabel,
              excludeChildSemantics: semanticsLabel != null,
              builder: (context, state) => _GlassSurface(
                width: width,
                height: height,
                padding: padding,
                borderColor: borderColor,
                isPressed: state.isPressed,
                isFocused: state.isFocused,
                child: child,
              ),
            ),
    );

    if (semanticsLabel != null && onTap == null) {
      card = Semantics(label: semanticsLabel, child: card);
    }

    if (!animate) {
      return card;
    }

    final mediaQuery = MediaQuery.maybeOf(context);
    final reduceMotion =
        mediaQuery?.disableAnimations == true ||
        mediaQuery?.accessibleNavigation == true;
    if (reduceMotion) {
      return card;
    }

    // A widget-owned ticker cancels with the surface. Delayed animation
    // restarts can otherwise survive a route or async-state replacement.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AfriMotion.surfaceEntrance,
      curve: Curves.easeOut,
      child: card,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: FractionalTranslation(
          translation: Offset(0, 0.02 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

class _GlassSurface extends StatelessWidget {
  const _GlassSurface({
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.borderColor,
    this.isPressed = false,
    this.isFocused = false,
  });

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final bool isPressed;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    final radius = ShapeTokens.cardRadius;
    final colors = context.afriSemanticColors;
    final highContrast = MediaQuery.highContrastOf(context);
    return AnimatedContainer(
      duration: AfriMotion.resolve(context, AfriMotion.surfaceResponse),
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(SpacingTokens.cardPadding),
      decoration: BoxDecoration(
        color: isPressed ? colors.cardSurfaceStrong : colors.cardSurface,
        borderRadius: radius,
        border: isFocused
            ? BorderTokens.focusAll(
                color: colors.primaryText,
                width: context.afriDesignTokens.focusRingWidth,
              )
            : highContrast || borderColor != null
            ? BorderTokens.all(
                color: borderColor ?? colors.border,
                width: highContrast
                    ? BorderTokens.strong
                    : BorderTokens.standard,
              )
            : null,
      ),
      child: child,
    );
  }
}
