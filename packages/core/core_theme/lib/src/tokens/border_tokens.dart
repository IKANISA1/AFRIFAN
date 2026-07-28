import 'package:flutter/material.dart';

import 'color_tokens.dart';

/// Border and outline tokens for the universal mobile system.
///
/// The system avoids hard 1px divider lines. When a boundary is needed, it
/// should be expressed as a low-opacity ghost outline sourced from here so
/// the whole app moves together if the fallback treatment changes.
class BorderTokens {
  BorderTokens._();

  static const double hairline = 0.6;
  static const double standard = 1.0;
  static const double focus = 1.2;
  static const double chrome = 1.15;
  static const double chromeFocus = 1.4;
  static const double strong = 1.5;
  static const double emphasis = 2.0;
  static const double tabIndicator = 2.5;

  static Color _resolveColor(Color? color, double opacity) {
    final base = color ?? ColorTokens.ghostBorder;
    return base.withValues(alpha: (base.a * opacity).clamp(0.0, 1.0));
  }

  static BorderSide side({
    Color? color,
    double width = hairline,
    double opacity = 1.0,
  }) {
    return BorderSide(color: _resolveColor(color, opacity), width: width);
  }

  static Border all({
    Color? color,
    double width = hairline,
    double opacity = 1.0,
  }) {
    return Border.all(color: _resolveColor(color, opacity), width: width);
  }

  static Border ghost({double width = hairline, double opacity = 1.0}) {
    return all(color: ColorTokens.ghostBorder, width: width, opacity: opacity);
  }

  static Border focusAll({
    Color? color,
    double width = focus,
    double opacity = 1.0,
  }) {
    return all(
      color: color ?? ColorTokens.primaryContainer,
      width: width,
      opacity: opacity,
    );
  }

  static Border top({
    Color? color,
    double width = hairline,
    double opacity = 1.0,
  }) {
    return Border(
      top: side(color: color, width: width, opacity: opacity),
    );
  }

  static Border sheet({
    Color? color,
    double width = hairline,
    double opacity = 1.0,
  }) {
    return Border(
      top: side(color: color, width: width, opacity: opacity),
      left: side(color: color, width: width, opacity: opacity),
      right: side(color: color, width: width, opacity: opacity),
    );
  }

  static OutlineInputBorder input({
    required BorderRadius borderRadius,
    Color? color,
    double width = hairline,
    double opacity = 1.0,
  }) {
    return OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: side(color: color, width: width, opacity: opacity),
    );
  }
}
