import 'package:flutter/material.dart';

import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/spacing_tokens.dart';

/// Shared universal separator for quiet in-card and route boundaries.
class AfriDivider extends StatelessWidget {
  const AfriDivider({
    super.key,
    this.height = BorderTokens.standard,
    this.thickness = BorderTokens.hairline,
    this.indent = SpacingTokens.spacing0,
    this.endIndent = SpacingTokens.spacing0,
    this.color,
  });

  final double height;
  final double thickness;
  final double indent;
  final double endIndent;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: height,
      thickness: thickness,
      indent: indent,
      endIndent: endIndent,
      color: color ?? ColorTokens.ghostBorder,
    );
  }
}
