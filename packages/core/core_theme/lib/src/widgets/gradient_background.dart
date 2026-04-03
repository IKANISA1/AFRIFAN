import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';

/// Hero gradient background — the "Signature Texture".
///
/// "Use linear gradients for hero backgrounds transitioning from
/// #0A0F2C (Deep Navy) to #C8102E (Club Red) at a 135-degree angle
/// to simulate movement."
class GradientBackground extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;

  const GradientBackground({super.key, required this.child, this.colors});

  @override
  Widget build(BuildContext context) {
    final gradientColors =
        colors ?? [ColorTokens.background, ColorTokens.surfaceContainerHighest];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: child,
    );
  }
}
