import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Status chip floating above the scanner reticle.
class FloatingStatusChip extends StatelessWidget {
  const FloatingStatusChip({
    super.key,
    required this.tone,
    required this.message,
  });

  final AfriScannerTone tone;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      AfriScannerTone.searching => ColorTokens.clubAccent,
      AfriScannerTone.ready => ColorTokens.success,
      AfriScannerTone.blocked => ColorTokens.error,
      AfriScannerTone.error => ColorTokens.error,
    };

    final icon = switch (tone) {
      AfriScannerTone.searching => Icons.radar_rounded,
      AfriScannerTone.ready => Icons.check_circle_outline_rounded,
      AfriScannerTone.blocked => Icons.block_rounded,
      AfriScannerTone.error => Icons.error_outline_rounded,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing4,
        vertical: SpacingTokens.spacing2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: SpacingTokens.spacing2),
          Flexible(
            child: Text(
              message,
              style: TypographyTokens.labelMedium().copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dot indicator for sample capture progress.
class SampleCaptureDots extends StatelessWidget {
  const SampleCaptureDots({
    super.key,
    required this.capturedCount,
    required this.requiredCount,
  });

  final int capturedCount;
  final int requiredCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(requiredCount, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: CapturedDot(isFilled: index < capturedCount),
        );
      }),
    );
  }
}

/// A single dot in the sample capture indicator.
class CapturedDot extends StatelessWidget {
  const CapturedDot({super.key, required this.isFilled});

  final bool isFilled;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      width: isFilled ? 14 : 10,
      height: isFilled ? 14 : 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isFilled
            ? ColorTokens.success
            : ColorTokens.surfaceContainerHigh.withValues(alpha: 0.3),
        boxShadow: isFilled
            ? [
                BoxShadow(
                  color: ColorTokens.success.withValues(alpha: 0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}

/// Privacy consent badge.
class PrivacyBadge extends StatelessWidget {
  const PrivacyBadge({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing3,
          vertical: SpacingTokens.spacing1,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined, size: 14, color: Colors.white70),
            const SizedBox(width: SpacingTokens.spacing1),
            Text(
              'ON-DEVICE PROCESSING',
              style: TypographyTokens.labelSmall().copyWith(
                color: Colors.white70,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for scanner reticle overlay.
class ScannerReticlePainter extends CustomPainter {
  ScannerReticlePainter({
    required this.reticleRect,
    required this.color,
    required this.cornerRadius,
    this.isCircular = false,
  });

  final Rect reticleRect;
  final Color color;
  final double cornerRadius;
  final bool isCircular;

  @override
  void paint(Canvas canvas, Size size) {
    // Dim background
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final fullRect = Offset.zero & size;

    if (isCircular) {
      final center = reticleRect.center;
      final radius = reticleRect.shortestSide / 2;
      canvas.drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(fullRect),
          Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
        ),
        bgPaint,
      );
    } else {
      canvas.drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(fullRect),
          Path()
            ..addRRect(
              RRect.fromRectAndRadius(
                reticleRect,
                Radius.circular(cornerRadius),
              ),
            ),
        ),
        bgPaint,
      );
    }

    // Corner brackets
    final bracketPaint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    const bracketLen = 20.0;
    final left = reticleRect.left;
    final top = reticleRect.top;
    final right = reticleRect.right;
    final bottom = reticleRect.bottom;

    // TL
    canvas.drawLine(Offset(left, top + bracketLen), Offset(left, top), bracketPaint);
    canvas.drawLine(Offset(left, top), Offset(left + bracketLen, top), bracketPaint);
    // TR
    canvas.drawLine(Offset(right - bracketLen, top), Offset(right, top), bracketPaint);
    canvas.drawLine(Offset(right, top), Offset(right, top + bracketLen), bracketPaint);
    // BL
    canvas.drawLine(Offset(left, bottom - bracketLen), Offset(left, bottom), bracketPaint);
    canvas.drawLine(Offset(left, bottom), Offset(left + bracketLen, bottom), bracketPaint);
    // BR
    canvas.drawLine(Offset(right - bracketLen, bottom), Offset(right, bottom), bracketPaint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - bracketLen), bracketPaint);
  }

  @override
  bool shouldRepaint(covariant ScannerReticlePainter oldDelegate) =>
      reticleRect != oldDelegate.reticleRect ||
      color != oldDelegate.color ||
      cornerRadius != oldDelegate.cornerRadius ||
      isCircular != oldDelegate.isCircular;
}
