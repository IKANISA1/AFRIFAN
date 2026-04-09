import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Scanner visual tone — drives ring color, glow, and status chip.
enum BiopayScannerTone { searching, ready, blocked, error }

/// Premium biometric scanner shell — Apple Face ID-inspired capture UI.
///
/// Stadium Pulse design tokens: GlassCard mandate, Ghost Borders,
/// Barlow Condensed + Inter typography, Club Red accents, deep navy bg.
///
/// Features:
/// - Segmented progress ring around the face oval (enrollment)
/// - Continuous pulsing ring (pay mode)
/// - Animated floating status chip at top
/// - Sample capture dots with checkmark fill animations
/// - Privacy badge ("No photos saved")
/// - Green flash overlay on each sample capture
class BiopayScannerShell extends StatefulWidget {
  const BiopayScannerShell({
    required this.isCameraReady,
    required this.statusLabel,
    required this.helperText,
    required this.tone,
    this.controller,
    this.footer,
    this.sampleCount = 0,
    this.totalSamples = 5,
    this.isEnrollMode = true,
    super.key,
  });

  final CameraController? controller;
  final bool isCameraReady;
  final String statusLabel;
  final String helperText;
  final BiopayScannerTone tone;
  final Widget? footer;
  final int sampleCount;
  final int totalSamples;
  final bool isEnrollMode;

  @override
  State<BiopayScannerShell> createState() => _BiopayScannerShellState();
}

