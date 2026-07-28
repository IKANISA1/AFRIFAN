import 'package:flutter/material.dart';

import '../runtime_branding.dart';
import '../tokens/border_tokens.dart';
import '../tokens/chrome_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/typography_tokens.dart';

/// Token-driven brand mark generated from runtime club identity.
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
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ColorTokens.clubPrimary.withValues(alpha: 0.98),
                ColorTokens.referencePaymentsPurpleDeep.withValues(alpha: 0.98),
              ],
            ),
            borderRadius: borderRadius ?? ShapeTokens.chipRadius,
            border: showBorder
                ? BorderTokens.all(color: ColorTokens.chromeBorder)
                : null,
            boxShadow: AfriShadows.brandMark(size),
          ),
          child: Text(
            resolvedLabel,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TypographyTokens.labelLarge(
              ColorTokens.chromeForeground,
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
