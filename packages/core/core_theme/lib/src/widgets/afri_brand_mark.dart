import 'package:flutter/material.dart';

import '../extensions.dart';
import '../runtime_branding.dart';
import '../tokens/border_tokens.dart';
import '../tokens/chrome_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/typography_tokens.dart';

/// Club initials on a native tonal surface; actual logo assets remain unchanged.
class AfriBrandMark extends StatelessWidget {
  const AfriBrandMark({
    super.key,
    this.label,
    this.size = AfriChromeTokens.commandControlSize,
    this.borderRadius,
    this.semanticLabel,
    this.showBorder = true,
  });

  final String? label;
  final double size;
  final BorderRadiusGeometry? borderRadius;
  final String? semanticLabel;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;
    final initials =
        (label?.trim().isNotEmpty == true
                ? _initialsFor(label!)
                : RuntimeBranding.appInitials)
            .trim();
    final resolvedLabel = initials.isEmpty ? 'AC' : initials;

    return Semantics(
      label: semanticLabel ?? '${RuntimeBranding.displayAppName} brand mark',
      image: true,
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.cardSurfaceStrong,
            borderRadius: borderRadius ?? ShapeTokens.chipRadius,
            border: showBorder
                ? BorderTokens.all(color: ColorTokens.chromeBorder)
                : null,
          ),
          child: Text(
            resolvedLabel,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TypographyTokens.labelLarge(
              colors.primaryText,
            ).copyWith(fontSize: (size * 0.28).clamp(13, 34).toDouble()),
          ),
        ),
      ),
    );
  }

  static String _initialsFor(String value) {
    final parts = value
        .split(RegExp(r'\s+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      final token = parts.first;
      return token.length >= 2
          ? token.substring(0, 2).toUpperCase()
          : token.toUpperCase();
    }
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
}
