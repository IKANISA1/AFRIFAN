import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../tokens/blur_tokens.dart';
import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/spacing_tokens.dart';
import 'afri_press_feedback.dart';

/// Floating glass surface with heavy blur and a low-opacity ghost border.
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

    if (animate) {
      final mediaQuery = MediaQuery.maybeOf(context);
      final reduceMotion =
          mediaQuery?.disableAnimations == true ||
          mediaQuery?.accessibleNavigation == true;

      if (!reduceMotion) {
        return card
            .animate()
            .fadeIn(duration: 420.ms, curve: Curves.easeOut)
            .slideY(
              begin: 0.04,
              end: 0,
              duration: 420.ms,
              curve: Curves.easeOut,
            );
      }
    }

    return card;
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
          sigmaX: AfriBlur.overlay,
          sigmaY: AfriBlur.overlay,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(SpacingTokens.spacing6),
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ColorTokens.surfaceBright.withValues(alpha: 0.64),
                ColorTokens.surfaceVariant.withValues(alpha: 0.42),
              ],
            ),
            border: isFocused
                ? BorderTokens.focusAll(
                    color: ColorTokens.primaryContainer,
                    opacity: 0.45,
                    width: BorderTokens.standard,
                  )
                : BorderTokens.all(color: effectiveBorderColor),
            boxShadow: [
              ...AfriShadows.glass(strength: isPressed ? 0.65 : 1.0),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.10),
                blurRadius: 24,
                spreadRadius: -18,
                offset: const Offset(-6, -10),
                blurStyle: BlurStyle.inner,
              ),
              BoxShadow(
                color: ColorTokens.ambientShadow.withValues(alpha: 0.28),
                blurRadius: 30,
                spreadRadius: -18,
                offset: const Offset(10, 14),
                blurStyle: BlurStyle.inner,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
