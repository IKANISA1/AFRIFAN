import 'dart:ui';

import 'package:flutter/material.dart';

import '../tokens/blur_tokens.dart';
import '../tokens/color_tokens.dart';

/// Atmospheric app shell background with layered glows and depth.
class GradientBackground extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;

  const GradientBackground({super.key, required this.child, this.colors});

  @override
  Widget build(BuildContext context) {
    final gradientColors =
        colors ??
        [
          ColorTokens.surfaceDim,
          ColorTokens.background,
          ColorTokens.surfaceContainerHigh,
        ];

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
          ),
        ),
        const _GlowOrb(
          alignment: Alignment.topRight,
          color: Color(0x5AA98DFF),
          size: 280,
        ),
        const _GlowOrb(
          alignment: Alignment.bottomLeft,
          color: Color(0x2E7B5BFF),
          size: 340,
        ),
        child,
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.alignment,
    required this.color,
    required this.size,
  });

  final Alignment alignment;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Transform.translate(
          offset: Offset(
            alignment.x > 0 ? size * 0.18 : -size * 0.18,
            alignment.y > 0 ? size * 0.18 : -size * 0.18,
          ),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: AfriBlur.atmospheric,
              sigmaY: AfriBlur.atmospheric,
            ),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [color, color.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
