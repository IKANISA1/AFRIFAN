import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'color_tokens.dart';

/// Typography tokens for the Tactile Monolith system.
///
/// - Space Grotesk: display and headline authority
/// - Manrope: editorial titles and body copy
/// - Inter: utility labels and micro-copy
class TypographyTokens {
  TypographyTokens._();

  static const Map<String, double> semanticSizes = {
    'displayLarge': 56.0,
    'displayMedium': 44.0,
    'displaySmall': 36.0,
    'headlineLarge': 32.0,
    'headlineMedium': 28.0,
    'headlineSmall': 24.0,
    'titleLarge': 22.0,
    'titleMedium': 18.0,
    'titleSmall': 16.0,
    'bodyLarge': 16.0,
    'bodyMedium': 15.0,
    'bodySmall': 14.0,
    'labelLarge': 16.0,
    'labelMedium': 14.0,
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
    height: 0.95,
    letterSpacing: -2.2,
  );

  static TextStyle displayMedium([Color? color]) => monolithFont(
    fontSize: semanticSizes['displayMedium'],
    fontWeight: FontWeight.w700,
    color: color ?? ColorTokens.onSurface,
    height: 0.98,
    letterSpacing: -1.8,
  );

  static TextStyle displaySmall([Color? color]) => monolithFont(
    fontSize: semanticSizes['displaySmall'],
    fontWeight: FontWeight.w700,
    color: color ?? ColorTokens.onSurface,
    height: 1.02,
    letterSpacing: -1.3,
  );

  static TextStyle headlineLarge() => monolithFont(
    fontSize: semanticSizes['headlineLarge'],
    fontWeight: FontWeight.w700,
    color: ColorTokens.onSurface,
    height: 1.05,
    letterSpacing: -1.0,
  );

  static TextStyle headlineMedium() => monolithFont(
    fontSize: semanticSizes['headlineMedium'],
    fontWeight: FontWeight.w700,
    color: ColorTokens.onSurface,
    height: 1.08,
    letterSpacing: -0.8,
  );

  static TextStyle headlineSmall() => monolithFont(
    fontSize: semanticSizes['headlineSmall'],
    fontWeight: FontWeight.w700,
    color: ColorTokens.onSurface,
    height: 1.12,
    letterSpacing: -0.5,
  );

  static TextStyle titleLarge([Color? color]) => editorialFont(
    fontSize: semanticSizes['titleLarge'],
    fontWeight: FontWeight.w700,
    color: color ?? ColorTokens.onSurface,
    height: 1.18,
    letterSpacing: -0.3,
  );

  static TextStyle titleMedium() => editorialFont(
    fontSize: semanticSizes['titleMedium'],
    fontWeight: FontWeight.w700,
    color: ColorTokens.onSurface,
    height: 1.24,
    letterSpacing: -0.2,
  );

  static TextStyle titleSmall() => editorialFont(
    fontSize: semanticSizes['titleSmall'],
    fontWeight: FontWeight.w700,
    color: ColorTokens.onSurface,
    height: 1.28,
    letterSpacing: -0.1,
  );

  static TextStyle bodyLarge() => editorialFont(
    fontSize: semanticSizes['bodyLarge'],
    fontWeight: FontWeight.w500,
    color: ColorTokens.onSurface,
    height: 1.55,
  );

  static TextStyle bodyMedium() => editorialFont(
    fontSize: semanticSizes['bodyMedium'],
    fontWeight: FontWeight.w500,
    color: ColorTokens.onSurface,
    height: 1.58,
  );

  static TextStyle bodySmall() => editorialFont(
    fontSize: semanticSizes['bodySmall'],
    fontWeight: FontWeight.w500,
    color: ColorTokens.onSurfaceVariant,
    height: 1.52,
  );

  static TextStyle labelLarge() => utilityFont(
    fontSize: semanticSizes['labelLarge'],
    fontWeight: FontWeight.w700,
    color: ColorTokens.onSurface,
    height: 1.25,
    letterSpacing: 0.4,
  );

  static TextStyle labelMedium() => utilityFont(
    fontSize: semanticSizes['labelMedium'],
    fontWeight: FontWeight.w700,
    color: ColorTokens.onSurfaceVariant,
    height: 1.24,
    letterSpacing: 0.5,
  );

  static TextStyle labelSmall() => utilityFont(
    fontSize: semanticSizes['labelSmall'],
    fontWeight: FontWeight.w700,
    color: ColorTokens.onSurfaceVariant,
    height: 1.22,
    letterSpacing: 0.7,
  );

  static TextStyle numericAlias({double fontSize = 20, Color? color}) =>
      monolithFont(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: color ?? ColorTokens.onSurface,
        letterSpacing: 2.6,
        height: 1.0,
      );
}
