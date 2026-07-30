import 'package:flutter/material.dart';

import 'color_tokens.dart';

/// Shadow presets for the universal mobile system.
class AfriShadows {
  AfriShadows._();

  static List<BoxShadow> brandMark(double size) => [
    BoxShadow(
      color: ColorTokens.ambientShadow.withValues(alpha: 0.24),
      blurRadius: size * 0.32,
      offset: Offset(0, size * 0.14),
    ),
  ];

  static List<BoxShadow> commandAvatar() => [
    BoxShadow(
      color: ColorTokens.ambientShadow.withValues(alpha: 0.28),
      blurRadius: 18,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> navigationChrome() => [
    BoxShadow(
      color: ColorTokens.ambientShadow.withValues(alpha: 0.36),
      blurRadius: 34,
      spreadRadius: -12,
      offset: const Offset(0, 18),
    ),
  ];

  static List<BoxShadow> primaryAction(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.16),
      blurRadius: 16,
      spreadRadius: -8,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> semanticAction(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.14),
      blurRadius: 14,
      spreadRadius: -10,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> selectedControl() => [
    BoxShadow(
      color: ColorTokens.ambientShadow.withValues(alpha: 0.12),
      blurRadius: 8,
      spreadRadius: -4,
      offset: const Offset(0, 2),
    ),
  ];

  static BoxShadow focusGlow(Color color) => BoxShadow(
    color: color.withValues(alpha: 0.18),
    blurRadius: 18,
    spreadRadius: -8,
    offset: const Offset(0, 8),
  );

  static BoxShadow pressedInner() => BoxShadow(
    color: ColorTokens.ambientShadow.withValues(alpha: 0.16),
    blurRadius: 10,
    spreadRadius: -8,
    offset: const Offset(0, 4),
    blurStyle: BlurStyle.inner,
  );

  static List<BoxShadow> scannerStatus(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.15),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];

  static List<BoxShadow> scannerDot(Color color) => [
    BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6),
  ];

  static List<BoxShadow> scannerCapture(Color color) => [
    BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8),
  ];

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

  static List<BoxShadow> glass(Brightness brightness, {double strength = 1.0}) {
    final isLight = brightness == Brightness.light;
    return [
      BoxShadow(
        color: ColorTokens.ambientShadow.withValues(
          alpha: (isLight ? 0.06 : 0.18) * strength,
        ),
        blurRadius: isLight ? 14 : 20,
        spreadRadius: -8,
        offset: Offset(0, isLight ? 6 : 10),
      ),
    ];
  }
}
