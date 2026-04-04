import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/shape_tokens.dart';
import 'afri_press_feedback.dart';

/// A card with a claymorphic aesthetic.
/// Applies inner shadows to create a tactical feeling of depth.
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

  /// The inner contents of the card.
  final Widget child;

  /// Background color of the card. Defaults to ColorTokens.surface.
  final Color? backgroundColor;

  /// Optional press handler. If provided, the card uses AfriPressFeedback
  /// to scale down and invert its shadows on press.
  final VoidCallback? onTap;

  /// Padding around the child.
  final EdgeInsetsGeometry? padding;

  /// Outer margin.
  final EdgeInsetsGeometry? margin;

  /// Corner radius. Defaults to ShapeTokens.radiusExtraLarge.
  final BorderRadiusGeometry? borderRadius;

  final double? width;
  final double? height;

  /// Optional accessibility label. When provided, wraps the card in a
  /// [Semantics] widget so screen readers announce meaningful context
  /// instead of reading raw child content.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        backgroundColor ?? Theme.of(context).colorScheme.surface;
    final effectiveRadius = borderRadius ?? ShapeTokens.cardRadius;

    Widget result;
    if (onTap != null) {
      result = Padding(
        padding: margin ?? EdgeInsets.zero,
        child: AfriPressFeedback(
          onTap: onTap,
          builder: (context, state) => _buildCard(
            effectiveColor,
            effectiveRadius,
            isPressed: state.isPressed,
          ),
        ),
      );
    } else {
      result = Padding(
        padding: margin ?? EdgeInsets.zero,
        child: _buildCard(effectiveColor, effectiveRadius, isPressed: false),
      );
    }

    if (semanticsLabel != null) {
      return Semantics(
        label: semanticsLabel,
        button: onTap != null,
        child: result,
      );
    }

    return result;
  }

  Widget _buildCard(
    Color color,
    BorderRadiusGeometry radius, {
    required bool isPressed,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        boxShadow: isPressed
            ? [
                BoxShadow(
                  color: ColorTokens.background.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(-2, -2),
                  blurStyle: BlurStyle.inner,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(4, 4),
                  blurStyle: BlurStyle.inner,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(-2, -2),
                  blurStyle: BlurStyle.inner,
                ),
                BoxShadow(
                  color: ColorTokens.background.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(4, 4),
                  blurStyle: BlurStyle.inner,
                ),
              ],
      ),
      child: child,
    );
  }
}
