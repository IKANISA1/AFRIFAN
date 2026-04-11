import 'package:flutter/material.dart';

import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/spacing_tokens.dart';
import 'afri_press_feedback.dart';

/// Primary neutral card surface used across the app.
class ClayCard extends StatelessWidget {
  const ClayCard({
    required this.child,
    this.backgroundColor,
    this.onTap,
    this.padding,
    this.margin,
    this.borderRadius,
    this.width,
    this.height,
    this.semanticsLabel,
    super.key,
  });

  final Widget child;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadiusGeometry? borderRadius;
  final double? width;
  final double? height;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerLow;
    final effectiveRadius = borderRadius ?? ShapeTokens.cardRadius;

    final surface = _ClaySurface(
      color: effectiveColor,
      radius: effectiveRadius,
      width: width,
      height: height,
      padding: padding,
      child: child,
    );

    Widget result = Padding(
      padding: margin ?? EdgeInsets.zero,
      child: onTap == null
          ? surface
          : AfriPressFeedback(
              onTap: onTap,
              semanticsLabel: semanticsLabel,
              tooltip: semanticsLabel,
              excludeChildSemantics: semanticsLabel != null,
              builder: (context, state) => _ClaySurface(
                color: effectiveColor,
                radius: effectiveRadius,
                width: width,
                height: height,
                padding: padding,
                isPressed: state.isPressed,
                isFocused: state.isFocused,
                child: child,
              ),
            ),
    );

    if (semanticsLabel != null && onTap == null) {
      result = Semantics(label: semanticsLabel, child: result);
    }
    return result;
  }
}

class _ClaySurface extends StatelessWidget {
  const _ClaySurface({
    required this.color,
    required this.radius,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.isPressed = false,
    this.isFocused = false,
  });

  final Color color;
  final BorderRadiusGeometry radius;
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final bool isPressed;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(SpacingTokens.spacing5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: isFocused
            ? BorderTokens.focusAll(
                color: ColorTokens.primaryContainer,
                opacity: 0.9,
              )
            : BorderTokens.ghost(width: BorderTokens.standard),
        boxShadow: [
          ...AfriShadows.standard(Brightness.dark),
          if (isPressed)
            BoxShadow(
              color: ColorTokens.ambientShadow.withValues(alpha: 0.16),
              blurRadius: 10,
              spreadRadius: -8,
              offset: const Offset(0, 4),
              blurStyle: BlurStyle.inner,
            ),
        ],
      ),
      child: child,
    );
  }
}
