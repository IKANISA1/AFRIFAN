import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'color_tokens.dart';

/// Typography tokens — Radical Minimalism through extreme scale.
///
/// - Barlow Condensed: Athletic, high-density feel for display/hero/titles
/// - Inter: Technical clarity for body/meta/labels
///
/// "Anonymous Identity": layouts optimized for 6-digit numeric aliases (e.g. 882-941)
///
/// FONT SIZE FLOORS (§12.1 Design Rules):
///   Body text minimum: 15sp
///   Hero text minimum: 32sp
///   Label minimum: 11sp (metadata only)
class TypographyTokens {
  TypographyTokens._();

  // ══════════════════════════════════════
  // DISPLAY — Barlow Condensed ExtraBold 800
  // For numeric data: XP, Scores, Timers
  // ══════════════════════════════════════

  /// display-lg: 3.5rem (56px) — primary data points
  static TextStyle displayLarge([Color? primaryColor]) =>
      GoogleFonts.barlowCondensed(
        fontSize: 56,
        fontWeight: FontWeight.w800,
        color: primaryColor ?? ColorTokens.onSurface,
        height: 1.1,
        letterSpacing: -1.5,
      );

  /// display-md: 2.75rem (44px)
  static TextStyle displayMedium([Color? primaryColor]) =>
      GoogleFonts.barlowCondensed(
        fontSize: 44,
        fontWeight: FontWeight.w800,
        color: primaryColor ?? ColorTokens.onSurface,
        height: 1.1,
        letterSpacing: -1.0,
      );

  /// display-sm: 2.25rem (36px)
  static TextStyle displaySmall([Color? primaryColor]) =>
      GoogleFonts.barlowCondensed(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: primaryColor ?? ColorTokens.onSurface,
        height: 1.15,
        letterSpacing: -0.5,
      );

  // ══════════════════════════════════════
  // HEADLINES — Barlow Condensed Bold 700
  // ALL CAPS to reinforce authority
  // ══════════════════════════════════════

  static TextStyle headlineLarge() => GoogleFonts.barlowCondensed(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: ColorTokens.onSurface,
    height: 1.2,
    letterSpacing: 1.5,
  );

  static TextStyle headlineMedium() => GoogleFonts.barlowCondensed(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: ColorTokens.onSurface,
    height: 1.2,
    letterSpacing: 1.2,
  );

  static TextStyle headlineSmall() => GoogleFonts.barlowCondensed(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: ColorTokens.onSurface,
    height: 1.25,
    letterSpacing: 1.0,
  );

  // ══════════════════════════════════════
  // TITLES — Barlow Condensed Bold 700
  // Screen headers
  // ══════════════════════════════════════

  static TextStyle titleLarge([Color? primaryColor]) =>
      GoogleFonts.barlowCondensed(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: primaryColor ?? ColorTokens.onSurface,
        height: 1.3,
        letterSpacing: 0.5,
      );

  static TextStyle titleMedium() => GoogleFonts.barlowCondensed(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: ColorTokens.onSurface,
    height: 1.3,
    letterSpacing: 0.3,
  );

  static TextStyle titleSmall() => GoogleFonts.barlowCondensed(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: ColorTokens.onSurface,
    height: 1.3,
    letterSpacing: 0.2,
  );

  // ══════════════════════════════════════
  // BODY — Inter Regular 400
  // Descriptions and running text
  // ══════════════════════════════════════

  static TextStyle bodyLarge() => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: ColorTokens.onSurface,
    height: 1.5,
  );

  static TextStyle bodyMedium() => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: ColorTokens.onSurface,
    height: 1.55,
  );

  static TextStyle bodySmall() => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: ColorTokens.onSurfaceVariant,
    height: 1.45,
  );

  // ══════════════════════════════════════
  // LABELS — Inter SemiBold 600
  // Sub-headers and button labels
  // ══════════════════════════════════════

  static TextStyle labelLarge() => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: ColorTokens.onSurface,
    height: 1.4,
    letterSpacing: 0.5,
  );

  static TextStyle labelMedium() => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: ColorTokens.onSurfaceVariant,
    height: 1.4,
    letterSpacing: 0.6,
  );

  static TextStyle labelSmall() => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: ColorTokens.onSurfaceVariant,
    height: 1.35,
    letterSpacing: 0.7,
  );

  // ══════════════════════════════════════
  // SPECIAL — Numeric Alias Style
  // Monospaced-style tracking for 6-digit IDs
  // ══════════════════════════════════════

  static TextStyle numericAlias({double fontSize = 20, Color? color}) =>
      GoogleFonts.barlowCondensed(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        color: color ?? ColorTokens.onSurface,
        letterSpacing: 3.0,
        height: 1.1,
      );
}
