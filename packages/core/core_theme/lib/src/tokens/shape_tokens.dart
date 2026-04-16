import 'package:flutter/material.dart';

/// Shape tokens — corner radii for all UI elements.
class ShapeTokens {
  ShapeTokens._();

  // ── Corner Radius Values ──
  static const double radiusSm = 4.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusXl = 12.0;
  static const double radiusFull = 9999.0;

  // ── Border Radius Presets ──
  static BorderRadius get chipRadius => BorderRadius.circular(radiusMd);
  static BorderRadius get inputRadius => BorderRadius.circular(radiusLg);
  static BorderRadius get cardRadius => BorderRadius.circular(radiusXl);
  static BorderRadius get buttonRadius => BorderRadius.circular(radiusFull);
  static BorderRadius get aliasPillRadius => BorderRadius.circular(radiusMd);
}
