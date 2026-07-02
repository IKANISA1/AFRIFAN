import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';

/// Full-screen route background using universal premium mobile gradient families.
class GradientBackground extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;
  final String? routePath;

  const GradientBackground({
    super.key,
    required this.child,
    this.colors,
    this.routePath,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = colors == null
        ? ColorTokens.screenGradientForPath(routePath)
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors!,
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.02),
                Colors.black.withValues(alpha: 0.18),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
