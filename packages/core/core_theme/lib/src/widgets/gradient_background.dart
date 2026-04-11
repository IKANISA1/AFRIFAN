import 'dart:ui';

import 'package:flutter/material.dart';

import '../tokens/blur_tokens.dart';
import '../tokens/color_tokens.dart';

/// Calm app shell background with a restrained vertical gradient.
class GradientBackground extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;

  const GradientBackground({super.key, required this.child, this.colors});

  @override
  Widget build(BuildContext context) {
    final gradientColors =
        colors ??
        [
          ColorTokens.background,
          ColorTokens.surfaceContainerLowest,
          ColorTokens.surfaceContainerLow,
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
          alignment: Alignment.topCenter,
          color: Color(0x180D63F3),
          size: 220,
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
            alignment.x > 0 ? size * 0.10 : -size * 0.10,
            alignment.y > 0 ? size * 0.10 : -size * 0.10,
          ),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: AfriBlur.standard,
              sigmaY: AfriBlur.standard,
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
