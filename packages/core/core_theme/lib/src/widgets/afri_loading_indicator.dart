import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/component_size_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/size_tokens.dart';

/// Minimalist loading indicator aligned with the monolith aesthetic.
class AfriLoadingIndicator extends StatelessWidget {
  const AfriLoadingIndicator({
    this.size = SizeTokens.loadingIndicator,
    this.color,
    this.value,
    this.strokeWidth = AfriComponentSizes.progressStroke,
    super.key,
  });

  final double size;
  final Color? color;
  final double? value;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          value: value,
          strokeWidth: strokeWidth,
          valueColor: AlwaysStoppedAnimation<Color>(
            color ?? ColorTokens.primaryContainer,
          ),
        ),
      ),
    );
  }
}

/// Shared universal linear progress indicator.
class AfriLinearProgressIndicator extends StatelessWidget {
  const AfriLinearProgressIndicator({
    super.key,
    this.value,
    this.minHeight = SizeTokens.linearIndicatorHeight,
    this.color,
    this.backgroundColor,
    this.borderRadius,
  });

  final double? value;
  final double minHeight;
  final Color? color;
  final Color? backgroundColor;
  final BorderRadiusGeometry? borderRadius;

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: value,
      minHeight: minHeight,
      color: color ?? ColorTokens.primaryContainer,
      backgroundColor: backgroundColor ?? ColorTokens.surfaceContainerHighest,
      borderRadius:
          borderRadius ?? BorderRadius.circular(ShapeTokens.radiusFull),
    );
  }
}
