import 'package:flutter/material.dart';

import 'color_tokens.dart';

/// Shadow presets for the Tactile Monolith design system.
class AfriShadows {
  AfriShadows._();

  static List<BoxShadow> standard(Brightness? brightness) {
    final strength = brightness == Brightness.light ? 0.14 : 0.24;
    return [
      BoxShadow(
        color: ColorTokens.ambientShadow.withValues(alpha: strength),
        blurRadius: 28,
        spreadRadius: -6,
        offset: const Offset(0, 10),
      ),
    ];
  }

  static List<BoxShadow> floating(
    Brightness? brightness, {
    double strength = 1.0,
  }) {
    final alpha = (brightness == Brightness.light ? 0.16 : 0.42) * strength;
    return [
      BoxShadow(
        color: ColorTokens.ambientShadow.withValues(alpha: alpha),
        blurRadius: 80,
        spreadRadius: -10,
        offset: const Offset(0, 20),
      ),
    ];
  }

  static List<BoxShadow> primaryGlow(Color primaryColor) {
    return [
      BoxShadow(
        color: primaryColor.withValues(alpha: 0.34),
        blurRadius: 36,
        spreadRadius: -6,
        offset: const Offset(0, 10),
      ),
    ];
  }

  static List<BoxShadow> glass({double strength = 1.0}) {
    return [
      BoxShadow(
        color: ColorTokens.ambientShadow.withValues(alpha: 0.4 * strength),
        blurRadius: 80,
        spreadRadius: -10,
        offset: const Offset(0, 20),
      ),
    ];
  }

  static ({BoxShadow topLeft, BoxShadow bottomRight}) clay({
    bool pressed = false,
  }) {
    if (pressed) {
      return (
        topLeft: BoxShadow(
          color: ColorTokens.ambientShadow.withValues(alpha: 0.32),
          blurRadius: 10,
          offset: const Offset(-4, -4),
          spreadRadius: -4,
        ),
        bottomRight: BoxShadow(
          color: Colors.white.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(6, 6),
          spreadRadius: -4,
        ),
      );
    }
    return (
      topLeft: BoxShadow(
        color: Colors.white.withValues(alpha: 0.18),
        blurRadius: 14,
        offset: const Offset(-6, -6),
        spreadRadius: -6,
      ),
      bottomRight: BoxShadow(
        color: ColorTokens.ambientShadow.withValues(alpha: 0.28),
        blurRadius: 20,
        offset: const Offset(10, 12),
        spreadRadius: -8,
      ),
    );
  }
}
