import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../tokens/motion_tokens.dart';

/// Starts a third-party effect chain while honoring both Flutter
/// reduced-motion accessibility signals.
///
/// With reduced motion enabled, decorative effects render at their requested
/// target immediately, skip stagger delays, and never start an animation
/// playback. Feature code must use this instead of `Widget.animate()`.
extension AfriMotionWidget on Widget {
  Animate afriAnimate(
    BuildContext context, {
    Duration? delay,
    AnimateCallback? onPlay,
    double? target,
  }) {
    final reduceMotion = AfriMotion.reduceMotion(context);
    return Animate(
      autoPlay: !reduceMotion,
      delay: reduceMotion ? Duration.zero : delay,
      onPlay: reduceMotion ? null : onPlay,
      value: reduceMotion ? (target ?? 1) : null,
      target: reduceMotion ? null : target,
      child: this,
    );
  }
}
