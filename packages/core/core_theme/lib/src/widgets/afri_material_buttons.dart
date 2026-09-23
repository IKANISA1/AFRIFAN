import 'package:flutter/material.dart';

import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/size_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

/// Shared text-style action for dialogs, compact rows, and inline commands.
class AfriTextButton extends StatelessWidget {
  const AfriTextButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: style?.merge(_textStyle()) ?? _textStyle(),
      child: child,
    );
  }

  static ButtonStyle styleFrom({
    Size? minimumSize,
    EdgeInsetsGeometry? padding,
    Color? foregroundColor,
    OutlinedBorder? shape,
  }) {
    return TextButton.styleFrom(
      minimumSize: minimumSize,
      padding: padding,
      foregroundColor: foregroundColor,
      shape: shape,
    );
  }

  static ButtonStyle _textStyle() {
    return TextButton.styleFrom(
      foregroundColor: ColorTokens.onSurface,
      disabledForegroundColor: ColorTokens.onSurfaceVariant,
      textStyle: TypographyTokens.labelLarge(),
      minimumSize: const Size(0, SizeTokens.touchTargetMin),
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing4,
        vertical: SpacingTokens.spacing3,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
      ),
    );
  }
}

/// Shared text-style icon action for compact command rows.
class AfriTextIconButton extends StatelessWidget {
  const AfriTextIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.style,
    this.focusNode,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final Widget label;
  final ButtonStyle? style;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: label,
      style:
          style?.merge(AfriTextButton._textStyle()) ??
          AfriTextButton._textStyle(),
      focusNode: focusNode,
    );
  }
}

/// Shared outline action for secondary commands and destructive confirmations.
class AfriOutlinedButton extends StatelessWidget {
  const AfriOutlinedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: style?.merge(_outlineStyle()) ?? _outlineStyle(),
      child: child,
    );
  }

  static ButtonStyle styleFrom({
    Size? minimumSize,
    EdgeInsetsGeometry? padding,
    Color? foregroundColor,
    BorderSide? side,
    OutlinedBorder? shape,
  }) {
    return OutlinedButton.styleFrom(
      minimumSize: minimumSize,
      padding: padding,
      foregroundColor: foregroundColor,
      side: side,
      shape: shape,
    );
  }

  static ButtonStyle _outlineStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: ColorTokens.onSurface,
      disabledForegroundColor: ColorTokens.onSurfaceVariant,
      side: BorderTokens.side(color: ColorTokens.chromeBorder),
      textStyle: TypographyTokens.labelLarge(),
      minimumSize: const Size(0, SizeTokens.touchTargetMin),
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing4,
        vertical: SpacingTokens.spacing3,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
      ),
    );
  }
}

/// Shared outline icon action for secondary commands.
class AfriOutlinedIconButton extends StatelessWidget {
  const AfriOutlinedIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.style,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final Widget label;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: label,
      style: AfriOutlinedButton._outlineStyle().merge(style),
    );
  }
}

/// Shared elevated action for compatibility with older feature flows.
class AfriElevatedButton extends StatelessWidget {
  const AfriElevatedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: _elevatedStyle().merge(style),
      child: child,
    );
  }

  static ButtonStyle styleFrom({
    Size? minimumSize,
    EdgeInsetsGeometry? padding,
    Color? backgroundColor,
    Color? foregroundColor,
    OutlinedBorder? shape,
  }) {
    return ElevatedButton.styleFrom(
      minimumSize: minimumSize,
      padding: padding,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      shape: shape,
    );
  }

  static ButtonStyle _elevatedStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: ColorTokens.onSurface,
      foregroundColor: ColorTokens.background,
      disabledBackgroundColor: ColorTokens.surfaceContainerHigh,
      disabledForegroundColor: ColorTokens.onSurfaceVariant,
      textStyle: TypographyTokens.labelLarge(),
      minimumSize: const Size(0, SizeTokens.touchTargetMin),
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing5,
        vertical: SpacingTokens.spacing3,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
      ),
      elevation: 0,
    );
  }
}
