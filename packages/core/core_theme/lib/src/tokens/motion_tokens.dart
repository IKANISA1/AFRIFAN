import 'package:flutter/animation.dart';

/// Motion tokens — animation durations, curves, and timing.
///
/// Inspired by physical tactile feedback — every interaction must feel
/// responsive and alive. Respects reduced-motion preferences.
class AfriMotion {
  AfriMotion._();

  // ── Durations ──
  /// Ultra-short press feedback (button scale). 80ms.
  static const Duration press = Duration(milliseconds: 80);

  /// Quick micro-interactions (chip toggle, icon swap). 150ms.
  static const Duration quick = Duration(milliseconds: 150);

  /// Standard element transitions (card expand, slide). 250ms.
  static const Duration standard = Duration(milliseconds: 250);

  /// Emphasized transitions (page enter, modal open). 350ms.
  static const Duration emphasized = Duration(milliseconds: 350);

  /// Slow atmospheric animations (background glow shift). 600ms.
  static const Duration atmospheric = Duration(milliseconds: 600);

  // ── Curves ──
  /// Spring-like press feedback curve.
  static const Curve pressCurve = Cubic(0.25, 0.46, 0.45, 0.94);

  /// Standard ease-out for entering elements.
  static const Curve enterCurve = Cubic(0.0, 0.0, 0.2, 1.0);

  /// Standard ease-in for exiting elements.
  static const Curve exitCurve = Cubic(0.4, 0.0, 1.0, 1.0);

  /// Emphasized curve for page transitions.
  static const Curve emphasizedCurve = Cubic(0.2, 0.0, 0.0, 1.0);
}
