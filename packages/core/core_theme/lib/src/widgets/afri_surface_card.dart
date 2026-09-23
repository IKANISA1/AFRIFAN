import 'package:flutter/material.dart';

import '../extensions.dart';
import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/motion_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/spacing_tokens.dart';
import 'afri_press_feedback.dart';

/// Primary **interactive** card surface — tappable tiles, action shortcuts,
/// navigation cards, and any surface where the user is expected to tap.
///
/// For **content containers** (read-only grouped info, transaction rows,
/// stat displays), prefer [GlassCard].
class AfriSurfaceCard extends StatelessWidget {
  const AfriSurfaceCard({
    required this.child,
    this.backgroundColor,
    this.onTap,
    this.padding,
    this.margin,
    this.borderRadius,
    this.width,
    this.height,
    this.semanticsLabel,
    this.semanticsHint,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
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
  final String? semanticsHint;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        backgroundColor ?? context.afriSemanticColors.cardSurface;
    final effectiveRadius = borderRadius ?? ShapeTokens.cardRadius;

    final surface = Opacity(
      opacity: enabled ? 1 : 0.48,
      child: _AfriSurface(
        color: effectiveColor,
        radius: effectiveRadius,
        width: width,
        height: height,
        padding: padding,
        child: child,
      ),
    );

    Widget result = Padding(
      padding: margin ?? EdgeInsets.zero,
      child: onTap == null
          ? surface
          : AfriPressFeedback(
              enabled: enabled,
              onTap: onTap,
              autofocus: autofocus,
              focusNode: focusNode,
              semanticsLabel: semanticsLabel,
              semanticsHint: semanticsHint,
              tooltip: semanticsLabel,
              excludeChildSemantics: semanticsLabel != null,
              builder: (context, state) => Opacity(
                opacity: enabled ? 1 : 0.48,
                child: _AfriSurface(
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
            ),
    );

    if (semanticsLabel != null && onTap == null) {
      result = Semantics(
        label: semanticsLabel,
        enabled: enabled,
        child: result,
      );
    }
    return result;
  }
}

class _AfriSurface extends StatelessWidget {
  const _AfriSurface({
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
    final colors = context.afriSemanticColors;
    final highContrast = MediaQuery.highContrastOf(context);
    return AnimatedContainer(
      duration: AfriMotion.quick,
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(SpacingTokens.cardPadding),
      decoration: BoxDecoration(
        color: isPressed
            ? Color.alphaBlend(
                colors.primaryText.withValues(alpha: 0.06),
                color,
              )
            : color,
        borderRadius: radius,
        border: isFocused
            ? BorderTokens.focusAll(
                color: highContrast
                    ? colors.primaryText
                    : ColorTokens.primaryContainer,
                opacity: highContrast ? 1 : 0.9,
                width: context.afriDesignTokens.focusRingWidth,
              )
            : highContrast
            ? BorderTokens.all(color: colors.border, width: BorderTokens.strong)
            : null,
      ),
      child: child,
    );
  }
}
