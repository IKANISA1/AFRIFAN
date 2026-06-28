import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
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
        .fadeIn(duration: 220.ms, curve: Curves.easeOut)
        .slideY(begin: 0.02, end: 0, duration: 220.ms, curve: Curves.easeOut);
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
          duration: const Duration(milliseconds: 140),
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
                  )
                : BorderTokens.all(
                    color: effectiveBorderColor,
                    width: BorderTokens.standard,
                  ),
            boxShadow: [
              ...AfriShadows.glass(strength: isPressed ? 0.65 : 1.0),
              if (isFocused)
                BoxShadow(
                  color: ColorTokens.primaryContainer.withValues(alpha: 0.18),
                  blurRadius: 18,
                  spreadRadius: -8,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
