import 'dart:ui';

import 'package:flutter/material.dart';

import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/typography_tokens.dart';

/// Numeric alias badge — the "Anonymous Identity" system.
///
/// "Never design for names. All layouts optimized for 6-digit numeric ."
/// - Monospaced-style tracking for the 6-digit numbers
/// - Glassmorphic pill container with sm radius
/// - Treated with same typographic weight as primary headlines
class NumericAlias extends StatelessWidget {
  final String alias;
  final double fontSize;
  final Color? color;
  final bool showBadge;

  const NumericAlias({
    super.key,
    required this.alias,
    this.fontSize = 20,
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
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
