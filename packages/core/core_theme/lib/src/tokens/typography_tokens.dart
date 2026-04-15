import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'color_tokens.dart';

/// Typography tokens for the AFRICLUB minimalist mobile system.
///
/// Space Grotesk remains available for high-impact brand moments, while the
/// day-to-day UI uses a tighter, calmer scale focused on clarity.
class TypographyTokens {
  TypographyTokens._();

  static const Map<String, double> semanticSizes = {
    'displayLarge': 48.0,
    'displayMedium': 40.0,
    'displaySmall': 32.0,
    'headlineLarge': 28.0,
    'headlineMedium': 24.0,
    'headlineSmall': 20.0,
    'titleLarge': 18.0,
    'titleMedium': 16.0,
    'titleSmall': 14.0,
    'bodyLarge': 16.0,
    'bodyMedium': 14.0,
    'bodySmall': 13.0,
    'labelLarge': 14.0,
    'labelMedium': 13.0,
    'labelSmall': 12.0,
  };

  static TextStyle monolithFont({
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return GoogleFonts.spaceGrotesk(
      textStyle: textStyle,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }

  static TextStyle editorialFont({
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return GoogleFonts.manrope(
      textStyle: textStyle,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }

  static TextStyle utilityFont({
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return GoogleFonts.inter(
      textStyle: textStyle,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }

  static TextStyle displayLarge([Color? color]) => monolithFont(
    fontSize: semanticSizes['displayLarge'],
    fontWeight: FontWeight.w700,
    color: color ?? ColorTokens.onSurface,
    height: 0.96,
    letterSpacing: -1.6,
  );

  static TextStyle displayMedium([Color? color]) => monolithFont(
    fontSize: semanticSizes['displayMedium'],
    fontWeight: FontWeight.w700,
    color: color ?? ColorTokens.onSurface,
    height: 0.98,
    letterSpacing: -1.2,
  );

  static TextStyle displaySmall([Color? color]) => monolithFont(
    fontSize: semanticSizes['displaySmall'],
    fontWeight: FontWeight.w700,
    color: color ?? ColorTokens.onSurface,
    height: 1.0,
    letterSpacing: -0.9,
  );

  static TextStyle headlineLarge([Color? color]) => utilityFont(
    fontSize: semanticSizes['headlineLarge'],
    fontWeight: FontWeight.w700,
    color: color ?? ColorTokens.onSurface,
    height: 1.1,
    letterSpacing: -0.5,
  );

  static TextStyle headlineMedium([Color? color]) => utilityFont(
    fontSize: semanticSizes['headlineMedium'],
    fontWeight: FontWeight.w700,
    color: color ?? ColorTokens.onSurface,
    height: 1.14,
    letterSpacing: -0.3,
  );

  static TextStyle headlineSmall([Color? color]) => utilityFont(
    fontSize: semanticSizes['headlineSmall'],
    fontWeight: FontWeight.w700,
    color: color ?? ColorTokens.onSurface,
    height: 1.18,
    letterSpacing: -0.2,
  );

  static TextStyle titleLarge([Color? color]) => utilityFont(
    fontSize: semanticSizes['titleLarge'],
    fontWeight: FontWeight.w600,
    color: color ?? ColorTokens.onSurface,
    height: 1.22,
    letterSpacing: -0.2,
  );

  static TextStyle titleMedium([Color? color]) => utilityFont(
    fontSize: semanticSizes['titleMedium'],
    fontWeight: FontWeight.w600,
    color: color ?? ColorTokens.onSurface,
    height: 1.24,
    letterSpacing: -0.1,
  );

  static TextStyle titleSmall([Color? color]) => utilityFont(
    fontSize: semanticSizes['titleSmall'],
    fontWeight: FontWeight.w600,
    color: color ?? ColorTokens.onSurface,
    height: 1.25,
  );

  static TextStyle bodyLarge([Color? color]) => editorialFont(
    fontSize: semanticSizes['bodyLarge'],
    fontWeight: FontWeight.w500,
    color: color ?? ColorTokens.onSurface,
    height: 1.48,
  );

  static TextStyle bodyMedium([Color? color]) => editorialFont(
    fontSize: semanticSizes['bodyMedium'],
    fontWeight: FontWeight.w500,
    color: color ?? ColorTokens.onSurface,
    height: 1.46,
  );

  static TextStyle bodySmall([Color? color]) => editorialFont(
    fontSize: semanticSizes['bodySmall'],
    fontWeight: FontWeight.w500,
    color: color ?? ColorTokens.onSurfaceVariant,
    height: 1.42,
  );

  static TextStyle labelLarge([Color? color]) => utilityFont(
    fontSize: semanticSizes['labelLarge'],
    fontWeight: FontWeight.w700,
    color: color ?? ColorTokens.onSurface,
    height: 1.18,
    letterSpacing: 0.2,
  );

  static TextStyle labelMedium([Color? color]) => utilityFont(
    fontSize: semanticSizes['labelMedium'],
    fontWeight: FontWeight.w600,
    color: color ?? ColorTokens.onSurface,
    height: 1.15,
    letterSpacing: 0.2,
  );

  static TextStyle labelSmall([Color? color]) => utilityFont(
    fontSize: semanticSizes['labelSmall'],
    fontWeight: FontWeight.w600,
    color: color ?? ColorTokens.onSurfaceVariant,
    height: 1.1,
    letterSpacing: 0.25,
  );

  static TextStyle numericAlias({double fontSize = 18, Color? color}) =>
      utilityFont(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: color ?? ColorTokens.onSurface,
        letterSpacing: 0.3,
      );

  // ── Semantic aliases ──

  /// Section title — medium-weight heading for card and list sections.
  static TextStyle sectionTitle([Color? color]) => utilityFont(
    fontSize: semanticSizes['titleMedium'],
    fontWeight: FontWeight.w600,
    color: color ?? ColorTokens.onSurface,
    height: 1.24,
    letterSpacing: -0.1,
  );

  /// Large metric value (wallet balance, score, stat hero).
  static TextStyle metricValue([Color? color]) => monolithFont(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: color ?? ColorTokens.onSurface,
    height: 1.0,
    letterSpacing: -0.4,
  );

  /// Small uppercase metric label (below stat values).
  static TextStyle metricLabel([Color? color]) => utilityFont(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: color ?? ColorTokens.onSurfaceVariant,
    height: 1.1,
    letterSpacing: 0.6,
  );

  /// Inline action text ("See all", "Open", "More").
  static TextStyle inlineAction([Color? color]) => utilityFont(
    fontSize: semanticSizes['labelMedium'],
    fontWeight: FontWeight.w600,
    color: color ?? ColorTokens.primaryContainer,
    height: 1.15,
    letterSpacing: 0.2,
  );
}

