import 'package:flutter/material.dart';

/// Shape tokens — corner radii for all UI elements.
class ShapeTokens {
  ShapeTokens._();

  // ── Corner Radius Values ──
  static const double radiusSm = 18.0; // Tightest allowed tactile corner
  static const double radiusMd = 24.0; // Minimum system radius (1.5rem)
  static const double radiusLg = 32.0; // Inputs, floating surfaces
  static const double radiusXl = 48.0; // Main cards (3rem)
  static const double radiusFull = 9999.0; // Buttons (pill shape)

  // ── Border Radius Presets ──
  static BorderRadius get chipRadius => BorderRadius.circular(radiusMd);
  static BorderRadius get inputRadius => BorderRadius.circular(radiusLg);
  static BorderRadius get cardRadius => BorderRadius.circular(radiusXl);
  static BorderRadius get buttonRadius => BorderRadius.circular(radiusFull);
  static BorderRadius get aliasPillRadius => BorderRadius.circular(radiusMd);
}
