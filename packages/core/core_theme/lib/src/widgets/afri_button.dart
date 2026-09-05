import 'package:flutter/material.dart';

import '../extensions.dart';
import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/component_size_tokens.dart';
import '../tokens/motion_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/size_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_press_feedback.dart';

/// Button variant enumeration for AFRICLUB UI primitives.
enum AfriButtonVariant {
  primary,
  secondary,
  outline,
  ghost,
  accent,
  destructive,
}

/// Shared button component with a small, consistent set of emphasis levels.
class AfriButton extends StatefulWidget {
  const AfriButton({
    required this.label,
    required this.onTap,
    this.variant = AfriButtonVariant.primary,
    this.icon,
    this.semanticsLabel,
    this.isLoading = false,
    this.fullWidth = true,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.labelMaxLines = 1,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final AfriButtonVariant variant;
  final IconData? icon;
  final String? semanticsLabel;
  final bool isLoading;
  final bool fullWidth;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final int labelMaxLines;

  @override
  State<AfriButton> createState() => _AfriButtonState();
}

class _AfriButtonState extends State<AfriButton> {
  bool get _isActive => widget.enabled && !widget.isLoading;

  void _onTap() {
    if (!_isActive) return;
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;
    late Color background;
    late Color foreground;
    Border? border;

    switch (widget.variant) {
      case AfriButtonVariant.primary:
        background = colors.buttonPrimaryBackground;
        foreground = colors.buttonPrimaryForeground;
      case AfriButtonVariant.secondary:
        background = colors.cardSurfaceStrong;
        foreground = colors.primaryText;
      case AfriButtonVariant.outline:
        background = Colors.transparent;
        foreground = colors.primaryText;
        border = BorderTokens.all(
          color: colors.borderStrong,
          width: BorderTokens.standard,
        );
      case AfriButtonVariant.ghost:
        background = Colors.transparent;
        foreground = colors.secondaryText;
      case AfriButtonVariant.accent:
        background = colors.accent;
        foreground = ColorTokens.contrastForeground(colors.accent);
      case AfriButtonVariant.destructive:
        background = colors.danger;
        foreground = ColorTokens.contrastForeground(colors.danger);
    }

    if (!_isActive) {
      if (widget.variant == AfriButtonVariant.primary ||
          widget.variant == AfriButtonVariant.accent ||
          widget.variant == AfriButtonVariant.destructive) {
        background = colors.cardSurfaceStrong;
      }
      foreground = ColorTokens.accessibleDisabledColor(colors.secondaryText);
      border = BorderTokens.all(
        color: ColorTokens.accessibleChartColor(colors.borderStrong),
        width: BorderTokens.standard,
      );
    }

    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (widget.isLoading) ...[
          SizedBox(
            width: SizeTokens.iconSm,
            height: SizeTokens.iconSm,
            child: CircularProgressIndicator(
              strokeWidth: AfriComponentSizes.progressStroke,
              valueColor: AlwaysStoppedAnimation(foreground),
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, size: SizeTokens.iconSm, color: foreground),
          const SizedBox(width: SpacingTokens.spacing2),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: widget.labelMaxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TypographyTokens.labelLarge(foreground),
          ),
        ),
      ],
    );

    return AfriPressFeedback(
      onTap: _onTap,
      enabled: _isActive,
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      semanticsLabel: widget.semanticsLabel ?? widget.label,
      excludeChildSemantics: true,
      scaleEnd: AfriMotion.buttonPressScale,
      builder: (context, state) => AnimatedContainer(
        duration: AfriMotion.resolve(context, AfriMotion.quick),
        curve: AfriMotion.enterCurve,
        constraints: const BoxConstraints(
          minHeight: AfriComponentSizes.buttonHeight,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing5,
          vertical: AfriComponentSizes.buttonVerticalPadding,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
          border: state.isFocused
              ? BorderTokens.focusAll(
                  // The action fill can itself be the accent color. The
                  // theme's primary text role stays high-contrast against
                  // both the page canvas and action fills in light and dark
                  // modes, so keyboard focus remains visibly non-color-only.
                  color: colors.primaryText,
                  width: context.afriDesignTokens.focusRingWidth,
                )
              : border,
        ),
        child: content,
      ),
    );
  }
}
