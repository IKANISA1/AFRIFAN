import 'dart:math';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Shows a brief confetti-like particle burst overlay.
///
/// Uses [Overlay] + [flutter_animate] for a lightweight effect
/// matching the web reference's `triggerConfetti()` without a
/// dedicated confetti package.
void showConfettiOverlay(BuildContext context) {
  if (AfriMotion.reduceMotion(context)) {
    return;
  }
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => _ConfettiBurst(
      onComplete: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );

  overlay.insert(entry);
}

class _ConfettiBurst extends StatefulWidget {
  const _ConfettiBurst({required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<_ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<_ConfettiBurst> {
  static const _particleCount = 24;
  static final _colors = <Color>[
    ColorTokens.primaryContainer,
    ColorTokens.success,
    ...ExternalBrandColors.confettiPalette.take(2), // gold + indigo
  ];

  late final List<_Particle> _particles;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _particles = List<_Particle>.generate(_particleCount, (_) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 80 + _random.nextDouble() * 160;
      return _Particle(
        dx: cos(angle) * speed,
        dy: sin(angle) * speed - 60, // bias upward
        size:
            SpacingTokens.spacing2 -
            SpacingTokens.spacing1 / 2 +
            _random.nextDouble() * SpacingTokens.spacing2,
        color: _colors[_random.nextInt(_colors.length)],
        isGroup: _random.nextBool(),
      );
    });

    Future<void>.delayed(AfriMotion.celebrationHold, () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final center = Offset(size.width / 2, size.height * 0.45);

    return IgnorePointer(
      child: SizedBox.expand(
        child: Stack(
          children: _particles
              .asMap()
              .entries
              .map((entry) {
                final i = entry.key;
                final p = entry.value;
                final delay = (i * 15).ms;

                return Positioned(
                  left: center.dx - p.size / 2,
                  top: center.dy - p.size / 2,
                  child:
                      Container(
                            width: p.size,
                            height: p.size,
                            decoration: BoxDecoration(
                              color: p.color,
                              shape: p.isGroup
                                  ? BoxShape.circle
                                  : BoxShape.rectangle,
                              borderRadius: p.isGroup
                                  ? null
                                  : BorderRadius.circular(
                                      SpacingTokens.spacing1 / 2,
                                    ),
                            ),
                          )
                          .afriAnimate(context, delay: delay)
                          .move(
                            begin: Offset.zero,
                            end: Offset(p.dx, p.dy),
                            duration: 900.ms,
                            curve: Curves.easeOutCubic,
                          )
                          .scaleXY(begin: 0, end: 1, duration: 200.ms)
                          .then(delay: 500.ms)
                          .fadeOut(duration: 400.ms),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.dx,
    required this.dy,
    required this.size,
    required this.color,
    required this.isGroup,
  });

  final double dx;
  final double dy;
  final double size;
  final Color color;
  final bool isGroup;
}
