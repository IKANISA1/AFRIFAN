import 'package:flutter/material.dart';

import 'color_tokens.dart';

/// Shadow presets for the universal mobile system.
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
}
