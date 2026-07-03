import 'package:flutter/material.dart';

/// Shape tokens — corner radii for all UI elements.
class ShapeTokens {
  ShapeTokens._();

  // ── Corner Radius Values ──
  static const double radiusSm = 8.0;
  static const double radiusMd = 14.0;
  static const double radiusLg = 20.0;
  static const double radiusXl = 24.0;
  static const double radiusXxl = 32.0;
  static const double radiusFull = 9999.0;

  // ── Border Radius Presets ──
  static BorderRadius get chipRadius => BorderRadius.circular(radiusMd);
  static BorderRadius get inputRadius => BorderRadius.circular(radiusLg);
  static BorderRadius get cardRadius => BorderRadius.circular(radiusSm);
  static BorderRadius get heroCardRadius => BorderRadius.circular(radiusXxl);
  static BorderRadius get chromeRadius => BorderRadius.circular(42);
  static BorderRadius get buttonRadius => BorderRadius.circular(radiusFull);
  static BorderRadius get aliasPillRadius => BorderRadius.circular(radiusMd);
}
