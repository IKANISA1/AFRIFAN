import 'package:flutter/material.dart';

import 'color_tokens.dart';

/// Shadow presets for the Tactile Monolith design system.
class AfriShadows {
  AfriShadows._();

  static List<BoxShadow> standard(Brightness? brightness) {
    final strength = brightness == Brightness.light ? 0.08 : 0.18;
    return [
      BoxShadow(
        color: ColorTokens.ambientShadow.withValues(alpha: strength),
        blurRadius: 18,
        spreadRadius: -8,
        offset: const Offset(0, 8),
      ),
    ];
  }

  static List<BoxShadow> floating(
    Brightness? brightness, {
    double strength = 1.0,
  }) {
    final alpha = (brightness == Brightness.light ? 0.10 : 0.22) * strength;
    return [
      BoxShadow(
        color: ColorTokens.ambientShadow.withValues(alpha: alpha),
        blurRadius: 28,
        spreadRadius: -10,
        offset: const Offset(0, 14),
      ),
    ];
  }

  static List<BoxShadow> primaryGlow(Color primaryColor) {
    return [
      BoxShadow(
        color: primaryColor.withValues(alpha: 0.16),
        blurRadius: 20,
        spreadRadius: -8,
        offset: const Offset(0, 8),
      ),
    ];
  }

  static List<BoxShadow> glass({double strength = 1.0}) {
    return [
      BoxShadow(
        color: ColorTokens.ambientShadow.withValues(alpha: 0.18 * strength),
        blurRadius: 20,
        spreadRadius: -8,
        offset: const Offset(0, 10),
      ),
    ];
  }

  static ({BoxShadow topLeft, BoxShadow bottomRight}) clay({
    bool pressed = false,
  }) {
    if (pressed) {
      return (
        topLeft: BoxShadow(
          color: ColorTokens.ambientShadow.withValues(alpha: 0.12),
          blurRadius: 8,
          offset: const Offset(-2, -2),
          spreadRadius: -6,
        ),
        bottomRight: BoxShadow(
          color: Colors.white.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(3, 3),
          spreadRadius: -6,
        ),
      );
    }
    return (
      topLeft: BoxShadow(
        color: Colors.white.withValues(alpha: 0.05),
        blurRadius: 12,
        offset: const Offset(-4, -4),
        spreadRadius: -8,
      ),
      bottomRight: BoxShadow(
        color: ColorTokens.ambientShadow.withValues(alpha: 0.16),
        blurRadius: 16,
        offset: const Offset(0, 8),
        spreadRadius: -8,
      ),
    );
  }
}
