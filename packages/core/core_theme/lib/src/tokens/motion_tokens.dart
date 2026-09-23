import 'package:flutter/widgets.dart';

/// Motion tokens — animation durations, curves, and timing.
///
/// Inspired by physical tactile feedback — every interaction must feel
/// responsive and alive. Respects reduced-motion preferences.
class AfriMotion {
  AfriMotion._();

  static const double buttonPressScale = 0.985;

  // ── Durations ──
  /// Ultra-short press feedback (button scale). 80ms.
  static const Duration press = Duration(milliseconds: 80);

  /// Quick micro-interactions (chip toggle, icon swap). 150ms.
  static const Duration quick = Duration(milliseconds: 150);

  /// Shared bottom-navigation selection transition. 180ms.
  static const Duration navigation = Duration(milliseconds: 180);

  /// Immediate surface and focus response used by shared controls. 140ms.
  static const Duration surfaceResponse = Duration(milliseconds: 140);

  /// Standard element transitions (card expand, slide). 250ms.
  static const Duration standard = Duration(milliseconds: 250);

  /// Emphasized transitions (page enter, modal open). 350ms.
  static const Duration emphasized = Duration(milliseconds: 350);

  /// Slow atmospheric animations (background glow shift). 600ms.
  static const Duration atmospheric = Duration(milliseconds: 600);

  /// Interval between automatic onboarding carousel changes.
  static const Duration carouselInterval = Duration(seconds: 6);

  /// Deliberate onboarding image transition that preserves visual orientation.
  static const Duration carouselTransition = Duration(milliseconds: 550);

  /// Short debounce for search and remote-repeat input. 250ms.
  static const Duration debounce = standard;

  /// Delayed affordance before showing an async confirmation. 800ms.
  static const Duration feedbackDelay = Duration(milliseconds: 800);

  /// Count-up and lightweight reward reveal timing. 1200ms.
  static const Duration rewardReveal = Duration(milliseconds: 1200);

  /// Completion hold for confetti and celebratory overlays. 1400ms.
  static const Duration celebrationHold = Duration(milliseconds: 1400);

  /// Skeleton shimmer cycle. 1500ms.
  static const Duration skeletonShimmer = Duration(milliseconds: 1500);

  /// Scanner reticle pulse cycle. 1600ms.
  static const Duration scannerPulse = Duration(milliseconds: 1600);

  /// Scanner capture acknowledgement. 300ms.
  static const Duration scannerFlash = Duration(milliseconds: 300);

  /// Standard content reveal and error-scale transition. 400ms.
  static const Duration contentReveal = Duration(milliseconds: 400);

  /// Error-attention shake. 500ms.
  static const Duration errorAttention = Duration(milliseconds: 500);

  /// Shared card entrance. 220ms.
  static const Duration surfaceEntrance = Duration(milliseconds: 220);

  /// Compact stagger delay. 100ms.
  static const Duration staggerCompact = Duration(milliseconds: 100);

  /// Standard stagger delay. 200ms.
  static const Duration staggerStandard = Duration(milliseconds: 200);

  /// Default informational and success toast duration.
  static const Duration toastStandard = Duration(seconds: 3);

  /// Extended error and action toast duration.
  static const Duration toastExtended = Duration(seconds: 4);

  // ── Curves ──
  /// Spring-like press feedback curve.
  static const Curve pressCurve = Cubic(0.25, 0.46, 0.45, 0.94);

  /// Standard ease-out for entering elements.
  static const Curve enterCurve = Cubic(0.0, 0.0, 0.2, 1.0);

  /// Standard ease-in for exiting elements.
  static const Curve exitCurve = Cubic(0.4, 0.0, 1.0, 1.0);

  /// Emphasized curve for page transitions.
  static const Curve emphasizedCurve = Cubic(0.2, 0.0, 0.0, 1.0);

  static bool reduceMotion(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    return mediaQuery?.disableAnimations == true ||
        mediaQuery?.accessibleNavigation == true;
  }

  static Duration resolve(BuildContext context, Duration duration) =>
      reduceMotion(context) ? Duration.zero : duration;
}
