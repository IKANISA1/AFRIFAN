import 'package:flutter/material.dart';

/// Shape tokens — corner radii for all UI elements.
class ShapeTokens {
  ShapeTokens._();

  // ── Corner Radius Values ──
  static const double radiusSm = 4.0; // Numeric alias pills
  static const double radiusMd = 12.0; // Chips, small elements
  static const double radiusLg = 16.0; // Inputs
  static const double radiusXl = 20.0; // Cards (1.5rem)
  static const double radiusFull = 9999.0; // Buttons (pill shape)

  // ── Border Radius Presets ──
  static BorderRadius get chipRadius => BorderRadius.circular(radiusMd);
  static BorderRadius get inputRadius => BorderRadius.circular(radiusLg);
  static BorderRadius get cardRadius => BorderRadius.circular(radiusXl);
  static BorderRadius get buttonRadius => BorderRadius.circular(radiusFull);
  static BorderRadius get aliasPillRadius => BorderRadius.circular(8.0);
}
