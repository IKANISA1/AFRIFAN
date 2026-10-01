import 'dart:ui';

import 'package:flutter/material.dart';

import '../tokens/blur_tokens.dart';
import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/component_size_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

/// Supporter numeric alias rendered with the selected Revolut control roles.
///
/// The existing six-digit product identity keeps its own content and formatting;
/// typography, tonal pill surface and spacing come from shared semantic tokens.
class NumericAlias extends StatelessWidget {
  final String alias;
  final double fontSize;
  final Color? color;
  final bool showBadge;

  const NumericAlias({
    super.key,
    required this.alias,
    this.fontSize = TypographyTokens.numericAliasDefaultSize,
    this.color,
    this.showBadge = true,
  });

  /// Format alias with hash prefix: 492031 → #492031
  String get formattedAlias {
    return '#$alias';
  }

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      formattedAlias,
      style: TypographyTokens.numericAlias(fontSize: fontSize, color: color),
    );

    if (!showBadge) return textWidget;

    return ClipRRect(
      borderRadius: ShapeTokens.aliasPillRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AfriBlur.subtle,
          sigmaY: AfriBlur.subtle,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing3,
            vertical: AfriComponentSizes.compactVerticalPadding,
          ),
          decoration: BoxDecoration(
            color: ColorTokens.glassFill,
            borderRadius: ShapeTokens.aliasPillRadius,
            border: BorderTokens.ghost(),
          ),
          child: textWidget,
        ),
      ),
    );
  }
}
