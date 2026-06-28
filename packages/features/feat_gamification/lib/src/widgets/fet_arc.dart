import 'dart:math';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Radial FET progress arc with massive center number.
class FetArc extends StatelessWidget {
  final int currentFet;
  final int maxFet;
  final String tier;
  final String nextTier;

  const FetArc({
    super.key,
    required this.currentFet,
    required this.maxFet,
    required this.tier,
    required this.nextTier,
  });

  @override
  Widget build(BuildContext context) {
    final primary = ColorTokens.clubAccent;
    final progress = (currentFet / maxFet).clamp(0.0, 1.0);

    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background arc
          CustomPaint(
            size: const Size(200, 200),
            painter: _ArcPainter(
              progress: progress,
              color: primary,
              backgroundColor: ColorTokens.surfaceContainerHigh,
              strokeWidth: 8,
            ),
          ),

          // Center content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currentFet.toString(),
                style: TypographyTokens.displayLarge(primary).copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'FET',
                style: TypographyTokens.labelLarge(
                  ColorTokens.onSurfaceVariant,
                ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 2.0),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.15),
                  borderRadius: ShapeTokens.chipRadius,
                ),
                child: Text(
                  tier,
                  style: TypographyTokens.labelLarge(
                    primary,
                  ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  _ArcPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background arc (270 degrees, gap at bottom)
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      (135 * pi / 180), // Start at bottom-left
      (270 * pi / 180), // 270 degree sweep
      false,
      bgPaint,
    );

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      (135 * pi / 180),
      (270 * progress * pi / 180),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
