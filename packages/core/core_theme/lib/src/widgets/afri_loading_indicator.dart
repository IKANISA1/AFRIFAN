import 'package:flutter/material.dart';
import '../tokens/color_tokens.dart';

/// Minimalist loading indicator aligned with the monolith aesthetic.
class AfriLoadingIndicator extends StatelessWidget {
  const AfriLoadingIndicator({this.size = 24, this.color, super.key});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            color ?? ColorTokens.clubAccent,
          ),
        ),
      ),
    );
  }
}
