import 'package:flutter/material.dart';

import 'color_tokens.dart';

/// Shadow presets for the ROUGEBLACK design system.
///
/// "Don't use standard Drop Shadows — all depth must be Tonal
/// (background shift) or Claymorphic (inner shadows)."
///
/// Shadows are always tinted with the surface hue, never grey.
class AfriShadows {
  AfriShadows._();

  /// Standard card shadow — subtle depth.
  static List<BoxShadow> standard(Brightness? brightness) {
    final strength = brightness == Brightness.light ? 0.15 : 0.4;
    return [
      BoxShadow(
        color: ColorTokens.ambientShadow.withValues(alpha: strength),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];
  }

  /// Floating shadow — for elevated elements (bottom sheets, FABs).
  static List<BoxShadow> floating(
    Brightness? brightness, {
    double strength = 1.0,
  }) {
    final alpha = (brightness == Brightness.light ? 0.12 : 0.55) * strength;
    return [
      BoxShadow(
        color: ColorTokens.ambientShadow.withValues(alpha: alpha),
        blurRadius: 40,
        offset: const Offset(0, 12),
      ),
    ];
  }

  /// Primary glow — for primary action buttons.
  static List<BoxShadow> primaryGlow(Color primaryColor) {
    return [
      BoxShadow(
        color: primaryColor.withValues(alpha: 0.3),
        blurRadius: 20,
        offset: const Offset(0, 4),
      ),
    ];
  }

  /// Glass shadow — for glassmorphic cards.
  static List<BoxShadow> glass() {
    return [
      BoxShadow(
        color: ColorTokens.ambientShadow.withValues(alpha: 0.8),
        blurRadius: 40,
        offset: const Offset(0, 8),
      ),
    ];
  }

  /// Clay inner shadows — for claymorphic buttons.
  /// Returns (topLeft, bottomRight) pair.
  static ({BoxShadow topLeft, BoxShadow bottomRight}) clay({
    bool pressed = false,
  }) {
    if (pressed) {
      return (
        topLeft: BoxShadow(
          color: ColorTokens.ambientShadow,
          blurRadius: 2,
          offset: const Offset(-2, -2),
        ),
        bottomRight: BoxShadow(
          color: Colors.white.withValues(alpha: 0.1),
          blurRadius: 4,
          offset: const Offset(4, 4),
        ),
      );
    }
    return (
      topLeft: BoxShadow(
        color: Colors.white.withValues(alpha: 0.2),
        blurRadius: 2,
        offset: const Offset(-2, -2),
      ),
      bottomRight: BoxShadow(
        color: ColorTokens.ambientShadow,
        blurRadius: 4,
        offset: const Offset(4, 4),
      ),
    );
  }
}
