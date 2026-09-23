import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/component_size_tokens.dart';
import '../tokens/icon_tokens.dart';
import '../tokens/motion_tokens.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/size_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_motion_widget.dart';

/// Scanner visual tone — drives ring color, glow, and status chip.
enum AfriScannerTone { searching, ready, blocked, error }

/// The shape of the targeting reticle.
enum AfriScannerReticle { circular, rectangular }

/// Premium biometric/QR scanner shell.
///
/// Features:
/// - Segmented or continuous targeting reticle
/// - Animated floating status chip
/// - Sample capture dots
/// - Privacy badge
/// - Green flash overlay
class AfriScannerShell extends StatefulWidget {
  const AfriScannerShell({
    required this.isCameraReady,
    required this.statusLabel,
    required this.helperText,
    required this.tone,
    this.reticle = AfriScannerReticle.circular,
    this.cameraPreview,
    this.footer,
    this.sampleCount = 0,
    this.totalSamples = 5,
    this.isEnrollMode = true,
    super.key,
  });

  final Widget? cameraPreview;
  final bool isCameraReady;
  final String statusLabel;
  final String helperText;
  final AfriScannerTone tone;
  final AfriScannerReticle reticle;
  final Widget? footer;
  final int sampleCount;
  final int totalSamples;
  final bool isEnrollMode;

  @override
  State<AfriScannerShell> createState() => _AfriScannerShellState();
}