class _BiopayScannerShellState extends State<BiopayScannerShell>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _flashController;
  int _previousSampleCount = 0;

  @override
  void initState() {
    super.initState();
    _previousSampleCount = widget.sampleCount;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void didUpdateWidget(covariant BiopayScannerShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.sampleCount > _previousSampleCount &&
        widget.sampleCount <= widget.totalSamples) {
      _previousSampleCount = widget.sampleCount;
      _flashController.forward(from: 0).then((_) {
        if (mounted) _flashController.reverse();
      });
    }

    final shouldPulse =
        widget.tone == BiopayScannerTone.searching ||
        widget.tone == BiopayScannerTone.ready;
    if (shouldPulse && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
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
      BiopayScannerTone.searching => ColorTokens.clubAccent,
      BiopayScannerTone.ready => ColorTokens.success,
      BiopayScannerTone.blocked => ColorTokens.warning,
      BiopayScannerTone.error => ColorTokens.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _toneColor();
    final space = context.afriSpace;
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;

    return Stack(
      children: [
        // ── Camera preview / gradient placeholder ────────────
        Positioned.fill(
          child: widget.isCameraReady && widget.controller != null
              ? CameraPreview(widget.controller!)
              : DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: ColorTokens.heroGradient(
                      from: ColorTokens.clubSecondary,
                      to: ColorTokens.background,
                    ),
                  ),
                ),
        ),

        // ── Segmented progress ring overlay ──────────────────
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _BiometricRingPainter(
                    color: statusColor,
                    pulseValue: _pulseController.value,
                    sampleCount: widget.sampleCount,
                    totalSamples: widget.totalSamples,
                    isEnrollMode: widget.isEnrollMode,
                    tone: widget.tone,
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

        // ── Bottom area: status + dots + privacy + footer ────
        Positioned(
          left: space.x5,
          right: space.x5,
          bottom: space.x4 + bottomPad,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FloatingStatusChip(
                label: widget.statusLabel,
                color: statusColor,
              ),
              SizedBox(height: space.x3),

              if (widget.isEnrollMode) ...[
                _SampleCaptureDots(
                  sampleCount: widget.sampleCount,
                  totalSamples: widget.totalSamples,
                  color: statusColor,
                ),
                SizedBox(height: space.x3),
              ],

              // Helper text — glass container per Glass Mandate
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
                    border: Border.all(color: ColorTokens.ghostBorder),
                  ),
                  child: Text(
                    widget.helperText,
                    style: TypographyTokens.bodySmall().copyWith(
                      color: ColorTokens.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              SizedBox(height: space.x3),

              const _PrivacyBadge(),

              if (widget.footer != null) ...[
                SizedBox(height: space.x3),
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
// Floating Status Chip — bottom status panel
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
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing5,
          vertical: SpacingTokens.spacing3,
        ),
        decoration: BoxDecoration(
          color: ColorTokens.background.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Text(
          label,
          style: TypographyTokens.titleMedium().copyWith(
            color: ColorTokens.onSurface,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
          padding: const EdgeInsets.symmetric(horizontal: 6),
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
      width: isCurrent ? 28 : 22,
      height: isCurrent ? 28 : 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isFilled
            ? ColorTokens.success.withValues(alpha: 0.2)
            : (isCurrent
                  ? color.withValues(alpha: 0.15)
                  : ColorTokens.glassFill),
        border: Border.all(
          color: isFilled
              ? ColorTokens.success
              : (isCurrent
                    ? color.withValues(alpha: 0.6)
                    : ColorTokens.ghostBorder),
          width: isCurrent ? 2 : 1.5,
        ),
        boxShadow: isFilled
            ? [
                BoxShadow(
                  color: ColorTokens.success.withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: isFilled
          ? const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: ColorTokens.success,
                )
                .animate()
                .scale(
                  begin: const Offset(0, 0),
                  end: const Offset(1, 1),
                  duration: 300.ms,
                  curve: Curves.elasticOut,
                )
                .fadeIn(duration: 150.ms)
          : (isCurrent
                ? Center(
                    child: Container(
                      width: 6,
                      height: 6,
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
// Privacy Badge — glassmorphic pill
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
        border: Border.all(color: ColorTokens.ghostBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_rounded,
            size: 12,
            color: ColorTokens.onSurface.withValues(alpha: 0.45),
          ),
          const SizedBox(width: 6),
          Text(
            'No photos saved',
            style: TypographyTokens.labelSmall().copyWith(
              color: ColorTokens.onSurface.withValues(alpha: 0.45),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Biometric Ring Painter — Segmented progress arcs
// ─────────────────────────────────────────────────────────────

class _BiometricRingPainter extends CustomPainter {
  const _BiometricRingPainter({
    required this.color,
    required this.pulseValue,
    required this.sampleCount,
    required this.totalSamples,
    required this.isEnrollMode,
    required this.tone,
  });

  final Color color;
  final double pulseValue;
  final int sampleCount;
  final int totalSamples;
  final bool isEnrollMode;
  final BiopayScannerTone tone;

  @override
  void paint(Canvas canvas, Size size) {
    const horizontalInset = 18.0;
    final ovalWidth = size.width - (horizontalInset * 2);
    final ovalHeight = (ovalWidth * 1.52)
        .clamp(size.height * 0.54, size.height * 0.68)
        .toDouble();
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.40),
      width: ovalWidth,
      height: ovalHeight,
    );

    // Darkened mask outside oval
    final fullRect = Path()..addRect(Offset.zero & size);
    final ovalPath = Path()..addOval(ovalRect);
    final mask = Path.combine(PathOperation.difference, fullRect, ovalPath);
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
    canvas.drawOval(ovalRect, glowPaint);

    if (isEnrollMode && totalSamples > 0) {
      _drawSegmentedRing(canvas, ovalRect);
    } else {
      _drawContinuousRing(canvas, ovalRect);
    }

    _drawTickMarks(canvas, ovalRect);
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

  void _drawContinuousRing(Canvas canvas, Rect ovalRect) {
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawOval(ovalRect, borderPaint);
  }

  void _drawTickMarks(Canvas canvas, Rect ovalRect) {
    final cx = ovalRect.center.dx;
    final cy = ovalRect.center.dy;
    final rx = ovalRect.width / 2;
    final ry = ovalRect.height / 2;

    final tickPaint = Paint()
      ..color = ColorTokens.onSurface.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

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
  }

  @override
  bool shouldRepaint(covariant _BiometricRingPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.sampleCount != sampleCount ||
        oldDelegate.totalSamples != totalSamples ||
        oldDelegate.isEnrollMode != isEnrollMode ||
        oldDelegate.tone != tone;
  }
}
