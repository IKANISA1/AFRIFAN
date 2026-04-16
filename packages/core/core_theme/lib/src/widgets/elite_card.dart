import 'package:flutter/material.dart';
import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/spacing_tokens.dart';
import 'afri_press_feedback.dart';

typedef EliteCardBuilder = Widget Function(BuildContext context, AfriPressState state);

/// A world-class operational card surface.
/// High density, sharp edges, and high contrast.
class EliteCard extends StatelessWidget {
  final Widget? child;
  final EliteCardBuilder? builder;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? borderColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  const EliteCard({
    super.key,
    this.child,
    this.builder,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderColor,
    this.backgroundColor,
    this.onTap,
    this.semanticsLabel,
  }) : assert(child != null || builder != null);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: AfriPressFeedback(
        onTap: onTap,
        semanticsLabel: semanticsLabel,
        builder: (context, state) => AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(SpacingTokens.spacing5),
          decoration: BoxDecoration(
            color: backgroundColor ?? ColorTokens.surface,
            borderRadius: ShapeTokens.cardRadius,
            border: BorderTokens.all(
              color: state.isFocused 
                  ? ColorTokens.clubAccent 
                  : (borderColor ?? ColorTokens.ghostBorder),
              width: BorderTokens.standard,
            ),
          ),
          child: builder != null ? builder!(context, state) : child!,
        ),
      ),
    );
  }
}
