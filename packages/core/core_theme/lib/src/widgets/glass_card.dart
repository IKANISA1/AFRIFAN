import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../extensions.dart';
import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/motion_tokens.dart';
import '../tokens/shadow_tokens.dart';
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

    return card
        .animate()
        .fadeIn(duration: AfriMotion.surfaceEntrance, curve: Curves.easeOut)
        .slideY(
          begin: 0.02,
          end: 0,
          duration: AfriMotion.surfaceEntrance,
          curve: Curves.easeOut,
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
    final effectiveBorderColor = borderColor ?? ColorTokens.ghostBorder;

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: ColorTokens.glassBlurSigma,
          sigmaY: ColorTokens.glassBlurSigma,
        ),
        child: AnimatedContainer(
          duration: AfriMotion.resolve(context, AfriMotion.surfaceResponse),
          curve: Curves.easeOutCubic,
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(SpacingTokens.spacing5),
          decoration: BoxDecoration(
            color: ColorTokens.glassFill,
            borderRadius: radius,
            border: isFocused
                ? BorderTokens.focusAll(
                    color: ColorTokens.primaryContainer,
                    opacity: 0.9,
                    width: context.afriDesignTokens.focusRingWidth,
                  )
                : BorderTokens.all(
                    color: effectiveBorderColor,
                    width: BorderTokens.standard,
                  ),
            boxShadow: [
              ...AfriShadows.glass(
                Theme.of(context).brightness,
                strength: isPressed ? 0.65 : 1.0,
              ),
              if (isFocused)
                AfriShadows.focusGlow(ColorTokens.primaryContainer),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
