import 'package:flutter/material.dart';

import '../extensions.dart';
import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/motion_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/spacing_tokens.dart';
import 'afri_press_feedback.dart';

typedef AfriPanelCardBuilder =
    Widget Function(BuildContext context, AfriPressState state);

/// Dense universal panel surface for operational content.
class AfriPanelCard extends StatelessWidget {
  final Widget? child;
  final AfriPanelCardBuilder? builder;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? borderColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  const AfriPanelCard({
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
    final colors = context.afriSemanticColors;
    final highContrast = MediaQuery.highContrastOf(context);
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: AfriPressFeedback(
        onTap: onTap,
        semanticsLabel: semanticsLabel,
        builder: (context, state) => AnimatedContainer(
          duration: AfriMotion.surfaceResponse,
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(SpacingTokens.cardPadding),
          decoration: BoxDecoration(
            color: backgroundColor ?? colors.cardSurface,
            borderRadius: ShapeTokens.cardRadius,
            border: state.isFocused || highContrast || borderColor != null
                ? BorderTokens.all(
                    color: state.isFocused
                        ? (highContrast
                              ? colors.primaryText
                              : ColorTokens.primaryContainer)
                        : (borderColor ??
                              (highContrast
                                  ? colors.border
                                  : ColorTokens.ghostBorder)),
                    width: highContrast
                        ? BorderTokens.strong
                        : BorderTokens.standard,
                  )
                : null,
          ),
          child: builder != null ? builder!(context, state) : child!,
        ),
      ),
    );
  }
}
