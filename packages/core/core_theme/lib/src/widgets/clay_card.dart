import 'package:flutter/material.dart';

import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/shape_tokens.dart';
import 'afri_press_feedback.dart';

/// Tactile clay surface with soft inner highlights and deep ambient depth.
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
        backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHigh;
    final effectiveRadius = borderRadius ?? ShapeTokens.cardRadius;

    Widget result;
    if (onTap != null) {
      result = Padding(
        padding: margin ?? EdgeInsets.zero,
        child: AfriPressFeedback(
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
            child: child,
          ),
        ),
      );
    } else {
      result = Padding(
        padding: margin ?? EdgeInsets.zero,
        child: _ClaySurface(
          color: effectiveColor,
          radius: effectiveRadius,
          width: width,
          height: height,
          padding: padding,
          child: child,
        ),
      );
    }

    if (semanticsLabel != null && onTap == null) {
      return Semantics(label: semanticsLabel, child: result);
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
  });

  final Color color;
  final BorderRadiusGeometry radius;
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final bool isPressed;

  @override
  Widget build(BuildContext context) {
    final highlight = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.06),
      color,
    );
    final lowlight = Color.alphaBlend(
      ColorTokens.primary.withValues(alpha: 0.12),
      color,
    );
    final clayShadow = AfriShadows.clay(pressed: isPressed);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [highlight, lowlight],
        ),
        border: BorderTokens.ghost(opacity: 0.10),
        boxShadow: [
          if (!isPressed) ...AfriShadows.standard(Brightness.dark),
          BoxShadow(
            color: clayShadow.topLeft.color,
            blurRadius: clayShadow.topLeft.blurRadius,
            spreadRadius: clayShadow.topLeft.spreadRadius,
            offset: clayShadow.topLeft.offset,
            blurStyle: BlurStyle.inner,
          ),
          BoxShadow(
            color: clayShadow.bottomRight.color,
            blurRadius: clayShadow.bottomRight.blurRadius,
            spreadRadius: clayShadow.bottomRight.spreadRadius,
            offset: clayShadow.bottomRight.offset,
            blurStyle: BlurStyle.inner,
          ),
        ],
      ),
      child: child,
    );
  }
}