class _AfriScannerShellState extends State<AfriScannerShell>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _flashController;
  int _previousSampleCount = 0;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _previousSampleCount = widget.sampleCount;

    _pulseController = AnimationController(
      vsync: this,
      duration: AfriMotion.scannerPulse,
    );

    _flashController = AnimationController(
      vsync: this,
      duration: AfriMotion.scannerFlash,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = AfriMotion.reduceMotion(context);
    _syncPulseAnimation();
    if (_reduceMotion) {
      _flashController.stop();
      _flashController.value = 0;
    }
  }

  @override
  void didUpdateWidget(covariant AfriScannerShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.sampleCount > _previousSampleCount &&
        widget.sampleCount <= widget.totalSamples) {
      _previousSampleCount = widget.sampleCount;
      if (!_reduceMotion) {
        unawaited(
          _flashController.forward(from: 0).then((_) {
            if (mounted) {
              unawaited(_flashController.reverse());
            }
          }),
        );
      }
    }

    _syncPulseAnimation();
  }

  void _syncPulseAnimation() {
    final shouldPulse =
        !_reduceMotion &&
        (widget.tone == AfriScannerTone.searching ||
            widget.tone == AfriScannerTone.ready);
    if (shouldPulse && !_pulseController.isAnimating) {
      unawaited(_pulseController.repeat(reverse: true));
    } else if (!shouldPulse && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  Color _toneColor() {
    return switch (widget.tone) {
      AfriScannerTone.searching => ColorTokens.primaryContainer,
      AfriScannerTone.ready => ColorTokens.success,
      AfriScannerTone.blocked => ColorTokens.warning,
      AfriScannerTone.error => ColorTokens.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _toneColor();
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;

    // Fallback spacing instead of relying on context.afriSpace extension if not available
    const double spaceX3 = SpacingTokens.spacing3;
    const double spaceX4 = SpacingTokens.spacing4;
    const double spaceX5 = SpacingTokens.spacing5;

    return Stack(
      children: [
        // ── Camera preview / gradient fallback ────────────
        Positioned.fill(
          child: widget.isCameraReady && widget.cameraPreview != null
              ? widget.cameraPreview!
              : DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: ColorTokens.heroGradient(
                      from: ColorTokens.surfaceContainerHigh,
                      to: ColorTokens.background,
                    ),
                  ),
                ),
        ),

        // ── Reticle overlay ──────────────────
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ScannerReticlePainter(
                    color: statusColor,
                    pulseValue: _pulseController.value,
                    sampleCount: widget.sampleCount,
                    totalSamples: widget.totalSamples,
                    isEnrollMode: widget.isEnrollMode,
                    tone: widget.tone,
                    reticle: widget.reticle,
                  ),
                );
              },
            ),
          ),
        ),

        // ── Green flash overlay on capture ───────────────────
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _flashController,
              builder: (context, _) {
                final opacity = _flashController.value * 0.18;
                if (opacity <= 0) return const SizedBox.shrink();
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: ColorTokens.success.withValues(alpha: opacity),
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
        ),

        // ── Floating status chip (top) ───────────────────────
        Positioned(
          top: spaceX4,
          left: spaceX5,
          right: spaceX5,
          child: SafeArea(
            child: _FloatingStatusChip(
              label: widget.statusLabel,
              color: statusColor,
            ),
          ),
        ),

        // ── Bottom area: dots + privacy + footer ─────────────
        Positioned(
          left: spaceX5,
          right: spaceX5,
          bottom: spaceX4 + bottomPad,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isEnrollMode) ...[
                _SampleCaptureDots(
                  sampleCount: widget.sampleCount,
                  totalSamples: widget.totalSamples,
                  color: statusColor,
                ),
                const SizedBox(height: spaceX3),
              ],

              // Helper text
              if (widget.helperText.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.spacing4,
                    vertical: SpacingTokens.spacing3,
                  ),
                  decoration: BoxDecoration(
                    color: ColorTokens.background.withValues(alpha: 0.66),
                    borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
                    border: BorderTokens.ghost(),
                  ),
                  child: Text(
                    widget.helperText,
                    style: TypographyTokens.bodySmall().copyWith(
                      color: ColorTokens.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                      height: TypographyTokens.lineHeightRelaxed,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: spaceX3),

              const _PrivacyBadge(),

              if (widget.footer != null) ...[
                const SizedBox(height: spaceX3),
                widget.footer!,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Floating Status Chip
// ─────────────────────────────────────────────────────────────

class _FloatingStatusChip extends StatelessWidget {
  const _FloatingStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AfriMotion.quick,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: Container(
        key: ValueKey<String>(label),
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing5,
          vertical: SpacingTokens.spacing3,
        ),
        decoration: BoxDecoration(
          color: ColorTokens.background.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
          border: BorderTokens.all(
            color: color,
            width: BorderTokens.strong,
            opacity: 0.35,
          ),
          boxShadow: AfriShadows.scannerStatus(color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: AfriComponentSizes.scannerStatusDot,
              height: AfriComponentSizes.scannerStatusDot,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: AfriShadows.scannerDot(color),
              ),
            ),
            const SizedBox(width: SpacingTokens.spacing3),
            Flexible(
              child: Text(
                label,
                style: TypographyTokens.labelLarge().copyWith(
                  color: ColorTokens.onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: TypographyTokens.trackingNone,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sample Capture Dots
// ─────────────────────────────────────────────────────────────

class _SampleCaptureDots extends StatelessWidget {
  const _SampleCaptureDots({
    required this.sampleCount,
    required this.totalSamples,
    required this.color,
  });

  final int sampleCount;
  final int totalSamples;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSamples, (index) {
        final isFilled = index < sampleCount;
        final isCurrent = index == sampleCount;
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AfriComponentSizes.scannerSampleGap,
          ),
          child: _CapturedDot(
            key: ValueKey<int>(index),
            isFilled: isFilled,
            isCurrent: isCurrent,
            color: color,
          ),
        );
      }),
    );
  }
}

class _CapturedDot extends StatelessWidget {
  const _CapturedDot({
    required this.isFilled,
    required this.isCurrent,
    required this.color,
    super.key,
  });

  final bool isFilled;
  final bool isCurrent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AfriMotion.quick,
      curve: Curves.easeOut,
      width: isCurrent
          ? AfriComponentSizes.scannerSampleCurrent
          : AfriComponentSizes.scannerSampleDefault,
      height: isCurrent
          ? AfriComponentSizes.scannerSampleCurrent
          : AfriComponentSizes.scannerSampleDefault,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isFilled
            ? ColorTokens.success.withValues(alpha: 0.2)
            : (isCurrent
                  ? color.withValues(alpha: 0.15)
                  : ColorTokens.glassFill),
        border: BorderTokens.all(
          color: isFilled
              ? ColorTokens.success
              : (isCurrent
                    ? color.withValues(alpha: 0.6)
                    : ColorTokens.ghostBorder),
          width: isCurrent ? BorderTokens.emphasis : BorderTokens.strong,
        ),
        boxShadow: isFilled
            ? AfriShadows.scannerCapture(ColorTokens.success)
            : null,
      ),
      child: isFilled
          ? Icon(
                  AfriIcons.check,
                  size: SizeTokens.iconXs,
                  color: ColorTokens.success,
                )
                .afriAnimate(context)
                .scale(
                  begin: const Offset(0, 0),
                  end: const Offset(1, 1),
                  duration: AfriMotion.scannerFlash,
                  curve: Curves.elasticOut,
                )
                .fadeIn(duration: AfriMotion.quick)
          : (isCurrent
                ? Center(
                    child: Container(
                      width: AfriComponentSizes.scannerSampleInner,
                      height: AfriComponentSizes.scannerSampleInner,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Privacy Badge
// ─────────────────────────────────────────────────────────────

class _PrivacyBadge extends StatelessWidget {
  const _PrivacyBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: SpacingTokens.spacing1 + 2,
      ),
      decoration: BoxDecoration(
        color: ColorTokens.glassFill,
        borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
        border: BorderTokens.ghost(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AfriIcons.lock,
            size: SizeTokens.iconXxs,
            color: ColorTokens.onSurface.withValues(alpha: 0.45),
          ),
          const SizedBox(width: AfriComponentSizes.scannerSampleGap),
          Text(
            'Photo library empty',
            style: TypographyTokens.labelSmall().copyWith(
              color: ColorTokens.onSurface.withValues(alpha: 0.45),
              fontWeight: FontWeight.w600,
              letterSpacing: TypographyTokens.trackingCompact,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Scanner Reticle Painter
// ─────────────────────────────────────────────────────────────

class _ScannerReticlePainter extends CustomPainter {
  const _ScannerReticlePainter({
    required this.color,
    required this.pulseValue,
    required this.sampleCount,
    required this.totalSamples,
    required this.isEnrollMode,
    required this.tone,
    required this.reticle,
  });

  final Color color;
  final double pulseValue;
  final int sampleCount;
  final int totalSamples;
  final bool isEnrollMode;
  final AfriScannerTone tone;
  final AfriScannerReticle reticle;

  @override
  void paint(Canvas canvas, Size size) {
    const horizontalInset = 18.0;
    final path = Path();

    // Define Reticle Shape
    if (reticle == AfriScannerReticle.circular) {
      final ovalWidth = size.width - (horizontalInset * 2);
      final ovalHeight = (ovalWidth * 1.52).clamp(
        size.height * 0.54,
        size.height * 0.68,
      );
      final ovalRect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.40),
        width: ovalWidth,
        height: ovalHeight,
      );
      path.addOval(ovalRect);
    } else {
      // Rectangular QR/Ticket shape
      final rectWidth = size.width - (horizontalInset * 2);
      // Square base for QR.
      final rectHeight = rectWidth;
      final rectRect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.40),
        width: rectWidth,
        height: rectHeight,
      );
      path.addRRect(
        RRect.fromRectAndRadius(
          rectRect,
          const Radius.circular(ShapeTokens.radiusXl),
        ),
      );
    }

    // Extracted bounds for glow and stroke logic
    final bounds = path.getBounds();

    // Darkened mask outside reticle
    final fullRect = Path()..addRect(Offset.zero & size);
    final mask = Path.combine(PathOperation.difference, fullRect, path);
    canvas.drawPath(
      mask,
      Paint()..color = ColorTokens.background.withValues(alpha: 0.45),
    );

    // Pulsing glow
    final glowAlpha = 0.08 + (pulseValue * 0.12);
    final glowWidth = 16.0 + (pulseValue * 8.0);
    final glowPaint = Paint()
      ..color = color.withValues(alpha: glowAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = glowWidth
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowWidth);

    if (reticle == AfriScannerReticle.circular) {
      canvas.drawOval(bounds, glowPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          bounds,
          const Radius.circular(ShapeTokens.radiusXl),
        ),
        glowPaint,
      );
    }

    // Reticle segments or continuous
    if (isEnrollMode &&
        totalSamples > 0 &&
        reticle == AfriScannerReticle.circular) {
      // Segmentation currently only makes aesthetic sense for circular face enroll
      _drawSegmentedRing(canvas, bounds);
    } else {
      _drawContinuousRing(canvas, bounds, path);
    }

    _drawTickMarks(canvas, bounds);
  }

  void _drawSegmentedRing(Canvas canvas, Rect ovalRect) {
    final segmentCount = totalSamples;
    const gapAngle = 0.08;
    final totalGap = gapAngle * segmentCount;
    final totalArc = 2 * math.pi - totalGap;
    final segmentArc = totalArc / segmentCount;
    const startOffset = -math.pi / 2;

    for (int i = 0; i < segmentCount; i++) {
      final segStart = startOffset + i * (segmentArc + gapAngle);
      final isFilled = i < sampleCount;
      final isCurrent = i == sampleCount;

      final segColor = isFilled
          ? ColorTokens.success
          : (isCurrent ? color : ColorTokens.ghostBorder);

      final strokeWidth = isCurrent ? 4.5 : (isFilled ? 4.0 : 2.5);

      final paint = Paint()
        ..color = segColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(ovalRect, segStart, segmentArc, false, paint);

      if (isFilled) {
        final fillGlow = Paint()
          ..color = segColor.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawArc(ovalRect, segStart, segmentArc, false, fillGlow);
      }
    }
  }

  void _drawContinuousRing(Canvas canvas, Rect bounds, Path path) {
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawPath(path, borderPaint);
  }

  void _drawTickMarks(Canvas canvas, Rect bounds) {
    final cx = bounds.center.dx;
    final cy = bounds.center.dy;
    final rx = bounds.width / 2;
    final ry = bounds.height / 2;

    final tickPaint = Paint()
      ..color = ColorTokens.onSurface.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    if (reticle == AfriScannerReticle.circular) {
      const angles = <double>[-math.pi / 2, 0, math.pi / 2, math.pi];
      for (final angle in angles) {
        final cosA = math.cos(angle);
        final sinA = math.sin(angle);
        final innerX = cx + (rx - 10) * cosA;
        final innerY = cy + (ry - 10) * sinA;
        final outerX = cx + (rx + 10) * cosA;
        final outerY = cy + (ry + 10) * sinA;
        canvas.drawLine(
          Offset(innerX, innerY),
          Offset(outerX, outerY),
          tickPaint,
        );
      }
    } else {
      // For rectangular reticle, ticks at the 4 corners going outward
      const inset = 8.0;

      // Top Left
      canvas.drawLine(
        Offset(bounds.left + inset, bounds.top + inset),
        Offset(bounds.left - inset, bounds.top - inset),
        tickPaint,
      );
      // Top Right
      canvas.drawLine(
        Offset(bounds.right - inset, bounds.top + inset),
        Offset(bounds.right + inset, bounds.top - inset),
        tickPaint,
      );
      // Bottom Left
      canvas.drawLine(
        Offset(bounds.left + inset, bounds.bottom - inset),
        Offset(bounds.left - inset, bounds.bottom + inset),
        tickPaint,
      );
      // Bottom Right
      canvas.drawLine(
        Offset(bounds.right - inset, bounds.bottom - inset),
        Offset(bounds.right + inset, bounds.bottom + inset),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScannerReticlePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.sampleCount != sampleCount ||
        oldDelegate.totalSamples != totalSamples ||
        oldDelegate.isEnrollMode != isEnrollMode ||
        oldDelegate.tone != tone ||
        oldDelegate.reticle != reticle;
  }
}
